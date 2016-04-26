defmodule Stache.Tokenizer do
  def tokenize(template, line \\ 1) do
    template
    |> String.to_char_list
    |> chunk_tokens([], :text, line, line, [])
    |> strip_comments
  end

  def strip_comments(tokens) do
    tokens
    |> Enum.chunk_by(&elem(&1, 1))
    |> Enum.reject(&standalone_comment?/1)
    |> List.flatten
    |> Enum.reject(&comment?/1)
  end

  defp standalone_comment?(line) do
    Enum.any?(line, &comment?/1) and Enum.all?(line, fn
      {:comment, _, _} -> true
      {:text, _, contents} -> String.strip(contents) == ""
      _ -> false
    end)
  end

  defp comment?({:comment, _, _}), do: true
  defp comment?(_), do: false

  def chunk_tokens([], tokens, :text, start, line, buffer) do
    tokens = add_token(tokens, :text, line, buffer)
    Enum.reverse(tokens)
  end
  def chunk_tokens([], _tokens, _state, start, line, _buffer) do
    {:error, line, "Unexpected EOF"}
  end
  def chunk_tokens('{{{' ++ stream, tokens, :text, start, line, buffer) do
    tokens = add_token(tokens, :text, start, buffer)
    chunk_tokens(stream, tokens, :triple, line, line, [])
  end
  def chunk_tokens('}}}' ++ stream, tokens, :triple, start, line, buffer) do
    # We've found a closing }}} after an open {{{.
    tokens = add_token(tokens, :triple, start, buffer)
    chunk_tokens(stream, tokens, :text, line, line, [])
  end
  def chunk_tokens('{{' ++ [s|stream], tokens, :text, start, line, buffer) 
    when s in [?#, ?^, ?!, ?/, ?>] do

    tag = case s do
      ?# -> :section
      ?! -> :comment
      ?^ -> :inverted
      ?/ -> :end
      ?> -> :partial
    end
    tokens = add_token(tokens, :text, start, buffer)
    chunk_tokens(stream, tokens, tag, line, line, [])
  end
  def chunk_tokens('{{' ++ stream, tokens, :text, start, line, buffer) do
    tokens = add_token(tokens, :text, start, buffer)
    chunk_tokens(stream, tokens, :double, line, line, [])
  end
  def chunk_tokens('}}\n' ++ stream, tokens, :comment, start, line, buffer) when start != line do
    tokens = add_token(tokens, :comment, start, buffer)
    chunk_tokens(stream, tokens, :text, line + 1, line + 1, [])
  end
  def chunk_tokens('}}' ++ stream, tokens, s, start, line, buffer)
    when s in [:double, :comment, :section, :inverted, :end, :partial] do

    tokens = add_token(tokens, s, start, buffer)
    chunk_tokens(stream, tokens, :text, line, line, [])
  end
  def chunk_tokens([?\n | stream], tokens, :text, start, line, buffer) do
    tokens = add_token(tokens, :text, start, [?\n|buffer])
    newline = line + 1
    chunk_tokens(stream, tokens, :text, newline, newline, [])
  end
  def chunk_tokens(stream, tokens, state, start, line, buffer) do
    case stream do
      '{{{' ++ _ -> {:error, line, "Unexpected \"{{{\"."}
      '}}}' ++ _ -> {:error, line, "Unexpected \"}}}\"."}
      '{{' ++ _  -> {:error, line, "Unexpected \"{{\"."}
      '}}' ++ _  -> {:error, line, "Unexpected \"}}\"."}
      [?\n | stream] -> chunk_tokens(stream, tokens, state, start, line + 1, [?\n|buffer])
      [c | stream]   -> chunk_tokens(stream, tokens, state, start, line, [c|buffer])
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
