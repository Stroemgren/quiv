defmodule GameBuddy.Pdx.FormatTest do
  use ExUnit.Case, async: true
  alias GameBuddy.Pdx.Format

  test "prints statements back as script" do
    stmts = [
      %{
        "k" => "potential",
        "op" => "=",
        "v" => %{"block" => [%{"k" => "tag", "op" => "=", "v" => "DAN", "line" => 2}]},
        "line" => 1
      },
      %{
        "k" => "color",
        "op" => "=",
        "v" => %{"tag" => "rgb", "block" => [%{"v" => 1, "line" => 3}, %{"v" => 2, "line" => 3}]},
        "line" => 3
      },
      %{"k" => "major", "op" => "=", "v" => true, "line" => 4}
    ]

    assert Format.to_script(stmts) ==
             "potential = {\n\ttag = DAN\n}\ncolor = rgb { 1 2 }\nmajor = yes"

    assert Format.to_script(stmts, 10) |> String.ends_with?("… (truncated)")
  end
end
