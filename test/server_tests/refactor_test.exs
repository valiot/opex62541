defmodule ServerRefactorTest do
  use ExUnit.Case, async: false

  alias OpcUA.Server

  setup do
    {:ok, pid} = Server.start_link()
    %{pid: pid}
  end

  test "test", state do
    assert :ok == Server.test(state.pid)
  end

  test "Set LD_LIBRARY_PATH" do
    System.put_env("LD_LIBRARY_PATH", "")
    assert "/priv" == Server.set_ld_library_path("/priv")
    assert System.get_env("LD_LIBRARY_PATH") == ":/priv/lib"
    assert "/priv" == Server.set_ld_library_path("/priv")
    assert System.get_env("LD_LIBRARY_PATH") == ":/priv/lib"
    assert "/privd" == Server.set_ld_library_path("/privd")
    assert System.get_env("LD_LIBRARY_PATH") == ":/priv/lib/:/privd/lib"
  end
end
