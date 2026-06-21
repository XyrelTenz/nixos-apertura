{pkgs ? import <nixpkgs> {config.android_sdk.accept_license = true; config.allowUnfree = true;}}: let
  android = pkgs.androidenv.composeAndroidPackages {
    platformVersions = ["34"];
    abiVersions = ["x86_64"];
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = ["google_apis_playstore"];
  };
in
  pkgs.mkShell {
    nativeBuildInputs = with pkgs; [
      clang
      cmake
      ninja
      pkg-config
      flutter
      jdk17
      android.androidsdk
    ];

    buildInputs = with pkgs; [
      gtk3
      pcre
      libepoxy
      libuuid
      xorg.libXdmcp
      libselinux
      libsepol
      libthai
      libdatrie
      libxkbcommon
      dbus
      at-spi2-core
      xorg.libXtst
      pcre2
      fontconfig
      sqlite
    ];

    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [pkgs.fontconfig pkgs.sqlite];

    ANDROID_HOME = "${android.androidsdk}/libexec/android-sdk";
  }
