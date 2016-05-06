defmodule Stache.Compiler do
  alias Stache.Tokenizer

  @doc """
  Compiles a template string into a quoted Elixir expression.

  Returns `{:ok, ast}` or `{:error, reason}`.
  """
  def compile(template, opts \\ []) do
    with {:ok, tokens} <- Tokenizer.tokenize(template, opts),
         {:ok, parsed} <- parse(tokens, [])
    do
      {:ok, generate_buffer(parsed, template, "")}
    end
  end

  @doc """
  Compiles a template string into a quoted Elixir expression.

  Raises Stache.SyntaxError if one is encountered.
  """
  def compile!(template, opts \\ []) do
    file = Keyword.get(opts, :file, :nofile)
    case compile(template, opts) do
      {:ok, compiled} -> compiled
      {:error, line, message} ->
        raise Stache.SyntaxError, message: message, line: line, file: file
    end
  end

  @doc false
  # Translates a compiled file into a quoted elixir expression
  # for evaluation
  def generate_buffer(tree, template, buffer \\ "")
  def generate_buffer([], _template, buffer), do: buffer
  def generate_buffer([{:text, text}|tree], template, buffer) do
    buffer = quote do: unquote(buffer) <> unquote(text)
    generate_buffer(tree, template, buffer)
  end
  def generate_buffer([{:double, keys}|tree], template, buffer) do
    vars = Enum.map(keys, &String.to_atom/1)
    buffer = quote do
      unquote(buffer) <> Stache.Util.escaped_var(var!(stache_assigns), unquote(vars))
    end
    generate_buffer(tree, template, buffer)
  end
  def generate_buffer([{:triple, keys}|tree], template, buffer) do
    vars = Enum.map(keys, &String.to_atom/1)
    buffer = quote do
      unquote(buffer) <> Stache.Util.var(var!(stache_assigns), unquote(vars))
    end
    generate_buffer(tree, template, buffer)
  end
  def generate_buffer([{:section, keys, meta, inner}|tree], template, buffer) do
    vars = Enum.map(keys, &String.to_atom/1)
    inner = generate_buffer(inner, template, "")
    raw_inner = slice_section(template, meta)
    delimeters = meta.delimeters

    buffer = quote do
      section = Stache.Util.scoped_lookup(var!(stache_assigns), unquote(vars))
      render_inner = fn var!(stache_assigns) -> unquote(inner) end
      unquote(buffer) <>
        case section do
          s when is_function(s) ->
            Stache.Util.eval_lambda(var!(stache_assigns), s, unquote(raw_inner), unquote(delimeters))
          s when s in [nil, false, []] -> ""
          [_|_] ->
            Enum.map(section, &render_inner.([&1|var!(stache_assigns)])) |> Enum.join
          _ ->
            new_assigns = [section|var!(stache_assigns)]
            render_inner.(new_assigns)
        end
    end
    generate_buffer(tree, template, buffer)
  end
  def generate_buffer([{:inverted, keys, _meta, inner}|tree], template, buffer) do
    vars = Enum.map(keys, &String.to_atom/1)
    inner = generate_buffer(inner, template, "")

    buffer = quote do
      section = Stache.Util.scoped_lookup(var!(stache_assigns), unquote(vars))
      render_inner = fn var!(stache_assigns) -> unquote(inner) end
      unquote(buffer) <>
        if section in [nil, false, []] do
            new_assigns = [section|var!(stache_assigns)]
            render_inner.(new_assigns)
        else
          ""
        end
    end
    generate_buffer(tree, template, buffer)
  end
  def generate_buffer([{:partial, meta, tag}|tree], template, buffer) do
    key = String.to_atom(tag)
    indent = String.duplicate(" ", Map.get(meta, :indent, 0))
    buffer = quote bind_quoted: [buffer: buffer, key: key, indent: indent] do
      buffer <>
        Stache.Util.render_partial(var!(stache_partials), key, var!(stache_assigns), indent)
    end
    generate_buffer(tree, template, buffer)
  end
  def generate_buffer([_|tree], template, buffer), do: generate_buffer(tree, template, buffer)

  defp slice_section(template, %{pos_start: s, pos_end: e}) do
    String.slice(template, s, e - s)
  end

  # Parses a stream of tokens, nesting any sections and expanding
  # any shorthand.
  defp parse([], parsed), do: {:ok, Enum.reverse(parsed)}
  defp parse([{:double, meta, "&" <> key}|tokens], parsed), do: parse([{:triple, meta, key}|tokens], parsed)
  defp parse([{interp, meta, key}|tokens], parsed) when interp in [:double, :triple] do
    with {:ok, keys} <- validate_key(key, meta)
    do
      parse(tokens, [{interp, keys}|parsed])
    end
  end
  defp parse([{:partial, meta, tag}|tokens], parsed) do
    with {:ok, tag} <- validate_tag(tag, meta)
    do
      parse(tokens, [{:partial, meta, tag}|parsed])
    end
  end
  defp parse([token = {:end, _, _}|tokens], parsed) do
    {token, tokens, Enum.reverse(parsed)}
  end
  defp parse([{section, meta =  %{line: line}, key}|tokens], parsed) when section in [:section, :inverted] do
    with {:ok, keys} <- validate_key(key, meta)
    do
      case parse(tokens, []) do
        {{:end, end_meta, ^key}, tokens, inner} ->
          section_meta = %{meta|pos_start: meta.pos_end, pos_end: end_meta.pos_start}
          parse(tokens, [{section, keys, section_meta, inner}|parsed])
        {{:end, %{line: line}, endtag}, _, _} ->
          {:error, line, "Unexpected {{/#{endtag}}}"}
        {:ok, _} ->
          {:error, line, "Reached EOF while searching for closing {{/#{key}}}"}
        error = {:error, _, _} -> error
      end
    end
  end
  defp parse([{:text, _, contents}|tokens], parsed), do: parse(tokens, [{:text, contents}|parsed])

  defp validate_key(".", _meta), do: {:ok, ["."]}
  defp validate_key(key, %{line: line}) do
    case String.split(key, ".") do
      [""] -> {:error, line, "Interpolation key cannot be empty"}
      keys = [_ | _] ->
        trimmed = Enum.map(keys, &String.strip/1)
        if Enum.all?(trimmed, &valid_key?/1) do
          {:ok, trimmed}
        else
          {:error, line, "Invalid key \"#{key}\""}
        end
    end
  end

  defp validate_tag(tag, meta = %{line: line}) do
    case validate_key(tag, meta) do
      {:error, _, _} -> {:error, line, "Invalid section tag \"#{tag}\""}
      {:ok, [tag]} -> {:ok, tag}
      {:ok, _} -> {:error, line, "Invalid section tag \"#{tag}\""}
    end
  end

  defp valid_key?(key), do: Regex.match?(~r/^[a-zA-Z_]+$/, key)
end
