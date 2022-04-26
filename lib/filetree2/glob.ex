defmodule Filetree2.Glob do
  import NimbleParsec

  special = [?\\, ?*, ??, ?., ?/, ?[, ?], ?,, ?{, ?}]

  not_special = Enum.map(special, &{:not, &1})

  double_asterisk = string("**") |> unwrap_and_tag(:dstar)
  asterisk = string("*") |> unwrap_and_tag(:star)
  qmark = string("?") |> unwrap_and_tag(:qmark)
  dot = string(".") |> unwrap_and_tag(:dot)
  slash = string("/") |> unwrap_and_tag(:slash)
  other = utf8_string(not_special, min: 1)

  quoted =
    ignore(string("\\"))
    |> utf8_string(special, 1)
    |> unwrap_and_tag(:quoted)

  braceword =
    [quoted, utf8_string([not: ?\\, not: ?,, not: ?}], min: 1)]
    |> choice()
    |> times(min: 1)
    |> tag(:word)

  commabracewordrepeat =
    ignore(string(","))
    |> concat(braceword)
    |> repeat()

  bracelist = braceword |> concat(commabracewordrepeat) |> tag(:braces)

  braces = ignore(string("{")) |> concat(bracelist) |> ignore(string("}"))

  @help "expected: \\*, \\?, \\., \\/, **, *, ?, ., / or something else"

  # TODO
  # {one,two}
  # [a-z,A-Z]
  # prefix** should be error too

  alternative =
    [quoted, double_asterisk, asterisk, qmark, dot, slash, braces, other]
    |> choice()
    |> label(@help)

  defparsec(:glob, empty() |> repeat(alternative) |> label(@help) |> eos())

  defp interpret(acc, [{:dstar, _} | [{:slash, _} | rest]]), do: interpret([".*/?" | acc], rest)
  defp interpret(acc, [{:dstar, _}]), do: interpret([".*" | acc], [])

  defp interpret(_, [{:dstar, _} | _]),
    do: {:error, "** only supported if followed by /"}

  defp interpret(acc, [{:star, _} | rest]), do: interpret(["[^/]*" | acc], rest)
  defp interpret(acc, [{:qmark, _} | rest]), do: interpret(["." | acc], rest)
  defp interpret(acc, [{:dot, _} | rest]), do: interpret(["\\." | acc], rest)
  defp interpret(acc, [{:slash, _} | rest]), do: interpret(["/" | acc], rest)
  defp interpret(acc, [{:quoted, code} | rest]), do: interpret([code | acc], rest)

  defp interpret(acc, [{:braces, list} | rest]),
    do: interpret([interpret_braces(list) | acc], rest)

  defp interpret(acc, [code | rest]), do: interpret([code | acc], rest)

  defp interpret(acc, []), do: {:ok, acc |> Enum.reverse()}

  defp interpret(lst), do: interpret([], lst)

  defp interpret_braces(lst) do
    [
      "(",
      lst
      |> Enum.map(&interpret_word/1)
      |> Enum.join("|"),
      ")"
    ]
  end

  # interpret already does quoted chars and string fragments
  defp interpret_word({:word, word}), do: interpret_word([], word)

  defp interpret_word(acc, [{:quoted, code} | rest]), do: interpret_word([code | acc], rest)
  defp interpret_word(acc, [code | rest]), do: interpret_word([code | acc], rest)
  defp interpret_word(acc, []), do: Enum.reverse(acc)


  def regex(glob) do
    with {:ok, scanned, _, _, _, _} <- glob(glob),
         {:ok, regex} <- interpret(scanned),
         regex = ["^", regex, "$"] |> IO.chardata_to_string(),
         {:ok, compiled} <- Regex.compile(regex) do
      {:ok, compiled}
    end
  end

  def regex!(glob) do
    {:ok, compiled} = regex(glob)
    compiled
  end
end
