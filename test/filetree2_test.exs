defmodule Filetree2Test do
  use ExUnit.Case, async: true

  doctest Filetree2

  test "should glob like Path.wildcard" do
    assert Path.wildcard("lib/**/*.ex") == Filetree2.wildcard(".", "lib/**/*.ex")

    assert Path.wildcard("{lib,test}/**/*.ex*") ==
             Filetree2.wildcard(".", ["{lib,test}/**/*.ex*"])

    assert Path.wildcard("[a-l]*/**/*.ex") == Filetree2.wildcard(".", "[a-l]*/**/*.ex")
  end

  test "should produce an error" do
    assert_raise FunctionClauseError, fn ->
      Filetree2.filetree("DIR_DOES_NOT_EXIST", error: :keep)
      |> Enum.to_list()
    end
  end

  test "should produce an empty list" do
    result =
      Filetree2.filetree("DIR_DOES_NOT_EXIST", error: :ignore)
      |> Enum.to_list()

    assert Enum.empty?(result)
  end

  describe "with empty dirs" do
    File.mkdir("test/empty_parent")
    File.mkdir("test/empty_parent/.hidden")
    File.mkdir("test/empty_parent/visible")

    test "should produce empty filetree" do
      assert Enum.empty?(Filetree2.filetree("test/empty_parent", type: :regular))
    end

    test "should produce list of empty directories" do
      dirs = Filetree2.empty_dirs("test/empty_parent")
      assert dirs == ["test/empty_parent/visible", "test/empty_parent/.hidden"]
    end

    test "should produce list of soon-to-be-empty parent directory" do
      dirs = Filetree2.empty_dirs2("test")

      assert dirs == [
               "test/empty_parent/visible",
               "test/empty_parent/.hidden",
               "test/empty_parent"
             ]
    end

    test "should not include call directory in empty_dirs result" do
      dirs = Filetree2.empty_dirs("test/empty_parent/visible")
      assert dirs == []
    end

    test "should not include call directory in empty_dirs2 result" do
      dirs = Filetree2.empty_dirs2("test/empty_parent/visible")
      assert dirs == []
    end

    test "should match the regex" do
      matches =
        Filetree2.filetree(".", match: ~R/core\.ex$/)
        |> Enum.to_list()

      assert matches == ["lib/filetree2/core.ex"]
    end
  end
end
