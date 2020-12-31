# Lifecycle

This tutorial will cover the following topics:

## Content

- [Server](#server)
  - [Server Configuration](#server-configuration)
  - [Basic Authentication](#basic-authentication)
  - [Start / Stop](#start-/-stop)
- [Client](#client)
  - [Client Configuration](#client-configuration)
  - [Connection](#connection)
    - [By URL](#by-url)
    - [By Username](#by-username)
    - [No Session](#no-session)

## Server

The code in this example shows the three parts for OPC UA Server lifecycle management: Creating a Server, set configuration Server and running the Server. Basic use of the [Server](https://hexdocs.pm/opex62541/OpcUA.Server.html) module.

The OPC UA Server is based on a `GenServer`, therefore it can be spawn a new server by using `start_link`.

```elixir
alias OpcUA.Server
{:ok, server_pid} = Server.start_link()
```

### Server Configuration

The easiest way to configure the server is using the `set_default_config/1` function, as shown in the following code:

```elixir
:ok = Server.set_default_config(server_pid)
```

By default the `hostname` is given by the localhost, however it is possible to overwrite its value by using  `set_hostname/2`:

```elixir
:ok = Server.set_hostname(server_pid, "opex-server")
```
**Note**: Be aware of DNS configuration.

It is also possible to change the default port as follows

```elixir
:ok = Server.set_port(server_pid, 4040)
```

**Note**: Default port value is 4840.

### Basic Authentication

Security is a fundamental aspect of OPC UA. It is possible to restrict access to the server by defining authorized users as shown bellow:

```elixir
:ok = Server.set_users(server_pid, [{"alde103", "103alde"}, {"pedro", "ordep"}])
```

In this example we declare two users (alde103 and pedro) with their respective passwords.

**Note**: This is not the best way to secure your OPC UA Server, refer to [Security](https://hexdocs.pm/opex62541/doc/security.html) tutorial for a better approach.

### Start / Stop 

At this point the server will not accept requests yet, use the `start/1` function to explicitly start the server.

```elixir
:ok = Server.start(server_pid)
```

The Server can be stopped with the `stop_server/1` function.

```elixir
:ok = Server.stop_server(server_pid)
```

## Client

The code in this example shows the three parts for OPC UA Client lifecycle management: creating, configuring and connecting a client to a server. Basic use of the [Client](https://hexdocs.pm/opex62541/OpcUA.Client.html) module.

The OPC UA Client is based on a `GenServer`, therefore it can be spawn a new server by using `start_link`.

```elixir
alias OpcUA.Client
{:ok, client_pid} = Client.start_link()
```

### Configuration

The client can be configured using the following function,

```elixir
:ok = Client.set_config(client_pid)
```
it is possible to overwrite some connection parameters (such as timeouts) by using  `set_hostname/2`,

```elixir
config = %{
  "requestedSessionTimeout" => 12000,
  "secureChannelLifeTime" => 6000,
  "timeout" => 500
}
:ok = Client.set_config(client_pid, config)
```

**Note**: Use `get_config/1` function to check the current client configuration.

### Connection

OPC UA provides a client-server communication model that includes status information. This status information is associated with a session.

The user can check the connection status through `get_state/1` function:

```elixir
{:ok,  "Disconnected"} = Client.get_state(client_pid)
```

#### By URL

The Client can connect to a Server by using `connect_by_url/2` and providing the Server's URL as follows:

```elixir
url = "opc.tcp://localhost:4048/"
:ok = Client.connect_by_url(client_pid, url: url)
{:ok,  "Session"} = Client.get_state(client_pid)
```

#### By Username

If the Server has some user restriction, the client must provide the username and password to access the Server, if this is your case use `connect_by_username/2`

```elixir
url = "opc.tcp://localhost:4840/"
user = "alde103"
password = "103adle"
:ok = Client.connect_by_username(client_pid, url: url, user: user, password: password)
```

#### No Session

There may be situations where a session is not required, for those cases use `connect_no_session/2`

```elixir
url = "opc.tcp://localhost:4048/"
:ok = Client.connect_no_session(c_pid, url: url)
{:ok,  "Secure Channel"} = Client.get_state(c_pid)
```