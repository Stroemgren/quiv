defmodule GameBuddy.Pdx.Lexer do
  @moduledoc """
  Tokenizer for Paradox (Clausewitz / Jomini) script files.

  Produces a flat list of tokens, each carrying its line number:

    * `{:lbrace, line}` / `{:rbrace, line}`
    * `{:op, "=" | "==" | "!=" | "<" | ">" | "<=" | ">=" | "?=", line}`
    * `{:string, text, line}` for double-quoted strings (quotes stripped, `\\"` unescaped)
    * `{:bare, text, line}` for any other run of characters

  Comments (`#` to end of line) and whitespace are dropped. A UTF-8 BOM is stripped.
  No game knowledge lives here.
  """

  @type token ::
          {:lbrace, pos_integer}
          | {:rbrace, pos_integer}
          | {:op, String.t(), pos_integer}
          | {:string, String.t(), pos_integer}
          | {:bare, String.t(), pos_integer}

  @spec tokenize(binary) :: {:ok, [token]} | {:error, String.t()}
  def tokenize(bin) when is_binary(bin) do
    bin |> strip_bom() |> lex(1, [])
  end

  defp strip_bom(<<0xEF, 0xBB, 0xBF, rest::binary>>), do: rest
  defp strip_bom(bin), do: bin

  defp lex(<<>>, _line, acc), do: {:ok, Enum.reverse(acc)}
  defp lex(<<"\n", rest::binary>>, line, acc), do: lex(rest, line + 1, acc)

  defp lex(<<c, rest::binary>>, line, acc) when c in [?\s, ?\t, ?\r, ?\f, ?\v],
    do: lex(rest, line, acc)

  defp lex(<<"#", rest::binary>>, line, acc), do: lex(skip_comment(rest), line, acc)
  defp lex(<<"{", rest::binary>>, line, acc), do: lex(rest, line, [{:lbrace, line} | acc])
  defp lex(<<"}", rest::binary>>, line, acc), do: lex(rest, line, [{:rbrace, line} | acc])

  for op <- ~w(?= == != <= >= = < >) do
    defp lex(<<unquote(op), rest::binary>>, line, acc),
      do: lex(rest, line, [{:op, unquote(op), line} | acc])
  end

  defp lex(<<"\"", rest::binary>>, line, acc) do
    case read_string(rest, line, []) do
      {:ok, text, rest, end_line} -> lex(rest, end_line, [{:string, text, line} | acc])
      {:error, reason} -> {:error, reason}
    end
  end

  defp lex(bin, line, acc) do
    {text, rest} = read_bare(bin, [])
    lex(rest, line, [{:bare, text, line} | acc])
  end

  # Leaves the newline in place so the caller counts it.
  defp skip_comment(<<"\n", _::binary>> = rest), do: rest
  defp skip_comment(<<_, rest::binary>>), do: skip_comment(rest)
  defp skip_comment(<<>>), do: <<>>

  defp read_string(<<"\\\"", rest::binary>>, line, acc), do: read_string(rest, line, [?" | acc])

  defp read_string(<<"\"", rest::binary>>, line, acc),
    do: {:ok, acc |> Enum.reverse() |> to_string(), rest, line}

  defp read_string(<<"\n", rest::binary>>, line, acc),
    do: read_string(rest, line + 1, [?\n | acc])

  defp read_string(<<c::utf8, rest::binary>>, line, acc), do: read_string(rest, line, [c | acc])

  defp read_string(<<>>, line, _acc),
    do: {:error, "unterminated string starting near line #{line}"}

  # A bare token runs until whitespace, a brace, a quote, a comment, or an operator.
  # `?` and `!` only terminate a token when they begin `?=` / `!=`.
  defp read_bare(<<c, _::binary>> = rest, acc)
       when c in [?\s, ?\t, ?\r, ?\n, ?\f, ?\v, ?{, ?}, ?", ?#, ?=, ?<, ?>],
       do: {acc |> Enum.reverse() |> to_string(), rest}

  defp read_bare(<<"?=", _::binary>> = rest, acc),
    do: {acc |> Enum.reverse() |> to_string(), rest}

  defp read_bare(<<"!=", _::binary>> = rest, acc),
    do: {acc |> Enum.reverse() |> to_string(), rest}

  defp read_bare(<<c::utf8, rest::binary>>, acc), do: read_bare(rest, [c | acc])
  defp read_bare(<<>>, acc), do: {acc |> Enum.reverse() |> to_string(), <<>>}
end
