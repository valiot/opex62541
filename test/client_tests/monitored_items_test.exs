defmodule ClientMonitoredItemsTest do
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
    {:ok, 1} = Server.add_monitored_item(pid, monitored_item: requested_new_node_id, sampling_time: 500.0)

    :ok = Server.start(pid)

    {:ok, c_pid} = Client.start_link()
    :ok = Client.set_config(c_pid)
    :ok = Client.connect_by_url(c_pid, url: "opc.tcp://localhost:4840/")

    %{c_pid: c_pid, ns_index: ns_index}
  end

  test "Add & delete a Subscription & Monitored Item", state do
    node_id = NodeId.new(ns_index: state.ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")

    assert {:ok, 1} == Client.add_subscription(state.c_pid)

    assert {:ok, 1} == Client.add_monitored_item(state.c_pid, monitored_item: node_id, subscription_id: 1)

    assert :ok == Client.write_node_value(state.c_pid, node_id, 10, 103103.0)
    c_response = Client.read_node_value(state.c_pid, node_id)
    assert c_response == {:ok, 103103.0}

    assert_receive({%OpcUA.NodeId{identifier: "R1_TS1_Temperature", identifier_type: 1, ns_index: 2}, 103103.0}, 5000)
    assert_receive({:data, 1, 1, 2}, 5000)
    Process.sleep(1000000)

    assert :ok == Client.delete_monitored_item(state.c_pid, monitored_item_id: 1, subscription_id: 1)

    assert :ok == Client.delete_subscription(state.c_pid, 1)

    # Subscription deleted
    assert_receive({:delete, 1}, 1000)
    # Monitored Item deleted
    assert_receive({:delete, 1, 1}, 1000)

    assert_receive({:delete, 1, 1, 2}, 5000)
  end
end
