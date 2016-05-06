defmodule Stache do
  @moduledoc """
  Mustache templates for Elixir.

  `Stache` is a templating engine for compiling mustache templates into native Elixir
  functions. It fully supports the features of the Mustache spec, allowing you to
  easily use the logic-less mustache templates you know and love.

  The API mirrors that of `EEx`.

  See the [mustache spec](https://mustache.github.io/mustache.5.html) for information
  about the mustache templating system itself.
  """

  @doc """
  Compiles and renders the template `string` with `context`.
  """
  def eval_string(string, context, partials \\ %{}) do
    string
    |> Stache.Compiler.compile!
    |> Code.eval_quoted([stache_assigns: [context], stache_partials: partials])
    |> elem(0)
  end

  @doc """
  Compiles and renders the template `filename` with `context`.
  """
  def eval_file(filename, context, partials \\ %{}) do
    File.read!(filename) |> eval_string(context, partials)
  end

  @doc """
  Compiles `template` and defines an elixir function from it.

  `kind` can be `:def` or `:defp`.

  This defines a 2-arity function that takes both the context to render
  along with the set of partials, if any. Both must be a `Map`.

  ## Examples

      # templates.ex
      defmodule Templates do
        require Stache

        def foo, do: 1
        Stache.function_from_string(:def, :hello_world, "{{hello}}, world!")
      end

      # iex
      Templates.hello_world %{hello: "Hello"} #=> "Hello, world!"
  """
  defmacro function_from_string(kind, name, template) do
    quote bind_quoted: binding do
      compiled = Stache.Compiler.compile!(template)

      case kind do
        :def ->
          def(unquote(name)(context, stache_partials \\ %{})) do
            var!(stache_assigns) = [context]
            unquote(compiled)
          end
        :defp ->
          defp(unquote(name)(context, stache_partials \\ %{})) do
            var!(stache_assigns) = [context]
            unquote(compiled)
          end
      end
    end
  end

  @doc """
  Compiles `file` and defines an elixir function from it.

  `kind` can be `:def` or `:defp`.

  This defines a 2-arity function that takes both the context to render
  along with the set of partials, if any. Both must be a `Map`.

  ## Examples
      # hello.stache
      {{hello}}, world!

      # templates.ex
      defmodule Templates do
        require Stache

        def foo, do: 1
        Stache.function_from_file(:def, :hello_world, "hello.stache")
      end

      # iex
      Templates.hello_world %{hello: "Hello"} #=> "Hello, world!"
  """
  defmacro function_from_file(kind, name, file) do
    template = File.read!(file)
    quote bind_quoted: [kind: kind, name: name, template: template] do
      Stache.function_from_string(kind, name, template)
    end
  end
end
