# Discovery

This tutorial will cover the following topics:

## Content

- [Local Discovery Server](#local-discovery-server)
- [Server](#server)
  - [LDS Configuration](#lds-configuration)
  - [Registration](#registration)
- [Client](#client)
  - [Scanning Network](#scan-network)

## Local Discovery Server

The Local Discovery Server (LDS) provides the necessary infrastructure to publicly expose the OPC UA Servers available on a given computer.

OPC UA Servers will periodically connect to the LDS and Register themselves as being available. This periodic activity means that the list of available OPC UA servers is always current and means that an OPC UA client can immediately connect to any of them.

## Server

Assuming that an OPC UA Server has been created and configured as shown in [Lifecycle](https://hexdocs.pm/opex62541/doc/lifecycle.html) tutorial.

## LDS Configuration

To spawn an LDS server, follow these steps.

```elixir
alias OpcUA.Server

{:ok, lds_pid} = Server.start_link()

:ok = Server.set_default_config(lds_pid)

application_uri = "urn:opex62541.test.local_discovery_server"
:ok = Server.set_lds_config(lds_pid, application_uri)
```

**Note**: LDS Servers only supports the Discovery Services. Therefore, it cannot be used in combination with any other capability.

## Registration

The LDS maintains a list of available servers which servers may use to announce their existence to clients. Any other server can register with this server using `discovery_register/2` function as shown below:

```elixir
alias OpcUA.Server

{:ok, server_pid} = Server.start_link()

:ok = Server.set_default_config(server_pid)

application_uri = "urn:opex62541.test.local_register_server"
:ok = Server.discovery_register(server_pid,
        application_uri: application_uri,
        server_name: "TestRegister",
        endpoint: "opc.tcp://localhost:4840"
      )
```
The `endpoint` option represents the LDS endpoint, and the `server_name` is how the registered server will be visible in the network.

The `discovery_unregister` can be used to delete the desired server from the LDS server.

```elixir
:ok = Server.discovery_unregister(server_pid)
```

## Client

Clients may request a list of all available servers from the discovery server (LDS) and then use the GetEndpoints service to get the connection information from a server.

Assuming you have an LDS server with a registered server

```elixir
alias OpcUA.Server

#LDS Server
{:ok, lds_pid} = Server.start_link()
:ok = Server.set_port(lds_pid, 4050)
:ok = Server.set_lds_config(lds_pid, "urn:opex62541.test.local_discovery_server")
:ok = Server.start(lds_pid)

#Normal OPC UA Server
{:ok, s_pid} = Server.start_link()
:ok = Server.set_port(s_pid, 4048)

:ok = Server.discovery_register(s_pid,
        application_uri: "urn:opex62541.test.local_register_server",
        server_name: "testRegister",
        endpoint: "opc.tcp://localhost:4050"
      )
:ok = Server.start(s_pid)

# Registration time
Process.sleep(1500)
```

### Scanning Network

To discover all OPC UA Server in the network, you can use `find_servers_on_network/2`,

```elixir
alias OpcUA.Client

{:ok, c_pid} = Client.start_link()
:ok = Client.set_config(c_pid)

# LDS Server url
url = "opc.tcp://localhost:4050/"

Client.find_servers_on_network(c_pid, url)

# this response may change depending on your computer
{:ok,
 [
   %{
     "capabilities" => ["LDS"],
     "discovery_url" => "opc.tcp://localhost:4050",
     "record_id" => 0,
     "server_name" => "LDS-localhost"
   },
   %{
     "capabilities" => ["NA"],
     "discovery_url" => "opc.tcp://localhost:4048",
     "record_id" => 1,
     "server_name" => "testRegister-localhost"
   }
 ]}
```
If you require more detailed information, you can use the `find_server/2` function.

```elixir
Client.find_servers(c_pid, url)

# this response may change depending on your computer
{:ok,
  [
    %{
      "discovery_url" => ["opc.tcp://localhost:4050/"],
      "name" => "open62541-based OPC UA Application",
      "product_uri" => "http://open62541.org",
      "application_uri" => "urn:opex62541.test.local_discovery_server",
      "server" => "urn:opex62541.test.local_discovery_server",
      "type" => "discovery_server"
    },
    %{
      "application_uri" => "urn:opex62541.test.local_register_server",
      "discovery_url" => [
        "opc.tcp://localhost:4048/",
        "opc.tcp://localhost:4048/"
      ],
      "name" => "open62541-based OPC UA Application",
      "product_uri" => "http://open62541.org",
      "server" => "urn:opex62541.test.local_register_server",
      "type" => "server"
    }
  ]}
```

Finally, to get the server endpoints, you can use the `get_endpoints/2` function.

```elixir

url = "opc.tcp://localhost:4048"
Client.get_endpoints(c_pid, url)

# this response may change depending on your computer
{:ok,
  [
    %{
      "endpoint_url" => "opc.tcp://localhost:4048",
      "security_level" => 1,
      "security_mode" => "none",
      "security_profile_uri" => "http://opcfoundation.org/UA/SecurityPolicy#None",
      "transport_profile_uri" =>
        "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"
    }
  ]}
```

