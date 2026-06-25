{ pkgs ? import <nixpkgs> {} }:

let
  localPkgs = import pkgs.path {
    config = {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
  };

  # Configure Android SDK permissions and components using the customized localPkgs
  androidComposition = localPkgs.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "11.0"; 
    toolsVersion = "26.1.1";
    platformToolsVersion = "35.0.2";
    buildToolsVersions = [ "34.0.0" "35.0.0" ];
    platformVersions = [ "34" "35" ];
    abiVersions = [ "armeabi-v7a" "arm64-v8a" "x86_64" ];
    includeEmulator = false; 
    includeSources = false;
    includeSystemImages = false;
  };
in
localPkgs.mkShell {
  buildInputs = [
    localPkgs.flutter
    localPkgs.dart

    androidComposition.androidsdk
    localPkgs.mesa-demos

    localPkgs.atk
    localPkgs.cairo
    localPkgs.gdk-pixbuf
    localPkgs.glib
    localPkgs.gtk3
    localPkgs.harfbuzz
    localPkgs.pango
    localPkgs.pcre2
    localPkgs.pkg-config
    localPkgs.libX11
  ];

  shellHook = ''
    export ANDROID_HOME="${androidComposition.androidsdk}/libexec/android-sdk"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
    
    # Expose graphic drivers for Wayland/XCB rendering verification
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib:$LD_LIBRARY_PATH"

    echo "⚡ Flutter & Android SDK development environment loaded! ⚡"
  '';
}