defmodule GameBuddy.Pdx.Format do
  @moduledoc "Prints a parsed statement list back as script text."

  @doc "Script text for JSON-shaped statements (as stored in the `ast` column)."
  def to_script(statements, max_chars \\ 2_500) when is_list(statements) do
    text = statements |> Enum.map(&statement(&1, 0)) |> Enum.join("\n")

    if String.length(text) > max_chars,
      do: String.slice(text, 0, max_chars) <> "\n… (truncated)",
      else: text
  end

  defp statement(%{"k" => k, "op" => op, "v" => v}, depth),
    do: indent(depth) <> "#{k} #{op} " <> value(v, depth)

  defp statement(%{"v" => v}, depth), do: indent(depth) <> value(v, depth)
  defp statement(other, depth), do: indent(depth) <> inspect(other)

  defp value(%{"tag" => tag, "block" => stmts}, depth), do: "#{tag} " <> block(stmts, depth)
  defp value(%{"block" => stmts}, depth), do: block(stmts, depth)
  defp value(true, _), do: "yes"
  defp value(false, _), do: "no"
  defp value(v, _) when is_binary(v), do: if(String.contains?(v, " "), do: ~s("#{v}"), else: v)
  defp value(v, _), do: to_string(v)

  defp block([], _depth), do: "{ }"

  defp block(stmts, depth) do
    scalars? = Enum.all?(stmts, fn s -> not Map.has_key?(s, "k") and scalar?(s["v"]) end)

    if scalars? and length(stmts) <= 12 do
      "{ " <> Enum.map_join(stmts, " ", &value(&1["v"], depth)) <> " }"
    else
      inner = Enum.map_join(stmts, "\n", &statement(&1, depth + 1))
      "{\n" <> inner <> "\n" <> indent(depth) <> "}"
    end
  end

  defp scalar?(v), do: not is_map(v)
  defp indent(depth), do: String.duplicate("\t", depth)
end
