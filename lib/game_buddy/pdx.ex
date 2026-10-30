defmodule GameBuddy.Pdx do
  @moduledoc """
  Entry points for parsing Paradox game files. Game-agnostic.
  """

  alias GameBuddy.Pdx.{Fold, Localization, Parser}

  @doc "Parse script text into an ordered AST."
  defdelegate parse(bin), to: Parser

  @doc "Parse a script file from disk."
  def parse_file(path) do
    with {:ok, bin} <- File.read(path), do: parse(bin)
  end

  @doc "Fold an AST into a plain map/list for jsonb storage and queries."
  defdelegate fold(statements), to: Fold, as: :run

  @doc "Parse a localization file."
  defdelegate parse_localization(bin), to: Localization, as: :parse

  def parse_localization_file(path) do
    with {:ok, bin} <- File.read(path), do: parse_localization(bin)
  end

  @doc "Convert an AST to JSON-friendly terms (atom keys to strings, nil-safe)."
  def ast_to_json(statements) when is_list(statements), do: Enum.map(statements, &stmt_to_json/1)

  defp stmt_to_json(%{k: k, op: op, v: v, line: line}),
    do: %{"k" => k, "op" => op, "v" => value_to_json(v), "line" => line}

  defp stmt_to_json(%{v: v, line: line}), do: %{"v" => value_to_json(v), "line" => line}

  defp value_to_json(%{tag: tag, block: stmts}),
    do: %{"tag" => tag, "block" => ast_to_json(stmts)}

  defp value_to_json(%{block: stmts}), do: %{"block" => ast_to_json(stmts)}
  defp value_to_json(scalar), do: scalar
end
