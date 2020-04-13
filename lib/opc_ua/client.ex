defmodule OpcUA.Client do
  use GenServer
  require Logger

  alias OpcUA.QualifiedName
  alias OpcUA.NodeId

  @c_timeout 5000
  @config_keys ["requestedSessionTimeout", "secureChannelLifeTime", "timeout"]

  defmodule State do
    @moduledoc false

    # port: C port process
    # controlling_process: parent process
    # queued_messages: queued messages during port request.

    defstruct port: nil,
              controlling_process: nil,
              queued_messages: []
  end

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

  # Handlers
  def init({_args, controlling_process}) do
    executable = :code.priv_dir(:opex62541) ++ '/opc_ua_client'

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

  def handle_call({:get_client_state, nil}, {_from, _}, state) do
    {new_state, response} = call_port(state, :get_client_state, nil)
    str_response = charlist_to_string(response)
    {:reply, str_response, new_state}
  end

  def handle_call({:set_client_config, args}, {_from, _}, state) do
    c_args =
      Enum.reduce(args, %{}, fn {key, value}, acc ->
        if is_nil(value) or key not in @config_keys do
          acc
        else
          Map.put(acc, key, value)
        end
      end)

    {new_state, response} = call_port(state, :set_client_config, c_args)
    {:reply, response, new_state}
  end

  def handle_call({:get_client_config, nil}, {_from, _}, state) do
    {new_state, response} = call_port(state, :get_client_config, nil)
    {:reply, response, new_state}
  end

  def handle_call({:reset_client, nil}, {_from, _}, state) do
    {new_state, response} = call_port(state, :reset_client, nil)
    {:reply, response, new_state}
  end

  def handle_call({:connect_client_by_url, url}, {_from, _}, state) do
    {new_state, response} = call_port(state, :connect_client_by_url, url)
    {:reply, response, new_state}
  end

  def handle_call({:connect_client_by_username, url, username, password}, {_from, _}, state) do
    {new_state, response} = call_port(state, :connect_client_by_username, {url, username, password})
    {:reply, response, new_state}
  end

  def handle_call({:connect_client_no_session, url}, {_from, _}, state) do
    {new_state, response} = call_port(state, :connect_client_no_session, url)
    {:reply, response, new_state}
  end

  def handle_call({:disconnect_client, nil}, {_from, _}, state) do
    {new_state, response} = call_port(state, :disconnect_client, nil)
    {:reply, response, new_state}
  end

  # Catch all

  def handle_call(invalid_call, {_from, _}, state) do
    Logger.error("#{__MODULE__} Invalid call: #{inspect(invalid_call)}")
    {:reply, {:error, :einval}, state}
  end

  def handle_info({_port, {:data, <<?r, response::binary>>}}, state) do
    data = :erlang.binary_to_term(response)
    Logger.warn("(#{__MODULE__}) data: #{inspect(data)}.")
    {:noreply, state}
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

  defp add_to_buffer_or_response(async_response, %{queued_messages: msgs} = state) do
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
    Enum.each(msgs, fn msg -> send(self(), msg) end)
    {%State{state | queued_messages: []}, response}
  end

  defp to_c(%NodeId{ns_index: ns_index, identifier_type: id_type, identifier: identifier}),
    do: {id_type, ns_index, identifier}

  defp to_c(%QualifiedName{ns_index: ns_index, name: name}),
    do: {ns_index, name}

  defp to_c(_invalid_struct), do: raise("Invalid Data type")

  # For NodeId, QualifiedName.
  defp value_to_c(data_type, value) when data_type in [16, 17, 19], do: to_c(value)
  # SEMANTICCHANGESTRUCTUREDATATYPE
  defp value_to_c(data_type, {arg1, arg2}) when data_type == 25, do: {to_c(arg1), to_c(arg2)}
  defp value_to_c(_data_type, value), do: value

  defp charlist_to_string({:ok, charlist}), do: {:ok, to_string(charlist)}
  defp charlist_to_string(error_response), do: error_response
end
