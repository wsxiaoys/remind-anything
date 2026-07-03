# Homebrew Cask for Remind Anything.
#
# Copy this file into your tap repo (e.g. wsxiaoys/homebrew-tap) under
# `Casks/remind-anything.rb`.
# Update `version` and `sha256` on every release (Scripts/release.sh prints both).
cask "remind-anything" do
  version "1.0.0"
  sha256 "ea464b8a0af15087a8e1b87dfd50dba9cf013709fcca1870efa8e08c85e224c5"

  url "https://github.com/wsxiaoys/remind-anything/releases/download/v#{version}/Remind-Anything-#{version}.dmg"
  name "Remind Anything"
  desc "Capture anything on screen, attach a note, get reminded with context"
  homepage "https://github.com/wsxiaoys/remind-anything"

  depends_on macos: :sonoma # macOS 14+, matches LSMinimumSystemVersion

  app "Remind Anything.app"

  zap trash: [
    "~/Library/Application Support/RemindAnything",
    "~/Library/Preferences/com.mengzhang.RemindAnything.plist",
  ]
end
