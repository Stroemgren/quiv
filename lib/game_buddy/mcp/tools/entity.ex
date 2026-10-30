defmodule GameBuddy.MCP.Tools.Entity do
  @moduledoc """
  The full document for one key: description, the game's attached text,
  conditions and effects in the game's own tooltip language, properties,
  connections (what it references and what references it, with keys), the
  source file and the script. Keys come from search results and from the
  connections of other documents; `index/<kind>` lists every key of a kind.
  A bare key that exists in several kinds returns the choices; an unknown key
  returns the closest names. The source path at the end and the script are
  for checking the files: answer in the game's own names and leave file names
  and keys out of the answer unless the user asks where something is defined.
  """
  use Anubis.Server.Component,
    type: :tool,
    name: "game_entity",
    title: "Entity document",
    annotations: %{"readOnlyHint" => true}

  alias GameBuddy.Knowledge
  alias GameBuddy.MCP.Tools.Helpers

  schema do
    field(:key, :string,
      required: true,
      description: "A key from search or a document (`kind/key`, or the bare key)."
    )

    field(:game, :string, description: "Optional. Defaults to the default game.")
    field(:version, :string, description: "Optional. Defaults to the latest indexed version.")
  end

  @impl true
  def description do
    "The full document for one key in #{Helpers.games_phrase()}, from the game's own " <>
      "files (use before web search for these games): description, the game's attached " <>
      "text, conditions and effects in the game's own tooltip language, properties, " <>
      "connections (what it references and what references it, with keys), the source " <>
      "file and the script. Keys come from game_search results and from the connections " <>
      "of other documents; `index/<kind>` lists every key of a kind, `topic/<concept>` " <>
      "how a concept works. Game and version are optional and default to the latest " <>
      "indexed version. A bare key that exists in several kinds returns the choices; an " <>
      "unknown key returns the closest names. The source path at the end and the script " <>
      "are for checking the " <>
      "files: answer in the game's own names and leave file names and keys out of the " <>
      "answer unless the user asks where something is defined. When the user asked about " <>
      "this specific entity (a reform, a privilege, a law, a building, ...), follow up " <>
      "with game_show(keys) so they see its card. `game` is one of " <>
      "#{Helpers.game_choices()}."
  end

  @impl true
  def execute(params, frame) do
    key = params |> Helpers.get(:key) |> to_string() |> String.trim()
    empty = fn game -> "No document has the key `#{key}` in #{game.name}." end

    Helpers.with_version(params, frame, &lookup(&1, key), empty)
  end

  defp lookup(gv, key) do
    case Knowledge.documents_for_key(gv, key) do
      [doc] ->
        {:text, doc.body}

      [] ->
        case Knowledge.resolve(gv, key, limit: 8) do
          [] ->
            {:error, "nothing with key or name #{inspect(key)}; try game_search"}

          candidates ->
            {:text,
             "No document has the key `#{key}`. Closest names:\n" <>
               Enum.map_join(
                 candidates,
                 "\n",
                 &"- #{&1.name || &1.key} — `#{&1.kind}/#{&1.key}`"
               )}
        end

      docs ->
        # several kinds share the key: the richest document first, the small
        # ones appended (minus their script), the rest listed by key
        best = Enum.max_by(docs, &String.length(&1.body))
        others = Enum.reject(docs, &(&1.id == best.id))
        {small, large} = Enum.split_with(others, &(String.length(&1.body) <= 4_000))

        appended =
          Enum.map_join(small, "\n\n", fn d ->
            "## Same key in `#{d.kind}/#{d.key}`\n" <>
              (d.body |> drop_script() |> drop_header())
          end)

        listed =
          if large == [],
            do: "",
            else:
              "\n\n## Same key in other kinds\n" <>
                Enum.map_join(large, ", ", &"`#{&1.kind}/#{&1.key}` (#{&1.title})")

        {:text, best.body <> "\n\n" <> appended <> listed}
    end
  end

  defp drop_script(body), do: body |> String.split("\n## Script\n") |> hd()

  defp drop_header(body) do
    body
    |> String.split("\n")
    |> Enum.drop_while(
      &(String.starts_with?(&1, "#") or String.starts_with?(&1, "`") or
          String.starts_with?(&1, "Source:"))
    )
    |> Enum.join("\n")
    |> String.trim()
  end
end
