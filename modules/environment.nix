{ config, lib, pkgs, username, timezone, ... }:

{
  time.timeZone = timezone;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    HYPRLAND_CONFIG = "/home/${username}/.config/hypr/hyprland.lua";
    QML2_IMPORT_PATH = "/run/current-system/sw/lib/qt-6/qml";
    QML_IMPORT_PATH  = "/run/current-system/sw/lib/qt-6/qml";

    PRISMA_SCHEMA_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/schema-engine";
    PRISMA_QUERY_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/query-engine";
    PRISMA_QUERY_ENGINE_LIBRARY = "${pkgs.prisma-engines}/lib/libquery_engine.node";
    PRISMA_FMT_BINARY = "${pkgs.prisma-engines}/bin/prisma-fmt";
  };

  programs.fish.enable = true;
  programs.zoxide.enable = true;


  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    stdenv.cc.cc.lib
    zlib
    fuse3
    alsa-lib
    at-spi2-core
    dbus
    glib
    gtk3
    libGL
    libappindicator-gtk3
    libnotify
    libxcb
    libxkbcommon
    mesa
    nspr
    nss
    pango
    pipewire
    systemd
    icu
    openssl
    libX11
    libxkbfile
    libSM
    libICE
    xcbutilcursor
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libxcb
    libxshmfence
    
    libpulseaudio
    fontconfig
    freetype
    libxml2
    expat
    libpng
    libbsd
    libuuid
    libdrm
    libsecret
    libXcomposite
    vulkan-loader
  ];
}
