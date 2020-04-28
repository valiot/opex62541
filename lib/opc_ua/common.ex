defmodule OpcUA.Common do
  @moduledoc """
  This module covers common functions for Client & Server behavior.
  """

  alias OpcUA.QualifiedName
  alias OpcUA.NodeId

  defmacro __using__(_opts) do

    quote do
      use GenServer
      require Logger

      @c_timeout 5000

      defmodule State do
        @moduledoc false

        # port: C port process
        # controlling_process: parent process
        # queued_messages: queued messages during port request.

        defstruct port: nil,
                  controlling_process: nil,
                  queued_messages: []
      end

      # Write nodes Attributes functions

      @doc """
      Change the browse name of a node in the server.
      """
      @spec write_node_browse_name(GenServer.server(), %NodeId{}, %QualifiedName{}) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_browse_name(pid, %NodeId{} = node_id, browse_name) do
        GenServer.call(pid, {:write_node_browse_name, node_id, browse_name})
      end

      @doc """
      Change the display name attribute of a node in the server.
      """
      @spec write_node_display_name(GenServer.server(), %NodeId{}, binary(), binary()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_display_name(pid, %NodeId{} = node_id, locale, name) do
        GenServer.call(pid, {:write_node_display_name, node_id, locale, name})
      end

      @doc """
      Change description attribute of a node in the server.
      """
      @spec write_node_description(GenServer.server(), %NodeId{}, binary(), binary()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_description(pid, %NodeId{} = node_id, locale, description) do
        GenServer.call(pid, {:write_node_description, node_id, locale, description})
      end

      #TODO: friendlier write_mask params
      @doc """
      Change 'Write Mask' attribute of a node in the server.
      """
      @spec write_node_write_mask(GenServer.server(), %NodeId{}, integer()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_write_mask(pid, %NodeId{} = node_id, write_mask) do
        GenServer.call(pid, {:write_node_write_mask, node_id, write_mask})
      end

      @doc """
      Change 'Is Abstract' attribute of a node in the server.
      """
      @spec write_node_is_abstract(GenServer.server(), %NodeId{}, boolean()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_is_abstract(pid, %NodeId{} = node_id, is_abstract?) do
        GenServer.call(pid, {:write_node_is_abstract, node_id, is_abstract?})
      end

      @doc """
      Change 'Inverse name' attribute of a node in the server.
      """
      @spec write_node_inverse_name(GenServer.server(), %NodeId{}, binary(), binary()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_inverse_name(pid, %NodeId{} = node_id, locale, inverse_name) do
        GenServer.call(pid, {:write_node_inverse_name, node_id, locale, inverse_name})
      end

      @doc """
      Change 'data_type' attribute of a node in the server.
      """
      @spec write_node_data_type(GenServer.server(), %NodeId{}, %NodeId{}) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_data_type(pid, %NodeId{} = node_id, %NodeId{} = data_type_node_id) do
        GenServer.call(pid, {:write_node_data_type, node_id, data_type_node_id})
      end

      @doc """
      Change 'Value Rank' of a node in the server.
      """
      @spec write_node_value_rank(GenServer.server(), %NodeId{}, integer()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_value_rank(pid, %NodeId{} = node_id, value_rank) do
        GenServer.call(pid, {:write_node_value_rank, node_id, value_rank})
      end

      @doc """
      Change 'Access level' of a node in the server.
      """
      @spec write_node_access_level(GenServer.server(), %NodeId{}, integer()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_access_level(pid, %NodeId{} = node_id, access_level) do
        GenServer.call(pid, {:write_node_access_level, node_id, access_level})
      end

      @doc """
      Change 'Minimum Sampling Interval level' of a node in the server.
      """
      @spec write_node_minimum_sampling_interval(GenServer.server(), %NodeId{}, integer()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_minimum_sampling_interval(pid, %NodeId{} = node_id, minimum_sampling_interval) do
        GenServer.call(pid, {:write_node_minimum_sampling_interval, node_id, minimum_sampling_interval})
      end

      @doc """
      Change 'Historizing' attribute of a node in the server.
      """
      @spec write_node_historizing(GenServer.server(), %NodeId{}, boolean()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_historizing(pid, %NodeId{} = node_id, historizing?) do
        GenServer.call(pid, {:write_node_historizing, node_id, historizing?})
      end

      @doc """
      Change 'Executable' attribute of a node in the server.
      """
      @spec write_node_executable(GenServer.server(), %NodeId{}, boolean()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_executable(pid, %NodeId{} = node_id, executable?) do
        GenServer.call(pid, {:write_node_executable, node_id, executable?})
      end

      @doc """
      Change 'Value' attribute of a node in the server.
      """
      @spec write_node_value(GenServer.server(), %NodeId{}, integer(), term()) :: :ok | {:error, binary()} | {:error, :einval}
      def write_node_value(pid, %NodeId{} = node_id, data_type, value) do
        GenServer.call(pid, {:write_node_value, node_id, data_type, value})
      end

      # Read nodes Attributes function

      @doc """
      Reads the browse name of a node in the server.
      """
      @spec read_node_browse_name(GenServer.server(), %NodeId{}) :: {:ok, %QualifiedName{}} | {:error, binary()} | {:error, :einval}
      def read_node_browse_name(pid, %NodeId{} = node_id) do
        GenServer.call(pid, {:read_node_browse_name, node_id})
      end

      @doc """
      Reads the display name attribute of a node in the server.
      """
      @spec read_node_display_name(GenServer.server(), %NodeId{}) :: {:ok, {binary(), binary()}} | {:error, binary()} | {:error, :einval}
      def read_node_display_name(pid, %NodeId{} = node_id) do
        GenServer.call(pid, {:read_node_display_name, node_id})
      end

      @doc """
      Reads description attribute of a node in the server.
      """
      @spec read_node_description(GenServer.server(), %NodeId{}) :: {:ok, {binary(), binary()}} | {:error, binary()} | {:error, :einval}
      def read_node_description(pid, node_id) do
        GenServer.call(pid, {:read_node_description, node_id})
      end

      @doc """
      Reads 'Is Abstract' attribute of a node in the server.
      """
      @spec read_node_is_abstract(GenServer.server(), %NodeId{}) :: {:ok, boolean()} | {:error, binary()} | {:error, :einval}
      def read_node_is_abstract(pid, node_id) do
        GenServer.call(pid, {:read_node_is_abstract, node_id})
      end

      #TODO: friendlier write_mask params
      @doc """
      Reads 'Write Mask' attribute of a node in the server.
      """
      @spec read_node_write_mask(GenServer.server(), %NodeId{}) :: {:ok, integer()} | {:error, binary()} | {:error, :einval}
      def read_node_write_mask(pid, node_id) do
        GenServer.call(pid, {:read_node_write_mask, node_id})
      end

      @doc """
      Reads 'data_type' attribute of a node in the server.
      """
      @spec read_node_data_type(GenServer.server(), %NodeId{}) :: {:ok, %NodeId{}} | {:error, binary()} | {:error, :einval}
      def read_node_data_type(pid, node_id) do
        GenServer.call(pid, {:read_node_data_type, node_id})
      end

      @doc """
      Reads 'Inverse name' attribute of a node in the server.
      """
      @spec read_node_inverse_name(GenServer.server(), %NodeId{}) :: {:ok, {binary(), binary()}} | {:error, binary()} | {:error, :einval}
      def read_node_inverse_name(pid, node_id) do
        GenServer.call(pid, {:read_node_inverse_name, node_id})
      end

      @doc """
      Reads 'Value Rank' of a node in the server.
      """
      @spec read_node_value_rank(GenServer.server(), %NodeId{}) :: {:ok, integer()} | {:error, binary()} | {:error, :einval}
      def read_node_value_rank(pid, node_id) do
        GenServer.call(pid, {:read_node_value_rank, node_id})
      end

      @doc """
      Reads 'Access level' of a node in the server.
      """
      @spec read_node_access_level(GenServer.server(), %NodeId{}) :: {:ok, integer()} | {:error, binary()} | {:error, :einval}
      def read_node_access_level(pid, node_id) do
        GenServer.call(pid, {:read_node_access_level, node_id})
      end

      @doc """
      Reads 'Minimum Sampling Interval level' of a node in the server.
      """
      @spec read_node_minimum_sampling_interval(GenServer.server(), %NodeId{}) :: {:ok, integer()} | {:error, binary()} | {:error, :einval}
      def read_node_minimum_sampling_interval(pid, node_id) do
        GenServer.call(pid, {:read_node_minimum_sampling_interval, node_id})
      end

      @doc """
      Reads 'Historizing' attribute of a node in the server.
      """
      @spec read_node_historizing(GenServer.server(), %NodeId{}) :: {:ok, boolean()} | {:error, binary()} | {:error, :einval}
      def read_node_historizing(pid, node_id) do
        GenServer.call(pid, {:read_node_historizing, node_id})
      end

      @doc """
      Reads 'Executable' attribute of a node in the server.
      """
      @spec read_node_executable(GenServer.server(), %NodeId{}) :: {:ok, boolean()} | {:error, binary()} | {:error, :einval}
      def read_node_executable(pid, node_id) do
        GenServer.call(pid, {:read_node_executable, node_id})
      end

      @doc """
      Reads 'Value' attribute of a node in the server.
      """
      @spec read_node_value(GenServer.server(), %NodeId{}) :: {:ok, term()} | {:error, binary()} | {:error, :einval}
      def read_node_value(pid, node_id) do
        GenServer.call(pid, {:read_node_value, node_id})
      end

      # Write nodes Attributes handlers

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

      def handle_call({:write_node_is_abstract, node_id, is_abstract?}, {_from, _}, state) when is_boolean(is_abstract?) do
        c_args = {to_c(node_id), is_abstract?}
        {new_state, response} = call_port(state, :write_node_is_abstract, c_args)
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

      def handle_call({:write_node_minimum_sampling_interval, node_id, minimum_sampling_interval}, {_from, _}, state) when is_float(minimum_sampling_interval) do
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

      # Read nodes Attributes handlers

      def handle_call({:read_node_browse_name, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, browse_name_response} = call_port(state, :read_node_browse_name, c_args)
        response = parse_browse_name(browse_name_response)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_display_name, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_display_name, c_args)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_description, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_description, c_args)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_is_abstract, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_is_abstract, c_args)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_write_mask, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_write_mask, c_args)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_data_type, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, data_type_response} = call_port(state, :read_node_data_type, c_args)
        response = parse_data_type(data_type_response)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_inverse_name, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_inverse_name, c_args)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_value_rank, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_value_rank, c_args)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_access_level, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_access_level, c_args)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_minimum_sampling_interval, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_minimum_sampling_interval, c_args)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_historizing, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_historizing, c_args)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_executable, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_executable, c_args)
        {:reply, response, new_state}
      end

      def handle_call({:read_node_value, node_id}, {_from, _}, state) do
        c_args = to_c(node_id)
        {new_state, response} = call_port(state, :read_node_value, c_args)
        {:reply, response, new_state}
      end

      # Catch all handlers

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
        new_state = %{state | queued_messages: new_msgs}

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
        {%{state | queued_messages: []}, response}
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

      defp parse_browse_name({:ok, {ns_index, name}}), do: {:ok, QualifiedName.new(ns_index: ns_index, name: name)}
      defp parse_browse_name(response), do: response

      defp parse_data_type({:ok, {ns_index, type, name}}), do: {:ok, NodeId.new(ns_index: ns_index, identifier_type: type, identifier: name)}
      defp parse_data_type(response), do: response
    end
  end
end
