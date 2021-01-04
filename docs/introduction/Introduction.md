# Introduction

## Content

- [OPC UA](#opc-ua)
- [Tutorials](#tutorials)
  - [Lifecycle](#lifecycle)
  - [Security](#security)
  - [Discovery](#discovery)
  - [Information Manipulation](#information-manipulation)
  - [Elixir Integration](#elixir-integration)
- [Development](#development)

## OPC UA

OPC UA (Unified Architecture) extends the great success of the OPC communication protocol, for data acquisition, information modeling (object-oriented) and communication between plant and applications (client-server) in a reliable and secure way. OPC UA is based on a service-oriented approach defined by the IEC 62451 standard.

Opex62541 wraps basic functions of OPC UA client and server.

## Tutorials

The purpose of the following sections is to provide a guided tour of how to use the this library in simple applications.

First we will explain the most important features and the manual way to use the library (such as configuration, connectivity, data modeling and execution).

And finally we will show automatic methods to configure and integrate the library with elixir module.

### Lifecycle

This section shows how the life cycle of a OPC UA client and server should be executed. We will see configuration and connectivity topics. 

### Security

Next, we will focus on adding a more robust security layer. We will show you the security modes we support and how to configure them.

### Discovery

We will discuss the interaction between an OPC UA client or server and a network, i.e. on the server side, how to become visible to clients and on the client side, how to scan the network to identify a server. In this section we will configure a Local Discovery Server (LDS), register a server in it and retrieve information.

### Information Manipulation

We will explore the ways in which the information is modeled in OPC UA, the methods to add the model to the server and how clients can extract the data. Topics such as Address space, Nodes, Monitored Items etc. will be covered.

### Elixir Integration

Finally, we will discuss a callback-based interface that facilitates the configuration and integration between the server or client and an elixir module.

## Development

Opex62541 is an Elixir wrapper for the open62541 library (C Code), therefore, two middlewares ([opc_ua_client.c](https://github.com/valiot/opex62541/blob/master/src/opc_ua_client.c) and [opc_ua_server.c](https://github.com/valiot/opex62541/blob/master/src/opc_ua_server.c)) were made to execute open62541 API functions based on stdio messages, this communication between Elixir and C middleware is establish by creating a port ([Erlang's Port Module](http://erlang.org/doc/tutorial/c_port.html)), which allows possible errors in the C code to be contained.