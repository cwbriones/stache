defmodule TokenizerTest do
  use ExUnit.Case

  import Stache.Tokenizer

  test "tokenizing a double stache" do
    assert tokenize("{{foo}}") == [{:double, 'foo'}]
  end

  test "tokenizing a triple stache" do
    assert tokenize("{{{foo}}}") == [{:triple, 'foo'}]
  end

  test "tokenizing plain text" do
    assert tokenize("foo") == [{:text, 'foo'}]
  end

  test "tokenizing a simple template" do
    template = "<h1>{{name}}</h1><p>{{description}}<p>" <>
      "<h2>Here\'s an example.</h2> <pre>{{{example}}}</pre>"

    assert tokenize(template) == [
      {:text, '<h1>'},
      {:double, 'name'},
      {:text, '</h1><p>'},
      {:double, 'description'},
      {:text, '<p><h2>Here\'s an example.</h2> <pre>'},
      {:triple, 'example'},
      {:text, '</pre>'}
    ]
  end

  test "tokeninizing a comment" do
    assert tokenize("{{! some comment }}") == [{:comment, ' some comment '}]
  end

  test "tokeninizing a section" do
    assert tokenize("{{#section}}foo{{/section}}") == [
      {:begin_section,'section'},
      {:text, 'foo'},
      {:end_section, 'section'}
    ]
  end

  test "tokeninizing an inverted section" do
    assert tokenize("{{^section}}foo{{/section}}") == [
      {:begin_inverted, 'section'},
      {:text, 'foo'},
      {:end_section, 'section'}
    ]
  end

  test "tokenizing a partial" do
    assert tokenize("{{>foo}}") == [{:partial, 'foo'}]
  end
end
