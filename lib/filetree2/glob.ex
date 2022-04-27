defmodule Filetree2.Glob do
  import NimbleParsec

  special = [?\\, ?*, ??, ?., ?/, ?[, ?], ?,, ?{, ?}, ?[, ?]]

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

  # bracket contents is just forwarded to regexp
  bracketword =
    [quoted, utf8_string([not: ?\\, not: ?]], min: 1)]
    |> choice()
    |> times(min: 1)
    |> tag(:brackets)

  brackets = ignore(string("[")) |> concat(bracketword) |> ignore(string("]"))

  @help "expected: \\*, \\?, \\., \\/, **, *, ?, ., / or something else"

  alternative =
    [quoted, double_asterisk, asterisk, qmark, dot, slash, braces, brackets, other]
    |> choice()
    |> label(@help)

  defparsec(:glob, empty() |> repeat(alternative) |> label(@help) |> eos())

  defp check([{:dstar, _} | [{:slash, _} | rest]]), do: check(rest)
  defp check([{:slash, _} | rest = [{:dstar, _} | _]]), do: check(rest)
  defp check([{:dstar, _}]), do: check([])
  defp check([]), do: {:ok, "ok"}

  defp check([{:dstar, _} | _]),
    do: {:error, "** only supported if followed by /"}

  defp check([_ | [{:dstar, _} | _]]),
    do: {:error, "** only supported if preceded by /"}

  defp check([_ | rest]), do: check(rest)

  defp check_glob(glob) do
    case hd(glob) do
      {:slash, _} -> {:error, "glob must not start with /"}
      _ -> check(glob)
    end
  end

  defp interpret_glob(lst) do
    result = interpret(lst)
    IO.chardata_to_string(["^", result, "$"])
  end

  defp interpret(acc, [{:dstar, _} | [{:slash, _} | rest]]), do: interpret([".*/?" | acc], rest)
  defp interpret(acc, [{:dstar, _}]), do: interpret([".*" | acc], [])
  defp interpret(acc, [{:star, _} | rest]), do: interpret(["[^/]*" | acc], rest)
  defp interpret(acc, [{:qmark, _} | rest]), do: interpret(["." | acc], rest)
  defp interpret(acc, [{:dot, _} | rest]), do: interpret(["\\." | acc], rest)
  defp interpret(acc, [{:slash, _} | rest]), do: interpret(["/" | acc], rest)
  defp interpret(acc, [{:quoted, code} | rest]), do: interpret([code | acc], rest)

  defp interpret(acc, [{:braces, list} | rest]),
    do: interpret([interpret_braces(list) | acc], rest)

  defp interpret(acc, [{:brackets, list} | rest]),
    do: interpret([["[", interpret(list), "]"] | acc], rest)

  defp interpret(acc, [code | rest]), do: interpret([code | acc], rest)
  defp interpret(acc, []), do: acc |> Enum.reverse()

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

  defp interpret_word({:word, word}), do: interpret(word)

  def regex(glob) do
    with {:ok, scanned, _, _, _, _} <- glob(glob),
         {:ok, _} <- check_glob(scanned),
         regex = interpret_glob(scanned),
         {:ok, compiled} <- Regex.compile(regex) do
      {:ok, compiled}
    end
  end

  @spec regex!(String.t()) :: Regex.t()
  def regex!(glob) do
    {:ok, compiled} = regex(glob)
    compiled
  end
end
