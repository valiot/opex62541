# Security

This tutorial will cover the following topics:

## Content

- [Security Model](#security-model)
- [Server](#server)
  - [Manual Configuration](#manual-configuration)
- [Client](#client)
  - [Security Modes](#connection)

## Security Model

The OPC UA security model is implemented through the definition of a secure channel, on which a session is based. A secure channel has the following features:
* Digital signatures ensures the integrity of the data.
* Encryption ensures confidentiality.
* Authentication and authorization of applications by using X.509 certificates.

A secure channel is related to a endpoint and each server offers one or more endpoints.
Each endpoint has the following features:
* Server application instance certificate: This is the public key of the server used by the client to make the exchange of data secure.
* Security policy: A set of algorithms used in security mechanisms.
* Security mode: There are three different modes: None, Sign or SignAndEncrypt.
* Authentication: The mechanisms used to authenticate a user during the creation of a session (by username, a certificate, or anonymous authentication).
* Transport protocol: Defines the network protocol that is going to be used.
* Endpoint URL: The network address used by the client to establish a secure channel with the endpoint.

Since this feature requires certificates to work, it is the user's responsibility to provide a valid certificate to the server or client.

## Server

Assuming that an OPC UA Server has been created as shown in [Lifecycle](https://hexdocs.pm/opex62541/doc/lifecycle.html) tutorial.

The easiest way to configure the security requirements of the server is by using the `set_default_config_with_certs/2` function, as shown in the following code:

```elixir
alias OpcUA.Server

certs_config = [
  port: 4840,
  certificate: File.read!("./certs/server_cert.der"),
  private_key: File.read!("./certs/server_key.der")
]

:ok = Server.set_default_config_with_certs(server_pid, certs_config)
```

## Manual Configuration

By default, the previous method sets all internal basic configuration, a tcp network layer (with port 4840) and all supported security policies, however this configuration can be done manually to fit your application.

Next we will detail step by step how to set the manual configuration as follows:

**Step 1:**  Set the internal (open62451) basics:
  
```elixir
:ok = Server.set_basics(server_pid)
```

**Step 2:**  Set the Transport Protocol with a given port (4041, for example):
  
```elixir
:ok = Server.set_network_tcp_layer(server_pid, 4041)
```

**Step 3:**  Set the Security Policies, Currently this library supports the following:
  * None.
  * Basic128Rsa15.
  * Basic256
  * Basic256Sha256.

The following code adds the security policy ``SecurityPolicy#None`` to the server.

```elixir
certs_info = [
  certificate: File.read!("./certs/server_cert.der")
]

:ok = Server.add_none_policy(server_pid, certs_info)
```

To add the security policy ``SecurityPolicy#Basic128Rsa15`` to the server use the next code,

```elixir
certs_info = [
  certificate: File.read!("./certs/server_cert.der"),
  private_key: File.read!("./certs/server_key.der")
]

:ok = Server.add_basic128rsa15_policy(server_pid, certs_info)
```

the next code adds the security policy ``SecurityPolicy#Basic256`` to the server,

```elixir
certs_info = [
  certificate: File.read!("./certs/server_cert.der"),
  private_key: File.read!("./certs/server_key.der")
]

:ok = Server.add_basic256_policy(server_pid, certs_info)
```

the security policy ``SecurityPolicy#Basic256Sha256`` can be added to the server using `add_basic256sha256_policy/2`, 

```elixir
certs_info = [
  certificate: File.read!("./certs/server_cert.der"),
  private_key: File.read!("./certs/server_key.der")
]

:ok = Server.add_basic256sha256_policy(server_pid, certs_info)
```

using `add_all_policies/2` adds all supported security policies and sets up certificate validation procedures.

```elixir
certs_info = [
  certificate: File.read!("./certs/server_cert.der"),
  private_key: File.read!("./certs/server_key.der")
]

:ok = Server.add_all_policies(server_pid, certs_info)
```

**Step 4:** Finally the following code adds an endpoint for every configured security policy to the server.
  
```elixir
:ok = Server.add_all_endpoints(server_pid, 4041)
```

## Client

Assuming that an OPC UA Client has been created as shown in [Lifecycle](https://hexdocs.pm/opex62541/doc/lifecycle.html) tutorial. The certificate and private key can be set as follow:

```elixir
certs_config = [
  security_mode: 2,
  certificate: File.read!("./certs/client_cert.der"),
  private_key: File.read!("./certs/client_key.der")
]

:ok = Client.set_config_with_certs(client_pid, certs_config)
```

## Security Modes

If the certificate is reliable, the client sends an Open Secure Channel request in line with the security policy and the security mode of the selected session endpoint; in the `set_config_with_certs/2` the `security_mode` option only accepts integers ([1, 2, 3]) and represents the following:
* None (1), the request will be sent without any security mechanisms.
* Sign (2), the request will be sent using the private key of the client as a signature.
* SignAndEncrypt (3), the request will be sent after encrypting it using the public key of the server.

Once the client is configured, you can connect the client to the server using the functions exposed in the [Lifecycle](https://hexdocs.pm/opex62541/doc/lifecycle.html) tutorial.