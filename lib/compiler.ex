defmodule Stache.Compiler do
  alias Stache.Tokenizer

  @doc """
  Compiles a template string into a form suitable for interpolation.
  """
  def compile(template, opts \\ []) do
    template
    |> Tokenizer.tokenize
    |> parse([])
  end

  # Parses a stream of tokens, nesting any sections and expanding
  # any shorthand.
  defp parse([], parsed), do: Enum.reverse(parsed)
  defp parse([text = {tag, _}|tokens], parsed) when tag in [:partial, :text, :triple, :double] do
    parse(tokens, [text|parsed])
  end
  defp parse([{:comment, _}|tokens], parsed), do: parse(tokens, parsed)
  defp parse([{section, tag}|tokens], parsed) when section in [:section, :inverted] do
    case section(tokens, [], tag) do
      {:ok, inner, tokens} ->
        parse(tokens, [[{section, tag, inner}]|parsed])
      error = {:error, _} -> error
    end
  end

  # Recursively parses the contents of a section or inverted section.
  defp section([], _, tag) do
    {:error, "Reached EOL searching for closing {{/#{tag}}}"}
  end
  defp section([{:end, tag}|tokens], scanned, tag) do
    inner = scanned
    |> Enum.reverse
    |> parse([])
    {:ok, inner, tokens}
  end
  defp section([t|tokens], scanned, tag), do: section(tokens, [t|scanned], tag)
end
