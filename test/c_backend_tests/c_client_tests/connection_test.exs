defmodule CClientConnectionTest do
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

    config = %{
      requestedSessionTimeout: 12000,
      secureChannelLifeTime: 6000,
      timeout: 500
    }

    msg = {:set_client_config, config}
    send(port, {self(), {:command, :erlang.term_to_binary(msg)}})

    status =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)

        x ->
          IO.inspect(x)
          :error
      after
        3000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    %{port: port, status: status}
  end

  test "Connect client by url", state do
    case state.status do
      :ok ->
        url = "opc.tcp://localhost:4840"
        msg = {:connect_client_by_url, url}
        send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

        c_response =
          receive do
            {_, {:data, <<?r, response::binary>>}} ->
              :erlang.binary_to_term(response)

            x ->
              IO.inspect(x)
              :error
          after
            3000 ->
              # Not sure how this can be recovered
              exit(:port_timed_out)
          end

        assert c_response == :ok

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

        assert c_response == {:ok, 'Session'}
      _ ->
        raise("Configuration fail")
    end
  end

  test "Connect client with no session", state do
    case state.status do
      :ok ->
        url = "opc.tcp://localhost:4840"
        n_chars = String.length(url)
        msg = {:connect_client_no_session, {n_chars, url}}
        send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

        c_response =
          receive do
            {_, {:data, <<?r, response::binary>>}} ->
              :erlang.binary_to_term(response)

            x ->
              IO.inspect(x)
              :error
          after
            3000 ->
              # Not sure how this can be recovered
              exit(:port_timed_out)
          end

        assert c_response == :ok

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

        assert c_response == {:ok, 'Secure Channel'}
      _ ->
       raise("Configuration fail")
    end
  end

  test "Connect client with username", state do
    case state.status do
      :ok ->
        url = "opc.tcp://localhost:4840"
        url_n_chars = String.length(url)
        username = "opc.tcp://localhost:4840"
        username_n_chars = String.length(url)
        password = "Secret"
        password_n_chars = String.length(password)
        msg = {:connect_client_by_username, {url_n_chars, url, username_n_chars, username, password_n_chars, password}}

        send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

        c_response =
          receive do
            {_, {:data, <<?r, response::binary>>}} ->
              :erlang.binary_to_term(response)

            x ->
              IO.inspect(x)
              :error
          after
            3000 ->
              # Not sure how this can be recovered
              exit(:port_timed_out)
          end
        # current server doesn't supports the user.
        assert c_response == {:error, 2149515264}
      _ ->
       raise("Configuration fail")
    end
  end

  test "Disconnect client", state do
    case state.status do
      :ok ->

        # Connect

        url = "opc.tcp://localhost:4840"
        n_chars = String.length(url)
        msg = {:connect_client_by_url, {n_chars, url}}
        send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

        c_response =
          receive do
            {_, {:data, <<?r, response::binary>>}} ->
              :erlang.binary_to_term(response)

            x ->
              IO.inspect(x)
              :error
          after
            3000 ->
              # Not sure how this can be recovered
              exit(:port_timed_out)
          end

        assert c_response == :ok

        # Disconnect

        msg = {:disconnect_client, nil}
        send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

        c_response =
          receive do
            {_, {:data, <<?r, response::binary>>}} ->
              :erlang.binary_to_term(response)

            x ->
              IO.inspect(x)
              :error
          after
            3000 ->
              # Not sure how this can be recovered
              exit(:port_timed_out)
          end

        assert c_response == :ok

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
      _ ->
        raise("Configuration fail")
    end
  end
end

