defmodule GameBuddy.Ingest.Localization do
  @moduledoc "Loads a language's localization files into a `GameBuddy.Loc` plus row list."

  alias GameBuddy.Pdx

  @doc """
  Returns `{loc, rows}` where rows are maps ready for insert_all. Later files
  override earlier ones for the same key, matching the adapter's ordering.
  """
  def load(files, lang, root) do
    files
    |> Task.async_stream(
      fn f ->
        {:ok, header, entries, _warnings} = Pdx.parse_localization_file(f)
        {f, header, entries}
      end,
      ordered: true,
      timeout: 60_000
    )
    |> Enum.reduce({%{}, %{}}, fn {:ok, {f, header, entries}}, {map, rows} ->
      if header == "l_#{lang}" or header == nil do
        rel = Path.relative_to(f, root)

        Enum.reduce(entries, {map, rows}, fn {k, v, line}, {m, r} ->
          {Map.put(m, k, v),
           Map.put(r, k, %{lang: lang, key: k, value: v, source_file: rel, source_line: line})}
        end)
      else
        {map, rows}
      end
    end)
    |> then(fn {map, rows} -> {GameBuddy.Loc.new(map), Map.values(rows)} end)
  end
end
