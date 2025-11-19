KDE Plasma Dotfiles

A collection of configuration files (dotfiles) for a clean, high-contrast, and productive KDE Plasma desktop environment on Arch Linux.

The goal of this repository is to provide a consistent, minimalist aesthetic using the Catppuccin color scheme (Mocha).
🚀 Included Configurations
Starship Prompt - Monochrome Versions

This collection includes two variants of the Starship prompt, both customized for a high-contrast, monochrome (grayscale) aesthetic using the Catppuccin Mocha palette. They share the following core features:

    Minimalist monochrome gradient for a clean look.

    The system time (%R) is highly visible on the darkest background.

    User and OS display.

    Full Git status and branch support.

Available Versions (found in the starship directory):

    Light → Dark Gradient (starship/light_dark_preset.toml) The prompt starts with lighter shades (like gray/white) at the beginning (OS, User) and transitions to darker shades (like black) towards the end (Time).

    Dark → Light Gradient (starship/dark_light_preset.toml) The prompt starts with darker shades (like black) at the beginning (OS, User) and transitions to lighter shades (like white/gray) towards the end (Time).

Rofi (Application Launcher)

The Rofi configurations are set up to provide a fast, visually matching application launcher and custom menu replacement.

Component
	

Description
	

File Location

config.rasi
	

The main Rofi configuration file.
	

rofi/config.rasi

tokyo.rasi
	

A custom color scheme or theme specific to your visual setup.
	

rofi/tokyo.rasi
📸 Previews
Preview: Starship Light → Dark

This is what the Starship terminal prompt looks like using the Light → Dark configuration:

(Action required: Upload the screenshot showing the Light → Dark gradient to assets/starship-light-dark.png)
Preview: Starship Dark → Light

This is what the Starship terminal prompt looks like using the Dark → Light configuration:

(Action required: Upload the screenshot showing the Dark → Light gradient to assets/starship-dark-light.png)
Preview: Rofi Application Launcher

This is what the Rofi launcher looks like with the custom tokyo.rasi theme:

(Action required: Upload a screenshot of your Rofi launcher to assets/rofi-preview.png)
📦 Installation

To install these dotfiles, you can clone the repository and use a tool like GNU Stow, or manually symlink the files into your system's configuration directories.

Manual Installation (Examples):
Starship

    Choose your config (e.g., light_dark_preset.toml).

    Backup your existing Starship configuration:

    mv ~/.config/starship.toml ~/.config/starship.toml.bak

    Symlink the new config:

    # Link the chosen file to the standard Starship path
    ln -s ~/path/to/this/repo/starship/light_dark_preset.toml ~/.config/starship.toml

Rofi

    Backup your Rofi config folder:

    mv ~/.config/rofi ~/.config/rofi.bak

    Symlink the new Rofi config:

    # Link the entire rofi folder
    ln -s ~/path/to/this/repo/rofi ~/.config/rofi

🔗 Attribution

This preset uses colors derived from the Catppuccin project.
