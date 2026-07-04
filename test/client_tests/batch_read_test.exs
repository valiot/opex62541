defmodule ClientBatchReadTest do
  use ExUnit.Case, async: false

  alias OpcUA.{NodeId, Server, QualifiedName, Client}

  setup do
    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_default_config(s_pid)
    :ok = Server.set_port(s_pid, 4010)

    {:ok, ns_index} = Server.add_namespace(s_pid, "BatchTest")

    parent_id =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "BatchParent")

    :ok =
      Server.add_object_node(s_pid,
        requested_new_node_id: parent_id,
        parent_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85),
        reference_type_node_id:
          NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 35),
        browse_name: QualifiedName.new(ns_index: ns_index, name: "BatchParent"),
        type_definition: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)
      )

    node_ids =
      for i <- 1..5 do
        node_id =
          NodeId.new(
            ns_index: ns_index,
            identifier_type: "string",
            identifier: "Var_#{i}"
          )

        :ok =
          Server.add_variable_node(s_pid,
            requested_new_node_id: node_id,
            parent_node_id: parent_id,
            reference_type_node_id:
              NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47),
            browse_name: QualifiedName.new(ns_index: ns_index, name: "Var #{i}"),
            type_definition: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)
          )

        :ok = Server.write_node_access_level(s_pid, node_id, 3)
        node_id
      end

    :ok = Server.start(s_pid)

    {:ok, c_pid} = Client.start_link()
    :ok = Client.set_config(c_pid)
    :ok = Client.connect_by_url(c_pid, url: "opc.tcp://localhost:4010/")

    %{c_pid: c_pid, s_pid: s_pid, ns_index: ns_index, node_ids: node_ids}
  end

  test "batch read multiple values", %{c_pid: c_pid, node_ids: node_ids} do
    Enum.with_index(node_ids, fn node_id, i ->
      :ok = Client.write_node_value(c_pid, node_id, 10, (i + 1) * 10.0)
    end)

    {:ok, results} = Client.read_node_values(c_pid, node_ids)

    assert length(results) == 5
    assert Enum.at(results, 0) == {:ok, 10.0}
    assert Enum.at(results, 1) == {:ok, 20.0}
    assert Enum.at(results, 2) == {:ok, 30.0}
    assert Enum.at(results, 3) == {:ok, 40.0}
    assert Enum.at(results, 4) == {:ok, 50.0}
  end

  test "batch read with nil values (unset)", %{c_pid: c_pid, node_ids: node_ids} do
    {:ok, results} = Client.read_node_values(c_pid, node_ids)

    assert length(results) == 5
    assert Enum.all?(results, fn r -> r == {:ok, nil} end)
  end

  test "batch read with nonexistent node returns per-node error", %{
    c_pid: c_pid,
    ns_index: ns_index,
    node_ids: node_ids
  } do
    # Write a value to the first node so we can verify it reads ok
    :ok = Client.write_node_value(c_pid, Enum.at(node_ids, 0), 6, 42)

    bad_node =
      NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "NonExistent")

    {:ok, results} = Client.read_node_values(c_pid, [Enum.at(node_ids, 0), bad_node])
    assert length(results) == 2
    assert {:ok, _} = Enum.at(results, 0)
    assert {:error, _} = Enum.at(results, 1)
  end

  test "batch read single node", %{c_pid: c_pid, node_ids: node_ids} do
    node_id = Enum.at(node_ids, 0)
    :ok = Client.write_node_value(c_pid, node_id, 10, 42.0)

    {:ok, results} = Client.read_node_values(c_pid, [node_id])
    assert results == [{:ok, 42.0}]
  end

  test "batch read mixed data types", %{c_pid: c_pid, node_ids: node_ids} do
    :ok = Client.write_node_value(c_pid, Enum.at(node_ids, 0), 0, true)
    :ok = Client.write_node_value(c_pid, Enum.at(node_ids, 1), 6, 42)
    :ok = Client.write_node_value(c_pid, Enum.at(node_ids, 2), 10, 3.14)
    :ok = Client.write_node_value(c_pid, Enum.at(node_ids, 3), 11, "hello")

    {:ok, results} = Client.read_node_values(c_pid, Enum.take(node_ids, 4))

    assert {:ok, true} = Enum.at(results, 0)
    assert {:ok, 42} = Enum.at(results, 1)
    assert {:ok, 3.14} = Enum.at(results, 2)
    assert {:ok, "hello"} = Enum.at(results, 3)
  end

  test "batch read is not supported on servers", %{s_pid: s_pid, node_ids: node_ids} do
    assert {:error, :not_supported} = Server.read_node_values(s_pid, node_ids)
  end

  test "batch read response larger than the port frame returns overflow error", %{
    c_pid: c_pid,
    node_ids: node_ids
  } do
    # 5 nodes x 15KB strings encode to ~75KB, above the 64KB port frame limit.
    big_string = String.duplicate("x", 15_000)

    Enum.each(node_ids, fn node_id ->
      :ok = Client.write_node_value(c_pid, node_id, 11, big_string)
    end)

    assert {:error, :overflow} = Client.read_node_values(c_pid, node_ids)
  end

  test "batch read with more than 100 nodes returns einval", %{
    c_pid: c_pid,
    ns_index: ns_index
  } do
    node_ids =
      for i <- 1..101 do
        NodeId.new(ns_index: ns_index, identifier_type: "string", identifier: "Fake_#{i}")
      end

    assert {:error, :einval} = Client.read_node_values(c_pid, node_ids)
  end
end
