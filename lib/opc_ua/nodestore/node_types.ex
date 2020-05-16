defmodule OpcUA.ObjectNode do
  use IsEnumerable
  use IsAccessible

  @moduledoc """
  A name qualified by a namespace.
  """

  @enforce_keys [:args]

  defstruct args: nil,
            executable: nil

  @doc """
  Creates a structure for a name qualified by a namespace.
  """
  @spec new(GenServer.server()) :: %__MODULE__{}
  def new(args: args) when is_list(args) do
    %__MODULE__{args: args}
  end

  def new(_invalid_data), do: raise("Invalid Namespace index or name (data type)")
end
