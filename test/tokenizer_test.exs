defmodule TokenizerTest do
  use ExUnit.Case

  import Stache.Tokenizer

  test "tokenizing a double stache" do
    assert tokenize("{{foo}}") == [{:double, 1, "foo"}]
  end

  test "tokenizing a triple stache" do
    assert tokenize("{{{foo}}}") == [{:triple, 1, "foo"}]
  end

  test "spaces should be trimmed on identifiers" do
    assert tokenize("{{  foo  }}") == [{:double, 1, "foo"}]
    assert tokenize("{{{  foo   }}}") == [{:triple, 1, "foo"}]
    assert tokenize("{{#  foo }}") == [{:section, 1, "foo"}]
    assert tokenize("{{^  foo  }}") == [{:inverted, 1, "foo"}]
    assert tokenize("{{>  foo }}") == [{:partial, 1, "foo"}]
    assert tokenize("{{/  foo  }}") == [{:end, 1, "foo"}]
  end

  test "tokenizing plain text" do
    assert tokenize("foo") == [{:text, 1, "foo"}]
  end

  test "tokenizing a simple template" do
    template = "<h1>{{name}}</h1><p>{{description}}<p>" <>
      "<h2>Here\"s an example.</h2> <pre>{{{example}}}</pre>"

    assert tokenize(template) == [
      {:text, 1, "<h1>"},
      {:double, 1, "name"},
      {:text, 1, "</h1><p>"},
      {:double, 1, "description"},
      {:text, 1, "<p><h2>Here\"s an example.</h2> <pre>"},
      {:triple, 1, "example"},
      {:text, 1, "</pre>"}
    ]
  end

  test "tokeninizing a comment" do
    assert tokenize("{{! some comment }}") == []
    assert tokenize("foo{{! some comment }}bar") == [{:text, 1, "foo"}, {:text, 1, "bar"}]
  end

  test "a standalone comment" do
    assert tokenize("foo\n    {{! some comment }}") == [{:text, 1, "foo\n"}]
    assert tokenize("foo\n{{! some comment }}     ") == [{:text, 1, "foo\n"}]
    assert tokenize("\n{{! some comment }}     ") == [{:text, 1, "\n"}]
    assert tokenize("{{! some comment }}     ") == []
    assert tokenize("       {{! some comment }}     ") == []
    assert tokenize("       {{! some comment }}\n") == []
  end

  test "tokeninizing a section" do
    assert tokenize("{{#section}}foo{{/section}}") == [
      {:section, 1,"section"},
      {:text, 1, "foo"},
      {:end, 1, "section"}
    ]
  end

  test "tokeninizing an inverted section" do
    assert tokenize("{{^section}}foo{{/section}}") == [
      {:inverted, 1, "section"},
      {:text, 1, "foo"},
      {:end, 1, "section"}
    ]
  end

  test "tokenizing a partial" do
    assert tokenize("{{>foo}}") == [{:partial, 1, "foo"}]
  end

  test "whitespace should be preserved in plain-text" do
    assert tokenize("\n foo bar baz   \n\n") == [
      {:text, 1, "\n"},
      {:text, 2, " foo bar baz   \n"},
      {:text, 3, "\n"}
    ]
  end

  test "line numbers are counted" do
    assert tokenize("{{foo}}\n{{>bar}}\n{{{baz}}}\nqux") == [
      {:double, 1, "foo"},
      {:text, 1, "\n"},
      {:partial, 2, "bar"},
      {:text, 2, "\n"},
      {:triple, 3, "baz"},
      {:text, 3, "\n"},
      {:text, 4, "qux"}
    ]
  end
end
