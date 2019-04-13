# LiveView

A Crystal abstract class for building server-rendered HTML components with client-side interactivity.

These live views are framework-agnostic. You can use them with any framework and even without a framework at all. They define `to_s(io)` so you can either build a string out of them or pipe them to an `IO` object (such as your web response).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     live_view:
       github: jgaskins/live_view
   ```

2. Run `shards install`

## Usage

To see a complete example app, check out [`crystal_live_view_example`](https://github.com/jgaskins/crystal_live_view_example)

```crystal
require "live_view"
```

To define a live view, you can inherit from the `LiveView` abstract class:

```crystal
class MyView < LiveView
end
```

In your HTML layout:

```html
  <%= LiveView.script_tag %>
```

### Rendering

To define what to render, you can either use the `render` macro to define the HTML inline or the `template` macro and specify the ECR template to render:

```crystal
class CurrentTime < LiveView
  render "The time is <time>#{Time.now}</time>"
end
```

### Updating the UI

The `update(socket : HTTP::WebSocket)` method will update the client with the new UI:

```crystal
update(socket) # Update with the current state
```

### Hooks

There are 3 hooks:

- `mount(socket : HTTP::WebSocket)` is called when the client makes a successful websocket connection
- `unmount(socket : HTTP::WebSocket)` is called when the websocket is closed
- `handle_event(message : String, data : String, socket : HTTP::WebSocket)` is called when an incoming message is received from the client websocket. The `data` argument will be a `String` in JSON format.

```crystal
def mount(socket)
end

def unmount(socket)
end

def handle_event(message, data, socket)
  case message
  when "increment"
    update(socket) { @count += 1 }
  when "decrement"
    update(socket) { @count -= 1 }
  end
end
```

### Recurrent UI updates

You can use the `every(interval : Time::Span)` method to call `update` at that interval. Use the `mount(socket : HTTP::WebSocket)` hook to set that up when the view mounts:

```crystal
class CurrentTime < LiveView
  render "The time is <time>#{Time.now}</time>"

  def mount(socket)
    every(1.second) { update socket }
  end
end
```

## Performance

- While the client is connected via WebSocket, the view remains in memory. When the client disconnects, the view is discarded.
- LiveViews which either never mount or which encounter errors (such as `IO::Error` breaking communication) will be discarded.
- The client will be given 30-60 seconds to connect after the view has been instantiated, depending on where the system is in the collection cycle.

## Contributing

1. Fork it (<https://github.com/jgaskins/live_view/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jamie Gaskins](https://github.com/your-github-user) - creator and maintainer
