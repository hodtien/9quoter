cask "9quoter" do
  version "0.1.2"
  sha256 "0c16fc00c1a7f594c09f2510ff6fbae0aad93f862e4478cb2aa5b2ce3dc4ed09"

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
