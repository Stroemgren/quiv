defmodule GameBuddy.Render.Pages do
  @moduledoc """
  The documents that are not entities: one index per kind (every entity on
  one line with its key and a few facets), the game intro, and the compiled
  search result. All generic.
  """

  alias GameBuddy.Render.Script

  @index_part_size 400
  @max_facets 5

  @doc """
  Index documents for a kind, split into parts of #{@index_part_size} lines:
  keys `index/<kind>`, `index/<kind>#2`, ...
  """
  def index(kind, entities, %Script{} = t, meta) do
    sorted = Enum.sort_by(entities, & &1.key)
    parts = Enum.chunk_every(sorted, @index_part_size)
    total = length(parts)

    parts
    |> Enum.with_index(1)
    |> Enum.map(fn {chunk, n} ->
      key = if n == 1, do: "index/#{kind}", else: "index/#{kind}##{n}"

      nav =
        if total > 1,
          do:
            "Part #{n} of #{total} (#{length(sorted)} entities). Other parts: " <>
              Enum.map_join(1..total, ", ", fn i ->
                if i == 1, do: "index/#{kind}", else: "index/#{kind}##{i}"
              end),
          else: "#{length(sorted)} entities."

      body =
        "# Index of #{kind} · #{meta.game} #{meta.version}\n#{nav}\n" <>
          "Look up any entry with game_entity(key).\n\n" <>
          Enum.map_join(chunk, "\n", &index_line(&1, t))

      %{key: key, title: "Index of #{kind}" <> if(n > 1, do: " (#{n})", else: ""), body: body}
    end)
  end

  defp index_line(e, t) do
    facets =
      (e.data || %{})
      |> Enum.filter(fn {k, v} -> scalar?(v) and not String.starts_with?(k, "_") end)
      |> Enum.sort()
      |> Enum.take(@max_facets)
      |> Enum.map_join(" · ", fn {k, v} -> "#{Script.label(k, t)}: #{Script.value_text(v, t)}" end)

    name = if e.name && e.name != e.key, do: "#{e.name} (#{e.key})", else: e.key

    desc =
      if e.description,
        do: " — " <> (e.description |> String.replace("\n", " ") |> String.slice(0, 120))

    "- #{name}" <> if(facets == "", do: "", else: " · " <> facets) <> (desc || "")
  end

  defp scalar?(v), do: is_binary(v) or is_number(v) or is_boolean(v)

  @doc """
  The game intro: what was indexed, how to use the tools, the game's own core
  vocabulary (the glossary entries its texts link to most) and per-game notes.
  """
  def intro(meta, kinds, concepts, notes, stats) do
    kinds_table =
      kinds
      |> Enum.sort_by(fn {k, _n, _ex} -> k end)
      |> Enum.map_join("\n", fn {k, n, ex} ->
        "- `#{k}` (#{n})#{if ex, do: ": e.g. #{ex}", else: ""}"
      end)

    concept_lines =
      Enum.map_join(concepts, "\n", fn {name, key, desc} ->
        "- **#{name}** (`#{key}`): #{desc}"
      end)

    notes_text =
      if notes == [],
        do: "",
        else: "\n\n## Notes on this game\n" <> Enum.map_join(notes, "\n", &("- " <> &1))

    """
    # #{meta.game} — #{meta.version}
    DLCs present in the files: #{if meta.dlcs == [], do: "none", else: Enum.join(meta.dlcs, ", ")}.
    Everything here is extracted from the game's own files for this exact version; nothing comes from wikis or the web. Facts about another version may differ.

    ## How to use this data
    - Every tool defaults to the latest indexed version of this game; `game` and `version` are optional.
    - `game_search(query)` returns a compiled document of the best matches across entities, the game's localization text and shipped docs, each with a key.
    - `game_entity(key)` returns the full document for a key: description, conditions and effects in the game's own tooltip language, properties, connections to other entities (with their keys) and the script.
    - Keys, source paths and script are for navigation and for checking the files. Answer with the game's own names; leave file names and keys out of the answer unless the user asks where something is defined.
    - Follow connections to escalate: a country's document names its culture; the culture's document names its culture group; the group's document lists what references it.
    - `game_entity("index/<kind>")` lists every entity of a kind on one line each (name, key, main facets), split into parts for large kinds.
    - `game_entity("topic/<concept>")` compiles how a glossary concept works: its entry, the entries it links to, the modifiers and engine constants that mention it. Start here for "how does X work" questions.
    - `game_show(keys)` renders entities as an interactive view (a card for one key, a comparison for several) in clients that support it; other clients get a one-line summary. Whenever the answer centers on specific entities (the user asked about one, or to see or compare some): `game_entity` for the facts, then `game_show` with those keys, then a short answer, as the view carries the details. Skip it for broad questions. At most once per reply.
    - `text/<file>` documents hold the game's UI text, tooltips, messages and hints by file; `docs/<file>` the readme, format notes and engine constants (with the developers' comments) shipped with the game.
    - Conditions say what the game checks; whether they hold in a running game (variables, owned land, current year) cannot be known here.
    - Which DLCs a player owns is not known here; DLC content is marked with its DLC.

    ## What is indexed
    #{stats.entities} entities in #{length(kinds)} kinds, #{stats.text_docs} localization text documents, #{stats.doc_files} shipped docs.

    ## Core vocabulary (the game's own glossary, most-referenced first)
    #{concept_lines}

    ## Kinds
    #{kinds_table}#{notes_text}
    """
    |> String.trim()
  end

  @doc "A compiled search result: the best matches with their keys and matched passages."
  def search(query, meta, hits) do
    body =
      hits
      |> Enum.with_index(1)
      |> Enum.map_join("\n\n", fn {h, i} ->
        passage = h[:snippet] && h.snippet |> strip_marks() |> String.replace("\n", " ")

        excerpt =
          (h[:body] || "")
          |> after_header()
          |> String.slice(0, 900)
          |> String.trim()

        [
          "## #{i}. #{h.title} — `#{h.id}`",
          if(passage && passage != "", do: "Matched: " <> passage),
          if(excerpt != "",
            do: excerpt <> if(String.length(h[:body] || "") > 900, do: "\n…", else: "")
          )
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join("\n")
      end)

    keys = Enum.map_join(hits, "\n", &"- `#{&1.id}`")

    """
    # Search: "#{query}" · #{meta.game} #{meta.version}
    #{length(hits)} results. Call game_entity(key) for any full document.

    #{body}

    ## Keys
    #{keys}
    """
    |> String.trim()
  end

  defp strip_marks(s), do: s |> String.replace("<b>", "") |> String.replace("</b>", "")

  # drop the title/identity lines so the excerpt starts at the description
  # The body without its header lines and without the source footer.
  defp after_header(body) do
    body
    |> String.split("\n")
    |> Enum.drop_while(&(String.starts_with?(&1, "#") or String.starts_with?(&1, "`")))
    |> Enum.reject(&String.starts_with?(&1, "Source file:"))
    |> Enum.join("\n")
    |> String.trim_leading()
  end

  @max_topic_items 30

  @doc """
  A topic document for a glossary concept: its description, the concepts it
  links to (with their descriptions), the modifiers whose descriptions mention
  it, the engine constants named after it, and what else mentions it. Built
  from the glossary's own link structure, so "how does X work" is one lookup.
  """
  def topic(concept, linked, modifiers, constants, mentioned_by, meta) do
    desc = concept.description || ""

    sections = [
      section("Related concepts", linked, fn {key, name, d} ->
        "- **#{name || key}** (`#{key}`): #{short(d)}"
      end),
      section("Modifiers that mention it", modifiers, fn {key, name, d} ->
        "- **#{name || key}** (`#{key}`): #{short(d)}"
      end),
      section("Engine constants", constants, fn {group, key, value} ->
        "- #{group}.#{key}: #{value}"
      end),
      section("Also mentioned by", mentioned_by, fn {kind, items} ->
        "- #{kind}: " <>
          Enum.map_join(items, ", ", fn {key, name} ->
            if(name && name != key, do: "#{name} (#{key})", else: key)
          end)
      end)
    ]

    ([
       "# #{concept.name || concept.key} (topic)\n`topic` · key `#{concept.key}` · #{meta.game} #{meta.version}\n" <>
         "Compiled from the game's glossary entry `#{concept.kind}/#{concept.key}`, the entries it links to, and the modifiers and constants that mention it.",
       desc
     ] ++ sections)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  defp section(_title, [], _fun), do: nil

  defp section(title, items, fun),
    do: "## #{title}\n" <> (items |> Enum.take(@max_topic_items) |> Enum.map_join("\n", fun))

  defp short(nil), do: ""
  defp short(d), do: d |> String.replace("\n", " ") |> String.slice(0, 300)
end
