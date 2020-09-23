defmodule ClientLifecycleTest do
  use ExUnit.Case

  #alias OpcUA.{NodeId, Server, QualifiedName}
  alias OpcUA.Client

  setup do
    {:ok, pid} = Client.start_link()
    %{pid: pid}
  end

  test "Get client state", state do
    c_response = Client.get_state(state.pid)
    assert c_response == {:ok, "Good"}
  end

  test "Get secure channel state", state do
    c_response = Client.get_secure_channel_state(state.pid)
    assert c_response == {:ok, "Closed"}
  end

  test "Get session state", state do
    c_response = Client.get_session_state(state.pid)
    assert c_response == {:ok, "Closed"}
  end


  test "Set/Get client config", state do
    config = %{
      "requestedSessionTimeout" => 12000,
      "secureChannelLifeTime" => 6000,
      "timeout" => 500
    }

    c_response = Client.set_config(state.pid, config)
    assert c_response == :ok

    c_response = Client.get_config(state.pid)
    assert c_response == {:ok, config}
  end

  test "Set default client config", state do
    config = %{
      "requestedSessionTimeout" => 1200000,
      "secureChannelLifeTime" => 600000,
      "timeout" => 5000
    }

    c_response = Client.set_config(state.pid)
    assert c_response == :ok

    c_response = Client.get_config(state.pid)
    assert c_response == {:ok, config}
  end
end
