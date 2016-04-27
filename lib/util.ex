defmodule Stache.Util do
  def var(scope, var), do: scoped_lookup(scope, var) |> to_string

  def escaped_var(scope, var), do: var(scope, var) |> escape_html

  def scoped_lookup([], _vars), do: nil
  def scoped_lookup([s|_scopes], [:'.']), do: s
  def scoped_lookup([s|scopes], vars) when not is_map(s), do: scoped_lookup(scopes, vars)
  def scoped_lookup([s|scopes], [v]) do
    case Access.fetch(s, v) do
      {:ok, value} -> value
      :error -> scoped_lookup(scopes, [v])
    end
  end
  def scoped_lookup([s|scopes], all_vars = [v|vars]) do
    case Access.fetch(s, v) do
      {:ok, value} -> get_in value, vars
      :error -> scoped_lookup(scopes, all_vars)
    end
  end

  def escape_html(text) do
    text
    |> String.codepoints
    |> escape_html("")
  end

  for {k, v} <- [{"&", "&amp;"}, {"<", "&lt;"}, {">", "&gt;"}, {"\"", "&quot;"}] do
    def escape_html([unquote(k)|text], buffer), do: escape_html(text, buffer <> unquote(v))
  end
  def escape_html([t|text], buffer), do: escape_html(text, buffer <> t)
  def escape_html([], buffer), do: buffer
end
