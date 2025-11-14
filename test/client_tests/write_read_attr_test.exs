defmodule ClientWriteAttrTest do
  use ExUnit.Case, async: false

  alias OpcUA.{Client, ExpandedNodeId, NodeId, Server, QualifiedName}

  setup do
    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_default_config(s_pid)
    :ok = Server.set_port(s_pid, 4007)

    {:ok, ns_index} = Server.add_namespace(s_pid, "Room")

    # Object Type Node
    requested_new_node_id =
      NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10000)

    parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 45)
    browse_name = QualifiedName.new(ns_index: 1, name: "Obj")

    :ok = Server.add_object_type_node(s_pid,
      requested_new_node_id: requested_new_node_id,
      parent_node_id: parent_node_id,
      reference_type_node_id: reference_type_node_id,
      browse_name: browse_name
    )
    :ok = Server.write_node_write_mask(s_pid, requested_new_node_id, 0x3FFFFF)

    # Object Node
    requested_new_node_id =
      NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10002)

    parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 35)
    browse_name = QualifiedName.new(ns_index: 1, name: "Test1")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)

    :ok = Server.add_object_node(s_pid,
      requested_new_node_id: requested_new_node_id,
      parent_node_id: parent_node_id,
      reference_type_node_id: reference_type_node_id,
      browse_name: browse_name,
      type_definition: type_definition
    )

    requested_new_node_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Sensor")

    parent_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 35)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "Temperature sensor")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)

    :ok = Server.add_object_node(s_pid,
      requested_new_node_id: requested_new_node_id,
      parent_node_id: parent_node_id,
      reference_type_node_id: reference_type_node_id,
      browse_name: browse_name,
      type_definition: type_definition
    )

    # Variable Node
    requested_new_node_id =
      NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10001)

    parent_node_id = NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10002)
    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47)
    browse_name = QualifiedName.new(ns_index: 1, name: "Var")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)

    :ok = Server.add_variable_node(s_pid,
      requested_new_node_id: requested_new_node_id,
      parent_node_id: parent_node_id,
      reference_type_node_id: reference_type_node_id,
      browse_name: browse_name,
      type_definition: type_definition,
      display_name: {"en-US", "Var Display Name"},
      description: {"en-US", "Variable description"}
    )

    :ok = Server.write_node_write_mask(s_pid, requested_new_node_id, 0x3FFFFF)
    :ok = Server.write_node_access_level(s_pid, requested_new_node_id, 3)

    requested_new_node_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    parent_node_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Sensor")

    reference_type_node_id = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47)
    browse_name = QualifiedName.new(ns_index: ns_index, name: "Temperature")
    type_definition = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)


    :ok = Server.add_variable_node(s_pid,
      requested_new_node_id: requested_new_node_id,
      parent_node_id: parent_node_id,
      reference_type_node_id: reference_type_node_id,
      browse_name: browse_name,
      type_definition: type_definition
    )

    # CurrentWrite, CurrentRead
    :ok = Server.write_node_access_level(s_pid, requested_new_node_id, 3)
    :ok = Server.start(s_pid)

    {:ok, c_pid} = Client.start_link()
    :ok = Client.set_config(c_pid)
    :ok = Client.connect_by_url(c_pid, url: "opc.tcp://localhost:4007/")

    %{c_pid: c_pid, ns_index: ns_index}
  end

  test "Write and Read Attributes", %{c_pid: c_pid, ns_index: _ns_index} do
    node_id =  NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10001)

    new_node_id =  NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10003)
    c_response = Client.write_node_node_id(c_pid, node_id, new_node_id)
    assert c_response == {:error, "BadWriteNotSupported"}

    c_response = Client.read_node_node_id(c_pid, node_id)
    assert c_response == {:ok, node_id}

    c_response = Client.write_node_node_class(c_pid, node_id, 0)
    assert c_response == {:error, "BadWriteNotSupported"}

    ob_ty_node_id =  NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10000)
    c_response = Client.read_node_node_class(c_pid, ob_ty_node_id)
    assert c_response == {:ok, "ObjectType"}

    ob_node_id =  NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10002)
    c_response = Client.read_node_node_class(c_pid, ob_node_id)
    assert c_response == {:ok, "Object"}

    c_response = Client.read_node_user_write_mask(c_pid, node_id)
    assert c_response == {:ok, 0x3FFFFF}

    c_response = Client.write_node_user_write_mask(c_pid, node_id, 0x3FFFFF)
    assert c_response == {:error, "BadWriteNotSupported"}

    c_response = Client.read_node_user_access_level(c_pid, node_id)
    assert c_response == {:ok, 3}

    assert :ok == Client.write_node_user_access_level(c_pid, node_id, 3)

    # For Method nodes
    c_response = Client.read_node_user_executable(c_pid, node_id)
    assert c_response == {:error, "BadAttributeIdInvalid"}

    c_response = Client.write_node_user_executable(c_pid, node_id, false)
    assert c_response == {:error, "BadWriteNotSupported"}

    # For Reference Type
    c_response = Client.read_node_symmetric(c_pid, node_id)
    assert c_response == {:error, "BadAttributeIdInvalid"}

    c_response = Client.write_node_symmetric(c_pid, node_id, false)
    assert c_response == {:error, "BadNodeClassInvalid"}

    # For View Node
    c_response = Client.read_node_contains_no_loops(c_pid, node_id)
    assert c_response == {:error, "BadAttributeIdInvalid"}

    c_response = Client.write_node_contains_no_loops(c_pid, node_id, false)
    assert c_response == {:error, "BadNodeClassInvalid"}

    # For View Node
    c_response = Client.read_node_event_notifier(c_pid, node_id)
    assert c_response == {:error, "BadAttributeIdInvalid"}

    c_response = Client.write_node_event_notifier(c_pid, node_id, 103)
    assert c_response == {:error, "BadNodeClassInvalid"}

    # DisplayName: Now we create nodes with localized displayName during creation
    c_response = Client.read_node_display_name(c_pid, node_id)
    assert c_response == {:ok, {"en-US", "Var Display Name"}}

    # We can modify displayName text while keeping the locale
    assert :ok == Client.write_node_display_name(c_pid, node_id, "en-US", "Modified Display Name")
    c_response = Client.read_node_display_name(c_pid, node_id)
    assert c_response == {:ok, {"en-US", "Modified Display Name"}}

    # Description was also set during creation
    c_response = Client.read_node_description(c_pid, node_id)
    assert c_response == {:ok, {"en-US", "Variable description"}}

    assert :ok == Client.write_node_description(c_pid, node_id, "en-US", "variable")
    c_response = Client.read_node_description(c_pid, node_id)
    assert c_response == {:ok, {"en-US", "variable"}}

    assert :ok == Client.write_node_write_mask(c_pid, node_id, 0x3BFFFF)
    c_response = Client.read_node_write_mask(c_pid, node_id)
    assert c_response == {:ok, 0x3BFFFF}

    object_type_nid = NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10000)
    assert :ok == Client.write_node_is_abstract(c_pid, object_type_nid, true)
    c_response = Client.read_node_is_abstract(c_pid, object_type_nid)
    assert c_response == {:ok, true}

    data_type_nid = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)
    assert :ok == Client.write_node_data_type(c_pid, node_id, data_type_nid)
    c_response = Client.read_node_data_type(c_pid, node_id)
    assert c_response == {:ok, %NodeId{identifier: 63, identifier_type: 0, ns_index: 0}}

    # this attributes is only for reference type node
    assert {:error, "BadNodeClassInvalid"} == Client.write_node_inverse_name(c_pid, object_type_nid, "en-US", "varis")
    reference_nid = NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 51)
    c_response = Client.read_node_inverse_name(c_pid, reference_nid)
    assert c_response == {:ok, {"", "ToTransition"}}

    assert :ok == Client.write_node_value_rank(c_pid, node_id, 3)
    c_response = Client.read_node_value_rank(c_pid, node_id)
    assert c_response == {:ok, 3}

    assert :ok == Client.write_node_access_level(c_pid, node_id, 3)
    c_response = Client.read_node_access_level(c_pid, node_id)
    assert c_response == {:ok, 3}

    assert :ok == Client.write_node_minimum_sampling_interval(c_pid, node_id, 100.0)
    c_response = Client.read_node_minimum_sampling_interval(c_pid, node_id)
    assert c_response == {:ok, 100.0}

    assert :ok == Client.write_node_historizing(c_pid, node_id, true)
    c_response = Client.read_node_historizing(c_pid, node_id)
    assert c_response == {:ok, true}

    # this attributes is only for Method node
    assert :ok == Client.write_node_executable(c_pid, node_id, false)
    c_response = Client.read_node_executable(c_pid, node_id)
    assert c_response == {:error, "BadAttributeIdInvalid"}
  end

  test "Write and Read Value Attributes", %{c_pid: c_pid, ns_index: ns_index} do
    node_id = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, nil}

    assert :ok == Client.write_node_value(c_pid, node_id, 0, true)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, true}
    # Server sending to elixir app callback
    assert_receive({^node_id, true}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 1, 21)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 21}
    # Server sending to elixir app callback
    assert_receive({^node_id, 21}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 2, 22)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 22}
    # Server sending to elixir app callback
    assert_receive({^node_id, 22}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 3, 23)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 23}
    # Server sending to elixir app callback
    assert_receive({^node_id, 23}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 4, 24)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 24}
    # Server sending to elixir app callback
    assert_receive({^node_id, 24}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 5, 25)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 25}
    # Server sending to elixir app callback
    assert_receive({^node_id, 25}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 6, 26)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 26}
    # Server sending to elixir app callback
    assert_receive({^node_id, 26}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 7, 27)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 27}
    # Server sending to elixir app callback
    assert_receive({^node_id, 27}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 8, 28)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 28}
    # Server sending to elixir app callback
    assert_receive({^node_id, 28}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 9, 103.0)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 103.0}
    # Server sending to elixir app callback
    assert_receive({^node_id, 103.0}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 10, 103.103)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 103.103}
    # Server sending to elixir app callback
    assert_receive({^node_id, 103.103}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 11, "alde103")
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, "alde103"}
    # Server sending to elixir app callback
    assert_receive({^node_id, "alde103"}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 12, 132304152032503440)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 132304152032503440}
    # Server sending to elixir app callback
    assert_receive({^node_id, 132304152032503440}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 13, {103,103,103, "holahola"})
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, {103,103,103, "holahola"}}
    # Server sending to elixir app callback
    assert_receive({^node_id, {103,103,103, "holahola"}}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 14, "holahola")
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, "holahola"}
    # Server sending to elixir app callback
    assert_receive({^node_id, "holahola"}, 1000)

    xml = "<note>\n<to>Tove</to>\n<from>Jani</from>\n<heading>Reminder</heading>\n<body>Don't forget me this weekend!</body>\n</note>\n"
    assert :ok == Client.write_node_value(c_pid, node_id, 15, xml)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, xml}
    # Server sending to elixir app callback
    assert_receive({^node_id, ^xml}, 1000)

    node_id_arg = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")
    assert :ok == Client.write_node_value(c_pid, node_id, 16, node_id_arg)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, node_id_arg}
    # Server sending to elixir app callback
    assert_receive({^node_id, node_id_arg}, 1000)

    desired_expanded_node_id = ExpandedNodeId.new(node_id: node_id_arg, name_space_uri: "", server_index: 0)
    assert :ok == Client.write_node_value(c_pid, node_id, 17, node_id_arg)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, desired_expanded_node_id}
    # Server sending to elixir app callback
    assert_receive({^node_id, ^desired_expanded_node_id}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 18, 0)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, "Good"}
    # Server sending to elixir app callback
    assert_receive({^node_id, "Good"}, 1000)

    qualified_name = QualifiedName.new(ns_index: 1, name: "TEMP")
    assert :ok == Client.write_node_value(c_pid, node_id, 19, qualified_name)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, qualified_name}
    # Server sending to elixir app callback
    assert_receive({^node_id, ^qualified_name}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 20, {"en-US", "A String"})
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, {"en-US", "A String"}}
    # Server sending to elixir app callback
    assert_receive({^node_id, {"en-US", "A String"}}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 350, {node_id_arg, node_id_arg})
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, {node_id_arg, node_id_arg}}
    # Server sending to elixir app callback
    assert_receive({^node_id, {node_id_arg, node_id_arg}}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 133, "10/02/20")
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, "10/02/20"}
    # Server sending to elixir app callback
    assert_receive({^node_id, "10/02/20"}, 1000)

    # v1.4.x: Type 28 changed - was UADPNETWORKMESSAGECONTENTMASK, now is IMAGEGIF
    # Skipping this test as the type mapping has changed
    # assert :ok == Client.write_node_value(c_pid, node_id, 28, 0x7fffffff)
    # c_response = Client.read_node_value(c_pid, node_id)
    # assert c_response == {:ok, 0x7fffffff}
    # # Server sending to elixir app callback
    # assert_receive({^node_id, 0x7fffffff}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 357, {103.1, 103.0})
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, {103.0999984741211, 103.0}}
    # Server sending to elixir app callback
    assert_receive({^node_id, {103.0999984741211, 103.0}}, 1000)

    # v1.4.x: ELEMENTOPERAND type changed from index 30 to 249
    assert :ok == Client.write_node_value(c_pid, node_id, 249, 0x7fffffff)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 0x7fffffff}
    # Server sending to elixir app callback
    assert_receive({^node_id, 0x7fffffff}, 1000)
  end

  test "Write and Read Value Attributes by Data type", %{c_pid: c_pid, ns_index: ns_index} do
    node_id = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    assert :ok == Client.write_node_value(c_pid, node_id, 0, true)
    c_response = Client.read_node_value_by_data_type(c_pid, node_id, 0)
    assert c_response == {:ok, true}

    assert :ok == Client.write_node_value(c_pid, node_id, 1, 21)
    c_response = Client.read_node_value_by_data_type(c_pid, node_id, 1)
    assert c_response == {:ok, 21}

    assert :ok == Client.write_node_value(c_pid, node_id, 357, {103.1, 103.0})
    c_response = Client.read_node_value_by_data_type(c_pid, node_id, 357)
    assert c_response == {:ok, {103.0999984741211, 103.0}}
  end
end
