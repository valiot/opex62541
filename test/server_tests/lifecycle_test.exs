defmodule ServerLifecycleTest do
  use ExUnit.Case

  alias OpcUA.Server

  setup do
    {:ok, pid} = OpcUA.Server.start_link
    %{pid: pid}
  end

  test "Set/Get client config" do
    # v1.4.x Breaking Changes:
    # 1. nThreads field removed from UA_ServerConfig (struct line 76-78)
    #    - Threading now managed via UA_EventLoop *eventLoop
    #    - No longer configurable via simple integer field
    #
    # 2. customHostname field removed from UA_ServerConfig (struct line 84-86)
    #    - Hostname now derived from applicationDescription.applicationName
    #    - Or from serverUrls array if applicationName is empty
    #    - UA_ServerConfig_setCustomHostname() API completely removed
    #
    # Expected behavior in v1.4.x:
    # - get_config returns hostname from applicationDescription.applicationName.text
    # - set_hostname API removed (see handle_set_hostname comment in opc_ua_server.c)
    # - security_level changed from 1 to 0 for SecurityPolicy#None
    #   (calculated in plugins/ua_config_default.c based on policy)
    #
    # v1.4.x Enhanced Config Fields:
    # - server_urls: Array of server URLs (e.g., ["opc.tcp://:4840"])
    # - tcp_config: TCP settings (enabled, buf_size, max_msg_size, max_chunks, reuse_addr)
    # - limits: Server limits (max_secure_channels, max_sessions, max_nodes_per_read/write/browse, etc.)
    # - security_config: Security settings (policies_count, none_policy_discovery_only, allow_none_policy_password)
    # - shutdown_delay: Grace period before shutdown
    # - subscriptions: Subscription settings (enabled, max_subscriptions, max_monitored_items, publishing_interval_limits)
    # - discovery: Discovery settings (cleanup_timeout, mdns_enabled)
    # - application_description: Full application description with URI, product URI, discovery URLs

    # start the server
    {:ok, pid} = Server.start_link(port: 0)

    desired_config = %{
      "hostname" => "open62541-based OPC UA Application",
      "endpoint_description" => [
        %{
          "endpoint_url" => "",
          "security_level" => 0,
          "security_mode" => "none",
          "security_profile_uri" =>
            "http://opcfoundation.org/UA/SecurityPolicy#None",
          "transport_profile_uri" =>
            "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"
        }
      ],
      "application_description" => [
        %{
          "application_uri" => "urn:open62541.server.application",
          "discovery_url" => [],
          "name" => "open62541-based OPC UA Application",
          "product_uri" => "http://open62541.org",
          "server" => "urn:open62541.server.application",
          "type" => "server"
        }
      ],
      "server_urls" => ["opc.tcp://:4840"],
      "tcp_config" => %{
        "enabled" => false,
        "buf_size" => 0,
        "max_msg_size" => 0,
        "max_chunks" => 0,
        "reuse_addr" => true
      },
      "limits" => %{
        "max_secure_channels" => 100,
        "max_security_token_lifetime" => 600000,
        "max_sessions" => 100,
        "max_session_timeout" => 3600000.0,
        "max_nodes_per_read" => 0,
        "max_nodes_per_write" => 0,
        "max_nodes_per_browse" => 0,
        "max_references_per_node" => 0
      },
      "security_config" => %{
        "security_policies_count" => 1,
        "none_policy_discovery_only" => false,
        "allow_none_policy_password" => false
      },
      "shutdown_delay" => 0.0,
      "subscriptions" => %{
        "enabled" => false,
        "max_subscriptions" => 0,
        "max_monitored_items" => 0,
        "publishing_interval_limits" => {100.0, 3600000.0}
      },
      "discovery" => %{
        "cleanup_timeout" => 3600,
        "mdns_enabled" => false
      }
    }

    response = Server.get_config(pid)

    assert response == {:ok, desired_config}
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

    response = Server.set_port(state.pid, 4022)
    assert response == :ok

    response = Server.start(state.pid)
    assert response == :ok

    response = Server.stop_server(state.pid)
    assert response == :ok
  end
end
