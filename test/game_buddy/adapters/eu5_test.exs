defmodule GameBuddy.Adapters.EU5Test do
  use ExUnit.Case, async: true
  alias GameBuddy.Adapters.EU5

  test "icon candidates follow the game's folder conventions with its default last" do
    assert EU5.icon_paths("estate_privileges", "noble_marriage_rights", %{}) == [
             "gfx/interface/icons/privileges/noble_marriage_rights.dds",
             "gfx/interface/icons/privileges/_default.dds"
           ]

    assert EU5.icon_paths("advances", "k", %{"icon" => "some_icon"}) == [
             "gfx/interface/advance/some_icon.dds",
             "gfx/interface/advance/_default.dds"
           ]

    assert EU5.icon_paths("government_reforms", "tsardom", %{}) |> hd() ==
             "gfx/interface/icons/government_reforms/illustrations/tsardom.dds"

    assert EU5.icon_paths("goods", "grain", %{}) |> hd() ==
             "gfx/interface/icons/trade_goods/icon_goods_grain.dds"

    assert EU5.icon_paths("game_concepts", "estate", %{"texture" => "location_icons/estates"}) ==
             ["gfx/interface/icons/location_icons/estates.dds"]

    assert EU5.icon_paths("cultures", "danish", %{}) == []
  end

  test "aliases are shown the way players write them" do
    alias GameBuddy.MCP.Tools.Helpers
    assert Helpers.format_alias("hearts of iron iv") == "Hearts of Iron IV"
    assert Helpers.format_alias("civ vii") == "CIV VII"
    assert Helpers.format_alias("hoi4") == "HOI4"
    assert Helpers.format_alias("europa universalis 5") == "Europa Universalis 5"
  end

  test "the theme declares textures with their 9-slice borders and text color roles" do
    theme = EU5.theme()
    assert theme["textures"]["frame"]["slice"] == 10
    assert theme["text_formats"]["roles"]["good"] == "color_green"
    assert theme["fonts"]["body"] == "Noto Serif"
  end
end
