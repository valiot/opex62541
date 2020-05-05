defmodule ServerRefactorTest do
  use ExUnit.Case
  doctest Opex62541

  alias OpcUA.Server

  setup do
    {:ok, pid} = Server.start_link()
    %{pid: pid}
  end

  test "test", state do
    :ok = Server.test(state.pid)
  end
end
