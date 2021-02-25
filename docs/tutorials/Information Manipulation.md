# Information Manipulation

This tutorial will cover the following topics:

## Content

- [Information Model](#information-model)
- [Server](#server)
  - [Address Space](#address-space)
  - [Nodes](#nodes)
    - [Object Nodes](#object-nodes)
    - [Variable Nodes](#variable-nodes)
  - [Read/Write Nodes](#read/write-nodes)
  - [Monitored Items](#monitored-items)
  - [Write Events](#monitored-items)
  - [Examples](#examples)
- [Client](#client)
  - [Read/Write Node](#read/write-node)
  - [Monitored Item](#monitored-item)
  - [Example](#example)

### Information Model

The information model is an abstract representation of the real objects that you need to manage in your application. The same pieces of physical equipment and the associated pieces of information can be modeled in different ways according to the specific process and environment requirements.

The basic principles of information modeling in OPC UA are as follows:
* Use of object-oriented techniques, including hierarchies and inheritance.
* The same mechanism is used to access the types and the instances.
* The hierarchies of the data types and the links between the nodes are extendable.
* There are no limitations on how to model information.
* Information modeling is always placed on the server-side.

## Server

Assuming that an OPC UA Server has been created and configured as shown in [Lifecycle](https://hexdocs.pm/opex62541/doc/lifecycle.html) tutorial.

### Address Space

The set of objects and related information that an OPC UA server makes available to the clients is the address space. The address space of the OPC UA is a set of nodes that are connected by references. Each node has properties, which are called attributes. In this library, we use one namespace per address space, so we will use the namespace to refer to an address space.

To add a new namespace to your server use `add_namespace/2`:

```elixir
alias OpcUA.{NodeId, QualifiedName, Server}
{:ok, ns_index} = Server.add_namespace(server_pid, "Room")
```

These functions take a configured OPC UA Server PID and an identifier as a unique string. It will return an index to be used as a reference to create the related nodes.

### Nodes

In OPC UA, every entity in the address space is a node. To uniquely identify a Node, each node has a NodeId; to create new NodeId's, use the [NodeId](https://hexdocs.pm/opex62541/OpcUA.NodeId.html) module, for example:

```elixir
requested_new_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 1000)
```
In this example, we have created a NodeId corresponding to `i=1000` (namespace index 0, numeric identifier, id 1000, according to OPC UA XML Schema)

**Note**: You can use the [zero namespace index](https://github.com/OPCFoundation/UA-Nodeset/blob/v1.04/Schema/NodeIds.csv) when you are referring to builtin nodes.

There are eight standard node classes: variable, object, method, view, data type, variable type, object type, and reference type. However, for this tutorial, we will describe an example of how to define object nodes and variable nodes.

**Note**: Currently, only the method node is not supported yet.

For this tutorial, we will model a temperature sensor by creating an object node of the sensor and a variable node representing the temperature.

#### Object Nodes

The object node class structures the address space and can be used to group variables, methods, or other objects.

```elixir
requested_new_node_id = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature-Sensor")
parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85)
reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 35)
browse_name = QualifiedName.new(ns_index: ns_index, name: "Temperature sensor")
type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)

:ok = Server.add_object_node(server_pid,
  requested_new_node_id: requested_new_node_id,
  parent_node_id: parent_node_id,
  reference_type_node_id: reference_type_node_id,
  browse_name: browse_name,
  type_definition: type_definition
)
```

For this case, we are define an object node as a `BaseObjectType` defined by `type_definition` (wildcard for object nodes `i=58`) with a `ns=1;s=R1_TS1_Temperature-Sensor` NodeId (OPC UA XML Schema) using `requested_new_node_id`, which parent node is an `ObjectsFolder` (`parent_node_id i=85`), it uses a `Organizes`(`i=35`) relationship and the clients should see the object node as `Temperature sensor` defined by `browse_name`.

**Note**: All nodes that use ns_index: 0 are [zero namespace nodes id index](https://github.com/OPCFoundation/UA-Nodeset/blob/v1.04/Schema/NodeIds.csv), which means that they are defined by OPC UA standard.

#### Variable Nodes

The variable node class represents a value. Clients can read, write, or subscribe to it (monitored items).

Now we are going to add a variable node (to holds the `Temperature` value) to our object node just as shown in the following example:

```elixir
requested_new_node_id = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")
parent_node_id = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature-Sensor")
reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47)
browse_name = QualifiedName.new(ns_index: ns_index, name: "Temperature")
type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)

:ok = Server.add_variable_node(server_pid,
  requested_new_node_id: requested_new_node_id,
  parent_node_id: parent_node_id,
  reference_type_node_id: reference_type_node_id,
  browse_name: browse_name,
  type_definition: type_definition
)
```

For this case, we are define an object node as a `BaseDataVariableType` defined by `type_definition` (wildcard for variable nodes `i=63`) with a `ns=1;s=R1_TS1_Temperature` NodeId (OPC UA XML Schema) using `requested_new_node_id`, which parent node is the  `R1_TS1_Temperature-Sensor`defined previously, it uses a `HasComponent`(`i=47`) relationship and the clients should see the variable node as `Temperature` defined by `browse_name`.

### Read/Write Nodes

Depending on the type of node (object, variable, reference, etc.), it's [attributes](https://documentation.unified-automation.com/uasdkhp/1.0.0/html/_l2_ua_node_classes.html) can change. When the node is created, its attributes will have a default value. However, you can read and write its value using the [Server](https://hexdocs.pm/opex62541/OpcUA.Server.html) module. The following example changes the access level and the value of the node.

```elixir
node_id = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")
# CurrentWrite, CurrentRead
:ok = Server.write_node_access_level(server_pid, node_id, 3)
{:ok, 3} = Server.read_node_access_level(server_pid, node_id)

# Change the Node Value.
:ok = Server.write_node_value(server_pid, node_id, 0, true)
{:ok, true} = Server.read_node_value(server_pid, node_id)

:ok = Server.write_node_value(server_pid, node_id, 1, 103)
{:ok, 103} = Server.read_node_value(server_pid, node_id)
```

First, we set the `access_level` to `CurrentWrite` and `CurrentRead` (3). Therefore the client has access to its value. Then we change the value from a `Boolean` (0) to a `Byte` (1) value (this is possible thanks to the variable wildcard that we use before).

**Note**: It is recommended to change the writing mask and the access level node attributes.

The `data_type` and `value` argument of `write_node_value/4` must be congruent, therefore, it is recommended to review the official [data types](https://opcfoundation.org/UA/schemas/1.04/Opc.Ua.Types.bsd).

### Monitored Items

Clients can subscribe to variable nodes through `monitored items`. A monitored item is used to request an OPC UA server for notifications of each change of value in a specific node.

```elixir
node_id = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")
# Add Temperature as a Monitored Item
{:ok, 1} = Server.add_monitored_item(server_pid, monitored_item: node_id, sampling_time: 1000.0)
# Deletes Monitored Item
:ok = Server.delete_monitored_item(server_pid, 1)
```

### Write Event Nodes

Each time a node value is updated, the Server module sends a message to the parent process in de form of {node_id, value}

Therefore, this feature can be handled by a module, as illustrated in the following example:

```elixir
defmodule MyServer do
  use OpcUA.Server
  require Logger

  def handle_write({node_id, value}, state) do
    Logger.debug("Value changed #{value} in #{node_id} Node")
    state
  end
end
```

### Examples

More examples can be found in the source code [tests](https://github.com/valiot/opex62541/tree/master/test/server_tests).

## Client

Assuming that an OPC UA Client has been created, configured, and connected to an OPC UA Server as shown in [Lifecycle](https://hexdocs.pm/opex62541/doc/lifecycle.html) tutorial.

### Read/Write Node

You can read and write its attribute value by using the [Client](https://hexdocs.pm/opex62541/OpcUA.Client.html) module. The following example changes the value of the node.

```elixir
node_id = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")
# Writes a Byte
:ok = Client.write_node_value(client_pid, node_id, 1, 21)
# Reads a Byte
{:ok, 21} = Client.read_node_value(client_pid, node_id)
```

### Monitored Item

To request a monitored item to a server, the client must first request a subscription request. Then the client must request the monitored item.

```elixir
node_id = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")
# Creates a subscription channels.
{:ok, 1} = Client.add_subscription(client_pid)
# Request a monitored item.
{:ok, 1} = Client.add_monitored_item(client_pid, monitored_item: node_id, subscription_id: 1)
```

### Example

More examples can be found in the source code [tests](https://github.com/valiot/opex62541/tree/master/test/client_tests).
