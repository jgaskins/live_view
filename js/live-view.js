(() => {
  var converter = preactHtmlConverter.PreactHTMLConverter();
  var html = converter.convert;

  var url = new URL(location.href);
  url.protocol = url.protocol.replace('http', 'ws');
  url.pathname = '/live-view';
  var live_view = new WebSocket(url);
  live_view.addEventListener('open', event => {
    // Hydrate client-side rendering
    document.querySelectorAll('[data-live-view]')
      .forEach(view => {
        var node = html(view.innerHTML)[0];
        preact.render(node, view, view.children[0]);
        live_view.send(JSON.stringify({
          subscribe: view.getAttribute('data-live-view'),
        }))
      });
  });

  live_view.addEventListener('message', event => {
    var data = event.data;
    var { id, render } = JSON.parse(data);

    document.querySelectorAll(`[data-live-view="${id}"]`)
      .forEach(view => {
        preact.render(html('<div>' + render + '</div>')[0], view, view.children[0]);
      });
  });

  live_view.addEventListener('close', event => {
    // Do we need to do anything here?
  });

  [
    'click',
    'change',
    'input',
  ].forEach(event_type => {
    document.addEventListener(event_type, event => {
      var element = event.target;
      var event_name = element.getAttribute('live-' + event_type);

      if(typeof event_name === 'string') {
        var channel = event
          .target
          .closest('[data-live-view]')
          .getAttribute('data-live-view')

        var data = {};
        switch(element.type) {
          case "checkbox": data = { value: element.checked }; break;
          // Are there others?
          default: data = { value: element.getAttribute('live-value') || element.value }; break;
        }

        live_view.send(JSON.stringify({
          event: event_name,
          data: JSON.stringify(data),
          channel: channel,
        }));
      }
    });
  });
})();
