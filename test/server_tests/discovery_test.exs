defmodule ServerDiscoveryTest do
  use ExUnit.Case, async: false

  alias OpcUA.{Server, Client}

  test "Configure an LDS Server" do
    {:ok, lds_pid} = Server.start_link()

    :ok = Server.set_default_config(lds_pid)

    assert :ok == Server.set_lds_config(lds_pid, "urn:opex62541.test.local_discovery_server")

    assert :ok == Server.start(lds_pid)
  end

  test "Register to a Discovery Server" do
    {:ok, lds_pid} = Server.start_link()
    :ok = Server.set_default_config(lds_pid)
    assert :ok == Server.set_lds_config(lds_pid, "urn:opex62541.test.local_discovery_server")
    assert :ok == Server.start(lds_pid)

    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_port(s_pid, 0)

    assert :ok ==
             Server.discovery_register(s_pid,
               application_uri: "urn:opex62541.test.local_register_server",
               server_name: "TestRegister",
               endpoint: "opc.tcp://localhost:4840"
             )

    assert :ok == Server.start(s_pid)
    # Registration time
    Process.sleep(1500)
    assert :ok == Server.discovery_unregister(s_pid)
  end

  test "Full Discovery Implementation" do
    {:ok, localhost} = :inet.gethostname()
    {:ok, lds_pid} = Server.start_link()
    #:ok = Server.set_default_config(lds_pid)
    :ok = Server.set_port(lds_pid, 4050)
    assert :ok == Server.set_lds_config(lds_pid, "urn:opex62541.test.local_discovery_server")
    assert :ok == Server.start(lds_pid)

    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_port(s_pid, 4048)

    assert :ok ==
             Server.discovery_register(s_pid,
               application_uri: "urn:opex62541.test.local_register_server",
               server_name: "testRegister",
               endpoint: "opc.tcp://localhost:4050"
             )

    assert :ok == Server.start(s_pid)

    # Registration time
    Process.sleep(1500)

    {:ok, c_pid} = Client.start_link()
    :ok = Client.set_config(c_pid)

    desired =
      {:ok,
       [
         %{
           "endpoint_url" => "opc.tcp://localhost:4050",
           "security_level" => 1,
           "security_mode" => "none",
           "security_profile_uri" => "http://opcfoundation.org/UA/SecurityPolicy#None",
           "transport_profile_uri" =>
             "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"
         }
       ]}

    url = "opc.tcp://localhost:4050"

    c_response = Client.get_endpoints(c_pid, url)
    assert c_response == desired

    desired =
      {:ok,
       [
         %{
           "discovery_url" => ["opc.tcp://#{localhost}:4050/"],
           "name" => "open62541-based OPC UA Application",
           "product_uri" => "http://open62541.org",
           "application_uri" => "urn:opex62541.test.local_discovery_server",
           "server" => "urn:opex62541.test.local_discovery_server",
           "type" => "discovery_server"
         },
         %{
           "application_uri" => "urn:opex62541.test.local_register_server",
           "discovery_url" => [
             "opc.tcp://#{localhost}:4048/",
             "opc.tcp://#{localhost}:4048/"
           ],
           "name" => "open62541-based OPC UA Application",
           "product_uri" => "http://open62541.org",
           "server" => "urn:opex62541.test.local_register_server",
           "type" => "server"
         }
       ]}

    c_response = Client.find_servers(c_pid, url)
    assert c_response == desired

    desired =
      {:ok,
       [
         %{
           "capabilities" => ["LDS"],
           "discovery_url" => "opc.tcp://#{localhost}:4050",
           "record_id" => 0,
           "server_name" => "LDS-#{localhost}"
         },
         %{
           "capabilities" => ["NA"],
           "discovery_url" => "opc.tcp://#{localhost}:4048",
           "record_id" => 1,
           "server_name" => "testRegister-#{localhost}"
         }
       ]}

    url = "opc.tcp://localhost:4050/"

    c_response = Client.find_servers_on_network(c_pid, url)
    assert c_response == desired
  end
end
