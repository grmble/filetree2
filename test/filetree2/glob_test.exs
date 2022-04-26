defmodule Filetree2.GlobTest do
  use ExUnit.Case, async: true

  doctest Filetree2.Glob

  alias Filetree2.Glob

  test "glob to regex" do
    {:ok, regex} = Glob.regex("prefix/**/*.ex")
    assert Regex.match?(regex, "prefix/dir/foo.ex")
    assert Regex.match?(regex, "prefix/foo.ex")
    assert ! Regex.match?(regex, "before/prefix/dir/foo.ex")
    assert ! Regex.match?(regex, "prefix/dir/foo.ex/after")
  end

  test "glob to regex - prefix and ** with no /" do
    {:ok, regex} = Glob.regex("prefix**/*.ex")
    assert Regex.match?(regex, "prefix/dir/foo.ex")
    assert Regex.match?(regex, "prefix/foo.ex")
    assert ! Regex.match?(regex, "before/prefix/dir/foo.ex")
    assert ! Regex.match?(regex, "prefix/dir/foo.ex/after")
  end

  test "** will match any file" do
    {:ok, regex} = Glob.regex("**")

    assert Regex.match?(regex, "d/f.ex")
    assert Regex.match?(regex, "f.ex")
    assert Regex.match?(regex, "f")
  end

  test "glob to regex - ** must be followed by /" do
    {:error, _} = Glob.regex("**suffix/*.ex")
  end

end
