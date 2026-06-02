cask "9quoter" do
  version "0.1.7"
  sha256 "83bb0df6c57240d73c9c7386c0f8f5a0f53b0867b7c2f865ca2d7589c6b2397c"

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
