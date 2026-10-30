defmodule GameBuddy.Render.Script do
  @moduledoc """
  Renders condition (trigger), effect and modifier blocks as readable lines in
  the game's own words. The game ships the rules: `trigger_localization` and
  `effect_localization` map each script predicate to localization templates
  ("Belongs to the [TARGET_CULTURE_GROUP.GetName] culture group"), and the
  modifier type definitions say how a value is formatted (`percent = yes`).
  The tables are read from the parsed files, so nothing here is game-specific;
  the conventions are those of the engine family.

  Lines come back as `{depth, text}` pairs.
  """

  alias GameBuddy.Loc

  defstruct triggers: %{}, effects: %{}, modifiers: %{}, icons: %{}, loc: %Loc{}, labels: nil

  @type line :: {non_neg_integer, String.t()}

  def new(opts) do
    %__MODULE__{
      triggers: Keyword.get(opts, :triggers, %{}),
      effects: Keyword.get(opts, :effects, %{}),
      modifiers: Keyword.get(opts, :modifiers, %{}),
      icons: Keyword.get(opts, :icons, %{}),
      loc: Keyword.get(opts, :loc, %Loc{}),
      labels: Keyword.get(opts, :labels)
    }
  end

  # -- classification ---------------------------------------------------------

  @trigger_names ~w(potential allow trigger is_shown visible possible can_select can_start can_pick
                    can_revoke locked limit is_valid show_trigger is_available can_use can_join_trigger
                    can_leave_trigger auto_disband_trigger auto_leave_trigger major_trigger)
  @effect_names ~w(effect immediate on_accept on_select on_start on_end after form_effect
                   on_debate_passed on_debate_failed hidden_effect)
  @combinators ~w(OR AND NOT NOR NAND trigger_if trigger_else trigger_else_if custom_tooltip always)

  @doc "How a block should be rendered: `:trigger`, `:effect`, `:modifier` or nil (generic)."
  def block_type(key, value, %__MODULE__{} = t) when is_map(value) and map_size(value) > 0 do
    keys = Map.keys(value)

    cond do
      String.contains?(key, "modifier") and share(keys, &Map.has_key?(t.modifiers, &1)) >= 0.5 ->
        :modifier

      key in @trigger_names or String.ends_with?(key, "_trigger") ->
        :trigger

      key in @effect_names or String.ends_with?(key, "_effect") ->
        :effect

      share(keys, &Map.has_key?(t.modifiers, &1)) >= 0.6 ->
        :modifier

      share(keys, &trigger_key?(&1, t)) >= 0.5 ->
        :trigger

      share(keys, &Map.has_key?(t.effects, &1)) >= 0.5 ->
        :effect

      true ->
        nil
    end
  end

  def block_type(key, value, t) when is_list(value) do
    case Enum.find(value, &is_map/1) do
      nil -> nil
      map -> block_type(key, map, t)
    end
  end

  def block_type(_key, _value, _t), do: nil

  defp share([], _fun), do: 0.0
  defp share(keys, fun), do: Enum.count(keys, fun) / length(keys)

  defp trigger_key?(k, t),
    do:
      k in @combinators or Map.has_key?(t.triggers, k) or String.starts_with?(k, "scope:") or
        String.starts_with?(k, "any_") or Loc.has?(t.loc, k <> "_equal")

  # -- triggers ---------------------------------------------------------------

  @comparator_words %{
    "=" => "",
    "==" => "",
    "?=" => "",
    "!=" => "not",
    ">" => "more than",
    ">=" => "at least",
    "<" => "less than",
    "<=" => "at most"
  }

  @suffixes %{
    "=" => "equal",
    "==" => "equal",
    "?=" => "equal",
    "!=" => "not_equal",
    ">" => "greater_than",
    ">=" => "greater_or_equal",
    "<" => "less_than",
    "<=" => "less_or_equal"
  }

  @doc "Lines for a trigger block."
  def trigger(block, t, depth \\ 0)
  def trigger(nil, _t, _depth), do: []
  def trigger(list, t, depth) when is_list(list), do: Enum.flat_map(list, &trigger(&1, t, depth))

  def trigger(block, t, depth) when is_map(block) do
    Enum.flat_map(block, fn {k, v} ->
      v |> dups() |> Enum.flat_map(&trigger_stmt(k, &1, t, depth))
    end)
  end

  def trigger(scalar, t, depth), do: [{depth, value_text(scalar, t)}]

  defp trigger_stmt("OR", v, t, depth), do: [{depth, "Any of:"} | trigger(v, t, depth + 1)]
  defp trigger_stmt("AND", v, t, depth), do: [{depth, "All of:"} | trigger(v, t, depth + 1)]
  defp trigger_stmt("NAND", v, t, depth), do: [{depth, "Not all of:"} | trigger(v, t, depth + 1)]

  defp trigger_stmt(k, v, t, depth) when k in ["NOT", "NOR"] do
    case single_leaf(v) do
      {pk, pv} ->
        {op, val} =
          case split_op(pv) do
            {nil, _} -> {"=", pv}
            pair -> pair
          end

        case template(t.triggers, pk, op, val, t, true) do
          {tpl, :negated} -> [{depth, fill(tpl, pk, op, val, t)}]
          _ -> [{depth, "None of:"} | trigger(v, t, depth + 1)]
        end

      nil ->
        [{depth, "None of:"} | trigger(v, t, depth + 1)]
    end
  end

  defp trigger_stmt(k, v, t, depth) when k in ["trigger_if", "trigger_else_if"] and is_map(v) do
    [{depth, "If:"}] ++
      trigger(v["limit"], t, depth + 1) ++
      [{depth, "then:"}] ++ trigger(Map.delete(v, "limit"), t, depth + 1)
  end

  defp trigger_stmt("trigger_else", v, t, depth),
    do: [{depth, "Otherwise:"} | trigger(v, t, depth + 1)]

  defp trigger_stmt("custom_tooltip", v, t, depth) when is_map(v) do
    case v["text"] && Loc.text(t.loc, v["text"]) do
      nil -> trigger(Map.delete(v, "text"), t, depth)
      text -> [{depth, text}]
    end
  end

  defp trigger_stmt("custom_tooltip", v, t, depth),
    do: [{depth, Loc.text(t.loc, to_string(v)) || to_string(v)}]

  defp trigger_stmt("always", true, _t, depth), do: [{depth, "Always"}]
  defp trigger_stmt("always", false, _t, depth), do: [{depth, "Never"}]

  defp trigger_stmt(k, v, t, depth) when is_map(v) do
    case split_op(v) do
      {nil, _} ->
        [{depth, scope_label(k, t) <> ":"} | trigger(v, t, depth + 1)]

      {"?=", val} when is_map(val) ->
        [{depth, scope_label(k, t) <> " (if any):"} | trigger(val, t, depth + 1)]

      {op, val} when is_map(val) ->
        [{depth, scope_label(k, t) <> " #{op}:"} | trigger(val, t, depth + 1)]

      {op, val} ->
        [{depth, leaf(k, op, val, t)}]
    end
  end

  defp trigger_stmt(k, v, t, depth), do: [{depth, leaf(k, "=", v, t)}]

  defp leaf(k, op, val, t) do
    cond do
      is_number(val) ->
        "#{label(k, t)} #{comparator(op, val)} #{value_text(val, t)}" |> squeeze()

      tpl = template(t.triggers, k, op, val, t, false) ->
        case tpl do
          {key, :negated} -> fill(key, k, op, val, t)
          {key, :positive} when op == "!=" or val == false -> "Not: " <> fill(key, k, op, val, t)
          {key, :positive} -> fill(key, k, op, val, t)
        end

      is_boolean(val) and val ->
        label(k, t)

      is_boolean(val) ->
        "Not: " <> label(k, t)

      true ->
        "#{label(k, t)} #{op_text(op)} #{value_text(val, t)}" |> squeeze()
    end
  end

  # -- effects ----------------------------------------------------------------

  @doc "Lines for an effect block."
  def effect(block, t, depth \\ 0)
  def effect(nil, _t, _depth), do: []
  def effect(list, t, depth) when is_list(list), do: Enum.flat_map(list, &effect(&1, t, depth))

  def effect(block, t, depth) when is_map(block) do
    Enum.flat_map(block, fn {k, v} ->
      v |> dups() |> Enum.flat_map(&effect_stmt(k, &1, t, depth))
    end)
  end

  def effect(scalar, t, depth), do: [{depth, value_text(scalar, t)}]

  defp effect_stmt(k, v, t, depth) when k in ["if", "else_if"] and is_map(v) do
    [{depth, "If:"}] ++
      trigger(v["limit"], t, depth + 1) ++
      [{depth, "then:"}] ++ effect(Map.delete(v, "limit"), t, depth + 1)
  end

  defp effect_stmt("else", v, t, depth), do: [{depth, "Otherwise:"} | effect(v, t, depth + 1)]

  defp effect_stmt("hidden_effect", v, t, depth),
    do: [{depth, "Hidden:"} | effect(v, t, depth + 1)]

  defp effect_stmt("limit", v, t, depth), do: [{depth, "Where:"} | trigger(v, t, depth + 1)]

  defp effect_stmt("custom_tooltip", v, t, depth) when is_map(v) do
    case v["text"] && Loc.text(t.loc, v["text"]) do
      nil -> effect(Map.delete(v, "text"), t, depth)
      text -> [{depth, text}]
    end
  end

  defp effect_stmt("custom_tooltip", v, t, depth),
    do: [{depth, Loc.text(t.loc, to_string(v)) || to_string(v)}]

  defp effect_stmt(k, v, t, depth) when is_map(v) do
    case {split_op(v), Map.has_key?(t.effects, k)} do
      {{nil, _}, true} -> [{depth, effect_leaf(k, v, t)}]
      {{nil, _}, false} -> [{depth, scope_label(k, t) <> ":"} | effect(v, t, depth + 1)]
      {{_op, val}, _} -> [{depth, effect_leaf(k, val, t)}]
    end
  end

  defp effect_stmt(k, v, t, depth), do: [{depth, effect_leaf(k, v, t)}]

  defp effect_leaf(k, v, t) do
    variant =
      if is_number(v) and v < 0,
        do: ["global_neg", "global", "first"],
        else: ["global", "first", "none"]

    case lookup(t.effects, k, variant, t) do
      nil -> "#{label(k, t)}: #{value_text(v, t)}"
      tpl -> fill(tpl, k, "=", v, t)
    end
  end

  # -- modifiers --------------------------------------------------------------

  @doc "Lines for a modifier block: `Discipline +5%`."
  def modifiers(block, t, depth \\ 0),
    do: Enum.map(modifier_rows(block, t, depth), fn {d, row} -> {d, row.text} end)

  @doc """
  Modifier rows as `{depth, %{label, value, tone, text}}`. `tone` is "good"
  or "bad" from the sign and the type's `color` (a `bad` type is bad when
  positive; `neutral` types have no tone), nil when unknown.
  """
  def modifier_rows(block, t, depth \\ 0)
  def modifier_rows(nil, _t, _depth), do: []

  def modifier_rows(list, t, depth) when is_list(list),
    do: Enum.flat_map(list, &modifier_rows(&1, t, depth))

  def modifier_rows(block, t, depth) when is_map(block) do
    Enum.flat_map(block, fn {k, v} ->
      v |> dups() |> Enum.map(fn v1 -> {depth, modifier_row(k, v1, t)} end)
    end)
  end

  def modifier_rows(scalar, t, depth) do
    text = value_text(scalar, t)
    [{depth, %{label: nil, value: text, tone: nil, text: text}}]
  end

  defp modifier_row(k, v, t) do
    def = Map.get(t.modifiers, k, %{})
    label = label(k, t)
    value = format_modifier(v, def, t)

    %{
      label: label,
      value: value,
      tone: tone(v, def),
      icon: Map.get(t.icons, k),
      text: String.trim("#{label} #{value}")
    }
  end

  defp tone(v, def) when is_number(v) and v != 0 do
    case {def["color"], v > 0} do
      {"neutral", _} -> nil
      {"bad", true} -> "bad"
      {"bad", false} -> "good"
      {_, true} -> "good"
      {_, false} -> "bad"
    end
  end

  defp tone(_, _), do: nil

  @doc "Formats a modifier value by its definition (percent, decimals, boolean)."
  def format_modifier(v, def, t \\ %__MODULE__{}) do
    cond do
      is_number(v) and def["percent"] == true -> signed(v * 100, def["decimals"] || 2) <> "%"
      is_number(v) and def["already_percent"] == true -> signed(v, def["decimals"] || 2) <> "%"
      is_number(v) -> signed(v, def["decimals"] || 3)
      is_boolean(v) -> if v, do: "yes", else: "no"
      true -> value_text(v, t)
    end
  end

  defp signed(v, decimals) do
    s = v |> abs() |> trim_number(decimals)
    if v < 0, do: "-" <> s, else: "+" <> s
  end

  defp trim_number(v, _decimals) when is_integer(v), do: Integer.to_string(v)

  defp trim_number(v, decimals) do
    v
    |> Float.round(decimals)
    |> :erlang.float_to_binary(decimals: decimals)
    |> String.replace(~r/\.?0+\z/, "")
    |> case do
      "" -> "0"
      s -> s
    end
  end

  # -- templates --------------------------------------------------------------

  # A template key for predicate `k` and whether it already expresses the
  # negation: the trigger_localization table first, then the `<k>_equal` /
  # `<K>_TRIGGER` naming conventions. nil when the game has none.
  defp template(table, k, op, val, t, negated?) do
    negated? = negated? or op == "!=" or val == false

    negated_key =
      if negated?,
        do:
          lookup(table, k, ["global_not", "none_not", "first_not"], t) ||
            auto_template(k, op, t, true)

    cond do
      negated_key -> {negated_key, :negated}
      key = lookup(table, k, ["global", "none", "first"], t) -> {key, :positive}
      key = auto_template(k, op, t, false) -> {key, :positive}
      true -> nil
    end
  end

  # First variant whose localization key exists.
  defp lookup(table, k, variants, t) do
    case Map.get(table, k) do
      %{} = entry ->
        Enum.find_value(variants, fn v ->
          key = entry[v]
          if is_binary(key) and Loc.has?(t.loc, key), do: key
        end)

      _ ->
        nil
    end
  end

  defp auto_template(k, op, t, negated?) do
    suffix =
      if negated? and op in ["=", "==", "?=", nil],
        do: "not_equal",
        else: Map.get(@suffixes, op, "equal")

    candidates = ["#{k}_#{suffix}", "#{k}_scope_#{suffix}", "#{k}_this_#{suffix}"]
    # the uppercase convention has no negated form
    candidates = if negated?, do: candidates, else: candidates ++ [String.upcase(k) <> "_TRIGGER"]
    Enum.find(candidates, &Loc.has?(t.loc, &1))
  end

  # Fill a template's placeholders with the value and clean the markup.
  defp fill(key, k, op, val, t) do
    raw = Loc.raw(t.loc, key) || key
    vtext = value_text(val, t)
    cmp = comparator(op, val)

    raw
    |> String.replace(~r/\[TARGET_[A-Z_]+\.Get[A-Za-z]+(?:\|[A-Za-z]+)?\]/, vtext)
    |> then(
      &Regex.replace(~r/\[([A-Z][A-Z_]*)\.Get[A-Za-z]+(?:\|[A-Za-z]+)?\]/, &1, fn _, scope ->
        "this " <> (scope |> String.downcase() |> String.replace("_", " "))
      end)
    )
    |> String.replace(~r/\$(COMPARATOR|COMPARISON|OP)(?:\|[^$]*)?\$/, cmp)
    |> then(
      &Regex.replace(~r/\$([A-Za-z_]+)(?:\|[^$]*)?\$/, &1, fn full, name ->
        cond do
          Loc.has?(t.loc, name) -> full
          name in ["CURRENCY", "NAME"] and is_number(val) -> "#{vtext} #{label(k, t)}"
          true -> vtext
        end
      end)
    )
    |> Loc.clean(t.loc)
    |> squeeze()
  end

  # -- values and labels --------------------------------------------------------

  @doc "Readable text for a scalar value: localized name with the key, or the scalar."
  def value_text(v, t)
  def value_text(true, _t), do: "yes"
  def value_text(false, _t), do: "no"
  def value_text(nil, _t), do: ""
  def value_text(v, _t) when is_number(v), do: to_string(v)

  def value_text(v, t) when is_binary(v) do
    bare = v |> String.split(":") |> List.last()

    case name_of(bare, t) do
      nil -> v
      ^v -> v
      name -> "#{name} (#{v})"
    end
  end

  def value_text(v, t) when is_list(v), do: Enum.map_join(v, ", ", &value_text(&1, t))

  def value_text(v, t) when is_map(v) do
    v
    |> Enum.reject(fn {k, _} -> k == "_tag" end)
    |> Enum.map_join(", ", fn {k, v1} -> "#{label(k, t)} #{value_text(v1, t)}" end)
  end

  @doc "Localized label for a key, or the key humanized."
  def label(k, t) do
    case name_of(k, t) do
      nil -> humanize(k)
      name -> name
    end
  end

  defp name_of(term, %{loc: loc, labels: nil}), do: Loc.text(loc, term)
  defp name_of(term, %{loc: loc, labels: fun}), do: Loc.first(loc, fun.(term))

  defp scope_label(k, t) do
    case k do
      "scope:" <> name -> humanize(name)
      "c:" <> tag -> name_of(tag, t) || tag
      _ -> label(k, t)
    end
  end

  defp humanize(k) do
    k
    |> String.split(":")
    |> List.last()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp comparator(nil, val), do: comparator("=", val)

  defp comparator(op, val) do
    case Map.get(@comparator_words, op) do
      nil -> op
      "" -> if is_number(val), do: "exactly", else: ""
      word -> word
    end
  end

  defp op_text(op) when op in ["=", "==", "?="], do: ""
  defp op_text(op), do: op

  defp split_op(%{"op" => op, "v" => v}), do: {op, v}
  defp split_op(_), do: {nil, nil}

  defp single_leaf(v) when is_map(v) and map_size(v) == 1 do
    [{k, val}] = Map.to_list(v)
    if is_list(val) or (is_map(val) and not Map.has_key?(val, "op")), do: nil, else: {k, val}
  end

  defp single_leaf(_), do: nil

  defp dups(list) when is_list(list), do: list
  defp dups(v), do: [v]

  defp squeeze(s), do: s |> String.replace(~r/\s+/, " ") |> String.trim()
end
