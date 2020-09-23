defmodule ClientConnectionTest do
  use ExUnit.Case

  alias OpcUA.{Client, Server}

  setup do
    {:ok, c_pid} = Client.start_link()
    :ok = Client.set_config(c_pid)

    # Server with no auth.
    {:ok, s_pid} = Server.start_link()
    #:ok = Server.set_default_config(s_pid)
    :ok = Server.set_port(s_pid, 4048)
    :ok = Server.start(s_pid)

    # Server with Auth
    {:ok, s_pid} = Server.start_link()
    :ok = Server.set_default_config(s_pid)
    :ok = Server.set_users(s_pid, [{"alde103", "secret"}])
    :ok = Server.start(s_pid)

    %{c_pid: c_pid, s_pid: s_pid}
  end

  test "Connect client by url, user, password", %{c_pid: c_pid} do
    url = "opc.tcp://alde-Satellite-S845:4840/"
    user = "alde103"
    password = "secret"

    assert :ok == Client.connect_by_username(c_pid, url: url, user: user, password: password)
    assert {:ok, "Good"} == Client.get_state(c_pid)
    assert {:ok, "Actived"} == Client.get_session_state(c_pid)
    assert {:ok, "Open"} == Client.get_secure_channel_state(c_pid)
  end

  test " Invalid Client Connection by url, user, password (invalid)", %{c_pid: c_pid} do
    url = "opc.tcp://alde-Satellite-S845:4840/"
    user = "alde103"
    assert {:error, "BadUserAccessDenied"} == Client.connect_by_username(c_pid, url: url, user: user, password: "InvalidPSW")
  end

  test " Invalid Client Connection by url, user, password", %{c_pid: c_pid} do
    url = "opc.tcp://alde-Satellite-S845:4840/"
    password = "secret"

    assert {:error, "BadUserAccessDenied"} == Client.connect_by_username(c_pid, url: url, user: "InvalidUser", password: password)
  end

  test "Connects/Disconnects a client by url", %{c_pid: c_pid}  do
    url = "opc.tcp://alde-Satellite-S845:4048/"

    assert :ok == Client.connect_by_url(c_pid, url: url)
    assert {:ok, "Good"} == Client.get_state(c_pid)
    assert {:ok, "Actived"} == Client.get_session_state(c_pid)
    assert {:ok, "Open"} == Client.get_secure_channel_state(c_pid)

    assert :ok == Client.disconnect(c_pid)
    assert {:ok, "Good"} == Client.get_state(c_pid)
    assert {:ok, "Closed"} == Client.get_session_state(c_pid)
    assert {:ok, "Closed"} == Client.get_secure_channel_state(c_pid)
  end
end
