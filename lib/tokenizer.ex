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
  def chunk_tokens(["{", "{" | stream], tokens, :text, acc) do
    tokens = add_token(tokens, :text, acc)
    chunk_tokens(stream, tokens, :double, "")
  end
  def chunk_tokens(["}", "}" | stream], tokens, :double, acc) do
    # We've found a closing }}} after an open {{{.
    tokens = add_token(tokens, :double, acc)
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
