defmodule Stache.Tokenizer do
  @moduledoc false

  @doc """
  Tokenizes the given binary.

  Returns {:ok, list} where list is one of the following:

    * `{:text, line, contents}`
    * `{:section, line, contents}`
    * `{:inverted, line, contents}`
    * `{:end, line, contents}`
    * `{:partial, line, contents}`
    * `{:double, line, contents}`
    * `{:triple, line, contents}`

  Or {:error, line, error} in the case of errors.
  """
  def tokenize(template, line \\ 1) do
    tokenized =
      template
      |> String.to_char_list
      |> tokenize([], :text, line, line, [])

    with {:ok, tokens} <- tokenized
    do
      {:ok, strip(tokens)}
    end
  end

  def strip(tokens) do
    tokens
    |> Enum.chunk_by(&elem(&1, 1))
    |> Enum.map(&strip_standalone/1)
    |> List.flatten
    |> Enum.reject(&comment?/1)
  end

  defp strip_standalone(line) do
    filtered = Enum.filter(line, fn
      {:text, _, contents} -> String.strip(contents) != ""
      _ -> true
    end)
    case filtered do
      [{tag, _, _}] when tag in [:comment, :end, :section, :inverted] -> filtered
      _ -> line
    end
  end

  defp comment?({:comment, _, _}), do: true
  defp comment?(_), do: false

  defp tokenize([], tokens, :text, _, line, buffer) do
    tokens = add_token(tokens, :text, line, buffer) |> Enum.reverse
    {:ok, tokens}
  end

  defp tokenize(stream, tokens, :text, start, line, buffer) do
    case stream do
      '{{{' ++ stream ->
        tokens = add_token(tokens, :text, start, buffer)
        tokenize(stream, tokens, :triple, line, line, [])
      '{{' ++ [s|stream] when s in [?#, ?^, ?!, ?/, ?>] ->
        tag = case s do
          ?# -> :section
          ?! -> :comment
          ?^ -> :inverted
          ?/ -> :end
          ?> -> :partial
        end
        tokens = add_token(tokens, :text, start, buffer)
        tokenize(stream, tokens, tag, line, line, [])
      '{{' ++ stream ->
        tokens = add_token(tokens, :text, start, buffer)
        tokenize(stream, tokens, :double, line, line, [])
      [?\n | stream] ->
        tokens = add_token(tokens, :text, start, [?\n|buffer])
        newline = line + 1
        tokenize(stream, tokens, :text, newline, newline, [])
      [c | stream] -> tokenize(stream, tokens, :text, start, line, [c|buffer])
    end
  end

  defp tokenize('}}}' ++ stream, tokens, :triple, start, line, buffer) do
    # We've found a closing }}} after an open {{{.
    tokens = add_token(tokens, :triple, start, buffer)
    tokenize(stream, tokens, :text, line, line, [])
  end

  defp tokenize('}}\n' ++ stream, tokens, s, start, line, buffer)
    when start != line and s in [:comment, :section, :inverted, :end] do
    tokens = add_token(tokens, s, start, buffer)
    tokenize(stream, tokens, :text, line + 1, line + 1, [])
  end

  defp tokenize('}}' ++ stream, tokens, s, start, line, buffer) do
    tokens = add_token(tokens, s, start, buffer)
    tokenize(stream, tokens, :text, line, line, [])
  end

  defp tokenize([], _, _, _, line, _), do: {:error, line, "Unexpected EOF"}

  defp tokenize(stream, tokens, state, start, line, buffer) do
    case stream do
      '{{{' ++ _ -> {:error, line, "Unexpected \"{{{\"."}
      '}}}' ++ _ -> {:error, line, "Unexpected \"}}}\"."}
      '{{' ++ _  -> {:error, line, "Unexpected \"{{\"."}
      '}}' ++ _  -> {:error, line, "Unexpected \"}}\"."}
      [?\n | stream] -> tokenize(stream, tokens, state, start, line + 1, [?\n|buffer])
      [c | stream]   -> tokenize(stream, tokens, state, start, line, [c|buffer])
    end
  end

  defp add_token(tokens, :text, _, []), do: tokens
  defp add_token(tokens, state, line, buffer) do
    buffer = buffer |> Enum.reverse |> to_string
    contents = case state do
      :text -> buffer
      :comment -> buffer
      _ -> String.strip(buffer)
    end
    [{state, line, contents}|tokens]
  end
end
