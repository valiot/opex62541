defmodule WriteReadAttrTest do
  use ExUnit.Case, async: false
  doctest Opex62541

  setup do
    executable = :code.priv_dir(:opex62541) ++ '/opc_ua_server'

    port =
      Port.open({:spawn_executable, executable}, [
        {:args, []},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    %{port: port}
  end

  test "write attr node", state do
    msg = {:set_default_server_config, nil}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    # node_id => {node_type, ns_index, node_id_params}
    # name {ns_index, str_len, node_id_params}
    #msg = {:add_variable_node, {{0, 1, 103}, {1,1,{4, "hola"}}, {2, 1, {102, 103, 103, "holahola"}}, 11, "Hola Elixir", nil}}
    msg = {:add_object_type_node, {{0, 1, 10000}, {0, 0, 58}, {0, 0, 45}, {1, "Obj"}}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    # node_id => {node_type, ns_index, node_id_params}
    # name {ns_index, str_len, node_id_params}
    #msg = {:add_variable_node, {{0, 1, 103}, {1,1,{4, "hola"}}, {2, 1, {102, 103, 103, "holahola"}}, 11, "Hola Elixir", nil}}
    msg = {:add_variable_node, {{0, 1, 10001}, {0, 1, 10000}, {0, 0, 46}, {1, "Var"}, {0, 0, 63}}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_browse_name, {{0, 1, 10001}, {1, "Var_N"}}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_display_name, {{0, 1, 10001}, "en-US", "var"}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_description, {{0, 1, 10001}, "en-US", "var"}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_write_mask, {{0, 1, 10001}, 200}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_is_abstract, {{0, 1, 10000}, true}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_data_type, {{0, 1, 10001}, {0, 0, 63}}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_value_rank, {{0, 1, 10001}, 100}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_access_level, {{0, 1, 10001}, 100}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_minimum_sampling_interval, {{0, 1, 10001}, 100.0}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_historizing, {{0, 1, 10001}, true}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_executable, {{0, 1, 10001}, true}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    #TODO:
    # Test for writeEventNotifier, writeArrayDimensions, writeExecutable,
    # add_reference, add_object_type, add_variable_type, add_reference_type, add_data_type
    # delete_node, delete_reference

  end

  test "write value attr node", state do
    msg = {:set_default_server_config, nil}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:add_namespace, {4, "Room"}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    {:ok, node_id} =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert node_id == 2

    # node_id => {node_type, ns_index, node_id_params}
    # name {ns_index, node_id_params}
    # node_request, parent_id,
    # msg = {:add_object_node, {{0, 1, 103}, {1,1,"hola"}, {2, 1, {102, 103, 103, "holahola"}}, {1,"Hola Elixir"}, {3,1,"holas"}}}
    msg = {:add_object_node, {{1, node_id, "R1_TS1_VendorName"}, {0, 0, 85}, {0, 0, 35}, {node_id, "Temperature sensor"}, {0, 0, 58}}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    # node_id => {node_type, ns_index, node_id_params}
    # name {ns_index, str_len, node_id_params}
    #msg = {:add_variable_node, {{0, 1, 103}, {1,1,{4, "hola"}}, {2, 1, {102, 103, 103, "holahola"}}, 11, "Hola Elixir", nil}}
    msg = {:add_variable_node, {{1, node_id, "R1_TS1_Temperature"}, {1, node_id, "R1_TS1_VendorName"}, {0, 0, 47}, {node_id, "Temperature"}, {0, 0, 63}}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:write_node_value, {{1, node_id, "R1_TS1_Temperature"}, 0, true}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok

    msg = {:start_server, nil}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        1000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok


  Process.sleep(5000000)
  end
end
