if status is-interactive
    # ── Useful abbreviations ──────────────────────────────────────────
    abbr -a ll  'ls -lah'
    abbr -a la  'ls -A'
    abbr -a g   'git'
    abbr -a gs  'git status'
    abbr -a gp  'git push'
    abbr -a gl  'git pull'
    abbr -a gc  'git commit -m'
    abbr -a lg  'lazygit'
    abbr -a nrs 'sudo nixos-rebuild switch --flake .#XyrelTenz'
    abbr -a v   'nvim'
    abbr -a cat 'bat'
    abbr -a ff  'fastfetch'

    # ── Tool integrations ─────────────────────────────────────────────
    if command -v zoxide >/dev/null 2>&1
        zoxide init fish | source
    end
    if command -v starship >/dev/null 2>&1
        starship init fish | source
    end

    # ── Environment ───────────────────────────────────────────────────
    fish_add_path ~/.local/bin
    fish_add_path ~/.cargo/bin
    fish_add_path ~/Android/Sdk/cmdline-tools/latest/bin
    fish_add_path ~/Android/Sdk/emulator
    fish_add_path ~/Android/Sdk/platform-tools

    alias bun='env LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib:$LD_LIBRARY_PATH bun'
    alias npx='env LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib:$LD_LIBRARY_PATH npx'
    alias npm='env LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib:$LD_LIBRARY_PATH npm'
    alias yarn='env LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib:$LD_LIBRARY_PATH yarn'
    alias node='env LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib:$LD_LIBRARY_PATH node'

    set -x ANDROID_HOME ~/Android/Sdk
    set -x ANDROID_SDK_ROOT ~/Android/Sdk
    set -x ANDROID_AVD_HOME ~/.config/.android/avd

    set -x DIRENV_LOG_FORMAT ""

    set -x EDITOR nvim
    set -x VISUAL nvim
end

function fish_greeting
    if status is-interactive
        ~/.config/fish/torii-greeting.sh
    end
end
