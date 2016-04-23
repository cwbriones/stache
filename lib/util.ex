defmodule Stache.Util do
  def var(scope, var), do: scoped_lookup(scope, var) |> to_string

  def escaped_var(scope, var), do: var(scope, var) |> escape_html

  def scoped_lookup([], _vars), do: nil
  def scoped_lookup([s|scope], vars) do
    get_in(s, vars) || scoped_lookup(scope, vars)
  end

  def escape_html(text), do: text
end
