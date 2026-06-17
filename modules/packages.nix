{
  config,
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    wget
    git
    ghostty
    rofi
    fastfetch
    unzip
    go
    python3
    fish
    starship
    ripgrep
    wf-recorder
    slurp

    kdePackages.dolphin
    kdePackages.qtsvg
    waybar
    firefox

    neovim
    android-tools
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
    slurp
    satty
    hyprpicker
    wl-clipboard
    cava
    matugen
    awww
    brightnessctl
    wallust
    cliphist
    imagemagick
    jq
    zoxide
    ddcutil
    (symlinkJoin {
      name = "quickshell-wrapped";
      paths = [quickshell];
      nativeBuildInputs = [makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/qs \
          --prefix PATH : "${lib.makeBinPath [(python3.withPackages (ps: [ps.pyxdg])) bluez networkmanager wireplumber matugen awww cava bash brightnessctl grim slurp satty hyprpicker wl-clipboard wallust cliphist imagemagick jq ddcutil]}" \
          --prefix QML2_IMPORT_PATH : "${kdePackages.qt5compat}/lib/qt-6/qml" \
          --prefix QT_PLUGIN_PATH : "${kdePackages.qtimageformats}/lib/qt-6/plugins"
      '';
    })
  ];
}
