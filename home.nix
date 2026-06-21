{ config, pkgs, lib, ... }:

let
  repoPath = "/home/xyreltenz/nixos-config/.config";
  androidSdk = pkgs.androidenv.composeAndroidPackages {
    abiVersions = [ "x86_64" ];
    platformVersions = [ "34" ];
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis_playstore" ];
  };
in
{
  home.username = "xyreltenz";
  home.homeDirectory = "/home/xyreltenz";
  home.stateVersion = "26.05";

  home.packages = [
    androidSdk.androidsdk
  ];

  home.sessionVariables = {
    ANDROID_HOME = "${androidSdk.androidsdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidSdk.androidsdk}/libexec/android-sdk";
  };

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
    _linkConfig "matugen"             "matugen"
    _linkConfig "brave-theme"          "brave-theme"

    # Starship config lives at ~/.config/starship.toml
    ln -sfn "${repoPath}/starship.toml" "$HOME/.config/starship.toml"

    # Link fastfetch lantern logo
    mkdir -p "$HOME/.config/fastfetch"
    ln -sfn "${repoPath}/fastfetch/lantern.txt" "$HOME/.config/fastfetch/lantern.txt"

    # Create placeholders for matugen and ricelin cache outputs to prevent startup crashes
    mkdir -p "$HOME/.cache/matugen"
    touch "$HOME/.cache/matugen/ghostty-colors"
    touch "$HOME/.cache/matugen/hypr-colors.lua"
    mkdir -p "$HOME/.cache/ricelin"
    touch "$HOME/.cache/ricelin/colors.json"
    touch "$HOME/.cache/ricelin/ghostty-colors"
    touch "$HOME/.cache/ricelin/hypr-colors.lua"
  '';
}
