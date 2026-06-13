if status is-interactive
    # ── Starship prompt ───────────────────────────────────────────────
    starship init fish | source

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

    # ── Environment ───────────────────────────────────────────────────
    set -x EDITOR nvim
    set -x VISUAL nvim
end
