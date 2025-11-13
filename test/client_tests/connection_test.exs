defmodule ClientConnectionTest do
  use ExUnit.Case

  alias OpcUA.{Client, Server}

  setup_all do
    #Server with no auth.
    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_default_config(s_pid)
    :ok = Server.set_port(s_pid, 4001)
    :ok = Server.start(s_pid)

    #Server with Auth
    # v1.4.x: set_users now accepts optional port parameter (following working pattern from server_access_control.c)
    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_users(s_pid, [{"alde103", "secret"}], 4002)
    :ok = Server.start(s_pid)

    %{s_pid: s_pid}
  end

  setup  do
    {:ok, c_pid} = Client.start_link()
    :ok = Client.set_config(c_pid)

    %{c_pid: c_pid}
  end

  test "Connect client by url", %{c_pid: c_pid} do
    url = "opc.tcp://localhost:4001/"

    assert :ok == Client.connect_by_url(c_pid, url: url)

    assert {:ok, "Session"} == Client.get_state(c_pid)
  end

  test "Connect client secure channel without session", _state do
    {:ok, c_pid} = Client.start_link()
    :ok = Client.set_config(c_pid)

    url = "opc.tcp://localhost:4001/"

    assert :ok == Client.connect_secure_channel(c_pid, url: url)
    assert {:ok,  "Secure Channel"} == Client.get_state(c_pid)
  end

  test "Disconnects a client", %{c_pid: c_pid} do
    url = "opc.tcp://localhost:4001/"

    assert :ok == Client.connect_by_url(c_pid, url: url)
    assert {:ok,  "Session"} == Client.get_state(c_pid)

    assert :ok == Client.disconnect(c_pid)
    assert {:ok,  "Disconnected"} == Client.get_state(c_pid)
  end

  test "Connect client by url, user, password", %{c_pid: c_pid} do
    url = "opc.tcp://localhost:4002/"
    user = "alde103"
    password = "secret"

    # v1.4.x: Following official example pattern, error code is BadUserAccessDenied for invalid credentials
    assert {:error, "BadUserAccessDenied"} == Client.connect_by_username(c_pid, url: url, user: user, password: "InvalidPSK")

    # v1.4.x: With the correct server configuration (following server_access_control.c pattern),
    # authentication should work without needing to reset the client
    assert :ok == Client.connect_by_username(c_pid, url: url, user: user, password: password)
    assert {:ok, "Session"} == Client.get_state(c_pid)
  end
end
