defmodule Mix.Tasks.Pdx.Parse do
  @shortdoc "Parse one Paradox script or localization file and print JSON"
  @moduledoc """
      mix pdx.parse PATH            # ordered AST
      mix pdx.parse PATH --fold     # folded map
      mix pdx.parse PATH --loc      # localization file
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, [path], _} = OptionParser.parse(args, switches: [fold: :boolean, loc: :boolean])

    cond do
      opts[:loc] ->
        {:ok, lang, entries, warnings} = GameBuddy.Pdx.parse_localization_file(path)

        IO.puts(
          Jason.encode!(
            %{
              lang: lang,
              count: length(entries),
              warnings: warnings,
              entries: Enum.take(entries, 50) |> Enum.map(&Tuple.to_list/1)
            },
            pretty: true
          )
        )

      true ->
        case GameBuddy.Pdx.parse_file(path) do
          {:ok, ast, warnings} ->
            unless warnings == [], do: IO.puts(:stderr, "warnings: #{inspect(warnings)}")

            out =
              if opts[:fold], do: GameBuddy.Pdx.fold(ast), else: GameBuddy.Pdx.ast_to_json(ast)

            IO.puts(Jason.encode!(out, pretty: true))

          {:error, reason} ->
            Mix.raise("parse error: #{reason}")
        end
    end
  end
end
