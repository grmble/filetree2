defmodule Filetree2.FilterTest do
  use ExUnit.Case, async: true

  doctest Filetree2.Filter

  alias Filetree2.Filter

  test "should ignore errors" do
    assert Filter.success?({:ok, "d/f", %{}})
    assert ! Filter.success?({:error, "d/f", :foo})
  end

  test "should do a full path regex match" do
    filter = Filter.full_path_matcher("d", Regex.compile!("f"))

    assert filter.({:ok, "d/f", %{}})
    assert filter.({:error, "", :foo})
    assert ! filter.({:ok, "D/f", %{}})
    assert ! filter.({:ok, "d/F", %{}})
  end

  test "should do a simple regex match" do
    filter = Filter.simple_matcher(Regex.compile!("f"))

    assert filter.({:ok, "x f x", %{}})
    assert filter.({:error, "", :foo})
  end

  test "should cut off leading ./" do
    assert Filter.only_path({:ok, "./x", %{}}) == "x"
    assert Filter.only_path({:ok, "x", %{}}) == "x"
  end

  test "should select regular files" do
    assert Filter.regular_file?({:ok, "./x", %{type: :regular}})
    assert !Filter.regular_file?({:ok, "x", %{type: :other}})
    assert Filter.regular_file?({:error, "", :foo})
  end

  test "should select by file type" do
    assert Filter.file_type_matcher(:regular).({:ok, "./x", %{type: :regular}})
    assert !Filter.file_type_matcher(:regular).({:ok, "x", %{type: :other}})
    assert Filter.file_type_matcher(:regular).({:error, "", :foo})
  end

  test "should compute relative ages" do
    epoch =  Filter.to_posix(0)
    y2k = Filter.to_posix(~U[2000-01-01 00:00:00.000Z])
    year = Filter.to_posix({1, :year})
    month = Filter.to_posix({1, :month})
    week = Filter.to_posix({1, :week})
    day = Filter.to_posix({1, :day})
    hour = Filter.to_posix({1, :hour})
    minute = Filter.to_posix({1, :minute})

    assert epoch == 0
    assert epoch < y2k
    assert y2k < year
    assert year < month
    assert month < week
    assert week < day
    assert day < hour
    assert hour < minute
  end

  test "should compare file mtime" do
    assert Filter.older_than(1).({:ok, "foo", %{mtime: 0}})
    assert !Filter.older_than(1).({:ok, "foo", %{mtime: 1}})
    assert Filter.older_than(1).({:error, "foo", :foo})
  end

end
