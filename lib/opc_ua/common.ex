defmodule OpcUA.Common do
  @moduledoc """
  This module covers common functions for Client & Server behavior.
  """

  alias OpcUA.QualifiedName
  alias OpcUA.{ExpandedNodeId, NodeId, QualifiedName}

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use GenServer, opts

      require Logger

      @c_timeout 5000

      @mix_env Mix.env()

      defmodule State do
        @moduledoc false

        # port: C port process
        # controlling_process: parent process

        defstruct port: nil,
                  controlling_process: nil
      end

      # Write nodes Attributes functions

      @doc """
      Change the browse name of a node in the server.
      """
      @spec write_node_browse_name(GenServer.server(), %NodeId{}, %QualifiedName{}) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_browse_name(pid, %NodeId{} = node_id, browse_name) do
        GenServer.call(pid, {:write, {:browse_name, node_id, browse_name}})
      end

      @doc """
      Change the display name attribute of a node in the server.
      """
      @spec write_node_display_name(GenServer.server(), %NodeId{}, binary(), binary()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_display_name(pid, %NodeId{} = node_id, locale, name) do
        GenServer.call(pid, {:write, {:display_name, node_id, {locale, name}}})
      end

      @doc """
      Change description attribute of a node in the server.
      """
      @spec write_node_description(GenServer.server(), %NodeId{}, binary(), binary()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_description(pid, %NodeId{} = node_id, locale, description) do
        GenServer.call(pid, {:write, {:description, node_id, {locale, description}}})
      end

      # TODO: friendlier write_mask params
      @doc """
      Change 'Write Mask' attribute of a node in the server.
      """
      @spec write_node_write_mask(GenServer.server(), %NodeId{}, integer()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_write_mask(pid, %NodeId{} = node_id, write_mask) do
        GenServer.call(pid, {:write, {:write_mask, node_id, write_mask}})
      end

      @doc """
      Change 'Is Abstract' attribute of a node in the server.
      """
      @spec write_node_is_abstract(GenServer.server(), %NodeId{}, boolean()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_is_abstract(pid, %NodeId{} = node_id, is_abstract?) do
        GenServer.call(pid, {:write, {:is_abstract, node_id, is_abstract?}})
      end

      @doc """
      Change 'Inverse name' attribute of a node in the server.
      """
      @spec write_node_inverse_name(GenServer.server(), %NodeId{}, binary(), binary()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_inverse_name(pid, %NodeId{} = node_id, locale, inverse_name) do
        GenServer.call(pid, {:write, {:inverse_name, node_id, {locale, inverse_name}}})
      end

      @doc """
      Change 'data_type' attribute of a node in the server.
      """
      @spec write_node_data_type(GenServer.server(), %NodeId{}, %NodeId{}) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_data_type(pid, %NodeId{} = node_id, %NodeId{} = data_type_node_id) do
        GenServer.call(pid, {:write, {:data_type, node_id, data_type_node_id}})
      end

      @doc """
      Change 'Value rank' of a node in the server.

      This attribute indicates whether the value attribute of the variable is an array and how many dimensions the array has.
      It may have the following values:

      value_rank >= 1: the value is an array with the specified number of dimensions
      value_rank =  0: the value is an array with one or more dimensions
      value_rank = -1: the value is a scalar
      value_rank = -2: the value can be a scalar or an array with any number of dimensions
      value_rank = -3: the value can be a scalar or a one dimensional array

      """
      @spec write_node_value_rank(GenServer.server(), %NodeId{}, integer()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_value_rank(pid, %NodeId{} = node_id, value_rank)
          when value_rank >= -3 and is_integer(value_rank) do
        GenServer.call(pid, {:write, {:value_rank, node_id, value_rank}})
      end

      @doc """
      Change 'Array Dimensions' of a node in the server.
      """
      @spec write_node_array_dimensions(GenServer.server(), %NodeId{}, list()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_array_dimensions(pid, %NodeId{} = node_id, array_dimensions)
          when is_list(array_dimensions) do
        GenServer.call(pid, {:write, {:array_dimensions, node_id, array_dimensions}})
      end

      @doc """
      Change 'Access level' of a node in the server.
      """
      @spec write_node_access_level(GenServer.server(), %NodeId{}, integer()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_access_level(pid, %NodeId{} = node_id, access_level) do
        GenServer.call(pid, {:write, {:access_level, node_id, access_level}})
      end

      @doc """
      Change 'Minimum Sampling Interval level' of a node in the server.
      """
      @spec write_node_minimum_sampling_interval(GenServer.server(), %NodeId{}, integer()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_minimum_sampling_interval(
            pid,
            %NodeId{} = node_id,
            minimum_sampling_interval
          ) do
        GenServer.call(
          pid,
          {:write, {:minimum_sampling_interval, node_id, minimum_sampling_interval}}
        )
      end

      @doc """
      Change 'Historizing' attribute of a node in the server.
      """
      @spec write_node_historizing(GenServer.server(), %NodeId{}, boolean()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_historizing(pid, %NodeId{} = node_id, historizing?) do
        GenServer.call(pid, {:write, {:historizing, node_id, historizing?}})
      end

      @doc """
      Change 'Executable' attribute of a node in the server.
      """
      @spec write_node_executable(GenServer.server(), %NodeId{}, boolean()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_executable(pid, %NodeId{} = node_id, executable?) do
        GenServer.call(pid, {:write, {:executable, node_id, executable?}})
      end

      @doc """
      Change 'event_notifier' attribute of a node in the server.
      """
      @spec write_node_event_notifier(GenServer.server(), %NodeId{}, integer()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_event_notifier(pid, %NodeId{} = node_id, event_notifier) when is_integer(event_notifier) do
        GenServer.call(pid, {:write, {:event_notifier, node_id, event_notifier}})
      end

      @doc """
      Change 'Value' attribute of a node in the server.
      """
      @spec write_node_value(GenServer.server(), %NodeId{}, integer(), term()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_value(pid, %NodeId{} = node_id, data_type, value, index \\ 0) do
        GenServer.call(pid, {:write, {:value, node_id, {data_type, value, index}}})
      end

      @doc """
      Creates a blank 'value array' attribute of a node in the server.
      Note: the array must match with 'value_rank' and 'array_dimensions' attribute.
      """
      @spec write_node_blank_array(GenServer.server(), %NodeId{}, integer(), list()) ::
              :ok | {:error, binary()} | {:error, :einval}
      def write_node_blank_array(pid, %NodeId{} = node_id, data_type, array_dimensions)
          when is_integer(data_type) and is_list(array_dimensions) do
        GenServer.call(pid, {:write, {:array, node_id, {data_type, array_dimensions}}})
      end

      # Read nodes Attributes function

      @doc """
      Reads the node_id attribute of a node in the server.
      """
      @spec read_node_node_id(GenServer.server(), %NodeId{}) ::
              {:ok, %NodeId{}} | {:error, binary()} | {:error, :einval}
      def read_node_node_id(pid, %NodeId{} = node_id) do
        GenServer.call(pid, {:read, {:node_id, node_id}})
      end

      @doc """
      Reads the node_class attribute of a node in the server.
      """
      @spec read_node_node_class(GenServer.server(), %NodeId{}) ::
              {:ok, %NodeId{}} | {:error, binary()} | {:error, :einval}
      def read_node_node_class(pid, %NodeId{} = node_id) do
        GenServer.call(pid, {:read, {:node_class, node_id}})
      end

      @doc """
      Reads the browse name attribute of a node in the server.
      """
      @spec read_node_browse_name(GenServer.server(), %NodeId{}) ::
              {:ok, %QualifiedName{}} | {:error, binary()} | {:error, :einval}
      def read_node_browse_name(pid, %NodeId{} = node_id) do
        GenServer.call(pid, {:read, {:browse_name, node_id}})
      end

      @doc """
      Reads the display name attribute of a node in the server.
      """
      @spec read_node_display_name(GenServer.server(), %NodeId{}) ::
              {:ok, {binary(), binary()}} | {:error, binary()} | {:error, :einval}
      def read_node_display_name(pid, %NodeId{} = node_id) do
        GenServer.call(pid, {:read, {:display_name, node_id}})
      end

      @doc """
      Reads description attribute of a node in the server.
      """
      @spec read_node_description(GenServer.server(), %NodeId{}) ::
              {:ok, {binary(), binary()}} | {:error, binary()} | {:error, :einval}
      def read_node_description(pid, node_id) do
        GenServer.call(pid, {:read, {:description, node_id}})
      end

      @doc """
      Reads 'Is Abstract' attribute of a node in the server.
      """
      @spec read_node_is_abstract(GenServer.server(), %NodeId{}) ::
              {:ok, boolean()} | {:error, binary()} | {:error, :einval}
      def read_node_is_abstract(pid, node_id) do
        GenServer.call(pid, {:read, {:is_abstract, node_id}})
      end

      @doc """
      Reads 'Symmetric' attribute of a node in the server.
      """
      @spec read_node_symmetric(GenServer.server(), %NodeId{}) ::
              {:ok, boolean()} | {:error, binary()} | {:error, :einval}
      def read_node_symmetric(pid, node_id) do
        GenServer.call(pid, {:read, {:symmetric, node_id}})
      end

      # TODO: friendlier write_mask params
      @doc """
      Reads 'Write Mask' attribute of a node in the server.
      """
      @spec read_node_write_mask(GenServer.server(), %NodeId{}) ::
              {:ok, integer()} | {:error, binary()} | {:error, :einval}
      def read_node_write_mask(pid, node_id) do
        GenServer.call(pid, {:read, {:write_mask, node_id}})
      end

      @doc """
      Reads 'data_type' attribute of a node in the server.
      """
      @spec read_node_data_type(GenServer.server(), %NodeId{}) ::
              {:ok, %NodeId{}} | {:error, binary()} | {:error, :einval}
      def read_node_data_type(pid, node_id) do
        GenServer.call(pid, {:read, {:data_type, node_id}})
      end

      @doc """
      Reads 'Inverse name' attribute of a node in the server.
      """
      @spec read_node_inverse_name(GenServer.server(), %NodeId{}) ::
              {:ok, {binary(), binary()}} | {:error, binary()} | {:error, :einval}
      def read_node_inverse_name(pid, node_id) do
        GenServer.call(pid, {:read, {:inverse_name, node_id}})
      end

      @doc """
      Reads 'contains_no_loops' attribute of a node in the server.
      """
      @spec read_node_contains_no_loops(GenServer.server(), %NodeId{}) ::
              {:ok, {binary(), binary()}} | {:error, binary()} | {:error, :einval}
      def read_node_contains_no_loops(pid, node_id) do
        GenServer.call(pid, {:read, {:contains_no_loops, node_id}})
      end

      @doc """
      Reads 'Value Rank' of a node in the server.
      """
      @spec read_node_value_rank(GenServer.server(), %NodeId{}) ::
              {:ok, integer()} | {:error, binary()} | {:error, :einval}
      def read_node_value_rank(pid, node_id) do
        GenServer.call(pid, {:read, {:value_rank, node_id}})
      end

      @doc """
      Reads 'array_dimensions' of a node in the server.
      """
      @spec read_node_array_dimensions(GenServer.server(), %NodeId{}) ::
              {:ok, list()} | {:error, binary()} | {:error, :einval}
      def read_node_array_dimensions(pid, node_id) do
        GenServer.call(pid, {:read, {:array_dimensions, node_id}})
      end

      @doc """
      Reads 'Access level' of a node in the server.
      """
      @spec read_node_access_level(GenServer.server(), %NodeId{}) ::
              {:ok, integer()} | {:error, binary()} | {:error, :einval}
      def read_node_access_level(pid, node_id) do
        GenServer.call(pid, {:read, {:access_level, node_id}})
      end

      @doc """
      Reads 'Minimum Sampling Interval level' of a node in the server.
      """
      @spec read_node_minimum_sampling_interval(GenServer.server(), %NodeId{}) ::
              {:ok, integer()} | {:error, binary()} | {:error, :einval}
      def read_node_minimum_sampling_interval(pid, node_id) do
        GenServer.call(pid, {:read, {:minimum_sampling_interval, node_id}})
      end

      @doc """
      Reads 'Historizing' attribute of a node in the server.
      """
      @spec read_node_historizing(GenServer.server(), %NodeId{}) ::
              {:ok, boolean()} | {:error, binary()} | {:error, :einval}
      def read_node_historizing(pid, node_id) do
        GenServer.call(pid, {:read, {:historizing, node_id}})
      end

      @doc """
      Reads 'Executable' attribute of a node in the server.
      """
      @spec read_node_executable(GenServer.server(), %NodeId{}) ::
              {:ok, boolean()} | {:error, binary()} | {:error, :einval}
      def read_node_executable(pid, node_id) do
        GenServer.call(pid, {:read, {:executable, node_id}})
      end

      @doc """
      Reads 'event_notifier' attribute of a node in the server.
      """
      @spec read_node_event_notifier(GenServer.server(), %NodeId{}) ::
              {:ok, term()} | {:error, binary()} | {:error, :einval}
      def read_node_event_notifier(pid, node_id) do
        GenServer.call(pid, {:read, {:event_notifier, node_id}})
      end

      @doc """
      Reads 'value' attribute of a node in the server.
      Note: If the value is an array you can search a scalar using `index` parameter.
      """
      @spec read_node_value(GenServer.server(), %NodeId{}, integer()) ::
              {:ok, term()} | {:error, binary()} | {:error, :einval}
      def read_node_value(pid, node_id, index \\ 0) do
        if(@mix_env != :test) do
          GenServer.call(pid, {:read, {:value, {node_id, index}}})
        else
          # Valgrind
          GenServer.call(pid, {:read, {:value, {node_id, index}}}, :infinity)
        end
      end

      @doc """
      Reads 'value' attribute of a node in the server.
      Note: If the value is an array you can search a scalar using `index` parameter.
      """
      @spec read_node_value_by_index(GenServer.server(), %NodeId{}, integer()) ::
              {:ok, term()} | {:error, binary()} | {:error, :einval}
      def read_node_value_by_index(pid, node_id, index \\ 0) do
        if(@mix_env != :test) do
          GenServer.call(pid, {:read, {:value_by_index, {node_id, index}}})
        else
          # Valgrind
          GenServer.call(pid, {:read, {:value_by_index, {node_id, index}}}, :infinity)
        end
      end

      @doc """
      Reads 'Value' attribute (matching data type) of a node in the server.
      """
      @spec read_node_value_by_data_type(GenServer.server(), %NodeId{}, integer()) ::
              {:ok, term()} | {:error, binary()} | {:error, :einval}
      def read_node_value_by_data_type(pid, node_id, data_type) when is_integer(data_type) do
        GenServer.call(pid, {:read, {:value_by_data_type, {node_id, data_type}}})
      end

      # Write nodes Attributes handlers
      def handle_call({:write, {:browse_name, node_id, browse_name}}, caller_info, state) do
        c_args = {to_c(node_id), to_c(browse_name)}
        call_port(state, :write_node_browse_name, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:display_name, node_id, {locale, name}}}, caller_info, state)
          when is_binary(locale) and is_binary(name) do
        c_args = {to_c(node_id), locale, name}
        call_port(state, :write_node_display_name, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call(
            {:write, {:description, node_id, {locale, description}}},
            caller_info,
            state
          )
          when is_binary(locale) and is_binary(description) do
        c_args = {to_c(node_id), locale, description}
        call_port(state, :write_node_description, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:write_mask, node_id, write_mask}}, caller_info, state)
          when is_integer(write_mask) do
        c_args = {to_c(node_id), write_mask}
        call_port(state, :write_node_write_mask, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:is_abstract, node_id, is_abstract?}}, caller_info, state)
          when is_boolean(is_abstract?) do
        c_args = {to_c(node_id), is_abstract?}
        call_port(state, :write_node_is_abstract, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call(
            {:write, {:inverse_name, node_id, {locale, inverse_name}}},
            caller_info,
            state
          )
          when is_binary(locale) and is_binary(inverse_name) do
        c_args = {to_c(node_id), locale, inverse_name}
        call_port(state, :write_node_inverse_name, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:data_type, node_id, data_type_node_id}}, caller_info, state) do
        c_args = {to_c(node_id), to_c(data_type_node_id)}
        call_port(state, :write_node_data_type, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:value_rank, node_id, value_rank}}, caller_info, state)
          when is_integer(value_rank) do
        c_args = {to_c(node_id), value_rank}
        call_port(state, :write_node_value_rank, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:array_dimensions, node_id, array_dimensions}}, caller_info, state)
          when is_list(array_dimensions) do
        with true <- all_must_be(:integer, array_dimensions) do
          c_args = {to_c(node_id), length(array_dimensions), List.to_tuple(array_dimensions)}
          call_port(state, :write_node_array_dimensions, caller_info, c_args)
          {:noreply, state}
        else
          _ ->
            {:reply, {:error, :einval}, state}
        end
      end

      def handle_call({:write, {:access_level, node_id, access_level}}, caller_info, state)
          when is_integer(access_level) do
        c_args = {to_c(node_id), access_level}
        call_port(state, :write_node_access_level, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call(
            {:write, {:minimum_sampling_interval, node_id, minimum_sampling_interval}},
            caller_info,
            state
          )
          when is_float(minimum_sampling_interval) do
        c_args = {to_c(node_id), minimum_sampling_interval}
        call_port(state, :write_node_minimum_sampling_interval, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:historizing, node_id, historizing?}}, caller_info, state)
          when is_boolean(historizing?) do
        c_args = {to_c(node_id), historizing?}
        call_port(state, :write_node_historizing, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:executable, node_id, executable?}}, caller_info, state)
          when is_boolean(executable?) do
        c_args = {to_c(node_id), executable?}
        call_port(state, :write_node_executable, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:event_notifier, node_id, event_notifier}}, caller_info, state)
          when is_integer(event_notifier) do
        c_args = {to_c(node_id), event_notifier}
        call_port(state, :write_node_event_notifier, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:value, node_id, {data_type, raw_value}}}, caller_info, state) do
        c_args = {to_c(node_id), data_type, 0, value_to_c(data_type, raw_value)}
        call_port(state, :write_node_value, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:value, node_id, {data_type, raw_value, index}}}, caller_info, state) do
        c_args = {to_c(node_id), data_type, index, value_to_c(data_type, raw_value)}
        call_port(state, :write_node_value, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:write, {:array, node_id, {data_type, array_dimensions}}}, caller_info, state)
          when is_integer(data_type) and is_list(array_dimensions) do
        with  true <- all_must_be(:integer, array_dimensions),
              array_raw_size <- get_array_raw_size(array_dimensions) do
          #{node_id, data_type, }
          c_args = {to_c(node_id), data_type, length(array_dimensions), array_raw_size, List.to_tuple(array_dimensions)}
          call_port(state, :write_node_blank_array, caller_info, c_args)
          {:noreply, state}
        else
          _ ->
            {:reply, {:error, :einval}, state}
        end
      end

      # Read nodes Attributes handlers

      def handle_call({:read, {:node_id, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_node_id, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:browse_name, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_browse_name, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:node_class, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_node_class, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:display_name, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_display_name, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:description, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_description, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:is_abstract, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_is_abstract, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:symmetric, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_symmetric, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:write_mask, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_write_mask, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:data_type, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_data_type, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:inverse_name, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_inverse_name, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:contains_no_loops, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_contains_no_loops, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:value_rank, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_value_rank, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:array_dimensions, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_array_dimensions, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:access_level, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_access_level, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:minimum_sampling_interval, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_minimum_sampling_interval, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:historizing, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_historizing, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:executable, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_executable, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:event_notifier, node_id}}, caller_info, state) do
        c_args = to_c(node_id)
        call_port(state, :read_node_event_notifier, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:value, {node_id, index}}}, caller_info, state) do
        c_args = {to_c(node_id), index}
        call_port(state, :read_node_value, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:value_by_index, {node_id, index}}}, caller_info, state) do
        c_args = {to_c(node_id), index}
        call_port(state, :read_node_value_by_index, caller_info, c_args)
        {:noreply, state}
      end

      def handle_call({:read, {:value_by_data_type, {node_id, data_type}}}, caller_info, state) do
        c_args = {to_c(node_id), data_type}
        call_port(state, :read_node_value_by_data_type, caller_info, c_args)
        {:noreply, state}
      end

      # Catch all handlers

      def handle_info({_port, {:data, <<?r, c_response::binary>>}}, state) do
        state =
          c_response
          |> :erlang.binary_to_term()
          |> handle_c_response(state)

        {:noreply, state}
      end

      # Write nodes Attributes C handlers

      defp handle_c_response({:write_node_browse_name, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_display_name, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_description, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_write_mask, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_is_abstract, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_inverse_name, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_data_type, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_value_rank, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_array_dimensions, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_access_level, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response(
             {:write_node_minimum_sampling_interval, caller_metadata, data},
             state
           ) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_historizing, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_executable, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_event_notifier, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_value, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:write_node_blank_array, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      # Read nodes Attributes C handlers

      defp handle_c_response({:read_node_node_id, caller_metadata, node_id_response}, state) do
        response = parse_node_id(node_id_response)
        GenServer.reply(caller_metadata, response)
        state
      end

      defp handle_c_response({:read_node_node_class, caller_metadata, data}, state) do
        response = charlist_to_string(data)
        GenServer.reply(caller_metadata, response)
        state
      end

      defp handle_c_response(
             {:read_node_browse_name, caller_metadata, browse_name_response},
             state
           ) do
        response = parse_browse_name(browse_name_response)
        GenServer.reply(caller_metadata, response)
        state
      end

      defp handle_c_response({:read_node_display_name, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_description, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_write_mask, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_is_abstract, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_symmetric, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_inverse_name, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_data_type, caller_metadata, data_type_response}, state) do
        response = parse_data_type(data_type_response)
        GenServer.reply(caller_metadata, response)
        state
      end

      defp handle_c_response({:read_node_value_rank, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_array_dimensions, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_access_level, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_minimum_sampling_interval, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_contains_no_loops, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_historizing, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_executable, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_event_notifier, caller_metadata, data}, state) do
        GenServer.reply(caller_metadata, data)
        state
      end

      defp handle_c_response({:read_node_value, caller_metadata, value_response}, state) do
        response = parse_value(value_response)
        GenServer.reply(caller_metadata, response)
        state
      end

      defp handle_c_response({:read_node_value_by_index, caller_metadata, value_response}, state) do
        response = parse_value(value_response)
        GenServer.reply(caller_metadata, response)
        state
      end

      defp handle_c_response(
             {:read_node_value_by_data_type, caller_metadata, value_response},
             state
           ) do
        response = parse_value(value_response)
        GenServer.reply(caller_metadata, response)
        state
      end

      defp use_valgrind?(), do: System.get_env("USE_VALGRIND", "false")

      defp open_port(executable, "false") do
        Port.open({:spawn_executable, to_charlist(executable)}, [
          {:args, []},
          {:packet, 2},
          :use_stdio,
          :binary,
          :exit_status
        ])
      end

      defp open_port(executable, valgrind_env) do
        Logger.warn("(#{__MODULE__}) Valgrind Activated: #{inspect valgrind_env}")
        Port.open({:spawn_executable, to_charlist("/usr/bin/valgrind.bin")}, [
          {:args,
           [
             "-q",
             "--undef-value-errors=no",
             "--leak-check=full",
             "--show-leak-kinds=all",
             #"--verbose",
             #"--track-origins=yes",
             executable
           ]},
          {:packet, 2},
          :use_stdio,
          :binary,
          :exit_status
        ])
      end

      defp call_port(state, command, caller, arguments) do
        msg = {command, caller, arguments}
        send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})
      end

      defp charlist_to_string({:ok, charlist}), do: {:ok, to_string(charlist)}
      defp charlist_to_string(error_response), do: error_response

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

      defp parse_browse_name({:ok, {ns_index, name}}),
        do: {:ok, QualifiedName.new(ns_index: ns_index, name: name)}

      defp parse_browse_name(response), do: response

      defp parse_node_id({:ok, {ns_index, type, name}}),
        do: {:ok, NodeId.new(ns_index: ns_index, identifier_type: type, identifier: name)}

      defp parse_node_id(response), do: response

      defp parse_data_type({:ok, {ns_index, type, name}}),
        do: {:ok, NodeId.new(ns_index: ns_index, identifier_type: type, identifier: name)}

      defp parse_data_type(response), do: response

      defp parse_value({:ok, {ns_index, type, name, name_space_uri, server_index}}),
        do:
          {:ok,
           ExpandedNodeId.new(
             node_id: NodeId.new(ns_index: ns_index, identifier_type: type, identifier: name),
             name_space_uri: name_space_uri,
             server_index: server_index
           )}

      defp parse_value({:ok, {ns_index, type, name}}),
        do: {:ok, NodeId.new(ns_index: ns_index, identifier_type: type, identifier: name)}

      defp parse_value({:ok, {{ns_index1, type1, name1}, {ns_index2, type2, name2}}}),
        do: {
          :ok,
          {
            NodeId.new(ns_index: ns_index1, identifier_type: type1, identifier: name1),
            NodeId.new(ns_index: ns_index2, identifier_type: type2, identifier: name2)
          }
        }

      defp parse_value({:ok, {ns_index, name}}) when is_integer(ns_index),
        do: {:ok, QualifiedName.new(ns_index: ns_index, name: name)}

      defp parse_value({:ok, array}) when is_list(array),
        do: {:ok, Enum.map(array, fn(data) -> parse_c_value(data) end)}

      defp parse_value(response), do: response

      defp parse_c_value({ns_index, type, name, name_space_uri, server_index}),
        do:
          ExpandedNodeId.new(
            node_id: NodeId.new(ns_index: ns_index, identifier_type: type, identifier: name),
            name_space_uri: name_space_uri,
            server_index: server_index
          )

      defp parse_c_value({ns_index, type, name}),
        do: NodeId.new(ns_index: ns_index, identifier_type: type, identifier: name)

      defp parse_c_value({{ns_index1, type1, name1}, {ns_index2, type2, name2}}),
        do: {
          NodeId.new(ns_index: ns_index1, identifier_type: type1, identifier: name1),
          NodeId.new(ns_index: ns_index2, identifier_type: type2, identifier: name2)
        }

      defp parse_c_value({ns_index, name}) when is_integer(ns_index),
        do: QualifiedName.new(ns_index: ns_index, name: name)

      defp parse_c_value(array) when is_list(array),
        do: Enum.map(array, fn(data) -> parse_c_value(data) end)

      defp parse_c_value(response), do: response

      @doc false
      def set_ld_library_path(priv_dir) do
        System.get_env("LD_LIBRARY_PATH", "")
        |> String.contains?(priv_dir)
        |> write_ld_library_path(priv_dir)
      end

      defp write_ld_library_path(false, priv_dir) do
        ld_dirs =
          System.get_env("LD_LIBRARY_PATH", "")
          |> Path.join(":")
          |> Path.join(priv_dir)
          |> Path.join("/lib")

        System.put_env("LD_LIBRARY_PATH", ld_dirs)
        priv_dir
      end

      defp all_must_be(:integer, list),
        do: Enum.all?(list, fn x -> is_integer(x) end)

      defp get_array_raw_size(array_dimensions),
        do: Enum.reduce(array_dimensions, 1, fn(x, acc) -> x * acc end)

      defp write_ld_library_path(true, priv_dir), do: priv_dir
    end
  end
end
