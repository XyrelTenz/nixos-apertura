{pkgs ? import <nixpkgs> {config.android_sdk.accept_license = true;}}: let
  android = pkgs.androidenv.composeAndroidPackages {
    platformVersions = ["34"];
    abiVersions = ["arm64-v8a"];
    includeEmulator = true;
    includeSystemImages = true;
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
