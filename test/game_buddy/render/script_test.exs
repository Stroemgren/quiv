defmodule GameBuddy.Render.ScriptTest do
  use ExUnit.Case, async: true
  alias GameBuddy.Loc
  alias GameBuddy.Render.Script

  defp tables do
    loc =
      Loc.new(%{
        "HAS_CULTURE_GROUP_TRIGGER" =>
          "Belongs to the [TARGET_CULTURE_GROUP.GetName] [culture_group_short|e]",
        "COUNTRYTAG_TRIGGER" => "Is $NAME|Y$",
        "IS_NOT_COUNTRY_TRIGGER" => "Is NOT $NAME|Y$",
        "government_type_equal" => "[COUNTRY.GetName|U] are a [TARGET_GOVERNMENT_TYPE.GetName]",
        "game_concept_culture_group_short" => "Culture Group",
        "russian_group" => "Russian",
        "monarchy" => "Monarchy",
        "PAP" => "Papal State",
        "MODIFIER_TYPE_NAME_discipline" => "Discipline",
        "MODIFIER_TYPE_NAME_monthly_prestige" => "Monthly Prestige",
        "stability" => "Stability"
      })

    Script.new(
      triggers: %{
        "has_culture_group" => %{"global" => "HAS_CULTURE_GROUP_TRIGGER"},
        "tag" => %{"global" => "COUNTRYTAG_TRIGGER", "global_not" => "IS_NOT_COUNTRY_TRIGGER"}
      },
      modifiers: %{"discipline" => %{"percent" => true}, "monthly_prestige" => %{}},
      loc: Loc.with_labels(loc, fn t -> [t, "MODIFIER_TYPE_NAME_#{t}", "game_concept_#{t}"] end),
      labels: fn t -> [t, "MODIFIER_TYPE_NAME_#{t}", "game_concept_#{t}"] end
    )
  end

  test "renders a scoped predicate with the game's template" do
    block = %{"culture" => %{"has_culture_group" => "culture_group:russian_group"}}

    assert Script.trigger(block, tables()) == [
             {0, "Culture:"},
             {1, "Belongs to the Russian (culture_group:russian_group) Culture Group"}
           ]
  end

  test "uses the auto-named template and a negated variant" do
    t = tables()

    assert Script.trigger(%{"government_type" => "government_type:monarchy"}, t) == [
             {0, "this country are a Monarchy (government_type:monarchy)"}
           ]

    assert Script.trigger(%{"NOT" => %{"tag" => "PAP"}}, t) == [{0, "Is NOT Papal State (PAP)"}]
  end

  test "combinators and numeric comparisons" do
    t = tables()
    block = %{"OR" => %{"stability" => %{"op" => ">=", "v" => 1}, "always" => true}}

    assert Script.trigger(block, t) == [
             {0, "Any of:"},
             {1, "Always"},
             {1, "Stability at least 1"}
           ]
  end

  test "formats modifiers by their definitions" do
    lines = Script.modifiers(%{"discipline" => 0.05, "monthly_prestige" => -0.5}, tables())
    assert lines == [{0, "Discipline +5%"}, {0, "Monthly Prestige -0.5"}]
  end

  test "classifies blocks" do
    t = tables()
    assert Script.block_type("potential", %{"tag" => "DAN"}, t) == :trigger
    assert Script.block_type("country_modifier", %{"discipline" => 0.1}, t) == :modifier

    assert Script.block_type("whatever", %{"has_culture_group" => "x", "tag" => "y"}, t) ==
             :trigger

    assert Script.block_type("color", %{"r" => 1}, t) == nil
  end
end
