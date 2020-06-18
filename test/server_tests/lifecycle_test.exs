defmodule ServerLifecycleTest do
  use ExUnit.Case

  #alias OpcUA.{NodeId, Server, QualifiedName}
  alias OpcUA.Server

  setup do
    {:ok, pid} = OpcUA.Server.start_link
    %{pid: pid}
  end

  test "Set/Get client config", state do
    desired_config = %{
      "application_description" => [%{
          "application_uri" => "urn:open62541.server.application",
          "discovery_url" => [],
          "name" => "open62541-based OPC UA Application",
          "product_uri" => "http://open62541.org",
          "server" => "urn:open62541.server.application",
          "type" => "server"
        }],
      "endpoint_description" => [
        %{
          "endpoint_url" => "",
          "security_level" => 1,
          "security_mode" => "none",
          "security_profile_uri" => "http://opcfoundation.org/UA/SecurityPolicy#None",
          "transport_profile_uri" =>
            "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"
        }
      ],
      "hostname" => "localhost",
      "n_threads" => 1
    }

    response = Server.set_default_config(state.pid)
    assert response == :ok

    response = Server.get_config(state.pid)
    assert response == {:ok, desired_config}
  end

  test "Set hostname", state do
    response = Server.set_default_config(state.pid)
    assert response == :ok

    response = Server.set_hostname(state.pid, "alde103")
    assert response == :ok

    {:ok, server_config} = Server.get_config(state.pid)
    assert server_config["hostname"] == "alde103"
  end

  test "Set port nomber", state do
    response = Server.set_default_config(state.pid)
    assert response == :ok

    response = Server.set_port(state.pid, 4040)
    assert response == :ok
  end

  test "Set users", state do
    response = Server.set_default_config(state.pid)
    assert response == :ok

    response = Server.set_users(state.pid, [{"alde", "edla"}, {"pedro", "ordep"}])
    assert response == :ok
  end

  test "Start/stop server", state do
    response = Server.set_default_config(state.pid)
    assert response == :ok

    response = Server.start(state.pid)
    assert response == :ok

    response = Server.stop_server(state.pid)
    assert response == :ok
  end
end
