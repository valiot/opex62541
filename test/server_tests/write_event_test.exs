defmodule ServerWriteEventTest do
  use ExUnit.Case

  alias OpcUA.{NodeId, Client, Server}

  defmodule MyServer do
    use OpcUA.Server
    alias OpcUA.{NodeId, Server, QualifiedName}
    require Logger

    # Use the `init` function to configure your server.
    def init({parent_pid, 103}, s_pid) do
      :ok = Server.set_port(s_pid, 4024)

      {:ok, _ns_index} = Server.add_namespace(s_pid, "Room")

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

      :ok = Server.start(s_pid)

      %{s_pid: s_pid, parent_pid: parent_pid}
    end

    def get_server_pid(pid) do
      GenServer.call(pid, :get_server_pid)
    end

    @impl true
    def handle_write(write_event, %{parent_pid: parent_pid} = state) do
      Logger.debug("(#{__MODULE__}) Received #{inspect(write_event)})")
      send(parent_pid, write_event)
      state
    end

    def handle_call(:get_server_pid, _from , state), do: {:reply, state.s_pid, state}
  end

  setup() do
    {:ok, my_pid} = MyServer.start_link({self(), 103})

    {:ok, c_pid} = Client.start_link()

    config = %{
      "requestedSessionTimeout" => 1200000,
      "secureChannelLifeTime" => 600000,
      "timeout" => 50000
    }

    :ok = Client.set_config(c_pid, config)
    :ok = Client.connect_by_url(c_pid, url: "opc.tcp://localhost:4024/")

    %{c_pid: c_pid, my_pid: my_pid}
  end

  test "Write value event", %{c_pid: c_pid, my_pid: my_pid} do
    node_id =  NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10001)

    s_pid = MyServer.get_server_pid(my_pid)
    assert :ok == Server.write_node_value(s_pid, node_id, 0, false)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, false}

    assert :ok == Client.write_node_value(c_pid, node_id, 0, true)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, true}
    assert_receive({node_id, true}, 1000)
    # Server values write must not activate a write event.
    refute_receive({_node_id, false}, 1000)

    assert :ok == Client.write_node_value(c_pid, node_id, 9, 100.0)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 100.0}
    assert_receive({node_id, 100.0}, 1000)

    assert :ok == Server.write_node_value(s_pid, node_id, 9, 90.0)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 90.0}
    # Server values write must not activate a write event.
    refute_receive({_node_id, 90.0}, 1000)
  end
end
