defmodule ServerDiscoveryTest do
  use ExUnit.Case, async: false
  doctest Opex62541

  alias OpcUA.Server

  test "Configure an LDS Server" do
    {:ok, lds_pid} = Server.start_link()

    :ok = Server.set_default_config(lds_pid)

    assert :ok == Server.set_lds_config(lds_pid, "urn:opex62541.test.local_discovery_server")

    assert :ok == Server.start(lds_pid)
  end
end
