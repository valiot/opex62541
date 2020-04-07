defmodule OpcUA.Server do
  use GenServer
  require Logger

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
  @spec set_port(GenServer.server(), binary()) :: :ok | {:error, binary()} | {:error, :einval}
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


  # Handelers
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

  # Handelers Lifecyle & Configuration Functions

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

  def handle_info({_port, {:data, data}}, state) do
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
end
