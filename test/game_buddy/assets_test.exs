defmodule GameBuddy.AssetsTest do
  use ExUnit.Case, async: true
  alias GameBuddy.Assets

  test "text colors come from the default formatting block, not the color-blind variants" do
    file =
      Path.join(System.tmp_dir!(), "textformatting_#{System.unique_integer([:positive])}.gui")

    File.write!(file, """
    textformatting = {
    \tcolor_blind_mode = deuteranopia
    \tformat = {
    \t\tname = color_green
    \t\tformat = "color:{ 0.75, 0.93, 0 }"
    \t}
    }

    textformatting = {
    \tformat = {
    \t\tname = color_green
    \t\tformat = "color:{0.35,0.83,0.41};glow_color:{0.0,0.0,0.0,0.5}"
    \t}
    \tformat = {
    \t\tname = color_white
    \t\tformat = "color:{0.94, 0.92, 0.85 }"
    \t}
    }
    """)

    assert Assets.text_colors(file, %{
             "good" => "color_green",
             "text" => "color_white",
             "x" => "nope"
           }) ==
             %{"good" => "#59d469", "text" => "#f0ebd9"}

    File.rm!(file)
  end

  test "data URIs carry the mime type" do
    assert Assets.data_uri("image/webp", "abc") == "data:image/webp;base64,YWJj"
  end
end
