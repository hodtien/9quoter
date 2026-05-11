cask "9quoter" do
  version "0.1.0"
  sha256 "289f0ad06a9570ae2034c45a80ac06e3918c0dcc1f3203ada894e7937d627e24"

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
