{ config, lib, pkgs, ... }:

{
  time.timeZone = "Asia/Manila";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    HYPRLAND_CONFIG = "/home/xyreltenz/.config/hypr/hyprland.lua";
    QML2_IMPORT_PATH = "/run/current-system/sw/lib/qt-6/qml";
    QML_IMPORT_PATH  = "/run/current-system/sw/lib/qt-6/qml";
  };

  # Registers fish in /etc/shells so it can be used as a login shell
  programs.fish.enable = true;
}
