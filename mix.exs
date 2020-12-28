defmodule Opex62541.MixProject do
  use Mix.Project

  def project do
    [
      app: :opex62541,
      version: "0.1.0",
      elixir: "~> 1.9",
      name: "opex62541",
      description: description(),
      package: package(),
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

  defp package() do
    [
      files: [
        "lib",
        "src",
        "test",
        "mix.exs",
        "README.md",
        "LICENSE"
      ],
      maintainers: ["valiot"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/valiot/opex62541"}
    ]
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
      {:elixir_cmake, github: "valiot/elixir-cmake", branch: "multi-projects"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end
end
