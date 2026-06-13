{ config, lib, pkgs, ... }:

{
  fonts.packages = with pkgs; [
    material-symbols
    rubik
    nerd-fonts.symbols-only
    nerd-fonts.jetbrains-mono
  ];
}
