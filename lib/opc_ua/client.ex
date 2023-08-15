defmodule OpcUA.Client do
  use OpcUA.Common

  @config_keys ["requestedSessionTimeout", "secureChannelLifeTime", "timeout"]

  alias OpcUA.NodeId

  @moduledoc """

  OPC UA Client API module.

  This module provides functions for configuration, read/write nodes attributes and discovery of a OPC UA Client.

  `OpcUA.Client` is implemented as a `__using__` macro so that you can put it in any module,
  you can initialize your Client manually (see `test/client_tests`) or by overwriting
  `configuration/1` and `monitored_items/1` to autoset the configuration and subscription items. It also helps you to
  handle Client's "subscription" events (monitorItems) by overwriting `handle_subscription/2` callback.

  The following example shows a module that takes its configuration from the environment (see `test/client_tests/terraform_test.exs`):

  ```elixir
  defmodule MyClient do
    use OpcUA.Client

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
  end
  ```

  Because it is small a GenServer, it accepts the same [options](https://hexdocs.pm/elixir/GenServer.html#module-how-to-supervise) for supervision
  to configure the child spec and passes them along to `GenServer`:

  ```elixir
  defmodule MyModule do
    use OpcUA.Client, restart: :transient, shutdown: 10_000
  end
  ```
  """

  @type conn_params ::
          {:hostname, binary()}
          | {:port, non_neg_integer()}
          | {:users, keyword()}

  @type config_options ::
          {:config, map()}
          | {:conn, conn_params}

  @doc """
  Optional callback that gets the Server configuration and discovery connection parameters.
  """
  @callback configuration(term()) :: config_options

  # TODO:
  @type monitored_items_options ::
          {:subscription, float()}
          | {:monitored_item, %OpcUA.MonitoredItem{}}

  @callback monitored_items(term()) :: monitored_items_options

  @doc """
  Optional callback that handles node values updates from a Client to a Server.

  It's first argument is a tuple, in which its first element is the `subscription_id`
  of the subscription that the monitored item belongs to. the second element
  is the 'monitored_item_id' which is an unique number asigned to a monitored item when
  its created and the third element of the tuple is the new value of the monitored item.

  the second argument it's the GenServer state (Parent process).
  """
  @callback handle_monitored_data({integer(), integer(), any()}, term()) :: term()

  @doc """
  Optional callback that handles a deleted monitored items events.

  It's first argument is the `subscription_id` of the subscription that the monitored
  item belongs to. The second element is the 'monitored_item_id' which is an unique
  number asigned to a monitored item when its created.

  The third argument it's the GenServer state (Parent process).
  """
  @callback handle_deleted_monitored_item(integer(), integer(), term()) :: term()

  @doc """
  Optional callback that handles a subscriptions timeout events.

  It's first argument is the `subscription_id` of the subscription.

  The second argument it's the GenServer state (Parent process).
  """
  @callback handle_subscription_timeout(integer(), term()) :: term()

  @doc """
  Optional callback that handles a subscriptions timeout events.

  It's first argument is the `subscription_id` of the subscription.

  The second argument it's the GenServer state (Parent process).
  """
  @callback handle_deleted_subscription(integer(), term()) :: term()

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer, Keyword.drop(opts, [:configuration])
      @behaviour OpcUA.Client
      @mix_env Mix.env()

      alias __MODULE__

      def start_link(user_initial_params \\ []) do
        GenServer.start_link(__MODULE__, user_initial_params, unquote(opts))
      end

      @impl true
      def init(user_initial_params) do
        send(self(), :init)
        {:ok, user_initial_params}
      end

      @impl true
      def handle_info(:init, user_initial_params) do
        # Client Terraform
        {:ok, c_pid} = OpcUA.Client.start_link()

        configuration = apply(__MODULE__, :configuration, [user_initial_params])
        monitored_items = apply(__MODULE__, :monitored_items, [user_initial_params])

        #OpcUA.Client.set_config(c_pid)

        # configutation = [config: list(), connection: list()]
        set_client_config(c_pid, configuration, :config)
        set_client_config(c_pid, configuration, :conn)

        # monitored_tiems = [subscription: 100.3, monitored_item: %MonitoredItem{}, ...]
        set_client_monitored_items(c_pid, monitored_items)

        # User initialization.
        user_state = apply(__MODULE__, :init, [user_initial_params, c_pid])

        {:noreply, user_state}
      end

      def handle_info({:timeout, subscription_id}, state) do
        state = apply(__MODULE__, :handle_subscription_timeout, [subscription_id, state])
        {:noreply, state}
      end

      def handle_info({:delete, subscription_id}, state) do
        state = apply(__MODULE__, :handle_deleted_subscription, [subscription_id, state])
        {:noreply, state}
      end

      def handle_info({:data, subscription_id, monitored_id, value}, state) do
        state =
          apply(__MODULE__, :handle_monitored_data, [
            {subscription_id, monitored_id, value},
            state
          ])

        {:noreply, state}
      end

      def handle_info({:delete, subscription_id, monitored_id}, state) do
        state =
          apply(__MODULE__, :handle_deleted_monitored_item, [subscription_id, monitored_id, state])

        {:noreply, state}
      end

      @impl true
      def handle_subscription_timeout(subscription_id, state) do
        require Logger

        Logger.warning(
          "No handle_subscription_timeout/2 clause in #{__MODULE__} provided for #{
            inspect(subscription_id)
          }"
        )

        state
      end

      @impl true
      def handle_deleted_subscription(subscription_id, state) do
        require Logger

        Logger.warning(
          "No handle_deleted_subscription/2 clause in #{__MODULE__} provided for #{
            inspect(subscription_id)
          }"
        )

        state
      end

      @impl true
      def handle_monitored_data(changed_data_event, state) do
        require Logger

        Logger.warning(
          "No handle_monitored_data/2 clause in #{__MODULE__} provided for #{
            inspect(changed_data_event)
          }"
        )

        state
      end

      @impl true
      def handle_deleted_monitored_item(subscription_id, monitored_id, state) do
        require Logger

        Logger.warning(
          "No handle_deleted_monitored_item/3 clause in #{__MODULE__} provided for #{
            inspect({subscription_id, monitored_id})
          }"
        )

        state
      end

      @impl true
      def configuration(_user_init_state), do: []

      @impl true
      def monitored_items(_user_init_state), do: []

      defp set_client_config(c_pid, configuration, type) do
        config_params = Keyword.get(configuration, type, [])

        Enum.each(config_params, fn config_param ->
          if(@mix_env != :test) do
            GenServer.call(c_pid, {type, config_param})
          else
            # Valgrind
            GenServer.call(c_pid, {type, config_param}, :infinity)
          end
        end)
      end

      defp set_client_monitored_items(c_pid, monitored_items) do
        Enum.each(monitored_items, fn {item_type, monitored_item} ->
          item_args = get_monitored_item_args(monitored_item)
          GenServer.call(c_pid, {:subscription, {item_type, item_args}})
        end)
      end

      defp get_monitored_item_args(monitored_item) when is_float(monitored_item),
        do: monitored_item

      defp get_monitored_item_args(monitored_item) when is_struct(monitored_item),
        do: monitored_item[:args]

      defoverridable start_link: 0,
                     start_link: 1,
                     configuration: 1,
                     monitored_items: 1,
                     handle_subscription_timeout: 2,
                     handle_deleted_subscription: 2,
                     handle_monitored_data: 2,
                     handle_deleted_monitored_item: 3
    end
  end

  # Configuration & Lifecycle functions

  @doc """
    Starts up a OPC UA Client GenServer.
  """
  @spec start_link(term(), list()) :: {:ok, pid} | {:error, term} | {:error, :einval}
  def start_link(args \\ [], opts \\ []) do
    GenServer.start_link(__MODULE__, {args, self()}, opts)
  end

  @doc """
    Stops a OPC UA Client GenServer.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
    Gets the state of the OPC UA Client.
  """
  @spec get_state(GenServer.server()) :: {:ok, binary()} | {:error, term} | {:error, :einval}
  def get_state(pid) do
    GenServer.call(pid, {:config, {:get_state, nil}})
  end

  @doc """
    Sets the OPC UA Client configuration.
  """
  @spec set_config(GenServer.server(), map()) :: :ok | {:error, term} | {:error, :einval}
  def set_config(pid, args \\ %{}) when is_map(args) do
    GenServer.call(pid, {:config, {:set_config, args}})
  end

  @doc """
    Sets the OPC UA Client configuration with all security policies for the given certificates.
    The following must be filled:
      * `:private_key` -> binary() or function().
      * `:certificate` -> binary() or function().
      * `:security_mode` -> interger().
    NOTE: [none: 1, sign: 2, sign_and_encrypt: 3]
  """
  @spec set_config_with_certs(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def set_config_with_certs(pid, args) when is_list(args) do
    if(@mix_env != :test) do
      GenServer.call(pid, {:config, {:set_config_with_certs, args}})
    else
      # Valgrind
      GenServer.call(pid, {:config, {:set_config_with_certs, args}}, :infinity)
    end
  end

  @doc """
    Gets the OPC UA Client current Configuration.
  """
  @spec get_config(GenServer.server()) :: {:ok, map()} | {:error, term} | {:error, :einval}
  def get_config(pid) do
    GenServer.call(pid, {:config, {:get_config, nil}})
  end

  @doc """
    Resets the OPC UA Client.
  """
  @spec reset(GenServer.server()) :: :ok | {:error, term} | {:error, :einval}
  def reset(pid) do
    GenServer.call(pid, {:config, {:reset_client, nil}})
  end

  # Connection functions

  @doc """
    Connects the OPC UA Client by a url.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec connect_by_url(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def connect_by_url(pid, args) when is_list(args) do
    if(@mix_env != :test) do
      GenServer.call(pid, {:conn, {:by_url, args}})
    else
      # Valgrind
      GenServer.call(pid, {:conn, {:by_url, args}}, :infinity)
    end
  end

  @doc """
    Connects the OPC UA Client by a url using a username and a password.
    The following must be filled:
    * `:url` -> binary().
    * `:user` -> binary().
    * `:password` -> binary().
  """
  @spec connect_by_username(GenServer.server(), list()) ::
          :ok | {:error, term} | {:error, :einval}
  def connect_by_username(pid, args) when is_list(args) do
    if(@mix_env != :test) do
      GenServer.call(pid, {:conn, {:by_username, args}})
    else
      # Valgrind
      GenServer.call(pid, {:conn, {:by_username, args}}, :infinity)
    end
  end

  @doc """
    Connects the OPC UA Client by a url without a session.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec connect_no_session(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def connect_no_session(pid, args) when is_list(args) do
    GenServer.call(pid, {:conn, {:no_session, args}})
  end

  @doc """
    Disconnects the OPC UA Client.
  """
  @spec disconnect(GenServer.server()) :: :ok | {:error, term} | {:error, :einval}
  def disconnect(pid) do
    GenServer.call(pid, {:conn, {:disconnect, nil}})
  end

  # Discovery functions

  @doc """
    Finds Servers Connected to a Discovery Server.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec find_servers_on_network(GenServer.server(), binary()) ::
          :ok | {:error, term} | {:error, :einval}
  def find_servers_on_network(pid, url) when is_binary(url) do
    GenServer.call(pid, {:discovery, {:find_servers_on_network, url}})
  end

  @doc """
    Finds Servers Connected to a Discovery Server.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec find_servers(GenServer.server(), binary()) :: :ok | {:error, term} | {:error, :einval}
  def find_servers(pid, url) when is_binary(url) do
    GenServer.call(pid, {:discovery, {:find_servers, url}})
  end

  @doc """
    Get endpoints from a OPC UA Server.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec get_endpoints(GenServer.server(), binary()) :: :ok | {:error, term} | {:error, :einval}
  def get_endpoints(pid, url) when is_binary(url) do
    GenServer.call(pid, {:discovery, {:get_endpoints, url}})
  end

  # Subscriptions and Monitored Items functions.

  @doc """
    Sends an OPC UA Server request to start subscription (to monitored items, events, etc).
  """
  @spec add_subscription(GenServer.server()) ::
          {:ok, integer()} | {:error, term} | {:error, :einval}
  def add_subscription(pid, publishing_interval \\ 500.0) when is_float(publishing_interval) do
    GenServer.call(pid, {:subscription, {:subscription, publishing_interval}})
  end

  @doc """
    Sends an OPC UA Server request to delete a subscription.
  """
  @spec delete_subscription(GenServer.server(), integer()) ::
          :ok | {:error, term} | {:error, :einval}
  def delete_subscription(pid, subscription_id) when is_integer(subscription_id) do
    GenServer.call(pid, {:subscription, {:delete, subscription_id}})
  end

  @doc """
    Adds a monitored item used to request a server for notifications of each change of value in a specific node.
    The following option must be filled:
    * `:subscription_id` -> integer().
    * `:monitored_item` -> %NodeId{}.
  """
  @spec add_monitored_item(GenServer.server(), list()) ::
          {:ok, integer()} | {:error, term} | {:error, :einval}
  def add_monitored_item(pid, args) when is_list(args) do
    GenServer.call(pid, {:subscription, {:monitored_item, args}})
  end

  @doc """
    Adds a monitored item used to request a server for notifications of each change of value in a specific node.
    The following option must be filled:
    * `:subscription_id` -> integer().
    * `:monitored_item_id` -> integer().
  """
  @spec delete_monitored_item(GenServer.server(), list()) ::
          :ok | {:error, term} | {:error, :einval}
  def delete_monitored_item(pid, args) when is_list(args) do
    GenServer.call(pid, {:subscription, {:delete_monitored_item, args}})
  end

  # Read nodes Attributes

  @doc """
    Reads 'user_write_mask' attribute of a node in the server.
  """
  @spec read_node_user_write_mask(GenServer.server(), %NodeId{}) ::
          :ok | {:error, binary()} | {:error, :einval}
  def read_node_user_write_mask(pid, %NodeId{} = node_id) do
    GenServer.call(pid, {:read, {:user_write_mask, node_id}})
  end

  @doc """
    Reads 'user_access_level' attribute of a node in the server.
  """
  @spec read_node_user_access_level(GenServer.server(), %NodeId{}) ::
          :ok | {:error, binary()} | {:error, :einval}
  def read_node_user_access_level(pid, %NodeId{} = node_id) do
    GenServer.call(pid, {:read, {:user_access_level, node_id}})
  end

  @doc """
    Reads 'user_executable' attribute of a node in the server.
  """
  @spec read_node_user_executable(GenServer.server(), %NodeId{}) ::
          :ok | {:error, binary()} | {:error, :einval}
  def read_node_user_executable(pid, %NodeId{} = node_id) do
    GenServer.call(pid, {:read, {:user_executable, node_id}})
  end

  # Write nodes Attributes

  @doc """
    Change 'node_id' attribute of a node in the server.
  """
  @spec write_node_node_id(GenServer.server(), %NodeId{}, %NodeId{}) ::
          :ok | {:error, binary()} | {:error, :einval}
  def write_node_node_id(pid, %NodeId{} = node_id, %NodeId{} = new_node_id) do
    GenServer.call(pid, {:write, {:node_id, node_id, new_node_id}})
  end

  @doc """
    Change 'symmetric' attribute of a node in the server.
  """
  @spec write_node_symmetric(GenServer.server(), %NodeId{}, boolean()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def write_node_symmetric(pid, %NodeId{} = node_id, symmetric) when is_boolean(symmetric) do
    GenServer.call(pid, {:write, {:symmetric, node_id, symmetric}})
  end

  @doc """
    Change 'node_class' attribute of a node in the server.
    Avalable value are:
      UNSPECIFIED = 0,
      OBJECT = 1,
      VARIABLE = 2,
      METHOD = 4,
      OBJECTTYPE = 8,
      VARIABLETYPE = 16,
      REFERENCETYPE = 32,
      DATATYPE = 64,
      VIEW = 128,
  """
  @spec write_node_node_class(GenServer.server(), %NodeId{}, integer()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def write_node_node_class(pid, %NodeId{} = node_id, node_class)
      when node_class in [0, 1, 2, 4, 8, 16, 32, 64, 128] do
    GenServer.call(pid, {:write, {:node_class, node_id, node_class}})
  end

  @doc """
    Change 'user_write_mask' attribute of a node in the server.
  """
  @spec write_node_user_write_mask(GenServer.server(), %NodeId{}, integer()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def write_node_user_write_mask(pid, %NodeId{} = node_id, user_write_mask)
      when is_integer(user_write_mask) do
    GenServer.call(pid, {:write, {:user_write_mask, node_id, user_write_mask}})
  end

  @doc """
    Change 'contains_no_loops' attribute of a node in the server.
  """
  @spec write_node_contains_no_loops(GenServer.server(), %NodeId{}, boolean()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def write_node_contains_no_loops(pid, %NodeId{} = node_id, contains_no_loops)
      when is_boolean(contains_no_loops) do
    GenServer.call(pid, {:write, {:contains_no_loops, node_id, contains_no_loops}})
  end

  @doc """
    Change 'user_access_level' attribute of a node in the server.
  """
  @spec write_node_user_access_level(GenServer.server(), %NodeId{}, integer()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def write_node_user_access_level(pid, %NodeId{} = node_id, user_access_level)
      when is_integer(user_access_level) do
    GenServer.call(pid, {:write, {:user_access_level, node_id, user_access_level}})
  end

  @doc """
    Change 'user_executable' attribute of a node in the server.
  """
  @spec write_node_user_executable(GenServer.server(), %NodeId{}, boolean()) ::
          :ok | {:error, binary()} | {:error, :einval}
  def write_node_user_executable(pid, %NodeId{} = node_id, user_executable)
      when is_boolean(user_executable) do
    GenServer.call(pid, {:write, {:user_executable, node_id, user_executable}})
  end

  @doc false
  def command(pid, request) do
    GenServer.call(pid, request)
  end

  # Handlers
  def init({_args, controlling_process}) do
    lib_dir =
      :opex62541
      |> :code.priv_dir()
      |> to_string()
      |> set_ld_library_path()

    executable = lib_dir <> "/opc_ua_client"

    port = open_port(executable, use_valgrind?())

    state = %State{port: port, controlling_process: controlling_process}
    {:ok, state}
  end

  # Lifecycle Handlers

  def handle_call({:config, {:get_state, nil}}, caller_info, state) do
    call_port(state, :get_client_state, caller_info, nil)
    {:noreply, state}
  end

  def handle_call({:config, {:set_config, args}}, caller_info, state) do
    c_args =
      Enum.reduce(args, %{}, fn {key, value}, acc ->
        if is_nil(value) or key not in @config_keys do
          acc
        else
          Map.put(acc, key, value)
        end
      end)

    call_port(state, :set_client_config, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:config, {:get_config, nil}}, caller_info, state) do
    call_port(state, :get_client_config, caller_info, nil)
    {:noreply, state}
  end

  def handle_call({:config, {:reset_client, nil}}, caller_info, state) do
    call_port(state, :reset_client, caller_info, nil)
    {:noreply, state}
  end

  # Encryption

  def handle_call({:config, {:set_config_with_certs, args}}, caller_info, state) do
    with  cert <- Keyword.fetch!(args, :certificate),
          pkey <- Keyword.fetch!(args, :private_key),
          security_mode <- Keyword.get(args, :security_mode, 1),
          certificate <- get_binary_data(cert),
          private_key <- get_binary_data(pkey),
          true <- is_binary(certificate),
          true <- is_binary(private_key),
          true <- security_mode in [1, 2, 3] do
      c_args = {security_mode, certificate, private_key}
      call_port(state, :set_config_with_security_policies, caller_info, c_args)
      {:noreply, state}
    else
      _ ->
        {:reply, {:error, :einval} ,state}
    end
  end

  # Connect to a Server Handlers

  def handle_call({:conn, {:by_url, args}}, caller_info, state) do
    url = Keyword.fetch!(args, :url)
    call_port(state, :connect_client_by_url, caller_info, url)
    {:noreply, state}
  end

  def handle_call({:conn, {:by_username, args}}, caller_info, state) do
    url = Keyword.fetch!(args, :url)
    username = Keyword.fetch!(args, :user)
    password = Keyword.fetch!(args, :password)

    c_args = {url, username, password}
    call_port(state, :connect_client_by_username, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:conn, {:no_session, args}}, caller_info, state) do
    url = Keyword.fetch!(args, :url)
    call_port(state, :connect_client_no_session, caller_info, url)
    {:noreply, state}
  end

  def handle_call({:conn, {:disconnect, nil}}, caller_info, state) do
    call_port(state, :disconnect_client, caller_info, nil)
    {:noreply, state}
  end

  # Discovery Handlers.

  def handle_call({:discovery, {:find_servers_on_network, url}}, caller_info, state) do
    call_port(state, :find_servers_on_network, caller_info, url)
    {:noreply, state}
  end

  def handle_call({:discovery, {:find_servers, url}}, caller_info, state) do
    call_port(state, :find_servers, caller_info, url)
    {:noreply, state}
  end

  def handle_call({:discovery, {:get_endpoints, url}}, caller_info, state) do
    call_port(state, :get_endpoints, caller_info, url)
    {:noreply, state}
  end

  # Subscriptions and Monitored Items functions.

  def handle_call({:subscription, {:subscription, publishing_interval}}, caller_info, state) do
    call_port(state, :add_subscription, caller_info, publishing_interval)
    {:noreply, state}
  end

  def handle_call({:subscription, {:delete, subscription_id}}, caller_info, state) do
    call_port(state, :delete_subscription, caller_info, subscription_id)
    {:noreply, state}
  end

  def handle_call({:subscription, {:monitored_item, args}}, caller_info, state) do
    with monitored_item <- Keyword.fetch!(args, :monitored_item) |> to_c(),
         subscription_id <- Keyword.fetch!(args, :subscription_id),
         sampling_time <- Keyword.get(args, :sampling_time, 250.0),
         true <- is_integer(subscription_id),
         true <- is_float(sampling_time) do
      c_args = {monitored_item, subscription_id, sampling_time}
      call_port(state, :add_monitored_item, caller_info, c_args)
      {:noreply, state}
    else
      _ ->
        {:reply, {:error, :einval}, state}
    end
  end

  def handle_call({:subscription, {:delete_monitored_item, args}}, caller_info, state) do
    with monitored_item_id <- Keyword.fetch!(args, :monitored_item_id),
         subscription_id <- Keyword.fetch!(args, :subscription_id),
         true <- is_integer(monitored_item_id),
         true <- is_integer(subscription_id) do
      c_args = {subscription_id, monitored_item_id}
      call_port(state, :delete_monitored_item, caller_info, c_args)
      {:noreply, state}
    else
      _ ->
        {:reply, {:error, :einval}, state}
    end
  end

  # Write nodes Attributes

  def handle_call({:read, {:user_write_mask, node_id}}, caller_info, state) do
    c_args = to_c(node_id)
    call_port(state, :read_node_user_write_mask, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:read, {:user_access_level, node_id}}, caller_info, state) do
    c_args = to_c(node_id)
    call_port(state, :read_node_user_access_level, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:read, {:user_executable, node_id}}, caller_info, state) do
    c_args = to_c(node_id)
    call_port(state, :read_node_user_executable, caller_info, c_args)
    {:noreply, state}
  end

  # Write nodes Attributes

  def handle_call({:write, {:node_id, node_id, new_node_id}}, caller_info, state) do
    c_args = {to_c(node_id), to_c(new_node_id)}
    call_port(state, :write_node_node_id, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:write, {:node_class, node_id, node_class}}, caller_info, state) do
    c_args = {to_c(node_id), node_class}
    call_port(state, :write_node_node_class, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:write, {:user_write_mask, node_id, user_write_mask}}, caller_info, state) do
    c_args = {to_c(node_id), user_write_mask}
    call_port(state, :write_node_user_write_mask, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:write, {:symmetric, node_id, symmetric}}, caller_info, state) do
    c_args = {to_c(node_id), symmetric}
    call_port(state, :write_node_symmetric, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:write, {:contains_no_loops, node_id, contains_no_loops}}, caller_info, state) do
    c_args = {to_c(node_id), contains_no_loops}
    call_port(state, :write_node_contains_no_loops, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:write, {:user_access_level, node_id, user_access_level}}, caller_info, state) do
    c_args = {to_c(node_id), user_access_level}
    call_port(state, :write_node_user_access_level, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:write, {:user_executable, node_id, user_executable}}, caller_info, state) do
    c_args = {to_c(node_id), user_executable}
    call_port(state, :write_node_user_executable, caller_info, c_args)
    {:noreply, state}
  end

  # Catch all

  def handle_call(invalid_call, _caller_info, state) do
    Logger.error("#{__MODULE__} Invalid call: #{inspect(invalid_call)}")
    {:reply, {:error, :einval}, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    Logger.warning("(#{__MODULE__}) Error code: #{inspect(code)}.")
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
    Logger.warning("(#{__MODULE__}) Unhandled message: #{inspect(msg)}.")
    {:noreply, state}
  end

  # Subscription C message handlers

  defp handle_c_response(
         {:subscription, {:data, subscription_id, monitored_id, c_value}},
         %{controlling_process: c_pid} = state
       ) do
    value = parse_c_value(c_value)
    send(c_pid, {:data, subscription_id, monitored_id, value})
    state
  end

  defp handle_c_response(
         {:subscription, message},
         %{controlling_process: c_pid} = state
       ) do
    send(c_pid, message)
    state
  end

  # Lifecycle C Handlers

  defp handle_c_response({:get_client_state, caller_metadata, client_state}, state) do
    str_client_state = charlist_to_string(client_state)
    GenServer.reply(caller_metadata, str_client_state)
    state
  end

  defp handle_c_response({:set_client_config, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  defp handle_c_response({:get_client_config, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  defp handle_c_response({:reset_client, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  # Encryption Handlers

  defp handle_c_response({:set_config_with_security_policies, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  # Connect to a Server C Handlers

  defp handle_c_response({:connect_client_by_url, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  defp handle_c_response({:connect_client_by_username, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  defp handle_c_response({:connect_client_no_session, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  defp handle_c_response({:disconnect_client, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  # Discovery functions C Handlers

  defp handle_c_response({:find_servers_on_network, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  defp handle_c_response({:find_servers, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  defp handle_c_response({:get_endpoints, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  # Subscriptions and Monitored Items functions.

  defp handle_c_response({:add_subscription, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  defp handle_c_response({:delete_subscription, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  defp handle_c_response({:add_monitored_item, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  defp handle_c_response({:delete_monitored_item, caller_metadata, c_response}, state) do
    GenServer.reply(caller_metadata, c_response)
    state
  end

  # Read nodes Attributes

  defp handle_c_response({:read_node_user_write_mask, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:read_node_user_access_level, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:read_node_user_executable, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end


  # Write nodes Attributes

  defp handle_c_response({:write_node_node_id, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:write_node_node_class, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:write_node_user_write_mask, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:write_node_symmetric, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:write_node_contains_no_loops, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:write_node_user_access_level, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end

  defp handle_c_response({:write_node_user_executable, caller_metadata, data}, state) do
    GenServer.reply(caller_metadata, data)
    state
  end
end
