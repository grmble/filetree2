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

  test "** will match any file" do
    {:ok, regex} = Glob.regex("**")

    assert Regex.match?(regex, "d/f.ex")
    assert Regex.match?(regex, "f.ex")
    assert Regex.match?(regex, "f")
  end

  test "glob to regex - ** must be followed by /" do
    {:error, error} = Glob.regex("**suffix/*.ex")

    assert String.contains?(error, "followed by /")

    {:error, error} = Glob.regex("asdf/**ex/*.ex")
    assert String.contains?(error, "followed by /")

    {:error, error} = Glob.regex("[a-l]*/**ex")
    assert String.contains?(error, "followed by /")

    {:error, error} = Glob.regex("[a-l]*/**.ex")
    assert String.contains?(error, "followed by /")

  end

  test "glob to regex - ** must be preceded by /" do
    {:ok, regex} = Glob.regex("prefix/**/*.ex")
    assert Regex.match?(regex, "prefix/dir/foo.ex")

    {:error, error} = Glob.regex("prefix**/*.ex")
    assert String.contains?(error, "preceded by /")
  end

  test "glob to regex - must not start with /" do
    {:error, error} = Glob.regex("/*.ex")
    assert String.contains?(error, "not start with /")
  end


  test "glob with braces" do
    {:ok, regex} = Glob.regex("{lib,test}/**/*.ex*")

    assert Regex.match?(regex, "lib/foo.ex")
    assert Regex.match?(regex, "test/foo_test.exs")
  end

  test "glob with brackets" do
    {:ok, regex} = Glob.regex("[a-zA-Z]*.ex")

    assert Regex.match?(regex, "a.ex")
    assert Regex.match?(regex, "Z.ex")
    assert ! Regex.match?(regex, "0.ex")
  end

  test "glob with question mark" do
    {:ok, regex} = Glob.regex("**/.ex?")

    assert Regex.match?(regex, "foo.exs")
  end

  test "glob with quoted character" do
    {:ok, regex} = Glob.regex("**/\\.gitignore")

    assert Regex.match?(regex, ".gitignore")
  end


end
