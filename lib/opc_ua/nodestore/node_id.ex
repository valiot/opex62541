defmodule OpcUA.NodeId do
  use IsEnumerable
  use IsAccessible

  @moduledoc """
  An identifier for a node in the address space of an OPC UA Server.

  An OPC UA information model is made up of nodes and references between nodes.
  Every node has a unique NodeId. NodeIds refer to a `namespace` with an additional
  `identifier` value that can be an integer, a string, a guid or a bytestring depending on the selected
  `identifier_type`.
  """
  alias OpcUA.NodeId
  @enforce_keys [:ns_index, :identifier_type, :identifier]
  @identifier_types ["integer", "string", "guid", "bytestring"]


  defstruct ns_index: nil,
            identifier_type: nil,
            identifier: nil

  @doc """
  Creates an structure for a node in the address space of an OPC UA Server.
  """
  @spec new(list()) :: %NodeId{}
  def new(ns_index: ns_index, identifier_type: id_type, identifier: identifier) when is_integer(ns_index) and id_type in @identifier_types do
    new_node_id(ns_index, id_type, identifier)
  end
  def new(_invalid_data), do: raise("Invalid Namespace index or identifier type")

  defp new_node_id(ns_index, "integer", identifier) when is_integer(identifier),
    do: %NodeId{ns_index: ns_index, identifier_type: 0, identifier: identifier}

  defp new_node_id(ns_index, "string", identifier) when is_binary(identifier),
    do: %NodeId{ns_index: ns_index, identifier_type: 1, identifier: identifier}

  defp new_node_id(ns_index, "guid", {_data1, _data2, _data3, data4} = identifier) when is_tuple(identifier) and is_binary(data4),
    do: %NodeId{ns_index: ns_index, identifier_type: 2, identifier: identifier}

  defp new_node_id(ns_index, "bytestring", identifier) when is_binary(identifier),
    do: %NodeId{ns_index: ns_index, identifier_type: 3, identifier: identifier}

  defp new_node_id(_ns_index, _id_type, _identifier), do: raise("Identifier type does not match with identifier data_type")
end

defmodule OpcUA.ExpandedNodeId do
  use IsEnumerable
  use IsAccessible

  @moduledoc """
  A NodeId that allows the namespace URI to be specified instead of an index.
  """
  alias OpcUA.{ExpandedNodeId, NodeId}
  @enforce_keys [:node_id, :name_space_uri, :server_index]

  defstruct node_id: nil,
            name_space_uri: nil,
            server_index: nil

  @doc """
  Creates an structure for an expanded node in the address space of an OPC UA Server.
  """
  @spec new(list()) :: %ExpandedNodeId{}
  def new(node_id: %NodeId{} = node_id, name_space_uri: name_space_uri, server_index: server_index) when is_binary(name_space_uri) and is_integer(server_index) do
    %ExpandedNodeId{node_id: node_id, name_space_uri: name_space_uri, server_index: server_index}
  end
  def new(_invalid_data), do: raise("Invalid Namespace index or identifier type")
end
