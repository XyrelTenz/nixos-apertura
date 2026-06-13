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
    _linkConfig "kitty"               "kitty"
    _linkConfig "cava"                "cava"
    _linkConfig "nvim"                "nvim"
    _linkConfig "quickshell/Apertura" "quickshell/Apertura"
    _linkConfig "fish"                "fish"

    # Starship config lives at ~/.config/starship.toml
    ln -sfn "${repoPath}/starship.toml" "$HOME/.config/starship.toml"
  '';
}
