defmodule Stache.Tokenizer do
  @moduledoc false

  defmodule State do
    defstruct [
      line: 0,
      pos: 0,
      pos_start: 0,
      start: 0,
      buffer: "",
      mode: :text,
      delim_start: {"{{", 2},
      delim_end: {"}}", 2},
      tokens: []
    ]
  end
  @default_delimeters {"{{", "}}"}

  @doc """
  Tokenizes the given binary.

  Returns {:ok, list} where list is one of the following:

    * `{:text, meta, contents}`
    * `{:section, meta, {start, end}, contents}`
    * `{:inverted, meta, contents}`
    * `{:end, meta, contents}`
    * `{:partial, meta, contents}`
    * `{:double, meta, contents}`
    * `{:triple, meta, contents}`

  Or {:error, line, error} in the case of errors.
  """
  def tokenize(template, opts \\ []) do
    line = Keyword.get(opts, :line, 1)
    delimeters = Keyword.get(opts, :delimeters, @default_delimeters)
    state = set_delimeters(%State{line: line, start: line}, delimeters)

    with {:ok, tokens} <- tokenize_loop(template, state)
    do
      {:ok, strip(tokens)}
    end
  end

  defp set_delimeters(state, {fst, snd}) do
    %State{state|
      delim_start: {fst, String.length(fst)},
      delim_end:   {snd, String.length(snd)}
    }
  end

  defp strip(tokens) do
    tokens
    |> Enum.chunk_by(fn t -> elem(t, 1) |> Access.get(:line) end)
    |> Enum.map(&strip_standalone/1)
    |> List.flatten
    |> Enum.reject(&comment_or_delimeter?/1)
  end

  defp strip_standalone(line) do
    filtered = Enum.filter(line, fn
      {:text, _, contents} -> String.strip(contents) != ""
      _ -> true
    end)
    # If there is only one token on a line other than whitespace, and the token is
    # a control structure, we can remove the line entirely from the template.
    case filtered do
      [{tag, _, _}] when tag in [:delimeter, :comment, :end, :section, :inverted, :partial] -> filtered
      _ -> line
    end
  end

  defp comment_or_delimeter?({:comment, _, _}), do: true
  defp comment_or_delimeter?({:delimeter, _, _}), do: true
  defp comment_or_delimeter?(_), do: false

  defp delimeter_change(state = %State{line: line, buffer: buffer}) do
    delimeters =
      buffer
      |> String.split
      |> Enum.reject(&String.contains?(&1, "="))
    case delimeters do
      [fst, snd] ->
        state = set_delimeters(state, {fst, snd})
        {:ok, state}
      _ -> {:error, line, "Improper delimeter change"}
    end
  end

  defp next_state(stream, next, state = %State{mode: mode, pos: pos}, inc) do
    new_pos = pos + inc
    boundary = case {mode, next} do
      # We just read a closing delimeter. It belongs to the current token.
      {_, :text} -> new_pos
      # We just read an opening delimeter. It belongs to the next token.
      {:text, _} -> pos
    end
    state = add_token(%State{state|pos: boundary})
    tokenize_loop(stream, %State{state|pos: new_pos, mode: next})
  end

  defp add_token(state = %State{mode: :text, buffer: ""}), do: state
  defp add_token(state = %State{start: start, mode: mode, buffer: buffer, pos: pos}) do
    contents = case mode do
      :text -> buffer
      :comment -> buffer
      _ -> String.strip(buffer)
    end

    {fst, _} = state.delim_start
    {snd, _} = state.delim_end
    delimeters = {fst, snd}
    meta = %{delimeters: delimeters, line: start, pos_start: state.pos_start, pos_end: pos}

    tokens = [{mode, meta, contents}|state.tokens]
    %State{state|tokens: tokens, buffer: "", start: state.line, pos_start: pos}
  end

  defp tokenize_loop("", state = %State{mode: :text}) do
    state = add_token(state)
    {:ok, Enum.reverse(state.tokens)}
  end

  defp tokenize_loop("", %State{line: line}), do: {:error, line, "Unexpected EOF"}

  defp tokenize_loop(stream, state = %State{mode: :text, line: line, buffer: buffer}) do
    {delim, dsize} = state.delim_start
    case stream do
      "{{{" <> stream ->
        next_state(stream, :triple, state, 3)
      <<"{{":: binary, s :: binary-size(1), stream::binary>>
        when s in ["!", "="] ->
        next = case s do
          "!" -> :comment
          "=" -> :delimeter
        end
        next_state(stream, next, state, 3)
      <<^delim::binary-size(dsize), s::binary-size(1), stream::binary>>
        when s in ["#", "^", "/", ">"] ->
        mode = case s do
          "#" -> :section
          "^" -> :inverted
          "/" -> :end
          ">" -> :partial
        end
        next_state(stream, mode, state, String.length(delim) + 1)
      <<^delim::binary-size(dsize), stream::binary>> ->
        next_state(stream, :double, state, String.length(delim))
      "\n" <> stream ->
        next_state(stream, :text, %State{state|line: line + 1, buffer: buffer <> "\n"}, 1)
      _ ->
        {c, stream} = String.next_codepoint(stream)
        tokenize_loop(stream, %State{state|buffer: buffer <> c, pos: state.pos + 1})
    end
  end

  defp tokenize_loop("\n" <> stream, state = %State{line: line, buffer: buffer}) do
    tokenize_loop(stream, %State{state|line: line + 1, buffer: buffer <> "\n", pos: state.pos + 1})
  end

  defp tokenize_loop("=}}" <> stream, state = %State{mode: :delimeter}) do
    with {:ok, state} <- delimeter_change(state),
    do: next_state(stream, :text, state, 3)
  end

  defp tokenize_loop("}}}" <> stream, state = %State{mode: :triple}) do
    # We've found a closing }}} after an open {{{.
    next_state(stream, :text, state, 3)
  end

  defp tokenize_loop(stream, state = %State{mode: m, start: start, line: line, buffer: buffer}) do
    {delim, dsize} = state.delim_end
    {sdelim, sdsize} = state.delim_start
    case stream do
      <<^delim::binary-size(dsize), "\n", stream::binary>>
        when start != line and m in [:comment, :section, :inverted, :end] ->
        next_state(stream, :text, %State{state|line: line + 1}, String.length(delim) + 1)
      <<^delim::binary-size(dsize), stream::binary>>
        when m in [:double, :comment, :section, :inverted, :end, :partial] ->
        next_state(stream, :text, state, String.length(delim))
      <<^delim::binary-size(dsize), _::binary>> ->
        {:error, line, "Unexpected \"#{delim}\""}
      <<^sdelim::binary-size(sdsize), _::binary>> ->
        {:error, line, "Unexpected \"#{sdelim}\""}
      "{{{" <> _ -> {:error, line, "Unexpected \"{{{\"."}
      "}}}" <> _ -> {:error, line, "Unexpected \"}}}\"."}
      _ ->
        {c, stream} = String.next_codepoint(stream)
        tokenize_loop(stream, %State{state|pos: state.pos + 1, line: line, buffer: buffer <> c})
    end
  end
end
