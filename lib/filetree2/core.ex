defmodule Filetree2.Core do
  @moduledoc """
  `Filetree2` low level core.

  This uses an erlang queue as state/accumulator
  to implement a recursive file/directory tree.

  Given a queue of file names that need processing,
  the `next/1` function can be used to get the next element.
  Arguments and return types are chosen to work with
  `Stream.unfold/2`.

  It is possible to use this in a GenServer too,
  but consider `Task.async_stream/3` first.
  """

  @type acc :: :queue.queue(Path.t())
  @type entry_ok :: {:ok, Path.t(), File.Stat.t()}
  @type entry_error :: {:error, Path.t(), File.posix()}
  @type entry :: entry_ok() | entry_error()

  @spec init(path) :: acc() when path: Path.t()
  @doc """
  Create a queue with the given directory
  """
  def init(path) do
    :queue.cons(path, :queue.new())
  end

  @spec next(acc) :: {entry(), acc()} | nil when acc: acc()
  @doc """
  Find the next entry in the recursive directory tree.

  The exact order of entries is undefined, but it is garuanteed
  that directory entries will come before the files or directories they contain.
  """
  def next(acc) do
    case :queue.out(acc) do
      {{:value, path}, acc} ->
        case File.stat(path) do
          {:ok, stat} ->
            if stat.type == :directory do
              case File.ls(path) do
                {:ok, files} ->
                  # we have to use cons for preorder traversal
                  # reversing the entries gives us Root - Left - Right
                  # instead of Root - Right - Left
                  acc =
                    Enum.reduce(
                      Enum.reverse(files),
                      acc,
                      &:queue.cons(Path.join(path, &1), &2)
                    )

                  {{:ok, path, stat}, acc}

                {:error, posix} ->
                  {{:error, path, posix}, acc}
              end
            else
              {{:ok, path, stat}, acc}
            end

          {:error, posix} ->
            {{:error, path, posix}, acc}
        end

      {:empty, _} ->
        nil
    end
  end
end
