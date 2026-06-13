{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # Hyprland compositor
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # Display manager
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # SDDM
  programs.silentSDDM = {
    enable = true;
    theme = "silvia";
  };

  # Hardware
  hardware.graphics.enable = true;
  hardware.bluetooth.enable = true;

  # XDG desktop portal
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };
}
