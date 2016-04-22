defmodule Stache.Tokenizer do
  def tokenize(template) do
    template
    |> String.to_char_list
    |> chunk_tokens([], :text, [])
  end

  def chunk_tokens([], tokens, :text, acc) do
    tokens = add_token(tokens, :text, acc)
    Enum.reverse(tokens)
  end
  def chunk_tokens([], _tokens, _, _), do: {:error, :eol}
  def chunk_tokens('{{{' ++ stream, tokens, :text, acc) do
    tokens = add_token(tokens, :text, acc)
    chunk_tokens(stream, tokens, :triple, [])
  end
  def chunk_tokens('}}}' ++ stream, tokens, :triple, acc) do
    # We've found a closing }}} after an open {{{.
    tokens = add_token(tokens, :triple, acc)
    chunk_tokens(stream, tokens, :text, [])
  end
  def chunk_tokens('{{' ++ [s|stream], tokens, :text, acc) when s in [?#, ?^, ?!, ?/, ?>] do
    tag = case s do
      ?# -> :section
      ?! -> :comment
      ?^ -> :inverted
      ?/ -> :end
      ?> -> :partial
    end
    tokens = add_token(tokens, :text, acc)
    chunk_tokens(stream, tokens, tag, [])
  end
  def chunk_tokens('{{' ++ stream, tokens, :text, acc) do
    tokens = add_token(tokens, :text, acc)
    chunk_tokens(stream, tokens, :double, [])
  end
  def chunk_tokens('}}' ++ stream, tokens, s, acc)
    when s in [:double, :comment, :section, :inverted, :end, :partial] do

    tokens = add_token(tokens, s, acc)
    chunk_tokens(stream, tokens, :text, [])
  end
  def chunk_tokens([c | stream], tokens, state, acc) do
    # text plain ol' text
    chunk_tokens(stream, tokens, state, [c|acc])
  end

  def add_token(tokens, :text, []), do: tokens
  def add_token(tokens, state, acc) do
    [{state, Enum.reverse(acc)}|tokens]
  end
end
