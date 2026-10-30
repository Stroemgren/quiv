defmodule GameBuddy.Loc do
  @moduledoc """
  In-memory localization table with the game's markup cleaned for reading.

  Cleaning rules (generic across Paradox games, measured on the EU5 files):

    * `$key$` is replaced by that key's cleaned text when it exists, else by `key`
    * `[concept|e]` becomes the concept name with underscores as spaces
    * `[GetFooType('key').GetName]`, `[GetCountry('DAN').GetAdjective]` and
      `[ShowRegionName('key')]` become the localized name (or adjective) of `key`
    * `[Scope.GetName]` and other scope functions become `[Scope]`
    * `#tag text#!` formatting is stripped to `text`
    * `@icon!` icons are removed
    * `\\n` becomes a newline
  """

  defstruct map: %{}, cache: nil, keys: nil, labels: nil, defines: %{}

  @type t :: %__MODULE__{
          map: %{String.t() => String.t()},
          cache: :ets.tid() | nil,
          keys: tuple | nil,
          labels: (String.t() -> [String.t()]) | nil,
          defines: %{String.t() => term}
        }

  def new(map \\ %{}), do: %__MODULE__{map: map}

  @doc """
  Attach a function that lists candidate localization keys for a term, used to
  turn `[concept|e]` links into the concept's localized name. Comes from the
  game adapter (`label_keys/1`).
  """
  def with_labels(%__MODULE__{} = loc, fun) when is_function(fun, 1), do: %{loc | labels: fun}

  @doc "Attach engine constants (`\"NCombat.COMBAT_DICE_SIDE\" => 10`) so `[GetDefine('NCombat','COMBAT_DICE_SIDE')]` renders as the value."
  def with_defines(%__MODULE__{} = loc, defines) when is_map(defines),
    do: %{loc | defines: defines}

  @doc "Localized name of a term via the label function, or nil."
  def label(%__MODULE__{labels: nil} = loc, term), do: text(loc, term)
  def label(%__MODULE__{labels: fun} = loc, term), do: first(loc, fun.(term))

  @doc """
  Attach a shared ETS memo for cleaned strings. The table is public so any
  process can read and write it; cleaning is deterministic so races are harmless.
  """
  def with_cache(%__MODULE__{} = loc) do
    %{
      loc
      | cache:
          :ets.new(:game_buddy_loc_cache, [
            :set,
            :public,
            read_concurrency: true,
            write_concurrency: true
          ])
    }
  end

  def drop_cache(%__MODULE__{cache: nil} = loc), do: loc

  def drop_cache(%__MODULE__{cache: t} = loc),
    do:
      (
        :ets.delete(t)
        %{loc | cache: nil}
      )

  @doc """
  Store the table in `:persistent_term` so worker processes can read it without
  copying. Large maps captured in closures are copied into every spawned
  process, which is what this avoids.
  """
  def share(%__MODULE__{} = loc, tag) do
    :persistent_term.put({__MODULE__, tag}, loc)
    tag
  end

  def shared(tag), do: :persistent_term.get({__MODULE__, tag})
  def unshare(tag), do: :persistent_term.erase({__MODULE__, tag})

  def put(%__MODULE__{map: m} = loc, key, value), do: %{loc | map: Map.put(m, key, value)}

  @doc "Raw value, or nil."
  def raw(%__MODULE__{map: m}, key), do: Map.get(m, key)

  def has?(%__MODULE__{map: m}, key), do: Map.has_key?(m, key)

  @doc "Cleaned text for a key, or nil when the key is missing."
  def text(%__MODULE__{cache: nil} = loc, key) do
    case raw(loc, key) do
      nil -> nil
      value -> clean(value, loc)
    end
  end

  def text(%__MODULE__{cache: table} = loc, key) do
    case :ets.lookup(table, key) do
      [{^key, cleaned}] ->
        cleaned

      [] ->
        cleaned = text(%{loc | cache: nil}, key)
        :ets.insert(table, {key, cleaned})
        cleaned
    end
  end

  @doc "First cleaned text among candidate keys, or nil."
  def first(%__MODULE__{} = loc, keys) do
    Enum.find_value(keys, fn k -> text(loc, k) end)
  end

  # -- prefix index -------------------------------------------------------------

  @doc "Build the sorted key index used by `with_prefix/3`."
  def index(%__MODULE__{map: m} = loc),
    do: %{loc | keys: m |> Map.keys() |> Enum.sort() |> List.to_tuple()}

  @doc "Keys starting with `prefix`, sorted, at most `limit` of them."
  def with_prefix(%__MODULE__{keys: nil} = loc, prefix, limit),
    do: with_prefix(index(loc), prefix, limit)

  def with_prefix(%__MODULE__{keys: keys}, prefix, limit) do
    n = tuple_size(keys)
    collect(keys, lower_bound(keys, prefix, 0, n), n, prefix, limit, [])
  end

  @doc """
  Keys that extend an entity key with `_` or `.`, which is where Paradox games
  keep an entity's extra prose: tooltips, mechanic explanations, option labels.
  """
  def related_keys(%__MODULE__{} = loc, key, limit \\ 40),
    do: with_prefix(loc, key <> "_", limit) ++ with_prefix(loc, key <> ".", limit)

  defp lower_bound(_keys, _p, lo, hi) when lo >= hi, do: lo

  defp lower_bound(keys, p, lo, hi) do
    mid = div(lo + hi, 2)

    if elem(keys, mid) < p,
      do: lower_bound(keys, p, mid + 1, hi),
      else: lower_bound(keys, p, lo, mid)
  end

  defp collect(_keys, _i, _n, _p, 0, acc), do: Enum.reverse(acc)

  defp collect(keys, i, n, p, limit, acc) when i < n do
    k = elem(keys, i)

    if String.starts_with?(k, p),
      do: collect(keys, i + 1, n, p, limit - 1, [k | acc]),
      else: Enum.reverse(acc)
  end

  defp collect(_keys, _i, _n, _p, _limit, acc), do: Enum.reverse(acc)

  # -- cleaning -----------------------------------------------------------------

  @doc "Clean a raw localization string."
  def clean(value, loc \\ new(), depth \\ 0)
  def clean(nil, _loc, _depth), do: nil

  def clean(value, loc, depth) when is_binary(value) do
    value
    |> resolve_refs(loc, depth)
    |> String.replace("\\n", "\n")
    |> String.replace(~r/@[A-Za-z0-9_]+!/, "")
    |> String.replace(~r/#[A-Za-z_]+(?:;[A-Za-z_0-9]+)*\s/, "")
    |> String.replace("#!", "")
    |> String.replace(~r/\[([^\]]+)\]/, fn m -> bracket(m, loc, depth) end)
    |> String.replace(~r/[ \t]+/, " ")
    |> String.trim()
  end

  defp resolve_refs(value, _loc, depth) when depth > 4, do: value

  defp resolve_refs(value, loc, depth) do
    Regex.replace(~r/\$([A-Za-z0-9_.]+)(?:\|[^$]*)?\$/, value, fn _, key ->
      case raw(loc, key) do
        nil -> key
        v -> clean(v, loc, depth + 1)
      end
    end)
  end

  defp raw_label(%__MODULE__{labels: fun} = loc, term) do
    keys = if fun, do: fun.(term), else: [term]
    Enum.find_value(keys, &raw(loc, &1))
  end

  # [GetCountry('DAN').GetAdjective], [GetInternationalOrganizationType('union').GetName],
  # [ShowRegionName('italy_region')]: a function with a quoted key argument.
  @named ~r/\A(?:Get|Show)[A-Za-z]*\('([^']+)'\)(?:\.Get([A-Za-z]+))?\z/

  defp bracket(m, loc, depth) do
    inner = m |> String.trim_leading("[") |> String.trim_trailing("]")

    cond do
      # [country|e] style game concept link: the concept's localized name.
      # Resolved at depth + 1 (not through the cache) because concept texts
      # link to each other and to themselves.
      Regex.match?(~r/\A[a-z0-9_]+\|[A-Za-z]+\z/, inner) ->
        term = inner |> String.split("|") |> hd()

        case if(depth < 3, do: raw_label(loc, term)) do
          nil -> String.replace(term, "_", " ")
          raw -> clean(raw, loc, depth + 1)
        end

      match = Regex.run(~r/\AGetDefine\('([A-Za-z0-9_]+)',\s*'([A-Za-z0-9_]+)'\)/, inner) ->
        [_, group, key] = match

        case Map.get(loc.defines, group <> "." <> key) do
          nil -> "#{group}.#{key}"
          v -> "#{define_value(v)} (#{group}.#{key})"
        end

      match = Regex.run(@named, inner) ->
        named(match, loc, depth)

      true ->
        inner
        |> String.split(~r/[.(|]/)
        |> hd()
        |> String.replace(~r/\AGet/, "")
        |> then(&"[#{&1}]")
    end
  end

  defp define_value(v) when is_list(v), do: Enum.map_join(v, ", ", &define_value/1)
  defp define_value(true), do: "yes"
  defp define_value(false), do: "no"
  defp define_value(v) when is_map(v), do: inspect(v)
  defp define_value(v), do: to_string(v)

  @name_attrs ~w(Name NameWithNoTooltip LongName LongNameWithNoTooltip ShortName ShortNameWithNoTooltip)

  defp named([_, key | rest], loc, depth) do
    attr = List.first(rest) || "Name"
    adjective? = String.contains?(attr, "Adjective")

    keys =
      if adjective?,
        do: ["#{key}_ADJ", "#{key}_adj", "#{key}_adjective", key, "#{key}_name"],
        else: [key, "#{key}_name"]

    name =
      case Enum.find_value(keys, &raw(loc, &1)) do
        v when is_binary(v) and depth < 4 -> clean(v, loc, depth + 1)
        _ -> String.replace(key, "_", " ")
      end

    cond do
      adjective? or attr in @name_attrs -> name
      pronoun?(attr) -> pronoun(attr)
      true -> "#{name} #{attr |> String.replace(~r/WithNoTooltip\z/, "") |> decamel()}"
    end
  end

  # GetHerHis / GetSheHe style: keep the first alternative
  defp pronoun?(attr), do: Regex.match?(~r/\A(Her|His|She|He|Him|Woman|Man)[A-Z]/, attr)

  defp pronoun(attr) do
    [_, first] = Regex.run(~r/\A(Her|His|She|He|Him|Woman|Man)[A-Z]/, attr)
    String.downcase(first)
  end

  defp decamel(s), do: s |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2") |> String.downcase()
end
