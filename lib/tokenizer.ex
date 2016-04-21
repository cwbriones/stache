defmodule Stache.Tokenizer do
  def tokenize(template) do
    template
    |> String.codepoints
    |> chunk_tokens([], :text, "")
  end

  def chunk_tokens([], tokens, :text, acc) do
    tokens = add_token(tokens, :text, acc)
    Enum.reverse(tokens)
  end
  def chunk_tokens([], _tokens, _, _), do: {:error, :eol}
  def chunk_tokens(["{", "{", "{" | stream], tokens, :text, acc) do
    tokens = add_token(tokens, :text, acc)
    chunk_tokens(stream, tokens, :triple, "")
  end
  def chunk_tokens(["}", "}", "}" | stream], tokens, :triple, acc) do
    # We've found a closing }}} after an open {{{.
    tokens = add_token(tokens, :triple, acc)
    chunk_tokens(stream, tokens, :text, "")
  end
  def chunk_tokens(["{", "{", s | stream], tokens, :text, acc) when s in ["#", "^", "!", "/", ">"] do
    tag = case s do
      "#" -> :begin_section
      "!" -> :comment
      "^" -> :begin_inverted
      "/" -> :end_section
      ">" -> :partial
    end
    tokens = add_token(tokens, :text, acc)
    chunk_tokens(stream, tokens, tag, "")
  end
  def chunk_tokens(["{", "{" | stream], tokens, :text, acc) do
    tokens = add_token(tokens, :text, acc)
    chunk_tokens(stream, tokens, :double, "")
  end
  def chunk_tokens(["}", "}" | stream], tokens, s, acc)
    when s in [:double, :comment, :begin_section, :begin_inverted, :end_section, :partial] do

    tokens = add_token(tokens, s, acc)
    chunk_tokens(stream, tokens, :text, "")
  end
  def chunk_tokens([c | stream], tokens, state, acc) do
    # text plain ol' text
    chunk_tokens(stream, tokens, state, acc <> c)
  end

  def add_token(tokens, :text, ""), do: tokens
  def add_token(tokens, state, acc) do
    token = %{contents: acc, token: state}
    [token|tokens]
  end
end
