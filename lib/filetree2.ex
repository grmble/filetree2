defmodule Filetree2 do
  @moduledoc """
  `Filetree2` high level API.

  Recursively visit all files in a directory tree
  with access to the stat struct.
  """

  alias Filetree2.Core
  alias Filetree2.Filter
  alias Filetree2.Glob

  @spec filetree(dir) :: Stream.t(Path.t()) when dir: Path.t()
  @doc """
  List the names of all files in the directory.

  If you need to filter by filename, consider `Path.wildcard/2`
  which uses `:file_lib.wildcard/2` behind the scenes.
  """
  def filetree(dir) do
    Stream.unfold(Core.init(dir), &Core.next/1)
    |> Stream.filter(&Filter.success?/1)
    |> Stream.filter(&Filter.regular_file?/1)
    |> Stream.map(&Filter.only_path/1)
  end


  @spec wildcard_stream(dir, glob) :: Stream.t(Core.entry()) when dir: Path.t(), glob: String.t() | [String.t()]
  @doc """
  Stream of file tree entries filtered by globs.

  Syntax is (somewhat) compatible to `Path.wildcard/2`
  """
  def wildcard_stream(dir, glob) when is_binary(glob), do: wildcard_stream(dir, [glob])
  def wildcard_stream(dir, glob) when is_list(glob) do
    filters = Enum.map(glob, &Filter.full_path_matcher(dir, Glob.regex!(&1)))
    Stream.unfold(Core.init(dir), &Core.next/1)
    |> Stream.filter(Filter.any_matcher(filters))
  end

  @spec wildcard(dir, glob) :: [String.t()] when dir: Path.t(), glob: String.t() | [String.t()]
  @doc """
  `Path.wildcard/2` clone using `wildcard_stream/2`

  For ease of use and to compare globbing implementations.
  """
  def wildcard(dir, glob) do
    wildcard_stream(dir, glob)
    |> Stream.filter(&Filter.success?/1)
    |> Stream.filter(&Filter.no_slashdots?/1)
    |> Stream.map(&Filter.only_path/1)
    |> Enum.sort()
  end

end
