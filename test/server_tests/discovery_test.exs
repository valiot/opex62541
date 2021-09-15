defmodule ServerDiscoveryTest do
  use ExUnit.Case, async: false

  alias OpcUA.{Server, Client}

  # Valgrind memory leaks detected
  # UA_Server_addPeriodicServerRegisterCallback (open62541.c:46592)
  # UA_Server_addPeriodicServerRegisterCallback (open62541.c:46578)
  # UA_Server_addPeriodicServerRegisterCallback (open62541.c:46613)
  # These memory leaks are managed by open62541 lib and there are freed by UA_Server_addPeriodicServerRegisterCallback with the right arguments.

  test "Configure an LDS Server" do
    {:ok, lds_pid} = Server.start_link()

    :ok = Server.set_default_config(lds_pid)
    :ok = Server.set_port(lds_pid, 4009)

    assert :ok == Server.set_lds_config(lds_pid, "urn:opex62541.test.local_discovery_server")

    assert :ok == Server.start(lds_pid)
  end

  test "Register to a Discovery Server" do
    {:ok, lds_pid} = Server.start_link()
    :ok = Server.set_default_config(lds_pid)
    :ok = Server.set_port(lds_pid, 4010)
    assert :ok == Server.set_lds_config(lds_pid, "urn:opex62541.test.local_discovery_server")
    assert :ok == Server.start(lds_pid)

    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_port(s_pid, 4011)

    assert :ok ==
             Server.discovery_register(s_pid,
               application_uri: "urn:opex62541.test.local_register_server",
               server_name: "TestRegister",
               endpoint: "opc.tcp://localhost:4010"
             )

    assert :ok == Server.start(s_pid)
    # Registration time
    Process.sleep(1500)
    assert :ok == Server.discovery_unregister(s_pid)

    assert :ok ==
      Server.discovery_register(s_pid,
        application_uri: "urn:opex62541.test.local_register_server",
        server_name: "TestRegister",
        endpoint: "opc.tcp://localhost:4010"
      )

    # Registration time
    Process.sleep(1500)
    assert :ok == Server.discovery_unregister(s_pid)
  end

  test "Full Discovery Implementation" do
    {:ok, localhost} = :inet.gethostname()
    {:ok, lds_pid} = Server.start_link()
    #:ok = Server.set_default_config(lds_pid)
    :ok = Server.set_port(lds_pid, 4012)
    assert :ok == Server.set_lds_config(lds_pid, "urn:opex62541.test.local_discovery_server")
    assert :ok == Server.start(lds_pid)

    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_port(s_pid, 4013)

    assert :ok ==
             Server.discovery_register(s_pid,
               application_uri: "urn:opex62541.test.local_register_server",
               server_name: "testRegister",
               endpoint: "opc.tcp://localhost:4012"
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
           "endpoint_url" => "opc.tcp://localhost:4013",
           "security_level" => 1,
           "security_mode" => "none",
           "security_profile_uri" => "http://opcfoundation.org/UA/SecurityPolicy#None",
           "transport_profile_uri" =>
             "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"
         }
       ]}

    url = "opc.tcp://localhost:4013"

    c_response = Client.get_endpoints(c_pid, url)
    assert c_response == desired

    desired =
      {:ok,
       [
         %{
           "discovery_url" => ["opc.tcp://#{localhost}:4012/"],
           "name" => "open62541-based OPC UA Application",
           "product_uri" => "http://open62541.org",
           "application_uri" => "urn:opex62541.test.local_discovery_server",
           "server" => "urn:opex62541.test.local_discovery_server",
           "type" => "discovery_server"
         },
         %{
           "application_uri" => "urn:opex62541.test.local_register_server",
           "discovery_url" => [
             "opc.tcp://#{localhost}:4013/",
             "opc.tcp://#{localhost}:4013/"
           ],
           "name" => "open62541-based OPC UA Application",
           "product_uri" => "http://open62541.org",
           "server" => "urn:opex62541.test.local_register_server",
           "type" => "server"
         }
       ]}

    url = "opc.tcp://localhost:4012"

    c_response = Client.find_servers(c_pid, url)
    assert c_response == desired

    desired =
      {:ok,
       [
         %{
           "capabilities" => ["LDS"],
           "discovery_url" => "opc.tcp://#{localhost}:4012",
           "record_id" => 0,
           "server_name" => "LDS-#{localhost}"
         },
         %{
           "capabilities" => ["NA"],
           "discovery_url" => "opc.tcp://#{localhost}:4013",
           "record_id" => 1,
           "server_name" => "testRegister-#{localhost}"
         }
       ]}

    url = "opc.tcp://localhost:4012/"

    c_response = Client.find_servers_on_network(c_pid, url)
    assert c_response == desired
  end
end
