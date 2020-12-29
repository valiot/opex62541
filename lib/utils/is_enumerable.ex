defmodule IsEnumerable do
  @moduledoc false

  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      defimpl Enumerable, for: __MODULE__ do
        def reduce(map, acc, fun) do
          map = :maps.without([:__struct__], map)
          do_reduce(:maps.to_list(map), acc, fun)
        end

        defp do_reduce(_,     {:halt, acc}, _fun),   do: {:halted, acc}
        defp do_reduce(list,  {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(list, &1, fun)}
        defp do_reduce([],    {:cont, acc}, _fun),   do: {:done, acc}
        defp do_reduce([h|t], {:cont, acc}, fun),    do: do_reduce(t, fun.(h, acc), fun)

        def member?(map, {:__struct__, value}) do
          {:ok, false}
        end

        def member?(map, {key, value}) do
          {:ok, match?({:ok, ^value}, :maps.find(key, map))}
        end

        def member?(_map, _other) do
          {:ok, false}
        end

        def count(map) do
          {:ok, map_size(map) - 1}
        end

        def slice(map) do
          map = :maps.without([:__struct__], map)
          Enumerable.slice(map)
        end
      end
    end
  end
end
