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

  defmacro function_from_string(kind, name, template) do
    quote bind_quoted: binding do
      compiled = Stache.Compiler.compile!(template)

      case kind do
        :def ->
          def(unquote(name)(initial_context)) do
            var!(stache_assigns) = [initial_context]
            unquote(compiled)
          end
        :defp ->
          defp(unquote(name)(initial_context)) do
            var!(stache_assigns) = [initial_context]
            unquote(compiled)
          end
      end
    end
  end
end
