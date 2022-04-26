defmodule Filetree2Test do
  use ExUnit.Case, async: true

  doctest Filetree2

  test "comparing globbing" do
    assert Path.wildcard("lib/**/*.ex") == Filetree2.wildcard(".", "lib/**/*.ex")
    assert Path.wildcard("{lib,test}/**/*.ex*") == Filetree2.wildcard(".", ["{lib,test}/**/*.ex*"])
  end

end
