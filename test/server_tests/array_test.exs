defmodule ServerArrayTest do
  use ExUnit.Case

  alias OpcUA.{NodeId, Server, QualifiedName}

  setup do
    {:ok, pid} = OpcUA.Server.start_link()
    Server.set_default_config(pid)
    Server.set_port(pid, 4008)
    {:ok, ns_index} = OpcUA.Server.add_namespace(pid, "Room")

    # Object type Node
    requested_new_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 10000)
    parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 45)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "Temperature sensor")

    Server.add_object_type_node(pid,
      requested_new_node_id: requested_new_node_id,
      parent_node_id: parent_node_id,
      reference_type_node_id: reference_type_node_id,
      browse_name: browse_name
    )

    # Object Node
    requested_new_node_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_VendorName")

    parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 35)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "Temperature sensor")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)

    Server.add_object_node(pid,
      requested_new_node_id: requested_new_node_id,
      parent_node_id: parent_node_id,
      reference_type_node_id: reference_type_node_id,
      browse_name: browse_name,
      type_definition: type_definition
    )

    # Variable Node
    requested_new_node_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    parent_node_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_VendorName")

    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "Temperature")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)

    Server.add_variable_node(pid,
      requested_new_node_id: requested_new_node_id,
      parent_node_id: parent_node_id,
      reference_type_node_id: reference_type_node_id,
      browse_name: browse_name,
      type_definition: type_definition
    )

    %{pid: pid, ns_index: ns_index}
  end

  test "read/write array value node", state do
    node_id = NodeId.new(ns_index: state.ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    resp = Server.write_node_value_rank(state.pid, node_id, 3)
    assert resp == :ok

    resp = Server.read_node_value_rank(state.pid, node_id)
    assert resp == {:ok, 3}

    resp = Server.write_node_array_dimensions(state.pid, node_id, [1, 3, 2])
    assert resp == :ok

    resp = Server.read_node_array_dimensions(state.pid, node_id)
    assert resp == {:ok, [1, 3, 2]}
  end

  test "create blank array value node", state do
    node_id = NodeId.new(ns_index: state.ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    resp = Server.write_node_value_rank(state.pid, node_id, 2)
    assert resp == :ok

    resp = Server.read_node_value_rank(state.pid, node_id)
    assert resp == {:ok, 2}

    resp = Server.write_node_array_dimensions(state.pid, node_id, [2, 2])
    assert resp == :ok

    resp = Server.read_node_array_dimensions(state.pid, node_id)
    assert resp == {:ok, [2, 2]}

    Server.start(state.pid)

    resp = Server.write_node_blank_array(state.pid, node_id, 0, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 1, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 2, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 3, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 4, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 5, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 6, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 7, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 8, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 9, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 10, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 11, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 12, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 13, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 14, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 15, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 16, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 17, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 18, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 19, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 20, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 350, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 133, [2, 2])
    assert resp == :ok

    # v1.4.x: Type 28 changed - was UADPNETWORKMESSAGECONTENTMASK, now is IMAGEGIF
    # Skipping this test as the type mapping has changed
    # resp = Server.write_node_blank_array(state.pid, node_id, 28, [2, 2])
    # assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 357, [2, 2])
    assert resp == :ok

    resp = Server.write_node_blank_array(state.pid, node_id, 249, [2, 2])
    assert resp == :ok
  end
end
