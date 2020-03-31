defmodule CServerNodeAdditionAndDeletionTest do
  use ExUnit.Case
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

  test "start_server", state do
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
  end

  test "Add object & variable node", state do
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
  end
end
