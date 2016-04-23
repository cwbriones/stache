defmodule Stache.Tokenizer do
  def tokenize(template, line \\ 1) do
    template
    |> String.to_char_list
    |> chunk_tokens([], :text, line, [])
  end

  def chunk_tokens([], tokens, :text, line, buffer) do
    tokens = add_token(tokens, :text, line, buffer)
    Enum.reverse(tokens)
  end
  def chunk_tokens([], _tokens, _state, line, _buffer) do
    {:error, line, "Unexpected EOF"}
  end
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
  def chunk_tokens(stream, tokens, state, line, buffer) do
    case stream do
      '{{{' ++ _ -> {:error, line, "Unexpected \"{{{\"."}
      '}}}' ++ _ -> {:error, line, "Unexpected \"}}}\"."}
      '{{' ++ _  -> {:error, line, "Unexpected \"{{\"."}
      '}}' ++ _  -> {:error, line, "Unexpected \"}}\"."}
      [?\n | next] -> chunk_tokens(next, tokens, state, line + 1, buffer)
      [c | next]   -> chunk_tokens(next, tokens, state, line, [c|buffer])
    end
  end

  def add_token(tokens, :text, _, []), do: tokens
  def add_token(tokens, state, line, buffer) do
    buffer = buffer |> Enum.reverse |> to_string
    contents = case state do
      :text -> buffer
      :comment -> buffer
      _ -> String.strip(buffer)
    end
    [{state, line, contents}|tokens]
  end
end
