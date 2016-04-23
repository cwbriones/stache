defmodule Stache.Compiler do
  alias Stache.Tokenizer

  @doc """
  Compiles a template string into a form suitable for interpolation.
  """
  def compile(template, _opts \\ []) do
    case Tokenizer.tokenize(template) do
      e = {:error, _, _} -> e
      tokens ->
        case parse(tokens, []) do
          {:ok, parsed} -> {:ok, to_quoted(parsed)}
          e = {:error, _, _} -> e
        end
    end
  end

  @doc """
  Compiles a template string into a form suitable for interpolation.

  Raises Stache.SyntaxError if one is encountered.
  """
  def compile!(template, opts \\ []) do
    file = Keyword.get(opts, :file, :nofile)
    case compile(template) do
      {:ok, compiled} -> compiled
      {:error, line, message} ->
        raise Stache.SyntaxError, message: message, line: line, file: file
    end
  end

  defp to_quoted(body), do: body

  # Parses a stream of tokens, nesting any sections and expanding
  # any shorthand.
  defp parse([], parsed), do: {:ok, Enum.reverse(parsed)}
  defp parse([{:comment, _, _}|tokens], parsed), do: parse(tokens, parsed)
  defp parse([{interp, line, key}|tokens], parsed) when interp in [:double, :triple] do
    with {:ok, keys} <- validate_key(key, line)
    do
      parse(tokens, [{interp, keys}|parsed])
    end
  end
  defp parse([{:partial, line, tag}|tokens], parsed) do
    with {:ok, tag} <- validate_tag(tag, line)
    do
      parse(tokens, [{:partial, tag}|parsed])
    end
  end
  defp parse([{section, line, tag}|tokens], parsed) when section in [:section, :inverted] do
    with {:ok, tag} <- validate_tag(tag, line),
         {:ok, inner, tokens} <- section(tokens, [], tag, line),
    do: parse(tokens, [{section, tag, inner}|parsed])
  end
  defp parse([{:text, _, contents}|tokens], parsed), do: parse(tokens, [{:text, contents}|parsed])

  # Recursively parses the contents of a section or inverted section.
  defp section([], _, tag, line) do
    {:error, line, "Reached EOF while searching for closing {{/#{tag}}}"}
  end
  defp section([{:end, _, tag}|tokens], scanned, tag, _line) do
    contents = scanned |> Enum.reverse

    with {:ok, inner} <- parse(contents, [])
    do
      {:ok, inner, tokens}
    end
  end
  defp section([t|tokens], scanned, tag, line), do: section(tokens, [t|scanned], tag, line)

  defp validate_key(key, line) do
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

  defp validate_tag(tag, line) do
    case validate_key(tag, line) do
      {:error, _, _} -> {:error, line, "Invalid section tag \"#{tag}\""}
      {:ok, [tag]} -> {:ok, tag}
      {:ok, _} -> {:error, line, "Invalid section tag \"#{tag}\""}
    end
  end

  defp valid_key?(key), do: Regex.match?(~r/^[a-zA-Z_]+$/, key)
end
