defmodule GameBuddy.Pdx.ParserTest do
  use ExUnit.Case, async: true
  alias GameBuddy.Pdx

  test "parses nested blocks, duplicates, operators and typed scalars" do
    src = """
    ﻿# comment
    @timer = 5
    monarchy = {
      use_regnal_number = yes
      heir_selection = salic_law
      heir_selection = elective_succession
      modifier = { care_about_producing_heirs = yes }
      color2 = rgb { 255 223 0 }
      allow = {
        OR = {
          has_or_had_tag = DIT
          "estate_power(estate_type:peasants_estate)" > 0.1
          societal_value:serfdom_vs_free_subjects > 80
        }
        ruler_or_regent ?= { save_scope_as = x }
        NOT = { tag = MAL }
      }
      graphical_cultures = { pirate_gfx other_gfx }
      start = 1337.4.1
      desc = "Holdings owned by [target.GetName] in our \\"country\\""
    }
    """

    assert {:ok, ast, []} = Pdx.parse(src)
    assert [%{k: "@timer", op: "=", v: 5}, %{k: "monarchy", op: "=", v: %{block: body}}] = ast

    folded = Pdx.fold(ast)
    m = folded["monarchy"]
    assert m["use_regnal_number"] == true
    assert m["heir_selection"] == ["salic_law", "elective_succession"]
    assert m["modifier"] == %{"care_about_producing_heirs" => true}
    assert m["color2"] == %{"_tag" => "rgb", "_v" => [255, 223, 0]}

    assert m["allow"]["OR"]["estate_power(estate_type:peasants_estate)"] == %{
             "op" => ">",
             "v" => 0.1
           }

    assert m["allow"]["OR"]["societal_value:serfdom_vs_free_subjects"] == %{
             "op" => ">",
             "v" => 80
           }

    assert m["allow"]["ruler_or_regent"] == %{"op" => "?=", "v" => %{"save_scope_as" => "x"}}
    assert m["allow"]["NOT"] == %{"tag" => "MAL"}
    assert m["graphical_cultures"] == ["pirate_gfx", "other_gfx"]
    assert m["start"] == "1337.4.1"
    assert m["desc"] == ~s(Holdings owned by [target.GetName] in our "country")

    assert Enum.any?(body, &(&1[:k] == "start" and &1.line == 19))
  end

  test "is lenient about stray and missing braces" do
    assert {:ok, [%{k: "a", v: 1}], [{_, "stray closing brace"}]} = Pdx.parse("a = 1 }")

    assert {:ok, [%{k: "a", v: %{block: [%{k: "b", v: 2}]}}],
            [{1, "block not closed before end of file"}]} = Pdx.parse("a = { b = 2")
  end

  test "parses localization" do
    src = """
    ﻿l_english:
     monarchy:0 "Monarchy"
     monarchy_desc: "A realm ruled by a \\"king\\" with $legitimacy$."
     # comment
     bad line here
    """

    assert {:ok, "l_english", entries, [{5, _}]} = Pdx.parse_localization(src)

    assert entries == [
             {"monarchy", "Monarchy", 2},
             {"monarchy_desc", ~s(A realm ruled by a "king" with $legitimacy$.), 3}
           ]
  end
end
