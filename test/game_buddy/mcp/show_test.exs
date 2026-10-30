defmodule GameBuddy.MCP.Tools.ShowTest do
  use ExUnit.Case, async: true
  alias GameBuddy.MCP.Tools.Show

  defp entity(n) do
    %{
      "name" => "E#{n}",
      "kind" => "k",
      "key" => "e#{n}",
      "script" => String.duplicate("s", 30_000),
      "properties" => for(i <- 1..2000, do: %{"depth" => 0, "text" => "p#{i}"}),
      "conditions" => [
        %{"title" => "Allow", "lines" => for(i <- 1..60, do: %{"depth" => 0, "text" => "c#{i}"})}
      ],
      "effects" => [],
      "connections" => %{
        "references" => [
          %{
            "kind" => "x",
            "count" => 30,
            "items" => for(i <- 1..25, do: %{"key" => "x#{i}", "name" => nil})
          }
        ],
        "referenced_by" => []
      }
    }
  end

  test "a small payload is left alone" do
    s = %{"entities" => [entity(1) |> Map.put("script", "tiny")], "missing" => []}
    assert Show.slim(s) == s
  end

  test "a large payload is trimmed in steps until it fits" do
    s = %{"entities" => for(n <- 1..6, do: entity(n)), "missing" => []}
    out = Show.slim(s)
    assert byte_size(Jason.encode!(out)) <= 100_000
    [e | _] = out["entities"]
    refute Map.has_key?(e, "script")
    assert length(e["properties"]) == 20 and e["properties_cut"] == 1980
    # later steps only run while the payload is still too large
    assert length(hd(e["conditions"])["lines"]) == 60
    assert e["name"] == "E1"
  end

  test "assets are attached in priority order within the budget" do
    theme = %{"textures" => %{"frame" => %{"asset" => "t/frame.dds"}}}

    structured = %{
      "entities" => [
        %{
          "icon" => "i/a.dds",
          "effects" => [%{"lines" => [%{"icon" => "m/x.dds"}, %{"icon" => "m/y.dds"}]}]
        },
        %{"icon" => "i/b.dds", "effects" => []}
      ],
      "missing" => []
    }

    order = Show.asset_paths(structured, theme)
    assert order == ["t/frame.dds", "i/a.dds", "i/b.dds", "m/x.dds", "m/y.dds"]

    found = Map.new(order, &{&1, {"image/webp", String.duplicate("x", 30)}})
    # each data URI is 63 bytes: the frame, both entity icons and one modifier icon fit
    out = Show.with_assets(structured, theme, found, order, 260)

    assert Map.keys(out["assets"]) |> Enum.sort() == [
             "i/a.dds",
             "i/b.dds",
             "m/x.dds",
             "t/frame.dds"
           ]

    assert out["theme"] == theme
    assert out["assets"]["i/a.dds"] =~ ~r/^data:image\/webp;base64,/

    # nothing stored: no keys added
    refute Map.has_key?(Show.with_assets(structured, nil, %{}, order), "assets")
  end
end
