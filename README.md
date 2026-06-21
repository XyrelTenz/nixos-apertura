# NixOS Configuration

A custom NixOS flake and Home Manager setup, custom-built for high-performance desktop layouts (Hyprland + Quickshell), terminal environments (Ghostty + Fish), and modern development workflows (Flutter, Android, TypeScript/React).

## Customizing for Your System (Other Users)

To adapt this configuration for another machine or user:

1. **Set your username:** Open [flake.nix](file:///home/xyreltenz/nixos-config/flake.nix) and change the `username` variable at the top of the outputs:
   ```nix
   let
     username = "your-username";
   in { ... }
   ```
2. **Set your hostname:** Open [flake.nix](file:///home/xyreltenz/nixos-config/flake.nix) and change the configuration attribute name and hostname to your preference:
   ```nix
   nixosConfigurations.yourHostName = nixpkgs.lib.nixosSystem { ... }
   ```
3. **Configure Hardware:** Copy your machine's `/etc/nixos/hardware-configuration.nix` over the repository's `hardware-configuration.nix` to ensure proper boot/mount settings for your specific hardware.
4. **Rebuild:** Deploy using your configuration name:
   ```bash
   sudo nixos-rebuild switch --flake .#yourHostName
   ```

---

## Repository Structure

```
nixos-config/
├── flake.nix                  → NixOS flake inputs, outputs, and system architecture
├── flake.lock                 → Locked dependency versions
├── configuration.nix          → System-level imports and configurations
├── home.nix                   → User-level Home Manager activation and configurations
├── modules/                   → Individual NixOS system module declarations
│   ├── boot.nix               → Bootloader settings
│   ├── networking.nix         → Network config (NetworkManager)
│   ├── audio.nix              → Pipewire audio setup
│   ├── fonts.nix              → NERD fonts & Unicode Japanese support
│   ├── users.nix              → System user declarations
│   ├── desktop.nix            → Hyprland, SilentSDDM, Flatpak, & graphics drivers
│   ├── environment.nix        → Timezone, session variables, shell registration
│   └── packages.nix           → System packages & dev tools (Android Studio, Neovim)
└── .config/                   → User configuration files (symlinked directly to ~/.config)
    └── (See .config/README.md for details)
```

---

## Getting Started

### 1. Installation and Rebuild
To apply changes to the system:

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#XyrelTenz
```

### 2. Installing Roblox (Sober)
The flatpak service is configured automatically. Run the following user commands to install Sober:

```bash
# Add the flathub remote catalog
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install the Sober client
flatpak install --user flathub org.vinegarhq.Sober
```

### 3. Keybindings
- **Super + Return**: Open Ghostty
- **Super + Space**: Launch App Launcher (Quickshell)
- **Super + C**: Select wallpapers
- **Super + B**: Shuffle wallpaper
- **Super + V**: Clipboard history
- **Super + L**: Lock screen
- **Print**: Capture screenshot (rishot)
