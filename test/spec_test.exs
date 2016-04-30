defmodule SpecTest do
  use ExUnit.Case

  defmodule SpecReader do
    @specdir "test/specs"
    @ignore [
      :lambdas, :partials
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

  ## ==================== LAMBDAS ========================
  ## These tests are particularly difficult to import from
  ## the yaml spec files, although we code potentially use
  ## Code.eval_string to read the lambdas.
  ##
  ## These are included directly, unchanged from the spec.

  test "A lambda's return value should be interpolated." do
    template = "Hello, {{lambda}}!"
    expected = "Hello, world!"
    data = %{lambda: fn -> "world" end}

    assert Stache.eval_string(template, data) == expected
  end

  test "A lambda's return value should be parsed." do
    template = "Hello, {{lambda}}!"
    expected = "Hello, world!"
    data = %{lambda: fn -> "{{planet}}" end, planet: "world"}

    assert Stache.eval_string(template, data) == expected
  end

  @tag :skip
  test "A lambda's return value should parse with the default delimiters." do
    template = "{{= | | =}}\nHello, (|&lambda|)!"
    expected = "Hello, (|planet| => world)!"
    data = %{lambda: fn -> "|planet| => {{planet}}" end, planet: "world"}

    assert Stache.eval_string(template, data) == expected
  end

  test "Interpolated lambdas should not be cached." do
    # This is the test that was difficult to include in the YAML spec.
    {:ok, agent} = Agent.start_link fn -> 0 end
    f = fn ->
      Agent.update(agent, &(&1 + 1))
      Agent.get(agent, &(&1))
    end

    template = "{{lambda}} == {{{lambda}}} == {{lambda}}"
    expected = "1 == 2 == 3"
    data = %{lambda: f}

    assert Stache.eval_string(template, data) == expected
  end

  test "Lambda results should be appropriately escaped." do
    template = "<{{lambda}}{{{lambda}}}"
    expected = "<&gt;>"
    data = %{lambda: fn -> ">" end}

    assert Stache.eval_string(template, data) == expected
  end

  @tag :skip
  test "Lambdas used for sections should receive the raw section string." do
    template = "<{{#lambda}}{{x}}{{/lambda}}>"
    expected = "<yes>"
    data = %{x: "Error!", lambda: fn text -> if text == "{{x}}", do: "yes", else: "no" end}

    assert Stache.eval_string(template, data) == expected
  end

  @tag :skip
  test "Lambdas used for sections should have their results parsed." do
    template = "<{{#lambda}}-{{/lambda}}>"
    expected = "<-Earth->"
    data = %{planet: "Earth", lambda: fn text -> "#{text}{{planet}}#{text}" end}

    assert Stache.eval_string(template, data) == expected
  end

  @tag :skip
  test "Lambdas used for sections should parse with the current delimiters." do
    template = "{{= | | =}}<|#lambda|-|/lambda|>"
    expected = "<-{{planet}} => Earth->"
    data = %{planet: "Earth", lambda: fn text -> "#{text}{{planet}} => |planet|#{text}" end}

    assert Stache.eval_string(template, data) == expected
  end

  @tag :skip
  test "Lambdas used for sections should not be cached." do
    template = "{{#lambda}}FILE{{/lambda}} != {{#lambda}}LINE{{/lambda}}"
    expected = "__FILE__ != __LINE__"
    data = %{lambda: fn text -> "__#{text}__" end}

    assert Stache.eval_string(template, data) == expected
  end

  test "Lambdas used for inverted sections should be considered truthy." do
    template = "<{{^lambda}}{{static}}{{/lambda}}>"
    expected = "<>"
    data = %{static: "static", lambda: fn _ -> false end}

    assert Stache.eval_string(template, data) == expected
  end
end
