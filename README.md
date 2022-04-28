# Filetree2

Recursively read directory entries, producing a stream of files and directories.

* Can filter by `Path.wildcard/1` style globs
* Can filter by modification time / file age

## Examples

Cleaning old files out of a local maven repository:

```elixir
    Filetree2.filetree(dir,
      type: :regular,
      dotfiles: :keep,
      match: ~R/SNAPSHOT/,
      older_than: {2, :month}
    )
    |> Enum.each(&File.rm(&1))
```

Deleting all empty directories (including parent directories containg only empty directories):

```elixir
    Filetree2.empty_dirs2(dir)
    |> Enum.each(&File.rmdir/1)
```

Deleting all empty files:

```elixir
    Filetree2.stream(dir, type: :regular, dotfiles: :keep)
    |> Stream.filter(fn {:ok, _, stat} -> stat.size == 0 end)
    |> Stream.map(&Filter.only_path/1)
    |> Enum.each(&File.rm/1)
```

## Installation

NOT IN HEX (YET)


IGNORE

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `filetree2` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:filetree2, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/filetree2>.