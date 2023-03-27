defmodule PlugGpgVerify.MixProject do
  use Mix.Project

  def project do
    [
      app: :plug_gpg_verify,
      version: "0.1.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package() do
    [
      maintainers: ["Matt Silbernagel"],
      description: "A simple plug for verifing a public_key",
      links: %{:GitHub => "https://github.com/silbermm/plug_gpg_verify"},
      licenses: ["GPL-3.0-or-later"],
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "COPYING*"
      ]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.29.1"},
      {:gpgmex, "~> 0.0.10"},
      {:plug, "~> 1.14"},
      {:diceware, "~> 0.2.8"},
      {:req, "~> 0.3"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0.2", only: [:test]}
    ]
  end

  defp docs do
    [
      main: "PlugGPGVerify",
      api_reference: false,
      extras: [
        "README.md": [filename: "readme", title: "Readme"],
        "CHANGELOG.md": [filename: "changelog", title: "Changelog"],
        COPYING: [filename: "COPYING", title: "License"]
      ],
      authors: ["Matt Silbernagel"],
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@8.13.3/dist/mermaid.min.js"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        mermaid.initialize({ startOnLoad: false });
        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition, function (svgSource, bindListeners) {
            graphEl.innerHTML = svgSource;
            bindListeners && bindListeners(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""
end
