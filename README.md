<p align="center"><img src="assets/splash.png" alt="Devcraft Logo"></p>

A lightweight wrapper for [PortableMC](https://github.com/theorzr/portablemc), a versatile Minecraft launcher in the command line.

Provides an easy way for developers to spin up offline Minecraft sessions with any loader and mods.

Designed mainly for Windows systems with Powershell terminals.

## Installation

If you want to adapt this project to your needs, simply clone it with Git.

However, you can also run the following command to install it automatically:

```powershell
irm https://raw.githubusercontent.com/jirisitera/devcraft/main/scripts/install.ps1 | iex
```

Or you can use a shorter command using my domain link:

```powershell
irm https://japicraft.com/mc | iex
```

## Usage

1. Open **Devcraft** via your Start Menu or Desktop shortcut.
2. A prompt window will appear asking for a username.
3. After entering your desired username, the client will automatically download any necessary game files (if it's your first time) and launch the game.

### Mod Support

If you want to distribute a specific set of mod, simply create a `mods.json` file inside the `game/` directory. On launch, it will automatically download any missing mods defined in this file.

**Format of `game/mods.json`:**

```json
{
    "mods": [
        {
            "filename": "example-mod.jar",
            "url": "https://example.com/mod.jar"
        }
    ]
}
```

## Building

If you want to modify the launcher and compile your own executable, you can use the included build script. This script automatically converts the project's icon and uses `ps2exe` to package `run.ps1` into `devcraft.exe`.

1. Clone this repository.
2. Run the build script in PowerShell:

```powershell
.\scripts\build.ps1
```

*(Note: If you do not have `ps2exe` installed, the build script will attempt to install it for you automatically).*

## License

This project is licensed under the MIT License. See the [LICENSE.txt](LICENSE.txt) file for more details.
