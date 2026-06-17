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
    abbr -a nrs 'sudo nixos-rebuild switch --flake ~/.nixos-config#'
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
    set -x EDITOR nvim
    set -x VISUAL nvim
end

function fish_greeting
    if status is-interactive
        ~/.config/fish/torii-greeting.sh
    end
end
