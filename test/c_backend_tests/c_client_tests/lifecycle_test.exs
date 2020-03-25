defmodule CClientLifecycleTest do
  use ExUnit.Case
  doctest Opex62541

  setup do
    executable = :code.priv_dir(:opex62541) ++ '/opc_ua_client'

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

  test "Get client state", state do
    msg = {:get_client_state, nil}
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

    assert c_response == {:ok, 'Disconnected'}
  end

  test "Set/Get client config", state do
    config = %{
      requestedSessionTimeout: 12000,
      secureChannelLifeTime: 6000,
      timeout: 500
    }

    msg = {:set_client_config, config}
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

    msg = {:get_client_config, nil}
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

    assert c_response == {:ok, config}
  end

  test "Reset client", state do
    msg = {:reset_client, nil}
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

