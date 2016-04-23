defmodule Stache.Tokenizer do
  def tokenize(template) do
    template
    |> String.to_char_list
    |> chunk_tokens([], :text, 1, [])
  end

  def chunk_tokens([], tokens, :text, line, buffer) do
    tokens = add_token(tokens, :text, line, buffer)
    Enum.reverse(tokens)
  end
  def chunk_tokens([], _tokens, _, _, _), do: {:error, :eol}
  def chunk_tokens('{{{' ++ stream, tokens, :text, line, buffer) do
    tokens = add_token(tokens, :text, line, buffer)
    chunk_tokens(stream, tokens, :triple, line, [])
  end
  def chunk_tokens('}}}' ++ stream, tokens, :triple, line, buffer) do
    # We've found a closing }}} after an open {{{.
    tokens = add_token(tokens, :triple, line, buffer)
    chunk_tokens(stream, tokens, :text, line, [])
  end
  def chunk_tokens('{{' ++ [s|stream], tokens, :text, line, buffer) when s in [?#, ?^, ?!, ?/, ?>] do
    tag = case s do
      ?# -> :section
      ?! -> :comment
      ?^ -> :inverted
      ?/ -> :end
      ?> -> :partial
    end
    tokens = add_token(tokens, :text, line, buffer)
    chunk_tokens(stream, tokens, tag, line, [])
  end
  def chunk_tokens('{{' ++ stream, tokens, :text, line, buffer) do
    tokens = add_token(tokens, :text, line, buffer)
    chunk_tokens(stream, tokens, :double, line, [])
  end
  def chunk_tokens('}}' ++ stream, tokens, s, line, buffer)
    when s in [:double, :comment, :section, :inverted, :end, :partial] do

    tokens = add_token(tokens, s, line, buffer)
    chunk_tokens(stream, tokens, :text, line, [])
  end
  def chunk_tokens([?\n | stream], tokens, state, line, buffer) do
    chunk_tokens(stream, tokens, state, line + 1, buffer)
  end
  def chunk_tokens([c | stream], tokens, state, line, buffer) do
    # text plain ol' text
    chunk_tokens(stream, tokens, state, line, [c|buffer])
  end

  def add_token(tokens, :text, _, []), do: tokens
  def add_token(tokens, state, line, buffer) do
    [{state, Enum.reverse(buffer), [line: line]}|tokens]
  end
end
