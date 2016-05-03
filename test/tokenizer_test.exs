defmodule TokenizerTest do
  use ExUnit.Case

  import Stache.Tokenizer

  test "tokenizing a double stache" do
    assert {:ok, [{:double, _, "foo"}]} = tokenize("{{foo}}")
  end

  test "tokenizing a triple stache" do
    assert {:ok, [{:triple, _, "foo"}]} = tokenize("{{{foo}}}")
  end

  test "spaces should be trimmed on identifiers" do
    assert {:ok, [{:double, _, "foo"}]} = tokenize("{{  foo  }}")
    assert {:ok, [{:triple, _, "foo"}]} = tokenize("{{{  foo   }}}")
    assert {:ok, [{:section, _, "foo"}]} = tokenize("{{#  foo }}")
    assert {:ok, [{:inverted, _, "foo"}]} = tokenize("{{^  foo  }}")
    assert {:ok, [{:partial, _, "foo"}]} = tokenize("{{>  foo }}")
    assert {:ok, [{:end, _, "foo"}]} = tokenize("{{/  foo  }}")
  end

  test "tokenizing plain text" do
    assert {:ok, [{:text, _, "foo"}]} = tokenize("foo")
  end

  test "tokenizing a simple template" do
    template = "<h1>{{name}}</h1><p>{{description}}<p>" <>
      "<h2>Here\"s an example.</h2> <pre>{{{example}}}</pre>"

    assert {:ok, [
      {:text, _, "<h1>"},
      {:double, _, "name"},
      {:text, _, "</h1><p>"},
      {:double, _, "description"},
      {:text, _, "<p><h2>Here\"s an example.</h2> <pre>"},
      {:triple, _, "example"},
      {:text, _, "</pre>"}
    ]} = tokenize(template)
  end

  test "tokeninizing a comment" do
    assert {:ok, []} = tokenize("{{! some comment }}")
    assert {:ok, [{:text, _, "foo"}, {:text, _, "bar"}]} = tokenize("foo{{! some comment }}bar")
  end

  test "a standalone comment" do
    assert {:ok, [{:text, _, "foo\n"}]} = tokenize("foo\n    {{! some comment }}")
    assert {:ok, [{:text, _, "foo\n"}]} = tokenize("foo\n{{! some comment }}     ")
    assert {:ok, [{:text, _, "\n"}]} = tokenize("\n{{! some comment }}     ")
    assert {:ok, []} = tokenize("{{! some comment }}     ")
    assert {:ok, []} = tokenize("       {{! some comment }}     ")
    assert {:ok, []} = tokenize("       {{! some comment }}\n")
  end

  test "tokeninizing a section" do
    assert {:ok, [
      {:section, _,"section"},
      {:text, _, "foo"},
      {:end, _, "section"}
    ]} = tokenize("{{#section}}foo{{/section}}")
  end

  test "tokeninizing an inverted section" do
    assert {:ok, [
      {:inverted, _, "section"},
      {:text, _, "foo"},
      {:end, _, "section"}
    ]} = tokenize("{{^section}}foo{{/section}}")
  end

  test "tokenizing a partial" do
    assert {:ok, [{:partial, _, "foo"}]} = tokenize("{{>foo}}")
  end

  test "whitespace should be preserved in plain-text" do
    assert {:ok, [
      {:text, %{line: 1}, "\n"},
      {:text, %{line: 2}, " foo bar baz   \n"},
      {:text, %{line: 3}, "\n"}
    ]} = tokenize("\n foo bar baz   \n\n")
  end

  test "line numbers are counted" do
    assert {:ok, [
      {:double, %{line: 1}, "foo"},
      {:text, %{line: 1}, "\n"},
      {:partial, %{line: 2}, "bar"},
      {:text, %{line: 2}, "\n"},
      {:triple, %{line: 3}, "baz"},
      {:text, %{line: 3}, "\n"},
      {:text, %{line: 4}, "qux"}
    ]} = tokenize("{{foo}}\n{{>bar}}\n{{{baz}}}\nqux")
  end

  test "characters consumed are counted" do
    assert {:ok, [{:text, %{pos_start: 0, pos_end: 1}, "😀"}]} = tokenize("😀")
    assert {:ok, [{:text, %{pos_start: 0, pos_end: 6}, "foobar"}]} = tokenize("foobar")
    assert {:ok, [{:double, %{pos_start: 0, pos_end: 10}, "foobar"}]} = tokenize("{{foobar}}")
    assert {:ok, [{:triple, %{pos_start: 0, pos_end: 12}, "foobar"}]} = tokenize("{{{foobar}}}")
    assert {:ok,
      [{:double, %{pos_start: 11, pos_end: 19}, "foobar"}]
    } = tokenize("{{= [ ] =}}[foobar]")

    assert {:ok, [
      {:section, %{line: 1, pos_start: 0, pos_end: 8}, "foo"},
      {:text, %{line: 2, pos_start: 9, pos_end: 11}, "  "},
      {:double, %{line: 2}, "bar"},
      {:text, %{line: 2}, "\n"},
      {:end, %{line: 3}, "foo"}
    ]} = tokenize("{{#foo}}\n  {{bar}}\n{{/foo}}\n")
  end

  test "standalone section tags" do
    assert {:ok, [{:section, _, "begin"}]} = tokenize("{{#begin}}\n")
    assert {:ok, [{:section, _, "begin"}]} = tokenize("  {{#begin}}\n")
    assert {:ok, [{:section, _, "begin"}]} = tokenize("  {{#begin}}  \n")
    assert {:ok, [{:section, _, "begin"}]} = tokenize("  {{#begin\n}}\n")

    assert {:ok, [{:inverted, _, "begin"}]} = tokenize("{{^begin}}\n")
    assert {:ok, [{:inverted, _, "begin"}]} = tokenize("  {{^begin}}\n")
    assert {:ok, [{:inverted, _, "begin"}]} = tokenize("  {{^begin}}  \n")
    assert {:ok, [{:inverted, _, "begin"}]} = tokenize("  {{^begin\n}}\n")

    assert {:ok, [{:end, _, "begin"}]} = tokenize("{{/begin}}\n")
    assert {:ok, [{:end, _, "begin"}]} = tokenize("  {{/begin}}\n")
    assert {:ok, [{:end, _, "begin"}]} = tokenize("  {{/begin}}  \n")
    assert {:ok, [{:end, _, "begin"}]} = tokenize("  {{/begin\n}}\n")
  end

  test "custom delimeters" do
    assert {:ok, [{:double, _, "foo"}]} = tokenize("{{= [ ] =}}[foo]")
    assert {:ok, [{:double, _, "foo"}]} = tokenize("[foo]", delimeters: {"[", "]"})
  end
end
