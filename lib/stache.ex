defmodule Stache do
  @doc """
  Compiles and renders the `template` with `params`.
  """
  def render_from_string(template, _params), do: template
end
