defmodule GameBuddy.Pdx.Parser do
  @moduledoc """
  Parses a token stream from `GameBuddy.Pdx.Lexer` into an ordered AST.

  The AST is a list of statements. Each statement is a map:

    * `%{k: key, op: op, v: value, line: n}` for `key op value`
    * `%{v: value, line: n}` for a bare value inside a block (list items)

  A value is a scalar, `%{block: [statements]}`, or `%{tag: "rgb", block: [...]}`
  for typed blocks such as `rgb { 255 0 0 }`.

  Scalars are typed: `yes`/`no` become booleans, integers and decimals become
  numbers, everything else (including dates like `1337.4.1`) stays a string.
  Quoted strings are never typed.

  Duplicate keys and statement order are preserved exactly. The parser is
  lenient the way the game is: a stray `}` at top level is skipped and an
  unclosed block is closed at end of file; both are reported as warnings.
  """

  alias GameBuddy.Pdx.Lexer

  @type statement :: map
  @type warning :: {pos_integer | nil, String.t()}

  @spec parse(binary) :: {:ok, [statement], [warning]} | {:error, String.t()}
  def parse(bin) when is_binary(bin) do
    with {:ok, tokens} <- Lexer.tokenize(bin) do
      {statements, rest, warnings} = statements(tokens, 0, [], [])
      warnings = if rest == [], do: warnings, else: [{nil, "unconsumed tokens"} | warnings]
      {:ok, statements, Enum.reverse(warnings)}
    end
  end

  # depth 0 is the file level. Returns {statements, remaining_tokens, warnings}.
  defp statements([], _depth, acc, warnings), do: {Enum.reverse(acc), [], warnings}

  defp statements([{:rbrace, _} | rest], depth, acc, warnings) when depth > 0,
    do: {Enum.reverse(acc), rest, warnings}

  defp statements([{:rbrace, line} | rest], 0, acc, warnings),
    do: statements(rest, 0, acc, [{line, "stray closing brace"} | warnings])

  # key op value
  defp statements([{kind, key, line}, {:op, op, _} | rest], depth, acc, warnings)
       when kind in [:bare, :string] do
    case value(rest, depth, warnings) do
      {:ok, v, rest, warnings} ->
        statements(rest, depth, [%{k: key, op: op, v: v, line: line} | acc], warnings)

      {:eof, warnings} ->
        {Enum.reverse([%{k: key, op: op, v: nil, line: line} | acc]), [],
         [{line, "missing value at end of file"} | warnings]}
    end
  end

  # bare value or anonymous block inside a list
  defp statements([{kind, _, line} | _] = tokens, depth, acc, warnings)
       when kind in [:bare, :string, :lbrace] do
    case value(tokens, depth, warnings) do
      {:ok, v, rest, warnings} -> statements(rest, depth, [%{v: v, line: line} | acc], warnings)
      {:eof, warnings} -> {Enum.reverse(acc), [], warnings}
    end
  end

  defp statements([{:lbrace, line} | _] = tokens, depth, acc, warnings) do
    {:ok, v, rest, warnings} = value(tokens, depth, warnings)
    statements(rest, depth, [%{v: v, line: line} | acc], warnings)
  end

  # an operator with no key: skip it
  defp statements([{:op, op, line} | rest], depth, acc, warnings),
    do: statements(rest, depth, acc, [{line, "dangling operator #{op}"} | warnings])

  defp value([{:lbrace, line} | rest], depth, warnings) do
    {stmts, rest, warnings} = block(rest, depth + 1, line, warnings)
    {:ok, %{block: stmts}, rest, warnings}
  end

  defp value([{:bare, tag, _}, {:lbrace, line} | rest], depth, warnings) do
    {stmts, rest, warnings} = block(rest, depth + 1, line, warnings)
    {:ok, %{tag: tag, block: stmts}, rest, warnings}
  end

  defp value([{:bare, text, _} | rest], _depth, warnings),
    do: {:ok, type_scalar(text), rest, warnings}

  defp value([{:string, text, _} | rest], _depth, warnings), do: {:ok, text, rest, warnings}

  defp value([{:op, op, line} | rest], depth, warnings),
    do:
      value(rest, depth, [
        {line, "unexpected operator #{op} where a value was expected"} | warnings
      ])

  defp value([{:rbrace, line} | _] = rest, _depth, warnings),
    do: {:ok, nil, rest, [{line, "empty value before closing brace"} | warnings]}

  defp value([], _depth, warnings), do: {:eof, warnings}

  defp block(tokens, depth, open_line, warnings) do
    case statements(tokens, depth, [], warnings) do
      {stmts, [], warnings} when tokens != [] ->
        if closed_at_eof?(tokens),
          do: {stmts, [], warnings},
          else: {stmts, [], [{open_line, "block not closed before end of file"} | warnings]}

      {stmts, rest, warnings} ->
        {stmts, rest, warnings}
    end
  end

  # true when the block's tokens end with a matching close brace
  defp closed_at_eof?(tokens), do: match?({:rbrace, _}, List.last(tokens))

  @doc false
  def type_scalar("yes"), do: true
  def type_scalar("no"), do: false

  def type_scalar(text) do
    cond do
      Regex.match?(~r/\A-?\d+\z/, text) ->
        String.to_integer(text)

      Regex.match?(~r/\A-?(\d+\.\d*|\.\d+)\z/, text) ->
        {f, ""} =
          Float.parse(if String.starts_with?(text, "."), do: "0" <> text, else: fixup_float(text))

        f

      true ->
        text
    end
  end

  defp fixup_float(text), do: if(String.ends_with?(text, "."), do: text <> "0", else: text)
end
