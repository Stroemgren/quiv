defmodule GameBuddy.MCP.Tools.Show do
  @moduledoc """
  Render entities as an interactive view in the conversation (an MCP App): a
  card for one key, a side-by-side comparison for several. Called whenever the
  answer centers on specific entities (the user asked about one, or to see or
  compare some), after `entity`; skipped for broad questions. Returns no new
  facts. The description the client sees is `description/0`.
  """
  use Anubis.Server.Component,
    type: :tool,
    name: "game_show",
    title: "Show entities",
    annotations: %{"readOnlyHint" => true},
    meta: %{
      "ui" => %{"resourceUri" => "ui://game-buddy/entities"},
      "ui/resourceUri" => "ui://game-buddy/entities"
    }

  alias Anubis.Server.Response
  alias GameBuddy.{Assets, Knowledge}
  alias GameBuddy.MCP.Tools.Helpers

  @max_keys 12

  schema do
    field(:keys, {:list, :string},
      required: true,
      description: "Keys (`kind/key`) to show together, up to #{@max_keys}."
    )

    field(:game, :string, description: "Optional. Defaults to the default game.")
    field(:version, :string, description: "Optional. Defaults to the latest indexed version.")
  end

  @impl true
  def description do
    "Render entities of #{Helpers.games_phrase()} as an interactive view in the " <>
      "conversation (an MCP App): a card for one key, a side-by-side comparison for " <>
      "several. Call it whenever the answer centers on specific entities: the user asked " <>
      "about one (\"explain the X privilege\", \"what does reform Y do\"), asked to show, " <>
      "see or compare things, or you are presenting a handful of alternatives. Get the " <>
      "facts with `game_entity` first, then call `game_show` with those keys (up to 12), then write " <>
      "a short answer, as the view carries the details. Skip it for broad questions whose " <>
      "answer is a long list or a mechanic with no single entity. It returns no new facts " <>
      "and is safe in every client: clients without UI get a one-line summary. At most " <>
      "once per reply. `game` is one of #{Helpers.game_choices()}."
  end

  @impl true
  def execute(params, frame) do
    keys =
      params
      |> Helpers.get(:keys)
      |> List.wrap()
      |> Enum.map(&(&1 |> to_string() |> String.trim()))
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
      |> Enum.take(@max_keys)

    empty = fn _game -> "Showing 0. Not found: #{Enum.join(keys, ", ")}." end

    Helpers.with_version(params, frame, &render(&1, keys), empty)
  end

  defp render(gv, keys) do
    {found, missing} =
      Enum.reduce(keys, {[], []}, fn key, {found, missing} ->
        case pick(Knowledge.documents_for_key(gv, key)) do
          nil -> {found, [key | missing]}
          doc -> {[doc | found], missing}
        end
      end)

    found = Enum.reverse(found)
    missing = Enum.reverse(missing)

    if found == [] do
      {:error,
       "nothing found for #{inspect(keys)}; keys come from game_search and game_entity documents"}
    else
      structured =
        %{
          "game" => gv.game.slug,
          "version" => gv.version,
          "entities" => Enum.map(found, &view/1),
          "missing" => missing
        }
        |> slim()
        |> attach_assets(gv)

      Response.tool()
      |> Response.text(summary(found, missing))
      |> Response.structured(structured)
    end
  end

  # Hosts stop rendering an app when a tool result gets very large (claude.ai:
  # ~150k characters), so the payload is trimmed in steps until it fits: first
  # the scripts go, then long property lists, then long condition/effect
  # blocks, then connection lists.
  @max_bytes 90_000
  @steps [
    &__MODULE__.drop_script/1,
    &__MODULE__.cap_properties/1,
    &__MODULE__.cap_blocks/1,
    &__MODULE__.cap_connections/1
  ]

  @doc false
  def slim(structured, steps \\ @steps) do
    if byte_size(Jason.encode!(structured)) <= @max_bytes or steps == [] do
      structured
    else
      [step | rest] = steps
      slim(Map.update!(structured, "entities", &Enum.map(&1, step)), rest)
    end
  end

  @doc false
  def drop_script(e), do: Map.delete(e, "script")

  @doc false
  def cap_properties(e), do: cap_list(e, "properties", 20)

  @doc false
  def cap_blocks(e) do
    e
    |> Map.update("conditions", [], fn bs -> Enum.map(bs, &cap_list(&1, "lines", 40)) end)
    |> Map.update("effects", [], fn bs -> Enum.map(bs, &cap_list(&1, "lines", 40)) end)
  end

  @doc false
  def cap_connections(%{"connections" => %{} = c} = e) do
    c =
      c
      |> Map.update("references", [], fn gs -> Enum.map(gs, &cap_list(&1, "items", 8)) end)
      |> Map.update("referenced_by", [], fn gs -> Enum.map(gs, &cap_list(&1, "items", 8)) end)

    Map.put(e, "connections", c)
  end

  def cap_connections(e), do: e

  # Keep the first `n` of a list field and say how many were cut.
  defp cap_list(map, field, n) do
    case Map.get(map, field) do
      list when is_list(list) and length(list) > n ->
        map
        |> Map.put(field, Enum.take(list, n))
        |> Map.put(field <> "_cut", length(list) - n)

      _ ->
        map
    end
  end

  # Icons and the theme (from `mix game.assets`) as data URIs, within a byte
  # budget on top of the sections: theme textures first, then entity icons,
  # then modifier icons. The page falls back to text for whatever is missing.
  @asset_budget 50_000

  defp attach_assets(structured, gv) do
    theme = Assets.theme(gv.id)
    wanted = asset_paths(structured, theme)
    with_assets(structured, theme, Assets.fetch(gv.id, wanted), wanted)
  end

  @doc false
  def asset_paths(structured, theme) do
    entities = structured["entities"] || []
    textures = for {_role, t} <- (theme && theme["textures"]) || %{}, p = t["asset"], do: p
    icons = for e <- entities, p = e["icon"], do: p

    rows =
      for e <- entities, b <- e["effects"] || [], l <- b["lines"] || [], p = l["icon"], do: p

    Enum.uniq(textures ++ icons ++ rows)
  end

  @doc false
  def with_assets(structured, theme, found, order, budget \\ @asset_budget) do
    {assets, _used} =
      Enum.reduce(order, {%{}, 0}, fn path, {acc, used} ->
        case found[path] do
          {mime, data} ->
            uri = Assets.data_uri(mime, data)

            if used + byte_size(uri) <= budget,
              do: {Map.put(acc, path, uri), used + byte_size(uri)},
              else: {acc, used}

          _ ->
            {acc, used}
        end
      end)

    structured
    |> then(&if(theme, do: Map.put(&1, "theme", theme), else: &1))
    |> then(&if(assets == %{}, do: &1, else: Map.put(&1, "assets", assets)))
  end

  # Several kinds share a bare key: prefer an entity document, then the richest.
  defp pick([]), do: nil

  defp pick(docs) do
    docs
    |> Enum.sort_by(&{is_nil(&1.sections), -String.length(&1.body || "")})
    |> hd()
  end

  # Entity documents carry their sections; other documents (index, topic,
  # text, docs) are shown as their markdown.
  defp view(%{sections: sections}) when is_map(sections), do: sections

  defp view(doc),
    do: %{"name" => doc.title, "kind" => doc.kind, "key" => doc.key, "markdown" => doc.body}

  defp summary(found, missing) do
    shown = Enum.map_join(found, ", ", &"#{&1.title} (#{&1.kind}/#{&1.key})")
    base = "Showing #{length(found)}: #{shown}."
    if missing == [], do: base, else: base <> " Not found: #{Enum.join(missing, ", ")}."
  end
end
