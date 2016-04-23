defmodule SpecTest do
  use ExUnit.Case

  defmodule SpecReader do
    @specdir "test/specs"
    @ignore [
      :lambdas, :delimiters, :inverted,
      :partials, :sections, :comments
    ]

    def load_specs do
      ignore = @ignore |> Enum.map(fn n -> to_string(n) <> ".yml" end)

      unless Enum.empty?(ignore) do
        IO.puts "Ignoring files in #{@specdir}: #{Enum.join(ignore, ", ")}"
      end

      File.ls!(@specdir)
      |> Enum.reject(&Enum.member?(ignore, &1))
      |> Enum.map(&Path.join(@specdir, &1))
      |> Enum.map(&:yaml.load_file(&1))
      |> Enum.flat_map(fn {:ok, [yaml]} ->
        keys_to_atoms(yaml["tests"])
      end)
    end

    def keys_to_atoms(list) when is_list(list) do
      Enum.map(list, &keys_to_atoms/1)
    end
    def keys_to_atoms(map) when is_map(map) do
      map
      |> Enum.map(fn {k, v} -> {String.to_atom(k), keys_to_atoms(v)} end)
      |> Enum.into(%{})
    end
    def keys_to_atoms(term), do: term
  end

  for %{desc: desc, data: data, template: tem, expected: exp} <- SpecReader.load_specs do
    @data data
    @exp exp
    @tem tem
    name = desc
      <> "\n     data:     #{inspect data}"
      <> "\n     template: #{inspect tem}\n"

    test name do
      assert Stache.eval_string(@tem, @data) == @exp
    end
  end
end
