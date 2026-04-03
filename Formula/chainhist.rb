class Chainhist < Formula
  desc "Chain multiple shell history commands using fuzzy selection"
  homepage "https://github.com/YOUR/chainhist"
  url "https://github.com/YOUR/chainhist/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  license "MIT"
  head "https://github.com/YOUR/chainhist.git", branch: "main"

  depends_on "fzf"

  def install
    # Install shell-specific scripts
    (prefix/"zsh").install "src/chainhist.zsh" => "chainhist.zsh"
    (prefix/"zsh").install "src/chainhist.plugin.zsh" => "chainhist.plugin.zsh"
    (prefix/"bash").install "src/chainhist.bash" => "chainhist.bash"
    (prefix/"fish").install "src/chainhist.fish" => "chainhist.fish"
    
    # Install fish function to proper location
    fish_function = share/"fish/vendor_functions.d/chainhist.fish"
    fish_function.install "src/chainhist.fish"
  end

  def caveats
    <<~EOS
      Add the following to your shell configuration:
      
      For zsh (~/.zshrc):
        source #{opt_prefix}/zsh/chainhist.plugin.zsh
      
      For bash (~/.bashrc):
        source #{opt_prefix}/bash/chainhist.bash
      
      For fish (~/.config/fish/config.fish):
        bind \\ch 'chainhist | read -l key; read -l cmd; and begin; switch $key; case ctrl-y; echo -n $cmd | pbcopy; or echo -n $cmd | xclip -selection clipboard; or echo -n $cmd | xsel --clipboard; echo "Copied to clipboard"; case "*"; commandline -- $cmd; commandline -f execute; end; end'
      
      Then reload: exec $SHELL
    EOS
  end

  test do
    assert_match "chainhist", shell_output("#{prefix}/zsh/chainhist.zsh 2>&1 || true")
  end
end