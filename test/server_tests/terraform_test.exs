defmodule ServerTerraformTest do
  use ExUnit.Case

  alias OpcUA.{Client, NodeId, Server, QualifiedName}

  @configuration [
    config: [
      users: {[{"alde103", "secret"}], 4023}
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
        browse_name: QualifiedName.new(ns_index: 2, name: "Var_N"),
        display_name: {"en-US", "var"},
        description: {"en-US", "variable"},
        type_definition: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)
      ],
      write_mask: 0x3BFFFF,
      access_level: 3,
      # This should not be applied, as browse_name is immutable after creation
      browse_name: QualifiedName.new(ns_index: 2, name: "Var_Mod"),
      display_name: {"en-US", "var mod"},
      description: {"en-US", "variable mod"},
      data_type: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63),
      value_rank: 3,
      minimum_sampling_interval: 100.0,
      historizing: true
    ),

    variable_node:  OpcUA.VariableNode.new(
      [
        requested_new_node_id: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Temperature"),
        parent_node_id: NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Sensor"),
        reference_type_node_id: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 47),
        browse_name: QualifiedName.new(ns_index: 2, name: "Temperature"),
        type_definition: NodeId.new(ns_index: 0, identifier_type: "integer", identifier: 63)
      ],
      write_mask: 0x3FFFFF,
      value: {0, false},
      access_level: 3
    ),
  ]

  defmodule MyServer do
    use OpcUA.Server
    alias OpcUA.Server

    # Use the `init` function to configure your server.
    def init({parent_pid, 103}, s_pid) do
      Server.start(s_pid)
      %{parent_pid: parent_pid}
    end

    def configuration(_user_init_state), do: Application.get_env(:opex62541, :configuration, [])
    def address_space(_user_init_state), do: Application.get_env(:opex62541, :address_space, [])

    def handle_write(write_event, %{parent_pid: parent_pid} = state) do
      send(parent_pid, write_event)
      state
    end
  end

  setup() do
    Application.put_env(:opex62541, :address_space, @address_space)
    Application.put_env(:opex62541, :configuration, @configuration)

    {:ok, _pid} = MyServer.start_link({self(), 103})

    # Give server time to start
    Process.sleep(100)

    {:ok, c_pid} = Client.start_link()

    config = %{
      "requestedSessionTimeout" => 1200000,
      "secureChannelLifeTime" => 600000,
      "timeout" => 50000
    }
    :ok = Client.set_config(c_pid, config)

    %{c_pid: c_pid}
  end

  test "Write value event", %{c_pid: c_pid} do
    url = "opc.tcp://127.0.0.1:4023/"
    user = "alde103"
    password = "secret"

    assert :ok == Client.connect_by_username(c_pid, url: url, user: user, password: password)

    node_id =  NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10001)

    # v1.4.x (and v1.0.4+): BrowseName is immutable after node creation
    # The browse_name attribute in VariableNode is ignored during terraform
    # Only the browse_name in the initialization params is used
    c_response = Client.read_node_browse_name(c_pid, node_id)
    assert c_response == {:ok, %QualifiedName{name: "Var_N", ns_index: 2}}

    # v1.4.x: DisplayName with locale must be set during node creation via add_variable_node
    # The terraform pattern sets attributes AFTER creation, which doesn't work for locale
    # The node gets browse_name as displayName without locale
    c_response = Client.read_node_display_name(c_pid, node_id)
    assert c_response == {:ok, {"en-US", "var mod"}}

    c_response = Client.read_node_description(c_pid, node_id)
    assert c_response == {:ok, {"en-US", "variable mod"}}

    c_response = Client.read_node_write_mask(c_pid, node_id)
    assert c_response == {:ok, 0x3BFFFF}

    object_type_nid = NodeId.new(ns_index: 1, identifier_type: "integer", identifier: 10000)
    c_response = Client.read_node_is_abstract(c_pid, object_type_nid)
    assert c_response == {:ok, true}

    c_response = Client.read_node_data_type(c_pid, node_id)
    assert c_response == {:ok, %NodeId{identifier: 63, identifier_type: 0, ns_index: 0}}

    c_response = Client.read_node_value_rank(c_pid, node_id)
    assert c_response == {:ok, 3}

    c_response = Client.read_node_access_level(c_pid, node_id)
    assert c_response == {:ok, 3}

    c_response = Client.read_node_minimum_sampling_interval(c_pid, node_id)
    assert c_response == {:ok, 100.0}

    c_response = Client.read_node_historizing(c_pid, node_id)
    assert c_response == {:ok, true}

    node_id =  NodeId.new(ns_index: 2, identifier_type: "string", identifier: "R1_TS1_Temperature")
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, false}

    assert :ok == Client.write_node_value(c_pid, node_id, 0, true)
    c_response = Client.read_node_value(c_pid, node_id)
    assert c_response == {:ok, true}
    assert_receive({^node_id, true}, 1000)

    assert :ok == Client.disconnect(c_pid)
  end
end
