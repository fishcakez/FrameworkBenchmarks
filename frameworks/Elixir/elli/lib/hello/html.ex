defmodule Hello.HTML do
  @moduledoc false

  @escape %{"&" => "&amp;",
            "<" => "&lt;",
            ">" => "&gt;",
            "\"" => "&quot;",
            "'" => "&#39;"}

  def escape(string), do: escape(string, "")

  for {from, to} <- @escape do
    defp escape(<<unquote(from), rest::bits>>, acc) do
      escape(rest, <<acc::bits, unquote(to)>>)
    end
  end
  defp escape(<<byte, rest::bits>>, acc) do
    escape(rest, <<acc::bits, byte>>)
  end
  defp escape(<<>>, acc) do
    acc
  end
end
