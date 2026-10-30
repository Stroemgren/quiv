defmodule Mix.Tasks.Game.Assets do
  @shortdoc "Convert and store the textures the default snapshot needs (icons, theme)"
  @moduledoc """
      mix game.assets [--game eu5] [--path ~/dev/game-data/eu5]

  Needs `python3` with Pillow (`pip install pillow`), which decodes the DDS
  textures. Run after `mix game.ingest`; idempotent (stored textures are
  skipped, the theme is rebuilt). `--path` defaults to the snapshot's source.
  """
  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [game: :string, path: :string])
    Application.put_env(:game_buddy, :embeddings, enabled: false)
    Mix.Task.run("app.start")

    gv = GameBuddy.Catalog.default_version(opts[:game]) || Mix.raise("no ingested snapshot")
    root = opts[:path] || gv.source_path || Mix.raise("pass --path to the game files")
    stats = GameBuddy.Assets.build(gv, Path.expand(root))
    {theme, stats} = Map.pop(stats, :theme)
    Mix.shell().info("assets for #{gv.game.slug} #{gv.version}: #{inspect(stats)}")
    Mix.shell().info("theme: #{inspect(Map.drop(theme, ["textures"]))}")
  end
end
