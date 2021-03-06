defmodule Stache.Mixfile do
  use Mix.Project

  def project do
    [app: :stache,
     version: "0.2.1",
     elixir: "~> 1.2",
     deps: deps,
     description: description,
     package: package
    ]
  end

  defp description do
    "Mustache templates in Elixir."
  end

  def package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Christian Briones"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/cwbriones/stache"
      }
    ]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [
      {:yamler, git: "https://github.com/goertzenator/yamler", tag: "16ebac5c", only: :test},
      {:ex_doc, "~> 0.11.4", only: :dev},
      {:earmark, "~> 0.2.1", only: :dev},
    ]
  end
end
