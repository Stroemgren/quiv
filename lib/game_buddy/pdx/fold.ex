defmodule GameBuddy.Pdx.Fold do
  @moduledoc """
  Folds an ordered AST into a plain map that is convenient for jsonb queries.

    * `key = value` becomes `"key" => value`
    * a key that appears more than once becomes a list of its values
    * a statement with an operator other than `=` becomes `%{"op" => ">", "v" => value}`
    * a block containing only bare values becomes a list
    * bare values in a mixed block are collected under `"_items"`
    * a tagged block becomes `%{"_tag" => "rgb", "_v" => folded}`

  Exactness is lost on purpose (a single repeated key and a one-element list
  look the same). The AST stays stored alongside for anything that needs it.
  """

  @spec fold([map]) :: map | list
  def fold(statements) when is_list(statements) do
    if statements != [] and Enum.all?(statements, &(not Map.has_key?(&1, :k))) do
      Enum.map(statements, &fold_value(&1.v))
    else
      Enum.reduce(statements, %{}, fn
        %{k: k, op: "=", v: v}, acc -> put_multi(acc, k, fold_value(v))
        %{k: k, op: op, v: v}, acc -> put_multi(acc, k, %{"op" => op, "v" => fold_value(v)})
        %{v: v}, acc -> put_multi(acc, "_items", fold_value(v))
      end)
    end
  end

  defp put_multi(map, key, value) do
    case Map.fetch(map, key) do
      :error -> Map.put(map, key, value)
      {:ok, {:multi, list}} -> Map.put(map, key, {:multi, [value | list]})
      {:ok, existing} -> Map.put(map, key, {:multi, [value, existing]})
    end
    |> finalize_if_last(key)
  end

  # {:multi, reversed} is an internal marker; materialize it lazily on read.
  defp finalize_if_last(map, _key), do: map

  @doc "Resolve internal multi markers into lists. Called once on the top-level fold."
  def finalize(map) when is_map(map) do
    Map.new(map, fn
      {k, {:multi, list}} -> {k, list |> Enum.reverse() |> Enum.map(&finalize/1)}
      {k, v} -> {k, finalize(v)}
    end)
  end

  def finalize(list) when is_list(list), do: Enum.map(list, &finalize/1)
  def finalize(other), do: other

  defp fold_value(%{tag: tag, block: stmts}), do: %{"_tag" => tag, "_v" => fold(stmts)}
  defp fold_value(%{block: stmts}), do: fold(stmts)
  defp fold_value(scalar), do: scalar

  @doc "Fold and finalize in one go."
  def run(statements), do: statements |> fold() |> finalize()
end
