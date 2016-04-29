defmodule Stache.Tokenizer do
  @moduledoc false

  defmodule State do
    defstruct [
      line: 0,
      start: 0,
      buffer: "",
      mode: :text,
      delimeters: {"{{", "}}"},
      tokens: []
    ]
  end

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
    state = %State{line: line, start: line}
    with {:ok, tokens} <- tokenize_loop(template, state)
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

  defp delimeter_change(line, buffer) do
    delimeters =
      buffer
      |> String.split
      |> Enum.reject(&String.contains?(&1, "="))
      |> Enum.map(&to_char_list/1)
    case delimeters do
      [fst, snd] -> {:ok, {fst, snd}}
      _ -> {:error, line, "Improper delimeter change"}
    end
  end

  def next_state(stream, next, state = %State{line: line}) do
    state = add_token(state)
    tokenize_loop(stream, %State{state| mode: next, start: line, buffer: ""})
  end

  defp add_token(state = %State{mode: :text, buffer: ""}), do: state
  defp add_token(state = %State{start: start, tokens: tokens, mode: mode, buffer: buffer}) do
    contents = case mode do
      :text -> buffer
      :comment -> buffer
      _ -> String.strip(buffer)
    end
    %State{state|tokens: [{mode, start, contents}|tokens]}
  end

  defp tokenize_loop("", state = %State{mode: :text}) do
    state = add_token(state)
    {:ok, Enum.reverse(state.tokens)}
  end

  defp tokenize_loop("", %State{line: line}), do: {:error, line, "Unexpected EOF"}

  defp tokenize_loop(stream, state = %State{mode: :text, line: line, buffer: buffer}) do
    case stream do
      "{{{" <> stream ->
        next_state(stream, :triple, state)
      <<"{{", s :: binary-size(1), stream::binary>>
        when s in ["#", "^", "!", "/", ">", "="] ->
        next = case s do
          "#" -> :section
          "!" -> :comment
          "^" -> :inverted
          "/" -> :end
          ">" -> :partial
          "=" -> :delimeter
        end
        next_state(stream, next, state)
      "{{" <> stream ->
        next_state(stream, :double, state)
      "\n" <> stream ->
        next_state(stream, :text, %State{state|line: line + 1, buffer: buffer <> "\n"})
      _ ->
        {c, stream} = String.next_codepoint(stream)
        tokenize_loop(stream, %State{state|buffer: buffer <> c})
    end
  end
  defp tokenize_loop("=}}" <> stream, state = %State{mode: :delimeter, line: line, buffer: buffer}) do
    with {:ok, delimeters} <- delimeter_change(line, buffer)
    do
      next_state(stream, :text, %State{state|delimeters: delimeters})
    end
  end

  defp tokenize_loop("}}}" <> stream, state = %State{mode: :triple}) do
    # We've found a closing }}} after an open {{{.
    next_state(stream, :text, state)
  end

  defp tokenize_loop("}}\n" <> stream, state = %State{start: start, line: line, mode: s})
    when start != line and s in [:comment, :section, :inverted, :end] do

    next_state(stream, :text, %State{state|line: line + 1})
  end

  defp tokenize_loop("}}" <> stream, state) do
    next_state(stream, :text, state)
  end

  defp tokenize_loop(stream, state = %State{line: line, buffer: buffer}) do
    case stream do
      "{{{" <> _ -> {:error, line, "Unexpected \"{{{\"."}
      "}}}" <> _ -> {:error, line, "Unexpected \"}}}\"."}
      "{{" <> _  -> {:error, line, "Unexpected \"{{\"."}
      "}}" <> _  -> {:error, line, "Unexpected \"}}\"."}
      "\n" <> stream -> tokenize_loop(stream, %State{state|line: line + 1, buffer: buffer <> "\n"})
      _ ->
        {c, stream} = String.next_codepoint(stream)
        tokenize_loop(stream, %State{state|line: line, buffer: buffer <> c})
    end
  end
end
