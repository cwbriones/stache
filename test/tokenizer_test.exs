defmodule TokenizerTest do
  use ExUnit.Case

  import Stache.Tokenizer

  test "tokenizing a double stache" do
    assert tokenize("{{foo}}") == [{:double, 'foo', [line: 1]}]
  end

  test "tokenizing a triple stache" do
    assert tokenize("{{{foo}}}") == [{:triple, 'foo', [line: 1]}]
  end

  test "tokenizing plain text" do
    assert tokenize("foo") == [{:text, 'foo', [line: 1]}]
  end

  test "tokenizing a simple template" do
    template = "<h1>{{name}}</h1><p>{{description}}<p>" <>
      "<h2>Here\'s an example.</h2> <pre>{{{example}}}</pre>"

    assert tokenize(template) == [
      {:text, '<h1>', [line: 1]},
      {:double, 'name', [line: 1]},
      {:text, '</h1><p>', [line: 1]},
      {:double, 'description', [line: 1]},
      {:text, '<p><h2>Here\'s an example.</h2> <pre>', [line: 1]},
      {:triple, 'example', [line: 1]},
      {:text, '</pre>', [line: 1]}
    ]
  end

  test "tokeninizing a comment" do
    assert tokenize("{{! some comment }}") == [{:comment, ' some comment ', [line: 1]}]
  end

  test "tokeninizing a section" do
    assert tokenize("{{#section}}foo{{/section}}") == [
      {:section,'section', [line: 1]},
      {:text, 'foo', [line: 1]},
      {:end, 'section', [line: 1]}
    ]
  end

  test "tokeninizing an inverted section" do
    assert tokenize("{{^section}}foo{{/section}}") == [
      {:inverted, 'section', [line: 1]},
      {:text, 'foo', [line: 1]},
      {:end, 'section', [line: 1]}
    ]
  end

  test "tokenizing a partial" do
    assert tokenize("{{>foo}}") == [{:partial, 'foo', [line: 1]}]
  end

  test "line numbers are counted" do
    assert tokenize("{{foo}}\n{{>bar}}\n{{{baz}}}\nqux") == [
      {:double, 'foo', [line: 1]},
      {:partial, 'bar', [line: 2]},
      {:triple, 'baz', [line: 3]},
      {:text, 'qux', [line: 4]}
    ]
  end
end
