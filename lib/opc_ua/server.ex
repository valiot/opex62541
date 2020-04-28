defmodule OpcUA.Server do
  use OpcUA.Common

  @doc """
  Starts up a OPC UA Server GenServer.
  """
  @spec start_link(term(), list()) :: {:ok, pid} | {:error, term} | {:error, :einval}
  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, {args, self()}, opts)
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
  @spec get_config(GenServer.server()) :: {:ok, map()} | {:error, binary()} | {:error, :einval}
  def get_config(pid) do
    GenServer.call(pid, {:get_server_config, nil})
  end

  @doc """
  Sets a default Server Config.
  """
  @spec set_default_config(GenServer.server()) :: :ok | {:error, binary()} | {:error, :einval}
  def set_default_config(pid) do
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


  # Handlers
  def init({_args, controlling_process}) do
    executable = :code.priv_dir(:opex62541) ++ '/opc_ua_server'

    port =
      Port.open({:spawn_executable, executable}, [
        {:args, []},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    state = %State{port: port, controlling_process: controlling_process}
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
end
