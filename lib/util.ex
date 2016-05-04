defmodule Stache.Util do
  def var(scope, var) do
    val = scoped_lookup(scope, var)
    if is_function(val) do
      eval_lambda(scope, val)
    else
      to_string(val)
    end
  end

  def eval_lambda(scope, lambda) do
    template = to_string(lambda.())
    compiled = Stache.Compiler.compile!(template)
    {result, _} = Code.eval_quoted(compiled, stache_assigns: scope)
    result
  end

  def eval_lambda(scope, lambda, raw, delimeters) do
    template = to_string(lambda.(raw))
    compiled = Stache.Compiler.compile!(template, delimeters: delimeters)
    {result, _} = Code.eval_quoted(compiled, stache_assigns: scope)
    result
  end

  def render_partial(partials, key, scope) do
    case Map.get(partials, key) do
      nil -> ""
      f   -> f.(scope, partials)
    end
  end

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
