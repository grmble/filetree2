defmodule Filetree2.FilterTest do
  use ExUnit.Case, async: true

  doctest Filetree2.Filter

  alias Filetree2.Filter

  test "warn errors" do
    assert Filter.success?({:ok, "d/f", %{}})
    assert ! Filter.success?({:error, "d/f", :foo})
  end

  test "full path regex match" do
    filter = Filter.full_path_matcher("d", Regex.compile!("f"))

    assert filter.({:ok, "d/f", %{}})
    assert filter.({:error, "", :foo})
    assert ! filter.({:ok, "D/f", %{}})
    assert ! filter.({:ok, "d/F", %{}})
  end

end
