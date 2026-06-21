{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  matugenPkg = inputs.matugen.packages.${pkgs.stdenv.hostPlatform.system}.default;
  neovim-11 = inputs.nixpkgs-neovim-11.legacyPackages.${pkgs.stdenv.hostPlatform.system}.neovim;
  img2art = pkgs.python3.pkgs.buildPythonApplication rec {
    pname = "img2art";
    version = "0.4.3";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/14/4b/b62b1646a4908df80968ff31383c01412e8c17ecf6a343762d072f20600d/img2art-0.4.3-py3-none-any.whl";
      sha256 = "sha256-N47r/GbBAbJJoeYnmtNgR3hbdpq/hrMyC1i/Eb8WYiU=";
    };
    propagatedBuildInputs = with pkgs.python3.pkgs; [
      numpy
      opencv4
      typer
      typing-extensions
    ];
    pythonRemoveDeps = [ "opencv-python" ];
    pythonRelaxDeps = [ "typer" ];
    doCheck = false;
  };
in {
  environment.systemPackages = with pkgs; [
    wget
    git
    ghostty
    fastfetch
    unzip
    go
    python3
    fish
    starship
    ripgrep
    wf-recorder
    scrcpy

    kdePackages.dolphin
    kdePackages.qtsvg
    brave

    neovim-11
    android-tools
    android-studio
    tree-sitter
    flutter
    nodejs_22
    clang
    ninja
    cmake
    pkg-config
    cargo
    rustc

    clang-tools
    typescript
    typescript-language-server
    taplo
    vue-language-server
    lua-language-server
    gopls
    gotools
    golines
    go-tools
    sqls
    lazygit
    gcc
    dart
    jdt-language-server
    rust-analyzer
    slint-lsp
    tailwindcss-language-server
    vscode-langservers-extracted
    stylua
    golangci-lint
    nixd
    alejandra
    kdePackages.qtdeclarative
    prettier
    ktfmt
    google-java-format
    rustfmt

    zed-editor-fhs

    grim
    satty
    hyprpicker
    wl-clipboard
    cava
    matugenPkg
    awww
    brightnessctl
    cliphist
    imagemagick
    jq
    img2art
    vlc
    ddcutil
    gpu-screen-recorder
    ffmpeg
    (symlinkJoin {
      name = "quickshell-wrapped";
      paths = [quickshell];
      nativeBuildInputs = [makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/qs \
          --prefix PATH : "${lib.makeBinPath [(python3.withPackages (ps: [ps.pyxdg])) bluez networkmanager wireplumber matugenPkg awww cava bash brightnessctl grim slurp satty hyprpicker wl-clipboard cliphist imagemagick jq ddcutil gpu-screen-recorder ffmpeg]}" \
          --prefix QML2_IMPORT_PATH : "${kdePackages.qt5compat}/lib/qt-6/qml" \
          --prefix QT_PLUGIN_PATH : "${kdePackages.qtimageformats}/lib/qt-6/plugins"
      '';
    })
  ];
}
