defmodule UtilTest do
  use ExUnit.Case

  test "html escaping" do
    assert Stache.Util.escape_html("<h1> \"Some Text\" & Others </h1>")
      == "&lt;h1&gt; &quot;Some Text&quot; &amp; Others &lt;/h1&gt;"
  end
end
