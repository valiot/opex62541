defmodule OpcUA.Server do
  use GenServer
  require Logger

  alias OpcUA.QualifiedName
  alias OpcUA.NodeId

  @c_timeout 5000

  defmodule State do
    @moduledoc false

    # port: C port process
    # controlling_process: where events get sent
    # queued_messages: queued messages during port request.

    defstruct port: nil,
              controlling_process: nil,
              queued_messages: [],
              configuration: nil,
              address_space: %{}
  end

  @doc """
  Starts up a OPC UA Server GenServer.
  """
  @spec start_link([term]) :: {:ok, pid} | {:error, term} | {:error, :einval}
  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  Stops a OPC UA Server GenServer.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  # Configuration & lifecycle functions

  @doc """
  Reads an internal Server Config.
  """
  @spec get_server_config(GenServer.server()) :: {:ok, map()} | {:error, binary()} | {:error, :einval}
  def get_server_config(pid) do
    GenServer.call(pid, {:get_server_config, nil})
  end

  @doc """
  Sets a default Server Config.
  """
  @spec set_default_server_config(GenServer.server()) :: :ok | {:error, binary()} | {:error, :einval}
  def set_default_server_config(pid) do
    GenServer.call(pid, {:set_default_server_config, nil})
  end

  @doc """
  Sets the host name for the Server.
  """
  @spec set_hostname(GenServer.server(), binary()) :: :ok | {:error, binary()} | {:error, :einval}
  def set_hostname(pid, hostname) when is_binary(hostname) do
    GenServer.call(pid, {:set_hostname, hostname})
  end

  @doc """
  Sets a port number for the Server.
  """
  @spec set_port(GenServer.server(), integer()) :: :ok | {:error, binary()} | {:error, :einval}
  def set_port(pid, port) when is_integer(port) do
    GenServer.call(pid, {:set_port, port})
  end

  @doc """
  Adds users (and passwords) the Server.
  Users must be a tuple list ([{user, password}]).
  """
  @spec set_users(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def set_users(pid, users) when is_list(users) do
    GenServer.call(pid, {:set_users, users})
  end

  @doc """
  Start OPC UA Server.
  """
  @spec start(GenServer.server()) :: :ok | {:error, binary()} | {:error, :einval}
  def start(pid) do
    GenServer.call(pid, {:start_server, nil})
  end

  @doc """
  Stop OPC UA Server.
  """
  @spec stop_server(GenServer.server()) :: :ok | {:error, binary()} | {:error, :einval}
  def stop_server(pid) do
    GenServer.call(pid, {:stop_server, nil})
  end

  # Add & Delete nodes functions

  @doc """
  Add a new namespace.
  """
  @spec add_namespace(GenServer.server(), binary()) :: {:ok, integer()} | {:error, binary()} | {:error, :einval}
  def add_namespace(pid, namespace) when is_binary(namespace) do
    GenServer.call(pid, {:add_namespace, namespace})
  end

  @doc """
  Add a new variable node to the server.
  The following must be filled:
    * `:requested_new_node_id` -> %NodeID{}.
    * `:parent_node_id` -> %NodeID{}.
    * `:reference_type_node_id` -> %NodeID{}.
    * `:browse_name` -> %QualifiedName{}.
    * `:type_definition` -> %NodeID{}.
  """
  @spec add_variable_node(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def add_variable_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add_variable_node, args})
  end


  @doc """
  Add a new variable type node to the server.
  The following must be filled:
    * `:requested_new_node_id` -> %NodeID{}.
    * `:parent_node_id` -> %NodeID{}.
    * `:reference_type_node_id` -> %NodeID{}.
    * `:browse_name` -> %QualifiedName{}.
    * `:type_definition` -> %NodeID{}.
  """
  @spec add_variable_type_node(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def add_variable_type_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add_variable_type_node, args})
  end

  @doc """
  Add a new object node to the server.
  The following must be filled:
    * `:requested_new_node_id` -> %NodeID{}.
    * `:parent_node_id` -> %NodeID{}.
    * `:reference_type_node_id` -> %NodeID{}.
    * `:browse_name` -> %QualifiedName{}.
    * `:type_definition` -> %NodeID{}.
  """
  @spec add_object_node(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def add_object_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add_object_node, args})
  end

  @doc """
  Add a new object type node to the server.
  The following must be filled:
    * `:requested_new_node_id` -> %NodeID{}.
    * `:parent_node_id` -> %NodeID{}.
    * `:reference_type_node_id` -> %NodeID{}.
    * `:browse_name` -> %QualifiedName{}.
  """
  @spec add_object_type_node(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def add_object_type_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add_object_type_node, args})
  end

  @doc """
  Add a new view node to the server.
  The following must be filled:
    * `:requested_new_node_id` -> %NodeID{}.
    * `:parent_node_id` -> %NodeID{}.
    * `:reference_type_node_id` -> %NodeID{}.
    * `:browse_name` -> %QualifiedName{}.
  """
  @spec add_view_node(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def add_view_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add_view_node, args})
  end

  @doc """
  Add a new reference type node to the server.
  The following must be filled:
    * `:requested_new_node_id` -> %NodeID{}.
    * `:parent_node_id` -> %NodeID{}.
    * `:reference_type_node_id` -> %NodeID{}.
    * `:browse_name` -> %QualifiedName{}.
  """
  @spec add_reference_type_node(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def add_reference_type_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add_reference_type_node, args})
  end

  @doc """
  Add a new data type node to the server.
  The following must be filled:
    * `:requested_new_node_id` -> %NodeID{}.
    * `:parent_node_id` -> %NodeID{}.
    * `:reference_type_node_id` -> %NodeID{}.
    * `:browse_name` -> %QualifiedName{}.
  """
  @spec add_data_type_node(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def add_data_type_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add_data_type_node, args})
  end

  @doc """
  Add a new reference in the server.
  The following must be filled:
    * `:source_id` -> %NodeID{}.
    * `:reference_type_id` -> %NodeID{}.
    * `:target_id` -> %NodeID{}.
    * `:is_forward` -> boolean().
  """
  @spec add_reference(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def add_reference(pid, args) when is_list(args) do
    GenServer.call(pid, {:add_reference, args})
  end

  @doc """
  Deletes a reference in the server.
  The following must be filled:
    * `:source_id` -> %NodeID{}.
    * `:reference_type_id` -> %NodeID{}.
    * `:target_id` -> %NodeID{}.
    * `:is_forward` -> boolean().
    * `:delete_bidirectional` -> boolean().
  """
  @spec delete_reference(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def delete_reference(pid, args) when is_list(args) do
    GenServer.call(pid, {:delete_reference, args})
  end

  @doc """
  Deletes a node in the server.
  The following must be filled:
    * `:node_id` -> %NodeID{}.
    * `:delete_references` -> boolean().
  """
  @spec delete_node(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def delete_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:delete_node, args})
  end

  # Write nodes Attributes functions

  @doc """
  Change the browse name of a node in the server.
  """
  @spec write_node_browse_name(GenServer.server(), %NodeId{}, %QualifiedName{}) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_browse_name(pid, node_id, browse_name) do
    GenServer.call(pid, {:write_node_browse_name, node_id, browse_name})
  end

  @doc """
  Change the display name attribute of a node in the server.
  """
  @spec write_node_display_name(GenServer.server(), %NodeId{}, binary(), binary()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_display_name(pid, node_id, locale, name) do
    GenServer.call(pid, {:write_node_display_name, node_id, locale, name})
  end

  @doc """
  Change description attribute of a node in the server.
  """
  @spec write_node_description(GenServer.server(), %NodeId{}, binary(), binary()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_description(pid, node_id, locale, description) do
    GenServer.call(pid, {:write_node_description, node_id, locale, description})
  end

  #TODO: friendlier write_mask params
  @doc """
  Change 'Write Mask' attribute of a node in the server.
  """
  @spec write_node_write_mask(GenServer.server(), %NodeId{}, integer()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_write_mask(pid, node_id, write_mask) do
    GenServer.call(pid, {:write_node_write_mask, node_id, write_mask})
  end

  @doc """
  Change 'Is Abstract' attribute of a node in the server.
  """
  @spec write_node_is_abstract(GenServer.server(), %NodeId{}, boolean()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_is_abstract(pid, node_id, is_abstract?) do
    GenServer.call(pid, {:write_node_is_abstract, node_id, is_abstract?})
  end

  @doc """
  Change 'Inverse name' attribute of a node in the server.
  """
  @spec write_node_inverse_name(GenServer.server(), %NodeId{}, binary(), binary()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_inverse_name(pid, node_id, locale, inverse_name) do
    GenServer.call(pid, {:write_node_inverse_name, node_id, locale, inverse_name})
  end

  @doc """
  Change 'data_type' attribute of a node in the server.
  """
  @spec write_node_data_type(GenServer.server(), %NodeId{}, %NodeId{}) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_data_type(pid, node_id, data_type_node_id) do
    GenServer.call(pid, {:write_node_data_type, node_id, data_type_node_id})
  end

  @doc """
  Change 'Value Rank' of a node in the server.
  """
  @spec write_node_value_rank(GenServer.server(), %NodeId{}, integer()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_value_rank(pid, node_id, value_rank) do
    GenServer.call(pid, {:write_node_value_rank, node_id, value_rank})
  end

  @doc """
  Change 'Access level' of a node in the server.
  """
  @spec write_node_access_level(GenServer.server(), %NodeId{}, integer()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_access_level(pid, node_id, access_level) do
    GenServer.call(pid, {:write_node_access_level, node_id, access_level})
  end

  @doc """
  Change 'Minimum Sampling Interval level' of a node in the server.
  """
  @spec write_node_minimum_sampling_interval(GenServer.server(), %NodeId{}, integer()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_minimum_sampling_interval(pid, node_id, minimum_sampling_interval) do
    GenServer.call(pid, {:write_node_minimum_sampling_interval, node_id, minimum_sampling_interval})
  end

  @doc """
  Change 'Historizing' attribute of a node in the server.
  """
  @spec write_node_historizing(GenServer.server(), %NodeId{}, boolean()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_historizing(pid, node_id, historizing?) do
    GenServer.call(pid, {:write_node_historizing, node_id, historizing?})
  end

  @doc """
  Change 'Executable' attribute of a node in the server.
  """
  @spec write_node_executable(GenServer.server(), %NodeId{}, boolean()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_executable(pid, node_id, executable?) do
    GenServer.call(pid, {:write_node_executable, node_id, executable?})
  end

  @doc """
  Change 'Value' attribute of a node in the server.
  """
  @spec write_node_value(GenServer.server(), %NodeId{}, integer(), term()) :: :ok | {:error, binary()} | {:error, :einval}
  def write_node_value(pid, node_id, data_type, value) do
    GenServer.call(pid, {:write_node_value, node_id, data_type, value})
  end


  # Handlers
  def init(_args) do
    executable = :code.priv_dir(:opex62541) ++ '/opc_ua_server'

    port =
      Port.open({:spawn_executable, executable}, [
        {:args, []},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    state = %State{port: port}
    {:ok, state}
  end

  # Handlers Lifecyle & Configuration Functions.

  def handle_call({:get_server_config, nil}, {_from, _}, state) do
    {new_state, response} = call_port(state, :get_server_config, nil)
    {:reply, response, new_state}
  end

  def handle_call({:set_default_server_config, nil}, {_from, _}, state) do
    {new_state, response} = call_port(state, :set_default_server_config, nil)
    {:reply, response, new_state}
  end

  def handle_call({:set_hostname, hostname}, {_from, _}, state) do
    {new_state, response} = call_port(state, :set_hostname, hostname)
    {:reply, response, new_state}
  end

  def handle_call({:set_port, port}, {_from, _}, state) do
    {new_state, response} = call_port(state, :set_port, port)
    {:reply, response, new_state}
  end

  def handle_call({:start_server, nil}, {_from, _}, state) do
    {new_state, response} = call_port(state, :start_server, nil)
    {:reply, response, new_state}
  end

  def handle_call({:set_users, users}, {_from, _}, state) do
    {new_state, response} = call_port(state, :set_users, users)
    {:reply, response, new_state}
  end

  def handle_call({:stop_server, nil}, {_from, _}, state) do
    {new_state, response} = call_port(state, :stop_server, nil)
    {:reply, response, new_state}
  end

  # Handlers Add & Delete Functions.

  def handle_call({:add_namespace, namespace}, {_from, _}, state) do
    {new_state, response} = call_port(state, :add_namespace, namespace)
    {:reply, response, new_state}
  end

  def handle_call({:add_variable_node, args}, {_from, _}, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()
    type_definition = Keyword.fetch!(args, :type_definition) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition}
    {new_state, response} = call_port(state, :add_variable_node, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:add_variable_type_node, args}, {_from, _}, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()
    type_definition = Keyword.fetch!(args, :type_definition) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition}
    {new_state, response} = call_port(state, :add_variable_type_node, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:add_object_node, args}, {_from, _}, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()
    type_definition = Keyword.fetch!(args, :type_definition) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name, type_definition}
    {new_state, response} = call_port(state, :add_object_node, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:add_object_type_node, args}, {_from, _}, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name}
    {new_state, response} = call_port(state, :add_object_type_node, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:add_view_node, args}, {_from, _}, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name}
    {new_state, response} = call_port(state, :add_view_node, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:add_reference_type_node, args}, {_from, _}, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name}
    {new_state, response} = call_port(state, :add_reference_type_node, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:add_data_type_node, args}, {_from, _}, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name}
    {new_state, response} = call_port(state, :add_data_type_node, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:add_reference, args}, {_from, _}, state) do
    source_id = Keyword.fetch!(args, :source_id) |> to_c()
    reference_type_id = Keyword.fetch!(args, :reference_type_id) |> to_c()
    target_id = Keyword.fetch!(args, :target_id) |> to_c()
    is_forward = Keyword.fetch!(args, :is_forward)

    c_args = {source_id, reference_type_id, target_id, is_forward}
    {new_state, response} = call_port(state, :add_reference, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:delete_reference, args}, {_from, _}, state) do
    source_id = Keyword.fetch!(args, :source_id) |> to_c()
    reference_type_id = Keyword.fetch!(args, :reference_type_id) |> to_c()
    target_id = Keyword.fetch!(args, :target_id) |> to_c()
    is_forward = Keyword.fetch!(args, :is_forward)
    delete_bidirectional = Keyword.fetch!(args, :delete_bidirectional)

    c_args = {source_id, reference_type_id, target_id, is_forward, delete_bidirectional}
    {new_state, response} = call_port(state, :delete_reference, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:delete_node, args}, {_from, _}, state) do
    node_id = Keyword.fetch!(args, :node_id) |> to_c()
    delete_reference = Keyword.fetch!(args, :delete_reference)

    c_args = {node_id, delete_reference}
    {new_state, response} = call_port(state, :delete_node, c_args)
    {:reply, response, new_state}
  end

  # Write nodes Attributes functions

  def handle_call({:write_node_browse_name, node_id, browse_name}, {_from, _}, state) do
    c_args = {to_c(node_id), to_c(browse_name)}
    {new_state, response} = call_port(state, :write_node_browse_name, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_display_name, node_id, locale, name}, {_from, _}, state) when is_binary(locale) and is_binary(name) do
    c_args = {to_c(node_id), locale, name}
    {new_state, response} = call_port(state, :write_node_display_name, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_description, node_id, locale, description}, {_from, _}, state) when is_binary(locale) and is_binary(description) do
    c_args = {to_c(node_id), locale, description}
    {new_state, response} = call_port(state, :write_node_description, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_write_mask, node_id, write_mask}, {_from, _}, state) when is_integer(write_mask) do
    c_args = {to_c(node_id), write_mask}
    {new_state, response} = call_port(state, :write_node_write_mask, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:handle_write_node_is_abstract, node_id, is_abstract?}, {_from, _}, state) when is_boolean(is_abstract?) do
    c_args = {to_c(node_id), is_abstract?}
    {new_state, response} = call_port(state, :handle_write_node_is_abstract, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_inverse_name, node_id, locale, inverse_name}, {_from, _}, state) when is_binary(locale) and is_binary(inverse_name) do
    c_args = {to_c(node_id), locale, inverse_name}
    {new_state, response} = call_port(state, :write_node_inverse_name, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_data_type, node_id, data_type_node_id}, {_from, _}, state) do
    c_args = {to_c(node_id), to_c(data_type_node_id)}
    {new_state, response} = call_port(state, :write_node_data_type, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_value_rank, node_id, value_rank}, {_from, _}, state) when is_integer(value_rank) do
    c_args = {to_c(node_id), value_rank}
    {new_state, response} = call_port(state, :write_node_value_rank, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_access_level, node_id, access_level}, {_from, _}, state) when is_integer(access_level) do
    c_args = {to_c(node_id), access_level}
    {new_state, response} = call_port(state, :write_node_access_level, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_minimum_sampling_interval, node_id, minimum_sampling_interval}, {_from, _}, state) when is_integer(minimum_sampling_interval) do
    c_args = {to_c(node_id), minimum_sampling_interval}
    {new_state, response} = call_port(state, :write_node_minimum_sampling_interval, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_historizing, node_id, historizing?}, {_from, _}, state) when is_boolean(historizing?) do
    c_args = {to_c(node_id), historizing?}
    {new_state, response} = call_port(state, :write_node_historizing, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_executable, node_id, executable?}, {_from, _}, state) when is_boolean(executable?) do
    c_args = {to_c(node_id), executable?}
    {new_state, response} = call_port(state, :write_node_executable, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:write_node_value, node_id, data_type, raw_value}, {_from, _}, state) do
    value = value_to_c(data_type, raw_value)
    c_args = {to_c(node_id), data_type, value}
    {new_state, response} = call_port(state, :write_node_value, c_args)
    {:reply, response, new_state}
  end

  # Catch all

  def handle_call(invalid_call, {_from, _}, state) do
    Logger.error("#{__MODULE__} Invalid call: #{inspect invalid_call}")
    {:reply, {:error, :einval}, state}
  end

  def handle_info({_port, {:data, <<?r, response::binary>>}}, state) do
    data = :erlang.binary_to_term(response)
    Logger.warn("(#{__MODULE__}) data: #{inspect data}.")
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    Logger.warn("(#{__MODULE__}) Error code: #{inspect code}.")
    Process.sleep(@c_timeout) #retrying delay
    {:stop, :restart, state}
  end

  def handle_info({:EXIT, _port, reason}, state) do
    Logger.debug("(#{__MODULE__}) Exit reason: #{inspect(reason)}")
    Process.sleep(@c_timeout) #retrying delay
    {:stop, :restart, state}
  end

  def handle_info(msg, state) do
    Logger.warn("(#{__MODULE__}) Unhandled message: #{inspect msg}.")
    {:noreply, state}
  end

  defp call_port(state, command, arguments, timeout \\ @c_timeout) do
    msg = {command, arguments}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})
    # Block until the response comes back since the C side
    # doesn't want to handle any queuing of requests. REVISIT
    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response) |> add_to_buffer_or_response(state)
    after
      timeout ->
        # Not sure how this can be recovered
        exit(:port_timed_out)
    end
  end

  # TODO: add dump
  defp add_to_buffer_or_response({:ok, _} = response, state), do: dump_msgs(response, state)
  defp add_to_buffer_or_response({:error, _} = response, state), do: dump_msgs(response, state)
  defp add_to_buffer_or_response(:ok, state), do: dump_msgs(:ok, state)
  defp add_to_buffer_or_response(async_response,  %{queued_messages: msgs} = state) do
    new_msgs = msgs ++ [async_response]
    new_state = %State{state | queued_messages: new_msgs}

    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response) |> add_to_buffer_or_response(new_state)
    after
      @c_timeout ->
        # Not sure how this can be recovered
        exit(:port_timed_out)
    end
  end

  defp dump_msgs(response, %{queued_messages: msgs} = state) do
    Enum.each(msgs, fn(msg) -> send(self(), msg) end)
    {%State{state | queued_messages: []}, response}
  end

  defp to_c(%NodeId{ns_index: ns_index, identifier_type: id_type, identifier: identifier}),
    do: {id_type, ns_index, identifier}

  defp to_c(%QualifiedName{ns_index: ns_index, name: name}),
    do: {ns_index, name}

  defp to_c(_invalid_struct), do:
    raise("Invalid Data type")

  # For NodeId, QualifiedName.
  defp value_to_c(data_type, value) when data_type in [16, 17, 19], do: to_c(value)
  # SEMANTICCHANGESTRUCTUREDATATYPE
  defp value_to_c(data_type, {arg1, arg2}) when data_type == 25, do: {to_c(arg1), to_c(arg2)}
  defp value_to_c(_data_type, value), do: value
end
