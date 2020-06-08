defmodule ClientArraysTest do
  use ExUnit.Case

  alias OpcUA.{NodeId, Server, QualifiedName, Client}

  setup do
    {:ok, pid} = OpcUA.Server.start_link()
    Server.set_default_config(pid)
    {:ok, ns_index} = OpcUA.Server.add_namespace(pid, "Room")

    # Object Node
    requested_new_node_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_VendorName")

    parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 35)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "Temperature sensor")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)

    :ok = Server.add_object_node(pid,
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

    :ok = Server.add_variable_node(pid,
      requested_new_node_id: requested_new_node_id,
      parent_node_id: parent_node_id,
      reference_type_node_id: reference_type_node_id,
      browse_name: browse_name,
      type_definition: type_definition
    )

    :ok = Server.write_node_access_level(pid, requested_new_node_id, 3)
    :ok = Server.write_node_write_mask(pid, requested_new_node_id, 3)

    :ok = Server.start(pid)

    {:ok, c_pid} = Client.start_link()
    :ok = Client.set_config(c_pid)
    :ok = Client.connect_by_url(c_pid, url: "opc.tcp://localhost:4840/")

    %{c_pid: c_pid, s_pid: pid, ns_index: ns_index}
  end

  test "write array node", state do
    node_id = NodeId.new(ns_index: state.ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    resp = Server.write_node_value_rank(state.s_pid, node_id, 1)
    assert resp == :ok

    resp = Server.read_node_value_rank(state.s_pid, node_id)
    assert resp == {:ok, 1}

    resp = Server.write_node_array_dimensions(state.s_pid, node_id, [4])
    assert resp == :ok

    resp = Client.read_node_array_dimensions(state.c_pid, node_id)
    assert resp == {:ok, [4]}

    resp = Client.write_node_array_dimensions(state.c_pid, node_id, [4])
    assert resp == :ok

    resp = Client.read_node_array_dimensions(state.c_pid, node_id)
    assert resp == {:ok, [4]}
  end
end
