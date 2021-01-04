# Elixir Integration

## Content
- [Integration](#integration)
- [Server](#server)  
  - [Server Configuration](#server-configuration)
  - [Address Space](#address-space)
  - [Write Events](#write-events)
  - [Examples](#examples)
- [Client](#client)
  - [Client Configuration](#client-configuration)
  - [Monitored Item](#monitored-item)
  - [Subscription](#subscription)
  - [Example](#example)

## Integration

Both, Server and Client modules are implemented as a `__using__` macro, so you can put it in any module;
you only need to add the defined callbacks to integrate this library to your project.

Either way, it is always possible to use Server and Client modules directly as shown in previous tutorials.

## Server

For convinience, `Server` is a `GenServer` wrapper for automating configuration and adding the address space (information model); it also accepts the same [options](https://hexdocs.pm/elixir/GenServer.html#module-how-to-supervise) for supervision to configure the child spec and passes them along to `GenServer`, for example:

```elixir
use OpcUA.Server, restart: :transient, shutdown: 10_000
```

with this instruction the Server backend will be integrated in you own application module, now you only have to add the callbacks you require.

The basic callback is the `init/2` that let you maniplulate the OPC UA server by given its PID (opc_ua_server_pid) with some user data (user_init_state):

```elixir
# Use the `init` function to configure your server.
def init(user_init_state, opc_ua_server_pid) do
  # Do some initial process and start the server at your convenience.
  Server.start(opc_ua_server_pid)
  # You can set a new state for your app (if require it).
  user_init_state
end
```

**Note**: No callback automatically starts the OPC UA server, so it is recommended to use `init\2` because is the last callback to be executed.

### Server Configuration

The first executed optional callback is `configuration/1`, it gets and execute the Server configuration and discovery connection parameters as follows:

```elixir
def configuration(_user_init_state) do
  [
    config: [
      port: 4041,
      users: [{"alde103", "secret"}]
    ]
  ]
end
```

In this example the server will use the port `4041` with predefined user, the `user_init_state` is propagated to this callback too.

**Note**: The output of this callbacks must be a list (type config_options) as shown in the [Server](https://hexdocs.pm/opex62541/OpcUA.Server.html) module.

### Address Space

The next executed optional callback is `address_space/1`, it gets and adds all nodes (namespaces, object nodes, variable nodes, monitored items) to the Server as follows:

```elixir
def address_space(_user_init_state) do
  [
    namespace: "Sensor",
    object_node: OpcUA.ObjectNode.new(
      [
        requested_new_node_id: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Sensor"),
        parent_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85),
        reference_type_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 35),
        browse_name: QualifiedName.new(ns_index: 2, name: "Temperature sensor"),
        type_definition: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)
      ]
    ),
    variable_node: OpcUA.VariableNode.new(
      [
        requested_new_node_id: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Temperature"),
        parent_node_id: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Sensor"),
        reference_type_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47),
        browse_name: QualifiedName.new(ns_index: 2, name: "Temperature"),
        type_definition: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)
      ],
      write_mask: 0x3FFFFF,
      value: {10, 103.0},
      access_level: 3
    ),
    monitored_item: OpcUA.MonitoredItem.new(
      [
        monitored_item: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Temperature"),
        sampling_time: 1000.0,
        subscription_id: 1
      ]
    )
  ]
end
```

In this example, it emulates a temperature sensor based on an object node (`R1_TS1_Sensor`) with a variable node (`R1_TS1_Temperature`) to display the temperature which is registrated as a monitored item, the `user_init_state` is also propagated to this callback too.

**Note**: The output of this callbacks must be a list (type address_space_list) as shown in the [Server](https://hexdocs.pm/opex62541/OpcUA.Server.html) module. The order matters according to the node dependency, in this example, the parent node of the variable node is an object node, if the object node is not defined at the variable node definition time the server will crash.

### Write Events

An runtime callback is `handle_write/2`, it handles every Client writing events to any Server node, as follows:

```elixir
def handle_write(write_event, state) do
  # Do something with the write event ({node_id, value} = write_event)
  # and your module state (state)
  state
end
```

### Examples

The following example shows a module that takes its configuration from the environment:

```elixir
defmodule MyServer do
  use OpcUA.Server
  alias OpcUA.{NodeId, Server, QualifiedName}

  # Use the `init` function to configure your server.
  def init(user_init_state, opc_ua_server_pid) do
    # Do some initial process and start the server at your convenience.
    Server.start(opc_ua_server_pid)
    # You can set a new state for your app.
    user_init_state
  end

  def configuration(_user_init_state), do: Application.get_env(:opex62541, :configuration, [])
  def address_space(_user_init_state), do: Application.get_env(:opex62541, :address_space, [])

  def handle_write(write_event, %{parent_pid: parent_pid} = state) do
    send(parent_pid, write_event)
    state
  end
end
```

This code can be excuted as

```elixir
{:ok, my_pid} = MyServer.start_link({self(), 103} = _user_init_state)
```

More examples can be found in the source code [tests](https://github.com/valiot/opex62541/tree/master/test/server_tests).

## Client

The `Client` module can be initialized manually (as shown in previous tutorials) or by overwriting `configuration/1` and `monitored_items/1` callbacks to autoset the configuration and subscription items. It also helps you to handle Client's "subscription" events (monitorItems) by overwriting `handle_subscription/2` callback.

Like the `Server` module, the `Client` module is also based on a `GenServer` behavior, therefore it accepts the same [options](https://hexdocs.pm/elixir/GenServer.html#module-how-to-supervise) for supervision to configure the child spec and passes them along to `GenServer`; to add the `Client` behavior to your application use the folling code:

```elixir
  use OpcUA.Client, restart: :transient, shutdown: 10_000
```

The basic callback is the `init/2` that let you maniplulate the OPC UA client by given its PID (opc_ua_server_pid) with some user data (user_init_state):

```elixir
# Use the `init` function to configure your client.
def init({parent_pid, 103} = _user_init_state, opc_ua_client_pid) do
  # this will be your app state
  %{parent_pid: parent_pid, opc_ua_client_pid: opc_ua_client_pid}
end
```

### Client Configuration

The first executed optional callback is `configuration/1`, it gets and execute the Client configuration and handles server connection parameters as follows:

```elixir
def configuration(_user_init_state) do
  {:ok, localhost} = :inet.gethostname()
  [
    config: [
      set_config: %{
        "requestedSessionTimeout" => 1200000,
        "secureChannelLifeTime" => 600000,
        "timeout" => 50000
      }
    ],
    conn: [
      by_username: [
        url: "opc.tcp://#{localhost}:4041/",
        user: "alde103",
        password: "secret"
      ]
    ]
  ]
end
```

In this example the client will use a predefined timeout and connection (url, user, etc.) paramters, the `user_init_state` is propagated to this callback too.

**Note**: The output of this callbacks must be a list (type config_options) as shown in the [Client](https://hexdocs.pm/opex62541/OpcUA.Client.html) module.

### Monitored Item

The next optional callback to be executed is `monitored_items/1`, it gets and adds all nodes (namespaces, object nodes, variable nodes, monitored items) to the Server, for example:

```elixir
def monitored_items(_user_init_state) do
  [
    subscription: 200.0,
    monitored_item: OpcUA.MonitoredItem.new(
      [
        monitored_item: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Temperature"),
        sampling_time: 100.0,
        subscription_id: 1
      ]
    )
  ]
end 
```

In this example, the client automatically sends a subscription request (with a publishing interval of 200.0 ms) and a monitored item request (`R1_TS1_Temperature`) , the `user_init_state` is also propagated to this callback too.

**Note**: The output of this callbacks must be a list (type address_space_list) as shown in the [Client](https://hexdocs.pm/opex62541/OpcUA.Client.html) module.


An runtime callback is `handle_monitored_data/2`, it handles every Server events triggered by a monitored item data, as follows:

```elixir
def handle_monitored_data(monitored_item_event, state) do
  # Do something with the event ({subscription_id, monitored_id, value} = monitored_item_event)
  # and your module state (state)
  state
end
```

Another runtime callback is `handle_deleted_monitored_item/2`, it handles the withdrawal events of monitored items from the server, for example:

```elixir
def handle_deleted_monitored_item(subscription_id, monitored_id, state) do
  # Do something with this event ({subscription_id, monitored_id, value} = monitored_item_event)
  # and your module state (state)
  state
end
```

### Subscription

Subscriptions are automatically created by the library, however, there are some callbacks to handle unexpected events, as shown bellow:

```elixir
def handle_subscription_timeout(subscription_id, state) do
  # Do something with this event (subscription_id is integer)
  # and your module state (state)
  state
end
```

The `handle_deleted_subscription/2`, it handles the withdrawal events of subscriptions from the server, for example:

```elixir
def handle_deleted_subscription(subscription_id, state) do
  # Do something with this event (subscription_id is integer)
  # and your module state (state)
  state
end
```


### Example

The following example shows a module that takes its configuration from the environment and notifies any client event to its parent process:

```elixir
defmodule MyClient do
  use OpcUA.Client
  alias OpcUA.Client

  # Use the `init` function to configure your Client.
  def init({parent_pid, 103} = _user_init_state, opc_ua_client_pid) do
    %{parent_pid: parent_pid, opc_ua_client_pid: opc_ua_client_pid}
  end

  def configuration(_user_init_state), do: Application.get_env(:my_client, :configuration, [])
  def monitored_items(_user_init_state), do: Application.get_env(:my_client, :monitored_items, [])

  def handle_subscription_timeout(subscription_id, state) do
    send(state.parent_pid, {:subscription_timeout, subscription_id})
    state
  end

  def handle_deleted_subscription(subscription_id, state) do
    send(state.parent_pid, {:subscription_delete, subscription_id})
    state
  end

  def handle_monitored_data(changed_data_event, state) do
    send(state.parent_pid, {:value_changed, changed_data_event})
    state
  end

  def handle_deleted_monitored_item(subscription_id, monitored_id, state) do
    send(state.parent_pid, {:item_deleted, {subscription_id, monitored_id}})
    state
  end

  def read_node_value(pid, node), do: GenServer.call(pid, {:read, node}, :infinity)

  def get_client(pid), do: GenServer.call(pid, {:get_client, nil})

  def handle_call({:read, node}, _from, state) do
    resp = Client.read_node_value(state.opc_ua_client_pid, node)
    {:reply, resp, state}
  end

  def handle_call({:get_client, nil}, _from, state) do
    {:reply, state.opc_ua_client_pid, state}
  end
end
```
This code can be excuted as

```elixir
{:ok, c_pid} = MyClient.start_link({self(), 103})
```

More examples can be found in the source code [tests](https://github.com/valiot/opex62541/tree/master/test/client_tests).