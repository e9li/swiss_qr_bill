defmodule SwissQrBill.MixProject do
  use Mix.Project

  def project do
    [
      app: :swiss_qr_bill,
      version: "0.2.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Swiss QR-bill generation library (QR-Rechnung) per SIX v2.4 spec (also conformant to v2.3)",
      package: package(),
      source_url: "https://git.e9li.com/e9li/swiss_qr_bill.git",
      name: "SwissQrBill",
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:qr_code, "~> 3.2"},
      {:pdf, "~> 0.8"},
      {:decimal, "~> 3.1"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Rafael Egli"],
      licenses: ["MIT"],
      links: %{
        "Repository" => "https://git.e9li.com/e9li/swiss_qr_bill"
      }
    ]
  end
end
