defmodule SpecTest do
  use ExUnit.Case

  defmodule SpecReader do
    @specdir "test/specs"
    @ignore [
      :lambdas, :delimiters, :inverted,
      :partials
    ]

    def load_specs do
      ignore = @ignore |> Enum.map(fn n -> to_string(n) <> ".yml" end)

      unless Enum.empty?(ignore) do
        IO.puts "Ignoring files in #{@specdir}: #{Enum.join(ignore, ", ")}"
      end

      File.ls!(@specdir)
      |> Enum.reject(&Enum.member?(ignore, &1))
      |> Enum.map(&Path.join(@specdir, &1))
      |> Enum.map(&load_tests/1)
      |> Enum.flat_map(&prepare_tests/1)
    end

    def load_tests(file) do
      {:ok, [yaml]} = :yaml.load_file(file)
      {file, yaml}
    end

    def prepare_tests({file, yaml}) do
      yaml["tests"]
      |> keys_to_atoms
      |> Enum.with_index
      |> Enum.map(fn {test, idx} -> Map.merge(%{index: idx}, test) end)
      |> Enum.map(&Map.merge(%{file: file}, &1))
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

  for %{
    file: f,
    index: idx,
    desc: desc,
    data: data,
    template: tem,
    expected: exp
  } <- SpecReader.load_specs do
    @data data
    @exp exp
    @tem tem

    name = desc <> " in file #{f}:#{idx}"

    test name do
      result = Stache.eval_string(@tem, @data)
      message = "
      Rendering Failed for template: #{inspect @tem}
        context: #{inspect @data}
        expected: #{inspect @exp}
        rendered: #{inspect result}
      "
      assert result == @exp, message
    end
  end
end
