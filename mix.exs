defmodule Opex62541.MixProject do
  use Mix.Project

  def project do
    [
      app: :opex62541,
      version: "0.1.0",
      elixir: "~> 1.9",
      name: "ABex",
      description: description(),
      #package: package(),
      source_url: "https://github.com/valiot/opex62541",
      start_permanent: Mix.env() == :prod,
      compilers: [:cmake] ++ Mix.compilers(),
      docs: [extras: ["README.md"], main: "readme"],
      build_embedded: true,
      cmake_lists: "src/",
      deps: deps()
    ]
  end

  defp description() do
    "Elixir wrapper for open62541, An open source implementation of OPC UA (OPC Unified Architecture) aka IEC 62541."
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_cmake, github: "valiot/elixir-cmake", branch: "dev"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
