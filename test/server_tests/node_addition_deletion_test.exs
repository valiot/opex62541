defmodule ServerNodeAdditionDeletionTest do
  use ExUnit.Case

  alias OpcUA.{NodeId, Server, QualifiedName}

  setup do
    {:ok, pid} = OpcUA.Server.start_link()
    Server.set_default_config(pid)
    %{pid: pid}
  end

  test "Add a namespace", state do
    {:ok, ns_index} = OpcUA.Server.add_namespace(state.pid, "Room")
    assert is_integer(ns_index)
  end

  test "Add object and variable nodes ", state do
    {:ok, ns_index} = OpcUA.Server.add_namespace(state.pid, "Room")

    # Object Node
    requested_new_node_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_VendorName")

    parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 35)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "Temperature sensor")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)

    resp =
      Server.add_object_node(state.pid,
        requested_new_node_id: requested_new_node_id,
        parent_node_id: parent_node_id,
        reference_type_node_id: reference_type_node_id,
        browse_name: browse_name,
        type_definition: type_definition
      )

    assert resp == :ok

    # Variable Node
    requested_new_node_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    parent_node_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_VendorName")

    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "Temperature")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)

    resp =
      Server.add_variable_node(state.pid,
        requested_new_node_id: requested_new_node_id,
        parent_node_id: parent_node_id,
        reference_type_node_id: reference_type_node_id,
        browse_name: browse_name,
        type_definition: type_definition
      )

    assert resp == :ok
  end
end
