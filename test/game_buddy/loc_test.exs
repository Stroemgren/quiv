defmodule GameBuddy.LocTest do
  use ExUnit.Case, async: true
  alias GameBuddy.Loc

  test "cleans game markup and resolves references" do
    loc =
      Loc.new(%{
        "nobles_estate" => "Nobility",
        "monarchy" => "Monarchy",
        "DAN_ADJ" => "Danish",
        "monarchy_desc" =>
          "A $monarchy$ is a [government_type|e] where the [ruler|e] rules. #italic De jure#! and @gold! 5 [COUNTRY.GetName|U] [ShowEstateTypeName('nobles_estate')] or [GetCountry('DAN').GetAdjective] [GetCountry('zzz').GetName]. Line\\nbreak $missing$"
      })

    assert Loc.text(loc, "monarchy_desc") ==
             "A Monarchy is a government type where the ruler rules. De jure and 5 [COUNTRY] Nobility or Danish zzz. Line\nbreak missing"

    assert Loc.first(loc, ["nope", "nobles_estate"]) == "Nobility"
    assert Loc.text(loc, "absent") == nil
  end

  test "memo cache returns the same cleaned text" do
    loc = Loc.new(%{"k" => "#bold x#!"}) |> Loc.with_cache()
    assert Loc.text(loc, "k") == "x"
    assert Loc.text(loc, "k") == "x"
    Loc.drop_cache(loc)
  end
end

defmodule GameBuddy.LocPrefixTest do
  use ExUnit.Case, async: true
  alias GameBuddy.Loc

  test "related keys extend the key with _ or ." do
    loc =
      Loc.new(%{
        "marriage_union" => "Marriage Union",
        "marriage_union_desc" => "d",
        "marriage_union_mechanic_tooltip" => "m",
        "marriage_unions_plural" => "no",
        "flavor.1" => "e",
        "flavor.1.a" => "opt",
        "zzz" => "z"
      })

    assert Loc.related_keys(loc, "marriage_union") ==
             ["marriage_union_desc", "marriage_union_mechanic_tooltip"]

    assert Loc.related_keys(loc, "flavor.1") == ["flavor.1.a"]
    assert Loc.with_prefix(loc, "nothing", 5) == []
  end
end

defmodule GameBuddy.LocDefinesTest do
  use ExUnit.Case, async: true
  alias GameBuddy.Loc

  test "GetDefine calls render as the constant's value" do
    loc = Loc.new(%{}) |> Loc.with_defines(%{"NCombat.INITIATIVE_CHANCE_EACH" => 0.025})

    assert Loc.clean(
             "chance is Initiative * [GetDefine('NCombat','INITIATIVE_CHANCE_EACH')|%G] and [GetDefine('NX','MISSING')]",
             loc
           ) ==
             "chance is Initiative * 0.025 (NCombat.INITIATIVE_CHANCE_EACH) and NX.MISSING"
  end
end
