defmodule Stache.Util do
  @html_escape_codes [{"&", "&amp;"}, {"<", "&lt;"}, {">", "&gt;"}, {"\"", "&quot;"}]

  def var(scope, var) do
    val = scoped_lookup(scope, var)
    if is_function(val) do
      eval_lambda(scope, val)
    else
      to_string(val)
    end
  end

  def escaped_var(scope, var), do: var(scope, var) |> escape_html

  def eval_lambda(scope, lambda) do
    case lambda.() do
      template when is_binary(template) ->
        template
        |> Stache.Compiler.compile!
        |> Code.eval_quoted(stache_assigns: scope)
        |> elem(0)
        |> to_string
      result -> to_string(result)
    end
  end

  def eval_lambda(scope, lambda, raw, delimeters) do
    case lambda.(raw) do
      template when is_binary(template) ->
        template
        |> Stache.Compiler.compile!(delimeters: delimeters)
        |> Code.eval_quoted(stache_assigns: scope)
        |> elem(0)
        |> to_string
      result -> to_string(result)
    end
  end

  def render_partial(partials, key, scope, indentation) do
    case Map.get(partials, key) do
      nil -> ""
      partial ->
        partial
        |> indent(indentation)
        |> eval_partial(scope, partials)
    end
  end

  defp indent(string, indent) do
    indent <> (String.split(string, ~r/\n(?=.)/) |> Enum.join("\n" <> indent))
  end

  defp eval_partial(partial, scope, partials) do
    partial
    |> Stache.Compiler.compile!
    |> Code.eval_quoted([stache_assigns: scope, stache_partials: partials])
    |> elem(0)
  end

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

  for {k, v} <- @html_escape_codes do
    def escape_html([unquote(k)|text], buffer), do: escape_html(text, buffer <> unquote(v))
  end
  def escape_html([t|text], buffer), do: escape_html(text, buffer <> t)
  def escape_html([], buffer), do: buffer
end
