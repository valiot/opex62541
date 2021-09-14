defmodule ClientEncryptionTest do
  use ExUnit.Case

  alias OpcUA.{Client, NodeId, Server, QualifiedName}

  setup do
    {:ok, s_pid} = Server.start_link()

    certs_config = [
      port: 4004,
      certificate: File.read!("./test/demo_certs/server_cert.der"),
      private_key: File.read!("./test/demo_certs/server_key.der")
    ]

    :ok = Server.set_default_config_with_certs(s_pid, certs_config)

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
      type_definition: type_definition
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

    %{c_pid: c_pid, ns_index: ns_index}
  end

  test "Connect a Client to a Server with security policy", %{c_pid: c_pid} do
    certs_config = [
      security_mode: 2,
      certificate: File.read!("./test/demo_certs/client_cert.der"),
      private_key: File.read!("./test/demo_certs/client_key.der")
    ]

    assert :ok == Client.set_config_with_certs(c_pid, certs_config)
    assert :ok == Client.connect_by_url(c_pid, url: "opc.tcp://localhost:4004/")
  end

  test "Connect a Client to a Server with security policy (sign_and_encrypted)", %{c_pid: c_pid} do
    certs_config = [
      security_mode: 3,
      certificate: File.read!("./test/demo_certs/client_cert.der"),
      private_key: File.read!("./test/demo_certs/client_key.der")
    ]

    assert :ok == Client.set_config_with_certs(c_pid, certs_config)
    assert :ok == Client.connect_by_url(c_pid, url: "opc.tcp://localhost:4004/")
  end

  test "Read/write data from a Server with security policy", %{c_pid: c_pid, ns_index: ns_index} do

    certs_config = [
      security_mode: 3,
      certificate: File.read!("./test/demo_certs/client_cert.der"),
      private_key: File.read!("./test/demo_certs/client_key.der")
    ]

    assert :ok == Client.set_config_with_certs(c_pid, certs_config)
    assert :ok == Client.connect_by_url(c_pid, url: "opc.tcp://localhost:4004/")

    node_id = NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, nil}

    assert :ok == Client.write_node_value(c_pid, node_id, 0, true)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, true}
  end
end
