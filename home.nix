{ config, pkgs, lib, ... }:

let
  repoPath = "/home/xyreltenz/nixos-config/.config";
in
{
  home.username = "xyreltenz";
  home.homeDirectory = "/home/xyreltenz";
  home.stateVersion = "26.05";

  home.activation.linkDotfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _linkConfig() {
      local src="${repoPath}/$1"
      local dst="$HOME/.config/$2"
      mkdir -p "$(dirname "$dst")"
      rm -rf "$dst"
      ln -sfn "$src" "$dst"
    }

    _linkConfig "hypr"                "hypr"
    _linkConfig "ghostty"             "ghostty"
    _linkConfig "cava"                "cava"
    _linkConfig "nvim"                "nvim"
    _linkConfig "quickshell"          "quickshell"
    _linkConfig "fish"                "fish"
    _linkConfig "wallust"             "wallust"

    # Starship config lives at ~/.config/starship.toml
    ln -sfn "${repoPath}/starship.toml" "$HOME/.config/starship.toml"

    # Link fastfetch lantern logo
    mkdir -p "$HOME/.config/fastfetch"
    ln -sfn "${repoPath}/fastfetch/lantern.txt" "$HOME/.config/fastfetch/lantern.txt"

    # Create placeholders for wallust cache outputs to prevent startup crashes
    mkdir -p "$HOME/.cache/wallust"
    touch "$HOME/.cache/wallust/ghostty-colors"
    touch "$HOME/.cache/wallust/hypr-colors.lua"
  '';
}
