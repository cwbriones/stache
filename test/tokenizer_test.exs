defmodule TokenizerTest do
  use ExUnit.Case

  import Stache.Tokenizer

  test "tokenizing a double stache" do
    assert tokenize("{{foo}}") == [%{token: :double, contents: "foo"}]
  end

  test "tokenizing a triple stache" do
    assert tokenize("{{{foo}}}") == [%{token: :triple, contents: "foo"}]
  end

  test "tokenizing plain text" do
    assert tokenize("foo") == [%{token: :text, contents: "foo"}]
  end

  test "tokenizing a simple template" do
    template = "<h1>{{name}}</h1><p>{{description}}<p>" <>
      "<h2>Here's an example.</h2> <pre>{{{example}}}</pre>"

    assert tokenize(template) == [
      %{token: :text, contents: "<h1>"},
      %{token: :double, contents: "name"},
      %{token: :text, contents: "</h1><p>"},
      %{token: :double, contents: "description"},
      %{token: :text, contents: "<p><h2>Here's an example.</h2> <pre>"},
      %{token: :triple, contents: "example"},
      %{token: :text, contents: "</pre>"}
    ]
  end

  test "tokeninizing a comment" do
    assert tokenize("{{! some comment }}") == [%{token: :comment, contents: " some comment "}]
  end

  test "tokeninizing a section" do
    assert tokenize("{{#section}}foo{{/section}}") == [
      %{token: :begin_section, contents: "section"},
      %{token: :text, contents: "foo"},
      %{token: :end_section, contents: "section"}
    ]
  end

  test "tokeninizing an inverted section" do
    assert tokenize("{{^section}}foo{{/section}}") == [
      %{token: :begin_inverted, contents: "section"},
      %{token: :text, contents: "foo"},
      %{token: :end_section, contents: "section"}
    ]
  end

  test "tokenizing a partial" do
    assert tokenize("{{>foo}}") == [%{token: :partial, contents: "foo"}]
  end
end
