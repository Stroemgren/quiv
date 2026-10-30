defmodule Mix.Tasks.Game.Ingest do
  @shortdoc "Ingest a game's files into a new snapshot"
  @moduledoc """
      mix game.ingest eu5 --path ~/dev/game-data/eu5 [--lang english]
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, [slug], _} = OptionParser.parse(args, switches: [path: :string, lang: :string])
    path = opts[:path] || Mix.raise("--path is required")
    Mix.Task.run("app.start")
    GameBuddy.Ingest.run(slug, path, lang: opts[:lang] || "english")
  end
end
