defmodule GameBuddyWeb.SiteComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import GameBuddyWeb.SiteComponents

  test "button renders a link when given an href and a button otherwise" do
    assert render_component(&button/1, href: "/x", inner_block: block("Go")) =~
             ~r/<a [^>]*href="\/x"/

    assert render_component(&button/1, inner_block: block("Go")) =~ ~r/<button type="button"/
  end

  test "button forces the hover look for the design system page" do
    html = render_component(&button/1, state: "hover", inner_block: block("Go"))
    assert html =~ "bg-brand-hover"
    refute html =~ "hover:bg-brand-hover"
  end

  test "mascot draws each expression" do
    for expression <- ~w(happy wink excited curious) do
      assert render_component(&mascot/1, expression: expression) =~ "gb-mascot-#{expression}"
    end
  end

  test "game card shows the icon when given one and the tile otherwise" do
    assert render_component(&game_card/1,
             name: "G",
             slug: "eu5",
             image: "/images/games/eu5/icon.png"
           ) =~ ~s(src="/images/games/eu5/icon.png")

    refute render_component(&game_card/1, name: "G", slug: "eu5") =~ "<img"
  end

  defp block(text), do: [%{inner_block: fn _, _ -> text end}]
end
