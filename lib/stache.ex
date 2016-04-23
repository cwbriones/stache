defmodule Stache do
  @doc """
  Compiles and renders the `template` with `params`.
  """
  def eval_string(template, params) do
    compiled = Stache.Compiler.compile!(template)
    {result, _} = Code.eval_quoted(compiled, [stache_assigns: [params]])
    result
  end

  def eval_file(filename, params) do
    compiled = Stache.Compiler.compile!(File.read!(filename))
    {result, _} = Code.eval_quoted(compiled, [stache_assigns: [params]])
    result
  end
end
