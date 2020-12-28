defmodule ClientDiscoveryTest do
  use ExUnit.Case

  alias OpcUA.{Client, Server}

  setup do
    {:ok, c_pid} = Client.start_link()
    :ok = Client.set_config(c_pid)

    #TODO: add discovery server.
    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_default_config(s_pid)
    :ok = Server.start(s_pid)

    %{c_pid: c_pid, s_pid: s_pid}
  end

  test "Get Endpoint", %{c_pid: c_pid} do
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

    url = "opc.tcp://localhost:4840"

    c_response = Client.get_endpoints(c_pid, url)
    assert c_response == desired
  end

  test "Find Server", %{c_pid: c_pid} do
    {:ok, localhost} = :inet.gethostname()
    desired =
      {:ok,
       [
         %{
           "discovery_url" => ["opc.tcp://#{localhost}:4840/"],
           "name" => "open62541-based OPC UA Application",
           "product_uri" => "http://open62541.org",
           "application_uri" => "urn:open62541.server.application",
           "server" => "urn:open62541.server.application",
           "type" => "server"
         }
       ]}

    url = "opc.tcp://localhost:4840"

    c_response = Client.find_servers(c_pid, url)
    assert c_response == desired
  end

  test "Find Server on Network", %{c_pid: c_pid} do
    _desired =
      {:ok,
       [
         %{
           "capabilities" => ["LDS"],
           "discovery_url" => "opc.tcp://localhost:4840",
           "record_id" => 0,
           "server_name" => "LDS-localhost"
         },
         %{
           "capabilities" => ["NA"],
           "discovery_url" => "opc.tcp://localhost:38365",
           "record_id" => 2,
           "server_name" => "Sample Server-localhost"
         }
       ]}

    url = "opc.tcp://localhost:4840"

    c_response = Client.find_servers_on_network(c_pid, url)
    #TODO: Add Server discovery
    assert c_response == {:error, "BadNotImplemented"}
  end

end
