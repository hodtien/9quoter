cask "9quoter" do
  version "0.1.4"
  sha256 "5c1619dd66d0513f1de36dd7b2651b518bc3e9c08c9ab04914107d6f4303760a"

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
