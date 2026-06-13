{ config, lib, pkgs, ... }:

{
  users.users.xyreltenz = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "adbusers" ];
    shell = pkgs.fish;
  };
}
