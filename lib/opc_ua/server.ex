defmodule OpcUA.Server do
  use OpcUA.Common

  alias OpcUA.{NodeId}

  @moduledoc """

  OPC UA Server API module.

  This module provides functions for configuration, add/delete/read/write nodes and discovery a OPC UA Server.

  `OpcUA.Server` is implemented as a `__using__` macro so that you can put it in any module,
  you can initialize your Server manually (see `test/server_tests/write_event_test.exs`) or by overwriting
  `configuration/0` and `address_space/0` to autoset  the configuration and information model. It also helps you to
  handle Server's "write value" events by overwriting `handle_write/2` callback.

  The following example shows a module that takes its configuration from the enviroment:

  ```elixir
  defmodule MyServer do
    use OpcUA.Server
    alias OpcUA.Server

    # Use the `init` function to configure your server.
    def init({parent_pid, 103} = _user_init_state, opc_ua_server_pid) do
      Server.start(opc_ua_server_pid)
      %{parent_pid: parent_pid}
    end

    def configuration(), do: Application.get_env(:opex62541, :configuration, [])
    def address_space(), do: Application.get_env(:opex62541, :address_space, [])

    def handle_write(write_event, %{parent_pid: parent_pid} = state) do
      send(parent_pid, write_event)
      state
    end
  end
  ```

  Because it is small a GenServer, it accepts the same [options](https://hexdocs.pm/elixir/GenServer.html#module-how-to-supervise) for supervision
  to configure the child spec and passes them along to `GenServer`:

  ```elixir
  defmodule MyModule do
    use OpcUA.Server, restart: :transient, shutdown: 10_000
  end
  ```
  """

  @doc """
  Optional callback that handles node values updates from a Client to a Server.

  It's first argument will a tuple, in which its first element is the `node_id` of the updated node
  and the second element is the updated value.

  the second argument it's the Process state (Parent process).
  """
  @callback handle_write(key :: {%NodeId{}, any}, map) :: map

  @type config_params ::
          {:hostname, binary()}
          | {:port, non_neg_integer()}
          | {:users, keyword()}


  @type config_options ::
          {:config, config_params}
          | {:discovery, {binary(), non_neg_integer()}}

  @doc """
  Optional callback that gets the Server configuration and discovery connection parameters.
  """
  @callback configuration() :: config_options

  @type address_space_list ::
          {:namespace, binary()}
          | {:variable_node, %OpcUA.VariableNode{}}
          | {:variable_type_node, %OpcUA.VariableTypeNode{}}
          | {:method_node, %OpcUA.MethodNode{}}  #WIP
          | {:object_node, %OpcUA.ObjectNode{}}
          | {:object_type_node, %OpcUA.ObjectTypeNode{}}
          | {:reference_type_node, %OpcUA.ReferenceTypeNode{}}
          | {:data_type_node, %OpcUA.DataTypeNode{}}
          | {:view_node, %OpcUA.ViewNode{}}
          | {:reference_node, %OpcUA.ReferenceNode{}}


  @doc """
  Optional callback that gets a list of nodes (with their attributes) to be automatically set.
  """
  @callback address_space() :: address_space_list

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer, Keyword.drop(opts, [:configuration])
      @behaviour OpcUA.Server

      alias __MODULE__

      def start_link(user_initial_params \\ []) do
        GenServer.start_link(__MODULE__, user_initial_params, unquote(opts))
      end

      @impl true
      def init(user_initial_params) do
        send self(), :init
        {:ok, user_initial_params}
      end

      @impl true
      def handle_info(:init, user_initial_params) do

        # Server Terraform
        {:ok, s_pid} = OpcUA.Server.start_link()
        configuration = apply(__MODULE__, :configuration, [])
        address_space = apply(__MODULE__, :address_space, [])

        OpcUA.Server.set_default_config(s_pid)

        # configutation = [config: list(), discovery: {term(), term()}]
        set_server_config(s_pid, configuration, :config)
        set_server_config(s_pid, configuration, :discovery)

        # address_space = [namespace: "", namespace: "", variable: %VariableNode{}, ...]
        set_server_address_space(s_pid, address_space)

        # User initialization.

        user_state = apply(__MODULE__, :init, [user_initial_params, s_pid])

        {:noreply, user_state}
      end

      def handle_info({%NodeId{} = node_id, value}, state) do
        state = apply(__MODULE__, :handle_write, [{node_id, value}, state])
        {:noreply, state}
      end

      def handle_write(write_event, _state) do
        raise "No handle_write/2 clause in #{__MODULE__} provided for #{inspect(write_event)}"
      end

      @impl true
      def address_space(), do: []

      @impl true
      def configuration(), do: []

      defp set_server_config(s_pid, configuration, type) do
        config_params = Keyword.get(configuration, type, [])
        Enum.each(config_params, fn(config_param) -> GenServer.call(s_pid, {type, config_param}) end)
      end

      defp set_server_address_space(s_pid, address_space) do
        for {node_type, node_params} <- address_space, reduce: %{} do
          acc -> add_node(s_pid, node_type, node_params, acc)
        end
      end

      defp add_node(s_pid, :namespace, node_param, namespaces) do
        ns_index = GenServer.call(s_pid, {:add, {:namespace, node_param}})
        Map.put(namespaces, node_param, ns_index)
      end

      defp add_node(s_pid, node_type, node, namespaces) do
        # separate the node params (creation arguments & node attributes)
        {node_args, node_attrs} =
          node
          |> Map.from_struct()
          |> Map.pop(:args)

        # Create node
        #node_args = replace_namespace(node_args, namespaces)
        GenServer.call(s_pid, {:add, {node_type, node_args}})

        # add nodes attribures
        node_id = Keyword.fetch!(node_args, :requested_new_node_id)
        #node_attrs = replace_namespace(node_attrs, namespaces)
        add_node_attrs(s_pid, node_id, node_attrs)

        namespaces
      end

      defp add_node_attrs(s_pid, node_id, node_attrs) do
        for {attr, attr_value} <- node_attrs do
          set_node_attr(s_pid, node_id, attr, attr_value)
        end
      end

      defp set_node_attr(_s_pid, _node_id, _attr, nil), do: nil
      defp set_node_attr(s_pid, node_id, attr, attr_value) do
        GenServer.call(s_pid, {:write, {attr, node_id, attr_value}})
      end

      # TODO: complete the function.
      # defp replace_namespace(params, namespaces) do
      #   for {param, param_value} <- params, reduce: %{} do
      #     acc ->
      #       param_value =
      #         if is_struct(params_value) do

      #         end
      #       Map.put
      #   end
      # end

      defoverridable  start_link: 0,
                      start_link: 1,
                      configuration: 0,
                      address_space: 0,
                      handle_write: 2
    end
  end

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
    GenServer.call(pid, {:config, {:get_server_config, nil}})
  end

  @doc """
  Sets a default Server Config.
  """
  @spec set_default_config(GenServer.server()) :: :ok | {:error, binary()} | {:error, :einval}
  def set_default_config(pid) do
    GenServer.call(pid, {:config, {:set_default_server_config, nil}})
  end

  @doc """
  Sets the host name for the Server.
  """
  @spec set_hostname(GenServer.server(), binary()) :: :ok | {:error, binary()} | {:error, :einval}
  def set_hostname(pid, hostname) when is_binary(hostname) do
    GenServer.call(pid, {:config, {:hostname, hostname}})
  end

  @doc """
  Sets a port number for the Server.
  """
  @spec set_port(GenServer.server(), integer()) :: :ok | {:error, binary()} | {:error, :einval}
  def set_port(pid, port) when is_integer(port) do
    GenServer.call(pid, {:config, {:port, port}})
  end

  @doc """
  Adds users (and passwords) the Server.
  Users must be a tuple list ([{user, password}]).
  """
  @spec set_users(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def set_users(pid, users) when is_list(users) do
    GenServer.call(pid, {:config, {:users, users}})
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

  # Discovery functions

  @doc """
  Sets the configuration for the a Server representing a local discovery server as a central instance.
  Any other server can register with this server using "discovery_register" function
  NOTE: before calling this function, this server should have the default configuration.
  LDS Servers only supports the Discovery Services. Cannot be used in combination with any other capability.

  The following args must be filled:
    * `:application_uri` -> binary().
    * `:timeout` -> boolean().
  """
  @spec set_lds_config(GenServer.server(), binary(), integer()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def set_lds_config(pid, application_uri, timeout \\ nil)
      when is_binary(application_uri) and (is_integer(timeout) or is_nil(timeout)) do
    GenServer.call(pid, {:discovery, {application_uri, timeout}})
  end

  @doc """
  Registers a server in a discovery server.
  NOTE: The Server sends the request once started. Use port = 0 to dynamically port allocation.

  The following must be filled:
    * `:application_uri` -> binary().
    * `:server_name` -> binary().
    * `:endpoint` -> binary().
    * `:timeout` -> boolean().
  """
  @spec discovery_register(GenServer.server(), list()) :: :ok | {:error, binary()} | {:error, :einval}
  def discovery_register(pid, args) when is_list(args) do
    GenServer.call(pid, {:discovery, {:discovery_register, args}})
  end

  @doc """
  Unregister the server from the discovery server.
  NOTE: Server must be started.
  """
  @spec discovery_unregister(GenServer.server()) :: :ok | {:error, binary()} | {:error, :einval}
  def discovery_unregister(pid) do
    GenServer.call(pid, {:discovery, {:discovery_unregister, nil}})
  end

  # Add & Delete nodes functions

  @doc """
  Add a new namespace.
  """
  @spec add_namespace(GenServer.server(), binary()) ::
          {:ok, integer()} | {:error, binary()} | {:error, :einval}
  def add_namespace(pid, namespace) when is_binary(namespace) do
    GenServer.call(pid, {:add, {:namespace, namespace}})
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
  @spec add_variable_node(GenServer.server(), list()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def add_variable_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add, {:variable_node, args}})
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
  @spec add_variable_type_node(GenServer.server(), list()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def add_variable_type_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add, {:variable_type_node, args}})
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
  @spec add_object_node(GenServer.server(), list()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def add_object_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add, {:object_node, args}})
  end

  @doc """
  Add a new object type node to the server.
  The following must be filled:
    * `:requested_new_node_id` -> %NodeID{}.
    * `:parent_node_id` -> %NodeID{}.
    * `:reference_type_node_id` -> %NodeID{}.
    * `:browse_name` -> %QualifiedName{}.
  """
  @spec add_object_type_node(GenServer.server(), list()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def add_object_type_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add, {:object_type_node, args}})
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
    GenServer.call(pid, {:add, {:view_node, args}})
  end

  @doc """
  Add a new reference type node to the server.
  The following must be filled:
    * `:requested_new_node_id` -> %NodeID{}.
    * `:parent_node_id` -> %NodeID{}.
    * `:reference_type_node_id` -> %NodeID{}.
    * `:browse_name` -> %QualifiedName{}.
  """
  @spec add_reference_type_node(GenServer.server(), list()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def add_reference_type_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add, {:reference_type_node, args}})
  end

  @doc """
  Add a new data type node to the server.
  The following must be filled:
    * `:requested_new_node_id` -> %NodeID{}.
    * `:parent_node_id` -> %NodeID{}.
    * `:reference_type_node_id` -> %NodeID{}.
    * `:browse_name` -> %QualifiedName{}.
  """
  @spec add_data_type_node(GenServer.server(), list()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def add_data_type_node(pid, args) when is_list(args) do
    GenServer.call(pid, {:add, {:data_type_node, args}})
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
    GenServer.call(pid, {:add, {:reference, args}})
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
  @spec delete_reference(GenServer.server(), list()) ::
          :ok | {:error, binary()} | {:error, :einval}
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


  @doc false
  def test(pid) do
    GenServer.call(pid, {:test, nil})
  end

  # Handlers
  def init({_args, controlling_process}) do

    lib_dir =
      :opex62541
      |> :code.priv_dir()
      |> to_string()
      |> set_ld_library_path()

    executable = lib_dir <> "/opc_ua_server"

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

  def handle_call({:config, {:get_server_config, nil}}, caller_info, state) do
    call_port(state, :get_server_config, caller_info, nil)
    {:noreply, state}
  end

  def handle_call({:config, {:set_default_server_config, nil}}, caller_info, state) do
    call_port(state, :set_default_server_config, caller_info, nil)
    {:noreply, state}
  end

  def handle_call({:config, {:hostname, hostname}}, caller_info, state) do
    call_port(state, :set_hostname, caller_info, hostname)
    {:noreply, state}
  end

  def handle_call({:config, {:port, port}}, caller_info, state) do
    call_port(state, :set_port, caller_info, port)
    {:noreply, state}
  end

  def handle_call({:config, {:users, users}}, caller_info, state) do
    call_port(state, :set_users, caller_info, users)
    {:noreply, state}
  end

  def handle_call({:start_server, nil}, caller_info, state) do
    call_port(state, :start_server, caller_info, nil)
    {:noreply, state}
  end

  def handle_call({:stop_server, nil}, caller_info, state) do
    call_port(state, :stop_server, caller_info, nil)
    {:noreply, state}
  end

  # Discovery Functions.

  def handle_call({:discovery, {:discovery_register, args}}, caller_info, state) do
    application_uri = Keyword.fetch!(args, :application_uri)
    server_name = Keyword.fetch!(args, :server_name)
    endpoint = Keyword.fetch!(args, :endpoint)
    timeout = Keyword.get(args, :timeout, nil)

    c_args = {application_uri, server_name, endpoint, timeout}
    call_port(state, :discovery_register, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:discovery, {:discovery_unregister, nil}}, caller_info, state) do
    call_port(state, :discovery_unregister, caller_info, nil)
    {:noreply, state}
  end

  def handle_call({:discovery, {application_uri, timeout}}, caller_info, state) do
    c_args = {application_uri, timeout}
    call_port(state, :set_lds_config, caller_info, c_args)
    {:noreply, state}
  end

  # Handlers Add & Delete Functions.

  def handle_call({:add, {:namespace, namespace}}, caller_info, state) do
    call_port(state, :add_namespace, caller_info, namespace)
    {:noreply, state}
  end

  def handle_call({:add, {:variable_node, args}}, caller_info, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()
    type_definition = Keyword.fetch!(args, :type_definition) |> to_c()

    c_args =
      {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name,
       type_definition}

    call_port(state, :add_variable_node, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:add, {:variable_type_node, args}}, caller_info, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()
    type_definition = Keyword.fetch!(args, :type_definition) |> to_c()

    c_args =
      {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name,
       type_definition}

    call_port(state, :add_variable_type_node, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:add, {:object_node, args}}, caller_info, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()
    type_definition = Keyword.fetch!(args, :type_definition) |> to_c()

    c_args =
      {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name,
       type_definition}

    call_port(state, :add_object_node, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:add, {:object_type_node, args}}, caller_info, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name}
    call_port(state, :add_object_type_node, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:add, {:view_node, args}}, caller_info, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name}
    call_port(state, :add_view_node, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:add, {:reference_type_node, args}}, caller_info, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name}
    call_port(state, :add_reference_type_node, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:add, {:data_type_node, args}}, caller_info, state) do
    requested_new_node_id = Keyword.fetch!(args, :requested_new_node_id) |> to_c()
    parent_node_id = Keyword.fetch!(args, :parent_node_id) |> to_c()
    reference_type_node_id = Keyword.fetch!(args, :reference_type_node_id) |> to_c()
    browse_name = Keyword.fetch!(args, :browse_name) |> to_c()

    c_args = {requested_new_node_id, parent_node_id, reference_type_node_id, browse_name}
    call_port(state, :add_data_type_node, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:add, {:reference, args}}, caller_info, state) do
    source_id = Keyword.fetch!(args, :source_id) |> to_c()
    reference_type_id = Keyword.fetch!(args, :reference_type_id) |> to_c()
    target_id = Keyword.fetch!(args, :target_id) |> to_c()
    is_forward = Keyword.fetch!(args, :is_forward)

    c_args = {source_id, reference_type_id, target_id, is_forward}
    call_port(state, :add_reference, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:delete_reference, args}, caller_info, state) do
    source_id = Keyword.fetch!(args, :source_id) |> to_c()
    reference_type_id = Keyword.fetch!(args, :reference_type_id) |> to_c()
    target_id = Keyword.fetch!(args, :target_id) |> to_c()
    is_forward = Keyword.fetch!(args, :is_forward)
    delete_bidirectional = Keyword.fetch!(args, :delete_bidirectional)

    c_args = {source_id, reference_type_id, target_id, is_forward, delete_bidirectional}
    call_port(state, :delete_reference, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:delete_node, args}, caller_info, state) do
    node_id = Keyword.fetch!(args, :node_id) |> to_c()
    delete_reference = Keyword.fetch!(args, :delete_reference)

    c_args = {node_id, delete_reference}
    call_port(state, :delete_node, caller_info, c_args)
    {:noreply, state}
  end

  # Catch all

  def handle_call({:test, nil}, caller_info, state) do
    call_port(state, :test, caller_info, nil)
    {:noreply, state}
  end

  def handle_call(invalid_call, _caller_info, state) do
    Logger.error("#{__MODULE__} Invalid call: #{inspect(invalid_call)}")
    {:reply, {:error, :einval}, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    Logger.warn("(#{__MODULE__}) Error code: #{inspect(code)}.")
    # retrying delay
    Process.sleep(@c_timeout)
    {:stop, :restart, state}
  end

  def handle_info({:EXIT, _port, reason}, state) do
    Logger.debug("(#{__MODULE__}) Exit reason: #{inspect(reason)}")
    # retrying delay
    Process.sleep(@c_timeout)
    {:stop, :restart, state}
  end

  def handle_info(msg, state) do
    Logger.warn("(#{__MODULE__}) Unhandled message: #{inspect(msg)}.")
    {:noreply, state}
  end

  defp handle_c_response(
         {:write, {ns_index, type, name}, c_value},
         %{controlling_process: c_pid} = state
       ) do
    variable_node = NodeId.new(ns_index: ns_index, identifier_type: type, identifier: name)
    value = parse_c_value(c_value)
    send(c_pid, {variable_node, value})
    state
  end

  defp handle_c_response({:test, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  # C Handlers Lifecyle & Configuration Functions.

  defp handle_c_response({:get_server_config, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:set_default_server_config, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:set_hostname, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:set_port, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:set_users, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:start_server, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:stop_server, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  # C Handlers Add & Delete Functions.

  defp handle_c_response({:add_namespace, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:add_variable_node, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:add_variable_type_node, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:add_object_node, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:add_object_type_node, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:add_view_node, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:add_reference_type_node, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:add_data_type_node, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:add_reference, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:delete_reference, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:delete_node, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  # C Handlers "Discovery".

  defp handle_c_response({:set_lds_config, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:discovery_register, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:discovery_unregister, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end
end
