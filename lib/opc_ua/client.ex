defmodule OpcUA.Client do
  use OpcUA.Common

  @config_keys ["requestedSessionTimeout", "secureChannelLifeTime", "timeout"]

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
    GenServer.call(pid, {:get_client_state, nil})
  end

  @doc """
    Sets the OPC UA Client configuration.
  """
  @spec set_config(GenServer.server(), map()) :: :ok | {:error, term} | {:error, :einval}
  def set_config(pid, args \\ %{}) when is_map(args) do
    GenServer.call(pid, {:set_client_config, args})
  end

  @doc """
    Gets the OPC UA Client current Configuration.
  """
  @spec get_config(GenServer.server()) :: {:ok, map()} | {:error, term} | {:error, :einval}
  def get_config(pid) do
    GenServer.call(pid, {:get_client_config, nil})
  end

  @doc """
    Resets the OPC UA Client.
  """
  @spec reset(GenServer.server()) :: :ok | {:error, term} | {:error, :einval}
  def reset(pid) do
    GenServer.call(pid, {:reset_client, nil})
  end

  # Connection functions

  @doc """
    Connects the OPC UA Client by a url.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec connect_by_url(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def connect_by_url(pid, url: url) when is_binary(url) do
    GenServer.call(pid, {:connect_client_by_url, url})
  end

  @doc """
    Connects the OPC UA Client by a url using a username and a password.
    The following must be filled:
    * `:url` -> binary().
    * `:user` -> binary().
    * `:password` -> binary().
  """
  @spec connect_by_username(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def connect_by_username(pid, url: url, user: username, password: password)
      when is_binary(url) and is_binary(username) and is_binary(password) do
    GenServer.call(pid, {:connect_client_by_username, url, username, password})
  end

  @doc """
    Connects the OPC UA Client by a url without a session.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec connect_no_session(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def connect_no_session(pid, url: url) when is_binary(url) do
    GenServer.call(pid, {:connect_client_no_session, url})
  end

  @doc """
    Disconnects the OPC UA Client.
  """
  @spec disconnect(GenServer.server()) :: :ok | {:error, term} | {:error, :einval}
  def disconnect(pid) do
    GenServer.call(pid, {:disconnect_client, nil})
  end

  # Discovery functions

  @doc """
    Finds Servers Connected to a Discovery Server.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec find_servers_on_network(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def find_servers_on_network(pid, url: url) when is_binary(url) do
    GenServer.call(pid, {:find_servers_on_network, url})
  end

  @doc """
    Finds Servers Connected to a Discovery Server.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec find_servers(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def find_servers(pid, url: url) when is_binary(url) do
    GenServer.call(pid, {:find_servers, url})
  end

  @doc """
    Get endpoints from a OPC UA Server.
    The following must be filled:
    * `:url` -> binary().
  """
  @spec get_endpoints(GenServer.server(), list()) :: :ok | {:error, term} | {:error, :einval}
  def get_endpoints(pid, url: url) when is_binary(url) do
    GenServer.call(pid, {:get_endpoints, url})
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

  # Lifecycle Handlers

  def handle_call({:get_client_state, nil}, caller_info, state) do
    call_port(state, :get_client_state, caller_info, nil)
    {:noreply, state}
  end

  def handle_call({:set_client_config, args}, caller_info, state) do
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

  def handle_call({:get_client_config, nil}, caller_info, state) do
    call_port(state, :get_client_config, caller_info, nil)
    {:noreply, state}
  end

  def handle_call({:reset_client, nil}, caller_info, state) do
    call_port(state, :reset_client, caller_info, nil)
    {:noreply, state}
  end

  # Connect to a Server Handlers

  def handle_call({:connect_client_by_url, url}, caller_info, state) do
    call_port(state, :connect_client_by_url, caller_info, url)
    {:noreply, state}
  end

  def handle_call({:connect_client_by_username, url, username, password}, caller_info, state) do
    c_args = {url, username, password}
    call_port(state, :connect_client_by_username, caller_info, c_args)
    {:noreply, state}
  end

  def handle_call({:connect_client_no_session, url}, caller_info, state) do
    call_port(state, :connect_client_no_session, caller_info, url)
    {:noreply, state}
  end

  def handle_call({:disconnect_client, nil}, caller_info, state) do
    call_port(state, :disconnect_client, caller_info, nil)
    {:noreply, state}
  end

  # Discovery Handlers.

  def handle_call({:find_servers_on_network, url}, caller_info, state) do
    call_port(state, :find_servers_on_network, caller_info, url)
    {:noreply, state}
  end

  def handle_call({:find_servers, url}, caller_info, state) do
    call_port(state, :find_servers, caller_info, url)
    {:noreply, state}
  end

  def handle_call({:get_endpoints, url}, caller_info, state) do
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
