defmodule OpcUA.QualifiedName do
  use IsEnumerable
  use IsAccessible

  @moduledoc """
  A name qualified by a namespace.
  """
  alias OpcUA.QualifiedName
  @enforce_keys [:ns_index, :name]

  defstruct ns_index: nil,
            name: nil

  @doc """
  Creates a structure for a name qualified by a namespace.
  """
  @spec new(GenServer.server()) :: %QualifiedName{}
  def new(ns_index: ns_index, name: name) when is_integer(ns_index) and is_binary(name) do
    %QualifiedName{ns_index: ns_index, name: name}
  end

  def new(_invalid_data), do: raise("Invalid Namespace index or name (data type)")
end
