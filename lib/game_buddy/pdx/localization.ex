defmodule GameBuddy.Pdx.Localization do
  @moduledoc """
  Parses Paradox localization files. They look like YAML but are not:

      l_english:
       some_key:0 "Some text with \"quotes\" and $refs$"
       other_key: "Text"

  Returns the language (from the `l_<lang>:` header) and a list of
  `{key, value, line}`. Lines that do not match are skipped and reported.
  """

  @line_re ~r/\A\s*([^\s:#"]+):(\d*)\s*"(.*)"\s*(?:#.*)?\z/

  @spec parse(binary) ::
          {:ok, String.t() | nil, [{String.t(), String.t(), pos_integer}],
           [{pos_integer, String.t()}]}
  def parse(bin) when is_binary(bin) do
    bin = strip_bom(bin)

    {lang, entries, warnings} =
      bin
      |> String.split(~r/\r?\n/)
      |> Enum.with_index(1)
      |> Enum.reduce({nil, [], []}, fn {raw, line}, {lang, entries, warnings} ->
        text = String.trim(raw)

        cond do
          text == "" or String.starts_with?(text, "#") ->
            {lang, entries, warnings}

          lang == nil and Regex.match?(~r/\Al_\w+:\s*(#.*)?\z/, text) ->
            {text |> String.split(":") |> hd(), entries, warnings}

          true ->
            case Regex.run(@line_re, raw) do
              [_, key, _version, value] ->
                {lang, [{key, unescape(value), line} | entries], warnings}

              nil ->
                {lang, entries, [{line, "unparsed: #{String.slice(text, 0, 60)}"} | warnings]}
            end
        end
      end)

    {:ok, lang, Enum.reverse(entries), Enum.reverse(warnings)}
  end

  defp unescape(value), do: value |> String.replace("\\\"", "\"") |> String.replace("\\n", "\n")

  defp strip_bom(<<0xEF, 0xBB, 0xBF, rest::binary>>), do: rest
  defp strip_bom(bin), do: bin
end
