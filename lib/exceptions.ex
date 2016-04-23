defmodule Stache.SyntaxError do
  @module """
  Raised during template compilation when a syntax error is detected in the input file or string.
  """
  defexception [:message, :file, :line]

  def exception(opts) do
    message = Keyword.fetch!(opts, :message)
    file = Keyword.get(opts, :file, :nofile)
    line = Keyword.fetch!(opts, :line)
    full_message = "Syntax error in #{file}:#{line}: #{message}"
    %__MODULE__{line: line, file: file, message: full_message}
  end
end
