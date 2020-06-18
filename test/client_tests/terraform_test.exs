defmodule ClientTerraformTest do
  use ExUnit.Case

  alias OpcUA.{Client, NodeId, Server, QualifiedName}

  @configuration_server [
    config: [
      port: 4041,
      users: [{"alde103", "secret"}]
    ]
  ]

  @address_space [
    namespace: "Sensor",
    object_type_node: OpcUA.ObjectTypeNode.new(
      [
        requested_new_node_id: NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10000),
        parent_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58),
        reference_type_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 45),
        browse_name: QualifiedName.new(ns_index: 1, name: "Obj")
      ],
      write_mask: 0x3FFFFF,
      is_abstract: true
    ),

    object_node: OpcUA.ObjectNode.new(
      [
        requested_new_node_id: NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10002),
        parent_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85),
        reference_type_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 35),
        browse_name: QualifiedName.new(ns_index: 1, name: "Test1"),
        type_definition: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)
      ]
    ),

    object_node: OpcUA.ObjectNode.new(
      [
        requested_new_node_id: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Sensor"),
        parent_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 85),
        reference_type_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 35),
        browse_name: QualifiedName.new(ns_index: 2, name: "Temperature sensor"),
        type_definition: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 58)
      ]
    ),

    variable_node:  OpcUA.VariableNode.new(
      [
        requested_new_node_id: NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10001),
        parent_node_id: NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10002),
        reference_type_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47),
        browse_name: QualifiedName.new(ns_index: 1, name: "Var"),
        type_definition: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)
      ],
      write_mask: 0x3BFFFF,
      access_level: 3,
      browse_name: QualifiedName.new(ns_index: 2, name: "Var_N"),
      display_name: {"en-US", "var"},
      description: {"en-US", "variable"},
      data_type: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63),
      value_rank: 3,
      minimum_sampling_interval: 100.0,
      historizing: true
    ),

    variable_node: OpcUA.VariableNode.new(
      [
        requested_new_node_id: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Temperature"),
        parent_node_id: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Sensor"),
        reference_type_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47),
        browse_name: QualifiedName.new(ns_index: 2, name: "Temperature"),
        type_definition: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)
      ],
      write_mask: 0x3FFFFF,
      value: {10, 103.0},
      access_level: 3
    ),
    monitored_item: OpcUA.MonitoredItem.new(
      [
        monitored_item: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Temperature"),
        sampling_time: 1000.0,
        subscription_id: 1
      ]
    )
  ]

  {:ok, localhost} = :inet.gethostname()

  @configuration_client [
    config: [
      set_config: %{
        "requestedSessionTimeout" => 1200000,
        "secureChannelLifeTime" => 600000,
        "timeout" => 50000
      }
    ],
    conn: [
      by_username: [
        url: "opc.tcp://#{localhost}:4041/",
        user: "alde103",
        password: "secret"
      ]
    ]
  ]

  @monitored_items [
    subscription: 200.0,
    monitored_item: OpcUA.MonitoredItem.new(
      [
        monitored_item: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Temperature"),
        sampling_time: 100.0,
        subscription_id: 1
      ]
    )
  ]

  defmodule MyClient do
    use OpcUA.Client
    alias OpcUA.Client

    # Use the `init` function to configure your Client.
    def init({parent_pid, 103} = _user_init_state, opc_ua_client_pid) do
      %{parent_pid: parent_pid, opc_ua_client_pid: opc_ua_client_pid}
    end

    def configuration(_user_init_state), do: Application.get_env(:my_client, :configuration, [])
    def monitored_items(_user_init_state), do: Application.get_env(:my_client, :monitored_items, [])

    def handle_subscription_timeout(subscription_id, state) do
      send(state.parent_pid, {:subscription_timeout, subscription_id})
      state
    end

    def handle_deleted_subscription(subscription_id, state) do
      send(state.parent_pid, {:subscription_delete, subscription_id})
      state
    end

    def handle_monitored_data(changed_data_event, state) do
      send(state.parent_pid, {:value_changed, changed_data_event})
      state
    end

    def handle_deleted_monitored_item(subscription_id, monitored_id, state) do
      send(state.parent_pid, {:item_deleted, {subscription_id, monitored_id}})
      state
    end

    def read_node_value(pid, node), do: GenServer.call(pid, {:read, node}, :infinity)

    def get_client(pid), do: GenServer.call(pid, {:get_client, nil})

    def handle_call({:read, node}, _from, state) do
      resp = Client.read_node_value(state.opc_ua_client_pid, node)
      {:reply, resp, state}
    end

    def handle_call({:get_client, nil}, _from, state) do
      {:reply, state.opc_ua_client_pid, state}
    end
  end

  defmodule MyServer do
    use OpcUA.Server
    alias OpcUA.Server

    # Use the `init` function to configure your server.
    def init({parent_pid, 103}, s_pid) do
      Server.start(s_pid)
      %{parent_pid: parent_pid}
    end

    def configuration(_user_init_state), do: Application.get_env(:my_server, :configuration, [])
    def address_space(_user_init_state), do: Application.get_env(:my_server, :address_space, [])

    @impl true
    def handle_write(write_event, %{parent_pid: parent_pid} = state) do
      send(parent_pid, write_event)
      state
    end
  end

  setup() do
    Application.put_env(:my_server, :address_space, @address_space)
    Application.put_env(:my_server, :configuration, @configuration_server)

    Application.put_env(:my_client, :configuration, @configuration_client)
    Application.put_env(:my_client, :monitored_items, @monitored_items)

    {:ok, _pid} = MyServer.start_link({self(), 103})
    {:ok, c_pid} = MyClient.start_link({self(), 103})

    %{c_pid: c_pid}
  end

  test "Write value event", %{c_pid: c_pid} do
    node_id =  NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Temperature")
    c_response = MyClient.read_node_value(c_pid, node_id)
    assert c_response == {:ok, 103.0}

    pid = MyClient.get_client(c_pid)

    assert :ok == Client.write_node_value(pid, node_id, 10, 103103.0)

    Process.sleep(200)

    assert :ok == Client.delete_monitored_item(pid, monitored_item_id: 1, subscription_id: 1)

    assert :ok == Client.delete_subscription(pid, 1)

    assert_receive({:value_changed, {1, 1, 103103.0}}, 1000)

    assert_receive({:item_deleted, {1, 1}}, 1000)

    assert_receive({:subscription_delete, 1}, 1000)
  end
end
