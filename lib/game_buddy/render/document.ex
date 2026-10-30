defmodule GameBuddy.Render.Document do
  @moduledoc """
  One document per entity, in the shape a reader would want from a reference
  site: name and identity, description, the extra prose the game attaches to
  the key, conditions and effects rendered in the game's own tooltip
  language, the remaining properties, connections to other entities (with
  keys, so a reader can follow them), the source location and the script
  itself.

  `build/4` produces the structured form (JSON-shaped, string keys), which is
  what UI clients get; `to_markdown/1` prints it for text clients. Generic:
  the only game knowledge used is the parsed data, the localization and the
  rendering tables from the files.
  """

  alias GameBuddy.Pdx.Format
  alias GameBuddy.Render.Script

  @max_depth 6
  @max_items 300
  @max_connections_per_kind 25
  @max_script_chars 2_500

  @type connections :: %{
          references: %{String.t() => [{String.t(), String.t() | nil}]},
          referenced_by: %{String.t() => {non_neg_integer, [{String.t(), String.t() | nil}]}}
        }

  @doc "Render an entity to markdown. `meta` carries game name, version and DLC list."
  def render(entity, %Script{} = t, conn, meta),
    do: entity |> build(t, conn, meta) |> to_markdown()

  @doc """
  The structured document: identity, prose, blocks of rendered condition and
  effect lines (`%{"depth", "text"}`), properties, connections and script.
  """
  def build(entity, %Script{} = t, conn, meta) do
    data = entity.data || %{}

    {blocks, plain} =
      Enum.split_with(data, fn {k, v} ->
        Script.block_type(k, v, t) in [:trigger, :effect, :modifier]
      end)

    conditions =
      for {k, v} <- blocks, Script.block_type(k, v, t) == :trigger, do: block({k, v}, t)

    effects =
      for {k, v} <- blocks,
          Script.block_type(k, v, t) in [:effect, :modifier],
          do: block({k, v}, t)

    %{
      "name" => entity[:name] || entity.key,
      "kind" => entity.kind,
      "key" => entity.key,
      "game" => meta.game,
      "version" => meta.version,
      "dlc" => entity[:dlc],
      "icon" => entity[:icon],
      "source" =>
        "#{entity.source_file}#{if entity[:source_line], do: ":#{entity.source_line}", else: ""}",
      "description" => blank_to_nil(entity[:description]),
      "texts" => texts(entity),
      "conditions" => conditions,
      "effects" => effects,
      "properties" =>
        plain
        |> Enum.take(@max_items)
        |> Enum.flat_map(&generic(&1, t, 0))
        |> Enum.map(&line_map/1),
      "connections" => connections(conn),
      "script" => script(entity)
    }
  end

  @doc "Print a structured document as markdown."
  def to_markdown(s) do
    [
      header(s),
      prose(s),
      section("Conditions", Enum.flat_map(s["conditions"], &block_lines/1)),
      section("Effects", Enum.flat_map(s["effects"], &block_lines/1)),
      section("Properties", Enum.map(s["properties"], &line/1)),
      connections_md(s["connections"]),
      script_md(s["script"]),
      source_md(s["source"])
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  # -- building ---------------------------------------------------------------

  # A named block rendered by type: its label and lines.
  defp block({k, v}, t) do
    lines =
      case Script.block_type(k, v, t) do
        :trigger -> Script.trigger(v, t, 0)
        :effect -> Script.effect(v, t, 0)
        :modifier -> Script.modifier_rows(v, t, 0)
      end

    %{"title" => Script.label(k, t), "lines" => Enum.map(lines, &line_map/1)}
  end

  defp line_map({depth, text}) when is_binary(text), do: %{"depth" => depth, "text" => text}

  # modifier rows keep label, value, tone and icon for clients that render UI
  defp line_map({depth, %{text: text} = row}) do
    base = %{
      "depth" => depth,
      "text" => text,
      "label" => row.label,
      "value" => row.value,
      "tone" => row.tone
    }

    if row[:icon], do: Map.put(base, "icon", row.icon), else: base
  end

  defp texts(e) do
    case e[:texts] do
      list when is_list(list) and list != [] ->
        Enum.map(list, fn {k, text} ->
          %{"label" => text_label(k, e.key), "text" => String.replace(text, "\n", " ")}
        end)

      _ ->
        []
    end
  end

  defp text_label(k, key),
    do:
      k
      |> String.replace_prefix(key, "")
      |> String.trim_leading("_")
      |> String.trim_leading(".")
      |> String.replace("_", " ")

  # Generic rendering of remaining fields; nested blocks are classified too.
  defp generic({k, v}, t, depth) when depth <= @max_depth do
    case Script.block_type(k, v, t) do
      :trigger -> [{depth, Script.label(k, t) <> ":"} | Script.trigger(v, t, depth + 1)]
      :effect -> [{depth, Script.label(k, t) <> ":"} | Script.effect(v, t, depth + 1)]
      :modifier -> [{depth, Script.label(k, t) <> ":"} | Script.modifiers(v, t, depth + 1)]
      nil -> plain({k, v}, t, depth)
    end
  end

  defp generic(_, _t, _depth), do: []

  defp plain({k, %{"op" => op, "v" => v}}, t, depth),
    do: [{depth, "#{Script.label(k, t)} #{op} #{inline(v, t)}"}]

  defp plain({k, v}, t, depth) do
    cond do
      scalar?(v) or (is_list(v) and Enum.all?(v, &scalar?/1)) or tagged?(v) ->
        [{depth, "#{Script.label(k, t)}: #{inline(v, t)}"}]

      is_map(v) and map_size(v) == 0 ->
        [{depth, "#{Script.label(k, t)}: {}"}]

      is_map(v) ->
        [
          {depth, Script.label(k, t) <> ":"}
          | v |> Enum.take(@max_items) |> Enum.flat_map(&generic(&1, t, depth + 1))
        ]

      is_list(v) ->
        [{depth, Script.label(k, t) <> ":"} | Enum.flat_map(v, &list_item(&1, t, depth + 1))]

      true ->
        [{depth, "#{Script.label(k, t)}: …"}]
    end
  end

  defp list_item(item, t, depth) when is_map(item),
    do: Enum.flat_map(item, &generic(&1, t, depth))

  defp list_item(item, t, depth), do: [{depth, inline(item, t)}]

  defp inline(v, t) do
    cond do
      scalar?(v) -> Script.value_text(v, t)
      tagged?(v) -> "#{v["_tag"]} #{inline(v["_v"], t)}"
      is_list(v) -> Enum.map_join(v, ", ", &inline(&1, t))
      is_map(v) -> Script.value_text(v, t)
      true -> "…"
    end
  end

  defp scalar?(v), do: is_binary(v) or is_number(v) or is_boolean(v) or is_nil(v)
  defp tagged?(v), do: is_map(v) and Map.has_key?(v, "_tag")

  defp connections(nil), do: nil

  defp connections(%{references: refs, referenced_by: by}) do
    references =
      refs
      |> Enum.sort()
      |> Enum.map(fn {kind, items} -> connection(kind, length(items), items) end)

    referenced_by =
      by
      |> Enum.sort()
      |> Enum.map(fn {kind, {count, items}} -> connection(kind, count, items) end)

    if references == [] and referenced_by == [],
      do: nil,
      else: %{"references" => references, "referenced_by" => referenced_by}
  end

  defp connection(kind, count, items) do
    %{
      "kind" => kind,
      "count" => count,
      "items" =>
        items
        |> Enum.take(@max_connections_per_kind)
        |> Enum.map(fn {key, name} -> %{"key" => key, "name" => name} end)
    }
  end

  defp script(%{ast: %{"statements" => stmts}}) when is_list(stmts) and stmts != [],
    do: Format.to_script(stmts, @max_script_chars)

  defp script(%{ast: stmts}) when is_list(stmts) and stmts != [],
    do: Format.to_script(stmts, @max_script_chars)

  defp script(_), do: nil

  # -- printing ---------------------------------------------------------------

  defp header(s) do
    dlc = if s["dlc"], do: " · DLC: #{s["dlc"]}", else: ""

    "# #{s["name"]}\n" <>
      "`#{s["kind"]}` · key `#{s["key"]}` · #{s["game"]} #{s["version"]}#{dlc}"
  end

  defp prose(s) do
    texts =
      case s["texts"] do
        [] -> nil
        list -> Enum.map_join(list, "\n", &"- #{&1["label"]}: #{&1["text"]}")
      end

    [s["description"], texts] |> Enum.reject(&is_nil/1) |> Enum.join("\n\n") |> blank_to_nil()
  end

  defp section(_title, []), do: nil
  defp section(title, lines), do: "## #{title}\n" <> Enum.join(lines, "\n")

  defp block_lines(%{"title" => title, "lines" => lines}),
    do: ["### #{title}" | Enum.map(lines, &line/1)]

  defp line(%{"depth" => depth, "text" => text}),
    do: String.duplicate("  ", depth) <> "- " <> text

  defp connections_md(nil), do: nil

  defp connections_md(%{"references" => refs, "referenced_by" => by}) do
    out = Enum.map(refs, &("- References #{&1["kind"]}: " <> names(&1)))
    incoming = Enum.map(by, &("- Referenced by #{&1["kind"]} (#{&1["count"]}): " <> names(&1)))
    "## Connections\n" <> Enum.join(out ++ incoming, "\n")
  end

  defp names(%{"items" => items, "count" => total}) do
    text =
      Enum.map_join(items, ", ", fn
        %{"key" => key, "name" => nil} -> key
        %{"key" => key, "name" => name} when name == key -> key
        %{"key" => key, "name" => name} -> "#{name} (#{key})"
      end)

    if total > length(items), do: text <> ", … #{total - length(items)} more", else: text
  end

  defp script_md(nil), do: nil
  defp script_md(text), do: "## Script\n```\n" <> text <> "\n```"

  # Last line, so that a file path never reads as part of the facts.
  defp source_md(nil), do: nil
  defp source_md(src), do: "Source file: `#{src}` (internal, not for the player)"

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s), do: s
end
