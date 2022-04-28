defmodule Filetree2 do
  @moduledoc """
  `Filetree2` high level API.

  Recursively visit all files in a directory tree
  with access to the stat struct.
  """

  alias Filetree2.Core
  alias Filetree2.Filter
  alias Filetree2.Glob

  @type options :: [
          error: :ignore | :keep,
          dotfiles: :ignore | :keep,
          type: :device | :directory | :regular | :other | :symlink | nil,
          older_than: DateTime.t() | integer() | Filter.age() | nil,
          match: Regex.t() | nil,
        ]

  @default_options [error: :ignore, dotfiles: :ignore]

  @spec stream(dir, opts) :: Stream.t(Core.entry()) when dir: Path.t(), opts: options()
  @doc """
  Recursively stream over the directory entries
  """
  def stream(dir, opts \\ @default_options) do
    opts = Keyword.merge(@default_options, opts)
    type = Keyword.get(opts, :type)
    older_than = Keyword.get(opts, :older_than)
    regex = Keyword.get(opts, :match)

    Stream.unfold(Core.init(dir), &Core.next/1)
    |> Filter.cfilter(Keyword.get(opts, :error) == :ignore, &Filter.success?/1)
    |> Filter.cfilter(type !== nil, Filter.file_type_matcher(type))
    |> Filter.cfilter(Keyword.get(opts, :dotfiles) == :ignore, &Filter.no_slashdots?/1)
    |> Filter.cfilter(older_than !== nil, Filter.older_than(older_than))
    |> Filter.cfilter(regex !== nil, Filter.simple_matcher(regex))
  end

  @spec filetree(dir, opts) :: Stream.t(Path.t()) when dir: Path.t(), opts: options()
  @doc """
  List the names of all files in the directory.

  If you need to filter by filename, consider `Path.wildcard/2`
  which uses `:file_lib.wildcard/2` behind the scenes.
  """
  def filetree(dir, opts \\ @default_options) do
    stream(dir, opts)
    |> Stream.map(&Filter.only_path/1)
  end

  @spec wildcard_stream(dir, glob, opts) :: Stream.t(Core.entry())
        when dir: Path.t(),
             glob: String.t() | [String.t()],
             opts: options()
  @doc """
  Stream of file tree entries filtered by globs.

  Syntax is (somewhat) compatible to `Path.wildcard/2`
  """
  def wildcard_stream(dir, glob, opts \\ @default_options)

  def wildcard_stream(dir, glob, opts) when is_binary(glob),
    do: wildcard_stream(dir, [glob], opts)

  def wildcard_stream(dir, glob, opts) when is_list(glob) do
    filters = Enum.map(glob, &Filter.full_path_matcher(dir, Glob.regex!(&1)))

    stream(dir, opts)
    |> Stream.filter(Filter.any_matcher(filters))
  end

  @spec wildcard(dir, glob, opts) :: [String.t()]
        when dir: Path.t(),
             glob: String.t() | [String.t()],
             opts: options()
  @doc """
  `Path.wildcard/2` clone using `wildcard_stream/3`

  For ease of use and to compare globbing implementations.
  """
  def wildcard(dir, glob, opts \\ @default_options) do
    wildcard_stream(dir, glob, opts)
    |> Stream.map(&Filter.only_path/1)
    |> Enum.sort()
  end

  @spec empty_dirs(dir, opts) :: list(Path.t()) when dir: Path.t(), opts: options()
  @doc """
  List of empty directories.

  If you use `dotfiles :ignore` you may get false positives.
  """
  def empty_dirs(dir, opts \\ [error: :ignore, dotfiles: :keep]) do
    counts =
      stream(dir, opts)
      |> Enum.reduce(%{}, &increment_counts/2)

    paths =
      Map.keys(counts)
      |> Enum.sort()
      # so entries come before containers
      |> Enum.reverse()

    Enum.filter(paths, &(Map.get(counts, &1) == 0))
  end

  @spec empty_dirs2(dir, opts) :: list(Path.t()) when dir: Path.t(), opts: options()
  @doc """
  List of empty directories and directories containing only empty directories.

  The paths are returned in descending order, so they can be removed as is.

  If you use `dotfiles :ignore` you may get false positives.
  """
  def empty_dirs2(dir, opts \\ [error: :ignore, dotfiles: :keep]) do
    counts =
      stream(dir, opts)
      |> Enum.reduce(%{}, &increment_counts/2)

    paths =
      Map.keys(counts)
      |> Enum.sort()
      # so entries come before containers
      |> Enum.reverse()

    {_, result} =
      Enum.reduce(paths, {counts, []}, fn path, {acc, result} ->
        count = Map.get(acc, path)

        dir = Path.dirname(path)

        if count == 0 && dir !== "." do
          {Map.update!(acc, dir, &(&1 - 1)), [path | result]}
        else
          {acc, result}
        end
      end)

    Enum.reverse(result)
  end

  defp increment_counts({:ok, path, %File.Stat{:type => :directory}}, acc = %{}) do
    acc
    |> Map.update(path, 0, & &1)
    |> increment_parent_count(path)
  end

  defp increment_counts({:ok, path, _}, acc = %{}), do: increment_parent_count(acc, path)

  defp increment_parent_count(acc = %{}, path) do
    dir = Path.dirname(path)
    Map.update(acc, dir, 1, &(&1 + 1))
  end
end
