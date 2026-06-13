import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: theme

    property string configPath: "/tmp/qs_colors.json"
    property string fallbackConfigPath: Quickshell.env("HOME") + "/.config/quickshell/Apertura/Colors/colors.json"

    property color theme_bg: "#9911111b"
    property color theme_primary: "#ffffff"
    property color theme_onPrimary: "#11111b"
    property color theme_fg: "#ffffff"
    property color theme_outline: "#26ffffff"

    FileView {
        id: colorConfigReader
        path: theme.configPath
        preload: true

        onTextChanged: {
            try {
                let rawText = text();
                if (rawText && rawText.trim() !== "") {
                    let parsed = JSON.parse(rawText);
                    if (parsed && parsed.base && parsed.text) {
                        theme.theme_bg = parsed.base;
                        theme.theme_primary = parsed.blue || parsed.mauve || "#ffffff";
                        theme.theme_onPrimary = parsed.crust || "#11111b";
                        theme.theme_fg = parsed.text;
                        theme.theme_outline = parsed.subtext1 || parsed.surface2 || "#26ffffff";
                    }
                }
            } catch (e) {
                console.log("❌ FileView /tmp/qs_colors.json Processing Exception: " + e);
            }
        }
    }

    FileView {
        id: fallbackColorConfigReader
        path: theme.fallbackConfigPath
        preload: true

        onTextChanged: {
            // Only use fallback if tmp colors are not loaded / default values
            if (theme.theme_bg === "#9911111b" || theme.theme_primary === "#ffffff") {
                try {
                    let rawText = text();
                    if (rawText && rawText.trim() !== "") {
                        let parsed = JSON.parse(rawText);
                        if (parsed && parsed.colors) {
                            if (parsed.colors.background && parsed.colors.background.dark && parsed.colors.background.dark.color)
                                theme.theme_bg = parsed.colors.background.dark.color;
                                
                            if (parsed.colors.primary && parsed.colors.primary.dark && parsed.colors.primary.dark.color)
                                theme.theme_primary = parsed.colors.primary.dark.color;
                                
                            if (parsed.colors.on_primary && parsed.colors.on_primary.dark && parsed.colors.on_primary.dark.color)
                                theme.theme_onPrimary = parsed.colors.on_primary.dark.color;
                                
                            if (parsed.colors.on_surface && parsed.colors.on_surface.dark && parsed.colors.on_surface.dark.color)
                                theme.theme_fg = parsed.colors.on_surface.dark.color;
                                
                            if (parsed.colors.outline && parsed.colors.outline.dark && parsed.colors.outline.dark.color)
                                theme.theme_outline = parsed.colors.outline.dark.color;
                        }
                    }
                } catch (e) {
                    console.log("❌ FileView fallback Colors Processing Exception: " + e);
                }
            }
        }
    }

    // Explicitly forces the FileView engine to discard cache and read disk bytes
    function reloadTheme() {
        colorConfigReader.reload();
        fallbackColorConfigReader.reload();
    }
}

