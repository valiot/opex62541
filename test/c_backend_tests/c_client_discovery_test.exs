defmodule CClientDiscoveryTest do
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

  test "Find server on network", state do
    desired =
      {:ok,
       [
         %{
           "capabilities" => ["LDS"],
           "discovery_url" => "opc.tcp://alde-Satellite-S845:4840",
           "record_id" => 0,
           "server_name" => "LDS-alde-Satellite-S845"
         },
         %{
           "capabilities" => ["NA"],
           "discovery_url" => "opc.tcp://alde-Satellite-S845:38365",
           "record_id" => 2,
           "server_name" => "Sample Server-alde-Satellite-S845"
         }
       ]}

    case state.status do
      :ok ->
        url = "opc.tcp://localhost:4840"
        n_chars = String.length(url)
        msg = {:find_servers_on_network, {n_chars, url}}
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

        assert c_response == desired

      _ ->
        raise("Configuration fail")
    end
  end

  test "Find Server", state do
    desired =
      {:ok,
       [
         %{
           "discovery_url" => ["opc.tcp://alde-Satellite-S845:4840/"],
           "application_uri" => "urn:open62541.example.local_discovery_server",
           "name" => "open62541-based OPC UA Application",
           "product_uri" => "http://open62541.org",
           "server" => "urn:open62541.example.local_discovery_server",
           "type" => "discovery_server"
         },
         %{
           "discovery_url" => [
             "opc.tcp://alde-Satellite-S845:38365/",
             "opc.tcp://alde-Satellite-S845:38365/"
           ],
           "application_uri" => "urn:open62541.example.server_register",
           "name" => "open62541-based OPC UA Application",
           "product_uri" => "http://open62541.org",
           "server" => "urn:open62541.example.server_register",
           "type" => "server"
         }
       ]}

    case state.status do
      :ok ->
        url = "opc.tcp://localhost:4840"
        n_chars = String.length(url)
        msg = {:find_servers, {n_chars, url}}
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

        assert c_response == desired

      _ ->
        raise("Configuration fail")
    end
  end

  test "Get Endpoint", state do
    desired =
      {:ok,
       [
         %{
           "endpoint_url" => "opc.tcp://localhost:4840",
           "security_level" => 1,
           "security_mode" => "none",
           "security_profile_uri" => "http://opcfoundation.org/UA/SecurityPolicy#None",
           "transport_profile_uri" =>
             "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"
         }
       ]}

    case state.status do
      :ok ->
        url = "opc.tcp://localhost:4840"
        n_chars = String.length(url)
        msg = {:get_endpoints, {n_chars, url}}
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

        assert c_response == desired

      _ ->
        raise("Configuration fail")
    end
  end
end
