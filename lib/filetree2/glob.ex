defmodule Filetree2.Glob do
  import NimbleParsec

  defp qual(arg, qualifier) do
    {qualifier, arg}
  end

  defp const(_, qualifier) do
    qualifier
  end

  special = [?\\, ?*, ??, ?., ?/]
  not_special = Enum.map(special, &{:not, &1})

  quoted = ignore(string("\\")) |> utf8_char(special) |> map({:qual, [:quoted]})
  double_asterisk = string("**") |> map({:const, [:double_asterisk]})
  asterisk = string("*") |> map({:const, [:asterisk]})
  qmark = string("?") |> map({:const, [:qmark]})
  dot = string(".") |> map({:const, [:dot]})
  slash = string("/") |> map({:const, [:slash]})
  other = utf8_char(not_special)

  @help "expected: \\*, \\?, \\., \\/, **, *, ?, ., / or something else"

  # TODO
  # {one,two}
  # [a-z,A-Z]
  # prefix** should be error too

  alternative =
    choice([quoted, double_asterisk, asterisk, qmark, dot, slash, other])
    |> label(@help)

  defparsecp(:glob, empty() |> repeat(alternative) |> label(@help) |> eos())

  defp interpret(acc, [:double_asterisk | [:slash | rest]]), do: interpret([".*/?" | acc], rest)
  defp interpret(acc, [:double_asterisk]), do: interpret([".*" | acc], [])

  defp interpret(_, [:double_asterisk | _]),
    do: {:error, "** only supported if followed by /"}

  defp interpret(acc, [:asterisk | rest]), do: interpret(["[^/]*" | acc], rest)
  defp interpret(acc, [:qmark | rest]), do: interpret(["." | acc], rest)
  defp interpret(acc, [:dot | rest]), do: interpret(["\\." | acc], rest)
  defp interpret(acc, [:slash | rest]), do: interpret(["/" | acc], rest)
  defp interpret(acc, [{:quoted, code} | rest]), do: interpret([code | acc], rest)
  defp interpret(acc, [code | rest]), do: interpret([code | acc], rest)

  defp interpret(acc, []), do: {:ok, ["$" | acc] |> Enum.reverse() |> IO.chardata_to_string()}

  defp interpret(lst), do: interpret(["^"], lst)

  def regex(glob) do
    with {:ok, scanned, _, _, _, _} <- glob(glob),
         {:ok, regex} <- interpret(scanned),
         {:ok, compiled} <- Regex.compile(regex) do
      {:ok, compiled}
    end
  end

  def regex!(glob) do
    {:ok, compiled} = regex(glob)
    compiled
  end
end
