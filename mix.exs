defmodule Opex62541.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/valiot/opex62541"

  def project do
    [
      app: :opex62541,
      version: @version,
      elixir: "~> 1.9",
      name: "Opex62541",
      docs: docs(),
      description: description(),
      package: package(),
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      compilers: [:cmake] ++ Mix.compilers(),
      build_embedded: true,
      cmake_lists: "src/",
      aliases: aliases(),
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
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/opex62541",
      logo: "docs/images/valiot-logo-blue.png",
      extra_section: "Tutorials",
      source_url: @source_url,
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: [
        "OPC UA Stack": [
          OpcUA.Client,
          OpcUA.Server,
          OpcUA.Common,
        ],
        "Information Modeling": [
          OpcUA.BaseNodeAttrs,
          OpcUA.VariableNode,
          OpcUA.VariableTypeNode,
          OpcUA.MethodNode,
          OpcUA.ObjectNode,
          OpcUA.ObjectTypeNode,
          OpcUA.ReferenceTypeNode,
          OpcUA.DataTypeNode,
          OpcUA.ViewNode,
          OpcUA.ReferenceNode,
          OpcUA.MonitoredItem
        ],
        "Extra": [
          OpcUA.ExpandedNodeId,
          OpcUA.NodeId,
          OpcUA.QualifiedName,
          Opex62541 
        ]
      ]
    ]
  end

  def extras() do
    [
      "README.md",
      "CHANGELOG.md",
      "docs/introduction/Introduction.md",
      "docs/tutorials/Lifecycle.md",
      "docs/tutorials/Security.md",
      "docs/tutorials/Discovery.md",
      "docs/tutorials/Information Manipulation.md",
      "docs/tutorials/Terraform.md"
    ]
  end

  defp groups_for_extras() do
    [
      "Introduction": ~r/docs\/introduction\/.?/,
      "Tutorials": ~r/docs\/tutorials\/.?/
    ]
  end

  defp aliases do
    [docs: ["docs", &copy_images/1]]
  end

  defp copy_images(_) do
    File.ls!("docs/images")
    |> Enum.each(fn x ->
      File.cp!("docs/images/#{x}", "doc/assets/#{x}")
    end)
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
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
    ]
  end
end
