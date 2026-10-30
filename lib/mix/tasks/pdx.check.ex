defmodule Mix.Tasks.Pdx.Check do
  @shortdoc "Parse every script (.txt) and localization (.yml) file under directories and report"
  @moduledoc """
      mix pdx.check DIR [DIR...] [--verbose]

  Reports per-directory counts of parsed files, files with warnings, and
  failures. Script files are everything ending in .txt; localization files
  end in .yml.
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, dirs, _} = OptionParser.parse(args, switches: [verbose: :boolean])
    if dirs == [], do: Mix.raise("give at least one directory")

    files =
      dirs
      |> Enum.flat_map(fn dir -> Path.wildcard(Path.join(dir, "**/*.{txt,yml}")) end)
      |> Enum.filter(&File.regular?/1)

    started = System.monotonic_time(:millisecond)

    results =
      files
      |> Task.async_stream(&check_file/1,
        ordered: false,
        timeout: 60_000,
        max_concurrency: System.schedulers_online() * 2
      )
      |> Enum.map(fn {:ok, r} -> r end)

    elapsed = System.monotonic_time(:millisecond) - started

    by_dir =
      results
      |> Enum.group_by(fn r -> r.path |> Path.dirname() |> top_dir(dirs) end)
      |> Enum.sort_by(fn {k, _} -> k end)

    IO.puts(String.pad_trailing("directory", 60) <> "   ok  warn  fail")

    for {dir, rs} <- by_dir do
      ok = Enum.count(rs, &(&1.status == :ok))
      warn = Enum.count(rs, &(&1.status == :warn))
      fail = Enum.count(rs, &(&1.status == :fail))

      IO.puts(
        String.pad_trailing(dir, 60) <>
          String.pad_leading("#{ok}", 5) <>
          String.pad_leading("#{warn}", 6) <> String.pad_leading("#{fail}", 6)
      )
    end

    total = length(results)
    fails = Enum.filter(results, &(&1.status == :fail))
    warns = Enum.filter(results, &(&1.status == :warn))

    IO.puts(
      "\n#{total} files in #{elapsed} ms: #{total - length(fails) - length(warns)} ok, #{length(warns)} with warnings, #{length(fails)} failed"
    )

    for r <- fails, do: IO.puts("FAIL #{r.path}: #{r.detail}")

    if opts[:verbose] do
      for r <- warns, do: IO.puts("WARN #{r.path}: #{r.detail}")
    else
      for r <- Enum.take(warns, 15), do: IO.puts("WARN #{r.path}: #{r.detail}")

      if length(warns) > 15,
        do: IO.puts("... #{length(warns) - 15} more warnings (use --verbose)")
    end
  end

  defp top_dir(dir, roots) do
    root = Enum.find(roots, fn r -> String.starts_with?(dir, r) end) || ""
    rel = Path.relative_to(dir, root)
    first = rel |> Path.split() |> List.first() || "."
    Path.join(Path.basename(root), first)
  end

  defp check_file(path) do
    try do
      if String.ends_with?(path, ".yml") do
        {:ok, lang, entries, warnings} = GameBuddy.Pdx.parse_localization_file(path)

        cond do
          lang == nil and entries == [] ->
            %{path: path, status: :fail, detail: "no language header and no entries"}

          warnings != [] ->
            %{
              path: path,
              status: :warn,
              detail: "#{length(warnings)} unparsed lines, first: #{inspect(hd(warnings))}"
            }

          true ->
            %{path: path, status: :ok, detail: nil}
        end
      else
        case GameBuddy.Pdx.parse_file(path) do
          {:ok, _ast, []} ->
            %{path: path, status: :ok, detail: nil}

          {:ok, _ast, warnings} ->
            %{path: path, status: :warn, detail: inspect(Enum.take(warnings, 3))}

          {:error, reason} ->
            %{path: path, status: :fail, detail: reason}
        end
      end
    rescue
      e -> %{path: path, status: :fail, detail: Exception.message(e)}
    end
  end
end
