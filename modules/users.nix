{ config, lib, pkgs, ... }:

{
  users.users.xyreltenz = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "adbusers" "kvm" ];
    shell = pkgs.fish;
  };
}
