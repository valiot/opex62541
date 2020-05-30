defmodule OpcUA.MonitoredItem do
  use IsEnumerable
  use IsAccessible

  alias OpcUA.NodeId

  @moduledoc """
  A Monitored Item is used to request a server for notifications of each change of value in a specific node.
  """
  @enforce_keys [:args]

  defstruct args: nil

  @doc """
  Creates an structure for an Monitored Item of an existing node in a Server.
  The following options must be filled:
    * `:monitored_item` -> %NodeId().
    * `:sampling_time` -> double().
    * `:subscription_id` -> integer().
  """
  @spec new(list()) :: %__MODULE__{}
  def new(args) when is_list(args) do
    with  monitored_item <- Keyword.fetch!(args, :monitored_item),
          sampling_time <- Keyword.fetch!(args, :sampling_time),
          subscription_id <- Keyword.get(args, :subscription_id, 0),
          %NodeId{} <- monitored_item,
          true <- is_float(sampling_time),
          true <- is_integer(subscription_id)
    do
      struct(%__MODULE__{args: args})
    else
      _ ->
        raise("Invalid argument: sampling_time must be a float number and monitored_item must be %OpcUA.NodeId{} struct")
    end
  end
  def new(_invalid_data), do: raise("Expecting ")
end
