defmodule IsAccessible do
  @moduledoc false

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Access

      @impl Access
      def fetch(term, key), do: Map.fetch(term, key)

      @impl Access
      def get_and_update(data, key, func) do
        Map.get_and_update(data, key, func)
      end

      @impl Access
      def pop(data, key), do: Map.pop(data, key)
    end
  end
end
