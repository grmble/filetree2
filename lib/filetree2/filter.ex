defmodule Filetree2.Filter do
  @moduledoc """
  Filters for streams of directory entries.
  """

  require Logger
  alias Filetree2.Core

  @spec cfilter(stream, condition, filter) :: Stream.t(Core.entry())
        when stream: Stream.t(Core.entry()),
             condition: boolean(),
             filter: (Path.t() -> boolean)
  @doc """
  Helper for conditional filtering, e.g. based on  keyword options
  """
  def cfilter(stream, condition, filter) do
    if condition do
      Stream.filter(stream, filter)
    else
      stream
    end
  end

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

  This does not touch the error entries, see `success?/1`.
  """
  def regular_file?({:ok, _, stat}), do: stat.type == :regular
  def regular_file?(_), do: true

  @spec file_type_matcher(type) :: (Core.entry() -> boolean)
        when type: :device | :directory | :regular | :other | :symlink
  def file_type_matcher(type) do
    fn
      {:ok, _, stat} -> stat.type == type
      _ -> true
    end
  end

  @spec only_path(entry) :: Path.t() when entry: Core.entry()
  @doc """
  Mapper that only leaves the path.

  This is not defined for error entries - filter them out before using `&success?/1`
  or handle the error in some way.
  """
  def only_path({:ok, path, _}) do
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

  @spec no_slashdots?(Core.entry()) :: boolean
  @doc """
  Remove files with leading dots from the stream.
  """
  def no_slashdots?({:ok, path, _}), do: !Regex.match?(~R"/\.", path)
  def no_slashdots?(_), do: true


  @type age_unit :: :minute | :hour | :day | :week | :month | :year
  @type age :: {integer(), age_unit()}

  @spec older_than(dt) :: (Core.entry() -> boolean) when dt: DateTime.t() | integer() | age()
  @doc """
  Select files or directories with an mtime < the given date.
  """
  def older_than(dt) do
    fn
      {:ok, _, stat} -> to_posix(stat.mtime) < to_posix(dt)
      _ -> true
    end
  end

  @spec to_posix(dt) :: integer() when dt: DateTime.t() | {{integer(), integer(), integer()}, {integer(), integer(), integer()}} | integer() | age()
  def to_posix(dt = %DateTime{}), do: DateTime.to_unix(dt)
  def to_posix(dt) when is_integer(dt), do: dt
  def to_posix({n, :minute}), do: now() - n*60
  def to_posix({n, :hour}), do: now() - n*3600
  def to_posix({n, :day}), do: now() - n*3600*24
  def to_posix({n, :week}), do: now() - n*3600*24*7
  def to_posix({n, :month}), do: now() - n*3600*24*30
  def to_posix({n, :year}), do: now() - n*3600*24*365

  def to_posix({{year, month, day}, {hour, minute, second}}) do
    date = Date.new!(year, month, day)
    time = Time.new!(hour, minute, second)
    DateTime.new!(date, time) |> DateTime.to_unix()
  end

  defp now(), do: System.os_time(:second)

end
