defmodule WriteAttrTest do
  use ExUnit.Case

  alias OpcUA.{NodeId, Server, QualifiedName}

  setup do
    {:ok, pid} = OpcUA.Server.start_link()
    Server.set_default_config(pid)
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

  test "write attrs node", state do
    node_id = NodeId.new(ns_index: state.ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")
    name = QualifiedName.new(ns_index: state.ns_index, name: "Var_N")
    resp = Server.write_node_browse_name(state.pid, node_id, name)
    assert resp == :ok

    resp = Server.write_node_display_name(state.pid, node_id, "en-US", "variable")
    assert resp == :ok

    resp = Server.write_node_description(state.pid, node_id, "en-US", "A variable")
    assert resp == :ok

    resp = Server.write_node_write_mask(state.pid, node_id, 200)
    assert resp == :ok

    ob_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 10000)
    resp = Server.write_node_is_abstract(state.pid, ob_type_node_id, true)
    assert resp == :ok

    dt_node_id = NodeId.new(ns_index: state.ns_index, identifier_type: "integer", identifier: 63)
    resp = Server.write_node_data_type(state.pid, node_id, dt_node_id)
    assert resp == :ok

    resp = Server.write_node_value_rank(state.pid, node_id, 103)
    assert resp == :ok

    resp = Server.write_node_access_level(state.pid, node_id, 103)
    assert resp == :ok

    resp = Server.write_node_minimum_sampling_interval(state.pid, node_id, 103.0)
    assert resp == :ok

    resp = Server.write_node_historizing(state.pid, node_id, true)
    assert resp == :ok

    resp = Server.write_node_executable(state.pid, node_id, true)
    assert resp == :ok
  end

  test "write value attr node", state do
    node_id = NodeId.new(ns_index: state.ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    resp = Server.write_node_value(state.pid, node_id, 0, true)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 1, 103)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 2, 103)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 3, 103)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 4, 103)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 5, 103)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 6, 103)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 7, 103)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 8, 103)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 9, 103.103)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 10, 103.103)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 11, "alde103")
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 12, 132304152032503440)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 13, {103,103,103, "holahola"})
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 14, "holahola")
    assert resp == :ok

    xml = "<note>\n<to>Tove</to>\n<from>Jani</from>\n<heading>Reminder</heading>\n<body>Don't forget me this weekend!</body>\n</note>\n"
    resp = Server.write_node_value(state.pid, node_id, 15, xml)
    assert resp == :ok

    node_id_arg = NodeId.new(ns_index: state.ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")
    resp = Server.write_node_value(state.pid, node_id, 16, node_id_arg)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 17, node_id_arg)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 18, 0)
    assert resp == :ok

    qualified_name = QualifiedName.new(ns_index: 1, name: "TEMP")
    resp = Server.write_node_value(state.pid, node_id, 19, qualified_name)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 20, {"en-US", "A String"})
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 25, {node_id_arg, node_id_arg})
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 26, "10/02/20")
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 28, 321321)
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 29, {103.1, 103.0})
    assert resp == :ok

    resp = Server.write_node_value(state.pid, node_id, 30, 21321)
    assert resp == :ok
  end
end
