defmodule ServerRefactorTest do
  use ExUnit.Case
  doctest Opex62541

  alias OpcUA.{NodeId, Server, QualifiedName}

  setup do
    {:ok, pid} = OpcUA.Server.start_link()
    %{pid: pid}
  end

  test "test", state do
    :ok = OpcUA.Server.test(state.pid)
  end
end
