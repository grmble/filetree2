defmodule Filetree2.Filter do
  @moduledoc """
  Filters for streams of directory entries.
  """

  require Logger
  alias Filetree2.Core

  @spec success?(entry) :: boolean when entry: Core.entry()
  @doc """
  Filter successful entries - error entries are logged using `Logger.warn/2` then removed from the stream.
  """
  def success?({:ok, _, _}), do: true

  def success?({:error, path, posix}) do
    Logger.warn("#{posix}: #{path}")
    false
  end

  @spec regular_file?(entry) :: boolean when entry: Core.entry()
  @doc """
  Only leave OK-entries for regular files.

  This does not touch the error entries, see `warn_errors/1`.
  or use `warn_errors/1`.
  """
  def regular_file?({:ok, _, stat}), do: stat.type == :regular

  @spec only_path(entry) :: Path.t() when entry: Core.entry()
  @doc """
  Mapper that only leaves the path.

  Remove `:ok | :error` and `File.Stat.t() | File.posix()`.

  Also removes a `./` prefix so output is identical to `Path.wildcard/1`
  """
  def only_path({_, path, _}) do
    if String.starts_with?(path, "./") do
      String.slice(path, 2, String.length(path) - 2)
    else
      path
    end
  end

  @spec any_matcher(filters) :: (Core.entry() -> boolean) when filters: Enumerable.t()
  @doc """
  Filter that returns true when any its sub-filters is true.
  """
  def any_matcher(filters) do
    fn entry -> Enum.any?(filters, fn f -> f.(entry) end) end
  end

  @doc """
  Matcher that filters based upon a regex match on the full path (with the base directory prefixed!)
  """
  def full_path_matcher(dir, regex) do
    fn
      {:ok, path, _} ->
        if String.starts_with?(path, dir) do
          p2 = String.slice(path, String.length(dir) + 1, String.length(path))
          Regex.match?(regex, p2)
        else
          false
        end

      _ ->
        true
    end
  end

  @doc """
  Simple regex matcher - for regexes that only do a partial match
  """
  def simple_matcher(regex) do
    fn
      {:ok, path, _} -> Regex.match?(regex, path)
      _ -> true
    end
  end

  def no_slashdots?({:ok, path, _}), do: !Regex.match?(~R"/\.", path)
  def no_slashdots?(_), do: true

end
