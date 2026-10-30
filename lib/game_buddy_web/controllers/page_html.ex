defmodule GameBuddyWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use GameBuddyWeb, :html

  embed_templates "page_html/*"

  @doc "An integer with thousands separators: 118249 becomes 118,249."
  def number(n) when is_integer(n) do
    n
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.join(",")
  end

  def number(n), do: to_string(n)

  @doc "A compact count for a headline figure: 118249 becomes 118k."
  def compact(n) when is_integer(n) and n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  def compact(n) when is_integer(n) and n >= 10_000, do: "#{div(n, 1000)}k"
  def compact(n) when is_integer(n) and n >= 1_000, do: "#{Float.round(n / 1000, 1)}k"
  def compact(n), do: number(n)

  @doc "The one-line status under a game's name."
  def game_meta(nil), do: "Files not surveyed yet"

  def game_meta(version) do
    build = if version.build_id, do: "Build #{version.build_id}", else: version.version

    date =
      if version.build_date,
        do: " · #{Calendar.strftime(version.build_date, "%b %-d, %Y")}",
        else: ""

    build <> date
  end

  @doc "The short label players use, for the hero's game chips."
  def chip_label(%{slug: "eu5"}), do: "EU5"
  def chip_label(%{slug: "hoi4"}), do: "HOI4"
  def chip_label(%{slug: "civ7"}), do: "Civ VII"
  def chip_label(game), do: game.name

  @doc """
  The example exchanges the hero cycles through, per game: real questions players
  ask. Where the game is indexed the answer quotes our own data; where it is not,
  the reply says so. Never invented facts. A `card` is optional: `rows` carry
  `text` and, for a modifier, `value` and `tone` (:good, :bad or :neutral).
  """
  def example_chats("eu5") do
    [
      %{
        question: "Explain the estate privilege called Fortification Licenses.",
        answer:
          "Fortification Licenses is a Nobility estate privilege. It needs the Castle advance and can be revoked freely. While granted:",
        card: %{
          icon: "hero-building-library",
          title: "Fortification Licenses",
          kind: "estate privilege · Nobility",
          rows: [
            %{text: "Allows Nobility Fortifications", value: "yes", tone: :good},
            %{text: "Fort Limit", value: "+10%", tone: :good},
            %{text: "Fortification Maintenance Efficiency", value: "+50%", tone: :good},
            %{text: "Nobles Power", value: "+75%", tone: :bad}
          ]
        }
      },
      %{
        question: "What does the Castle advance unlock?",
        answer:
          "Castle is an advance of the Age of Traditions and requires Feudalism. It unlocks:",
        card: %{
          icon: "hero-academic-cap",
          title: "Castle",
          kind: "advance · Age of Traditions",
          rows: [
            %{text: "Castle", value: "building", tone: :neutral},
            %{text: "Military Orders", value: "Clergy privilege", tone: :neutral},
            %{text: "Fortification Licenses", value: "Nobility privilege", tone: :neutral},
            %{text: "Starting technology level", value: "3", tone: :neutral}
          ]
        }
      },
      %{
        question: "Why do I keep getting the Serfdom unrest event?",
        answer: "Serfdom is a Revolutionary Chaos event. It can fire while all of these hold:",
        card: %{
          icon: "hero-bolt",
          title: "Serfdom",
          kind: "event · Revolutionary Chaos",
          rows: [
            %{text: "Serfdom vs Free Subjects at most -50"},
            %{text: "Not under the Revolutionary Autocracy reform"},
            %{text: "Not already fired (tracked by a variable)"}
          ]
        }
      }
    ]
  end

  def example_chats("hoi4") do
    [
      %{
        question: "What does Anschluss require with, and without, Götterdämmerung?",
        answer:
          "Hearts of Iron IV is next in line. Once its files are indexed, this answer comes from the focus tree script itself, including the branch the game takes when the DLC is owned."
      },
      %{
        question: "What exactly does the Four Year Plan focus give?",
        answer:
          "Hearts of Iron IV is next in line. Once indexed, the answer lists the focus's effects as the script states them, with the exact numbers."
      }
    ]
  end

  def example_chats("civ7") do
    [
      %{
        question: "Does Kambu-Mera really cut specialist upkeep by 100%?",
        answer:
          "Civilization VII is being surveyed. The answer will quote the modifier the game applies rather than the tooltip, so a mismatch between the two shows up."
      },
      %{
        question: "What do I need to unlock the Mongols in the Exploration Age?",
        answer:
          "Civilization VII is being surveyed. The answer will quote the unlock conditions from the game's data files, not a summary of them."
      }
    ]
  end

  def example_chats(_slug) do
    [
      %{
        question: "What exactly do I need to unlock this, and what does it change?",
        answer:
          "This game is being surveyed. Once its files are indexed, the answer quotes the script and the numbers it holds."
      }
    ]
  end

  @doc """
  The hero's exchanges in cycling order, flattened across the games as given
  (live games first): each with its `entry` (the game and its icon), the `chat`,
  its `index` in the whole cycle and its place `n` of `count` within the game.
  """
  def hero_chats(games) do
    games
    |> Enum.flat_map(fn entry ->
      chats = example_chats(entry.game.slug)

      chats
      |> Enum.with_index(1)
      |> Enum.map(fn {chat, n} -> %{entry: entry, chat: chat, n: n, count: length(chats)} end)
    end)
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> Map.put(item, :index, index) end)
  end

  @doc "The colour of a modifier value in an example card."
  def row_tone(:good), do: "text-lime"
  def row_tone(:bad), do: "text-coral"
  def row_tone(_), do: "text-white"

  @doc "A design page section number: 1 becomes 01."
  def section_number(i), do: i |> Integer.to_string() |> String.pad_leading(2, "0")

  @doc "The numbers a snapshot's stats carry, as {label, value}, for the hero strip."
  def snapshot_figures(nil), do: []

  def snapshot_figures(version) do
    stats = version.stats || %{}

    for {label, key} <- [
          {"entities", "entities"},
          {"documents", "documents"},
          {"localization strings", "localization_keys"},
          {"cross-references", "entity_refs"}
        ],
        value = stats[key],
        is_integer(value),
        do: {label, value}
  end
end
