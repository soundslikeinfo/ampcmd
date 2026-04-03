class Ampcmd < Formula
  desc "Chain multiple shell history commands using fuzzy selection"
  homepage "https://github.com/soundslikeinfo/ampcmd"
  url "https://github.com/soundslikeinfo/ampcmd/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  license "MIT"
  head "https://github.com/soundslikeinfo/ampcmd.git", branch: "main"

  depends_on "fzf"

  def install
    # Install shell-specific scripts
    (prefix/"zsh").install "src/ampcmd.zsh" => "ampcmd.zsh"
    (prefix/"zsh").install "src/ampcmd.plugin.zsh" => "ampcmd.plugin.zsh"
    (prefix/"bash").install "src/ampcmd.bash" => "ampcmd.bash"
    (prefix/"fish").install "src/ampcmd.fish" => "ampcmd.fish"
    
    # Install fish function to proper location
    fish_function = share/"fish/vendor_functions.d/ampcmd.fish"
    fish_function.install "src/ampcmd.fish"
  end

  def caveats
    <<~EOS
      Add the following to your shell configuration:
      
      For zsh (~/.zshrc):
        source #{opt_prefix}/zsh/ampcmd.plugin.zsh
      
      For bash (~/.bashrc):
        source #{opt_prefix}/bash/ampcmd.bash
      
      For fish (~/.config/fish/config.fish):
        bind \\ch 'ampcmd | read -l key; read -l cmd; and begin; switch $key; case ctrl-y; echo -n $cmd | pbcopy; or echo -n $cmd | xclip -selection clipboard; or echo -n $cmd | xsel --clipboard; echo "Copied to clipboard"; case "*"; commandline -- $cmd; commandline -f execute; end; end'
      
      Then reload: exec $SHELL
    EOS
  end

  test do
    assert_match "ampcmd", shell_output("#{prefix}/zsh/ampcmd.zsh 2>&1 || true")
  end
end