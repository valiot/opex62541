defmodule OpcUA.Client do
  use OpcUA.Common
  alias OpcUA.NodeId

  @config_keys ["requestedSessionTimeout", "secureChannelLifeTime", "timeout"]

   @moduledoc """

  OPC UA Client API module.

  This module provides functions for configuration, read/write nodes attributes and discovery of a OPC UA Client.

  `OpcUA.Client` is implemented as a `__using__` macro so that you can put it in any module,
  you can initialize your Client manually (see `test/client_tests`) or by overwriting
  `configuration/0` and `monitored_items` to autoset the configuration and subscription items. It also helps you to
  handle Client's "subscription" events (monitorItems) by overwriting `handle_subscription/2` callback.

  The following example shows a module that takes its configuration from the enviroment (see `test/client_tests/terraform_test.exs`):

  ```elixir
  defmodule MyClient do
    use OpcUA.Client
    alias OpcUA.Client

    # Use the `init` function to configure your Client.
    def init({parent_pid, 103} = _user_init_state, opc_ua_client_pid) do
      %{parent_pid: parent_pid}
    end

    def configuration(), do: Application.get_env(:opex62541, :configuration, [])
    def monitored_items(), do: Application.get_env(:opex62541, :monitored_items, [])

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
    use OpcUA.Client, restart: :transient, shutdown: 10_000
  end
  ```
  """

  @type config_params ::
          {:hostname, binary()}
          | {:port, non_neg_integer()}
          | {:users, keyword()}


  @type config_options ::
          {:config, config_params}
          | {:connection, {binary(), non_neg_integer()}}

  @doc """
  Optional callback that gets the Server configuration and discovery connection parameters.
  """
  @callback configuration() :: config_options

  #TODO:
  @type monitored_items_options ::
          {:config, config_params}
          | {:connection, {binary(), non_neg_integer()}}

  @callback monitored_items() :: monitored_items_options

  @doc """
  Optional callback that handles node values updates from a Client to a Server.

  It's first argument will a tuple, in which its first element is the `node_id` of the monitored node
  and the second element is the updated value.

  the second argument it's the GenServer state (Parent process).
  """
  @callback handle_subscription(key :: {%NodeId{}, any}, map) :: map

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer, Keyword.drop(opts, [:configuration])
      @behaviour OpcUA.Client

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

        # Client Terraform
        {:ok, c_pid} = OpcUA.Client.start_link()
        configuration = apply(__MODULE__, :configuration, [])
        monitored_items = apply(__MODULE__, :monitored_items, [])

        OpcUA.Client.set_config(c_pid)

        # configutation = [config: list(), connection: list()]
        set_client_config(c_pid, configuration, :config)
        set_client_config(c_pid, configuration, :conn)

        # address_space = [namespace: "", namespace: "", variable: %VariableNode{}, ...]
        set_client_monitored_items(c_pid, monitored_items)

        # User initialization.
        user_state = apply(__MODULE__, :init, [user_initial_params, c_pid])

        {:noreply, user_state}
      end

      def handle_info({%NodeId{} = node_id, value}, state) do
        state = apply(__MODULE__, :subscription_event, [{node_id, value}, state])
        {:noreply, state}
      end

      @impl true
      def handle_subscription(subscription_event, _state) do
        raise "No handle_subscription/2 clause in #{__MODULE__} provided for #{inspect(subscription_event)}"
      end

      @impl true
      def monitored_items(), do: []

      @impl true
      def configuration(), do: []

      defp set_client_config(c_pid, configuration, type) do
        config_params = Keyword.get(configuration, type, [])
        Enum.each(config_params, fn(config_param) -> GenServer.call(c_pid, {type, config_param}) end)
      end

      defp set_client_monitored_items(c_pid, monitored_items) do
        Enum.each(monitored_items, fn(monitored_item) -> GenServer.call(c_pid, {:add, {:monitored_items, monitored_item}}) end)
      end

      defoverridable  start_link: 0,
                      start_link: 1,
                      configuration: 0,
                      monitored_items: 0,
                      handle_subscription: 2
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
    GenServer.call(pid, {:conn, {:by_url, args}})
  end

  @doc """
    Connects the OPC UA Client by a url using a username and a password.
    The following must be filled:
    * `:url` -> binary().
    * `:user` -> binary().
    * `:password` -> binary().
  """
  @spec connect_by_username(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def connect_by_username(pid, args) when is_list(args) do
    GenServer.call(pid, {:conn, {:by_username, args}})
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
  @spec find_servers_on_network(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def find_servers_on_network(pid, url: url) when is_binary(url) do
    GenServer.call(pid, {:discovery, {:find_servers_on_network, url}})
  end

  @doc """
    Finds Servers Connected to a Discovery Server.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec find_servers(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def find_servers(pid, url: url) when is_binary(url) do
    GenServer.call(pid, {:discovery, {:find_servers, url}})
  end

  @doc """
    Get endpoints from a OPC UA Server.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec get_endpoints(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def get_endpoints(pid, url: url) when is_binary(url) do
    GenServer.call(pid, {:discovery, {:get_endpoints, url}})
  end

  # Handlers
  def init({_args, controlling_process}) do
    lib_dir =
      :opex62541
      |> :code.priv_dir()
      |> to_string()
      |> set_ld_library_path()

    executable = lib_dir <> "/opc_ua_client"

    port =
      Port.open({:spawn_executable, to_charlist(executable)}, [
        {:args, []},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

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

  # Catch all

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

  defp charlist_to_string({:ok, charlist}), do: {:ok, to_string(charlist)}
  defp charlist_to_string(error_response), do: error_response
end
