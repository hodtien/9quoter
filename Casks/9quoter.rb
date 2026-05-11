cask "9quoter" do
  version "0.1.3"
  sha256 "eca85c58280788ca79c57f47f29dac660fcd40c0fe8fe907d314b460c858a8d5"

  url "https://github.com/hodtien/9quoter/releases/download/v#{version}/9Quoter-#{version}.zip"
  name "9Quoter"
  desc "macOS menu bar quota tracker for 9router providers"
  homepage "https://github.com/hodtien/9quoter"

  depends_on macos: ">= :ventura"

  app "9Quoter.app"

  zap trash: [
    "~/Library/Preferences/dev.hodtien.9quoter.plist",
  ]
end
