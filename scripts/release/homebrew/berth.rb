class Berth < Formula
  desc "Emulator and simulator lease broker for parallel agents"
  homepage "https://github.com/LunabeeStudio/berth"
  url "https://github.com/LunabeeStudio/berth/releases/download/v{{VERSION}}/berth-macos-arm64.tar.gz"
  sha256 "{{SHA256}}"
  license "MIT"

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "berth", "berth-bar"
  end

  def caveats
    <<~EOS
      Next steps:
        berth prepare <AVD>     boot an AVD once and save its clean snapshot
        berth status            show the pool and the leases
        berth daemon install    optional, start the broker at login
        berth-bar               show the menu-bar status item

      Updates come from Homebrew: run `brew upgrade berth`.
      `berth update` and auto update are off. An idle daemon restarts into the new version by itself.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/berth --version")
  end
end
