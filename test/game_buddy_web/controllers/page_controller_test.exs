defmodule GameBuddyWeb.PageControllerTest do
  use GameBuddyWeb.ConnCase, async: true

  describe "GET /" do
    test "renders the landing page with its sections", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)
      doc = LazyHTML.from_document(html)

      for id <- ~w(hero features games demo how-it-works platform) do
        assert LazyHTML.query(doc, "##{id}") |> Enum.count() == 1, "missing ##{id}"
      end

      assert html =~ "Quiv"
      assert html =~ "/mcp"
      assert LazyHTML.query(doc, "[data-chat-demo]") |> Enum.count() == 1
    end

    test "opens on a dark band under a transparent header", %{conn: conn} do
      doc = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

      assert LazyHTML.query(doc, "header[data-site-header][data-theme=dark]") |> Enum.count() == 1
      assert LazyHTML.query(doc, "#hero[data-header-dark]") |> Enum.count() == 1
      # the hero and the closing call to action; the example chat sits in the hero
      assert LazyHTML.query(doc, "[data-header-dark]") |> Enum.count() == 2
    end
  end

  describe "hero_chats/1" do
    alias GameBuddyWeb.PageHTML

    test "flattens the example exchanges per game in the order given" do
      games = [%{game: %{slug: "eu5"}}, %{game: %{slug: "hoi4"}}, %{game: %{slug: "new"}}]
      chats = PageHTML.hero_chats(games)

      assert Enum.map(chats, & &1.index) == Enum.to_list(0..(length(chats) - 1))
      assert Enum.map(chats, & &1.entry.game.slug) |> Enum.dedup() == ~w(eu5 hoi4 new)

      assert Enum.count(chats, &(&1.entry.game.slug == "eu5")) ==
               length(PageHTML.example_chats("eu5"))

      for item <- chats do
        assert item.n in 1..item.count
        assert is_binary(item.chat.question) and is_binary(item.chat.answer)

        for row <- (item.chat[:card] && item.chat.card.rows) || [] do
          assert is_binary(row.text)
        end
      end
    end
  end

  describe "GET /design" do
    test "renders every section the left nav links to", %{conn: conn} do
      html = conn |> get(~p"/design") |> html_response(200)
      doc = LazyHTML.from_document(html)

      assert LazyHTML.query(doc, "#design-nav") |> Enum.count() == 1

      for {id, _label} <- GameBuddyWeb.DesignComponents.sections() do
        assert LazyHTML.query(doc, "#design-nav a[href='##{id}']") |> Enum.count() == 1
        assert LazyHTML.query(doc, "section##{id}") |> Enum.count() == 1, "missing section ##{id}"
      end
    end
  end

  test "GET / shows the example chats behind a chip strip", %{conn: conn} do
    doc = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    tabs = LazyHTML.query(doc, "#hero-games [role=tab][data-chat-tab]")
    chats = LazyHTML.query(doc, "[data-chat-stage] [data-chat]")

    # at least one exchange per chip, one dot per exchange, one of each active
    assert Enum.count(chats) >= Enum.count(tabs)
    assert Enum.count(LazyHTML.query(doc, "[data-chat-dot]")) == Enum.count(chats)
    assert Enum.count(LazyHTML.query(doc, "#hero-games [role=tab][aria-selected=true]")) <= 1
    assert Enum.count(LazyHTML.query(doc, "[data-chat-stage] [data-chat][data-active]")) <= 1
    assert Enum.count(LazyHTML.query(doc, "#hero .mascot, #hero [data-mascot]")) == 0
  end
end
