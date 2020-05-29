defmodule MonitoredItemsTest do
  use ExUnit.Case

  alias OpcUA.{NodeId, Server, QualifiedName}

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

    %{pid: pid, ns_index: ns_index}
  end

  test "Add & delete a monitored Item", state do
    node_id = NodeId.new(ns_index: state.ns_index, identifier_type: "string", identifier: "R1_TS1_Temperature")
    assert {:ok, 1} == Server.add_monitored_item(state.pid, monitored_item: node_id, sampling_time: 1000.0)
    # Expected error with a undefined monitored item.
    assert {:error, "BadMonitoredItemIdInvalid"} == Server.delete_monitored_item(state.pid, 10)
    assert :ok == Server.delete_monitored_item(state.pid, 1)
  end
end
