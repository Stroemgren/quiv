defmodule GameBuddy.Render.DocumentTest do
  use ExUnit.Case, async: true
  alias GameBuddy.Loc
  alias GameBuddy.Render.{Document, Script}

  test "renders the sections of an entity document" do
    loc =
      Loc.new(%{
        "MODIFIER_TYPE_NAME_discipline" => "Discipline",
        "COUNTRYTAG_TRIGGER" => "Is $NAME$"
      })

    labels = fn t -> [t, "MODIFIER_TYPE_NAME_#{t}"] end

    t =
      Script.new(
        triggers: %{"tag" => %{"global" => "COUNTRYTAG_TRIGGER"}},
        modifiers: %{"discipline" => %{"percent" => true}},
        icons: %{"discipline" => "gfx/interface/icons/modifier_types/discipline.dds"},
        loc: Loc.with_labels(loc, labels),
        labels: labels
      )

    entity = %{
      kind: "estate_privileges",
      key: "x_priv",
      name: "X Privilege",
      description: "Flavour.",
      texts: [{"x_priv_tooltip", "Attached tooltip text here."}],
      data: %{
        "potential" => %{"tag" => "MOR"},
        "country_modifier" => %{"discipline" => 0.05},
        "estate" => "tribes_estate"
      },
      ast: %{
        "statements" => [%{"k" => "estate", "op" => "=", "v" => "tribes_estate", "line" => 2}]
      },
      source_file: "common/estate_privileges/x.txt",
      source_line: 1,
      dlc: nil,
      icon: "gfx/interface/icons/privileges/x_priv.dds"
    }

    conn = %{
      references: %{"estates" => [{"tribes_estate", "Tribes"}]},
      referenced_by: %{"advances" => {2, [{"a1", "Adv 1"}, {"a2", nil}]}}
    }

    doc = Document.render(entity, t, conn, %{game: "Game", version: "v1", dlcs: []})

    assert doc =~ "# X Privilege\n`estate_privileges` · key `x_priv` · Game v1"
    assert doc =~ "Flavour."
    assert doc =~ "- tooltip: Attached tooltip text here."
    assert doc =~ "## Conditions\n### Potential\n- Is MOR"
    assert doc =~ "## Effects\n### Country modifier\n- Discipline +5%"
    assert doc =~ "## Properties\n- Estate: tribes_estate"
    assert doc =~ "- References estates: Tribes (tribes_estate)"
    assert doc =~ "- Referenced by advances (2): Adv 1 (a1), a2"
    assert doc =~ "## Script\n```\nestate = tribes_estate\n```"

    # the file path is the last line, labelled, and nowhere else
    refute doc =~ "Source:"

    assert String.ends_with?(
             doc,
             "```\n\nSource file: `common/estate_privileges/x.txt:1` (internal, not for the player)"
           )

    # the structured form prints to the same markdown and carries the parts
    sections = Document.build(entity, t, conn, %{game: "Game", version: "v1", dlcs: []})
    assert Document.to_markdown(sections) == doc
    assert sections["name"] == "X Privilege"
    assert sections["icon"] == "gfx/interface/icons/privileges/x_priv.dds"
    refute doc =~ "gfx/"
    assert sections["texts"] == [%{"label" => "tooltip", "text" => "Attached tooltip text here."}]

    assert sections["conditions"] == [
             %{"title" => "Potential", "lines" => [%{"depth" => 0, "text" => "Is MOR"}]}
           ]

    assert sections["effects"] == [
             %{
               "title" => "Country modifier",
               "lines" => [
                 %{
                   "depth" => 0,
                   "text" => "Discipline +5%",
                   "label" => "Discipline",
                   "value" => "+5%",
                   "tone" => "good",
                   "icon" => "gfx/interface/icons/modifier_types/discipline.dds"
                 }
               ]
             }
           ]

    assert sections["properties"] == [%{"depth" => 0, "text" => "Estate: tribes_estate"}]

    assert sections["connections"]["referenced_by"] == [
             %{
               "kind" => "advances",
               "count" => 2,
               "items" => [%{"key" => "a1", "name" => "Adv 1"}, %{"key" => "a2", "name" => nil}]
             }
           ]

    assert sections["script"] == "estate = tribes_estate"
    assert sections["source"] == "common/estate_privileges/x.txt:1"
  end
end
