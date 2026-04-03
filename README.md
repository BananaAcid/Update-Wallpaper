# Update-Wallpaper - Periodically recolor your desktop wallpaper with AI

Change the windows wallpaper with AI generated images, based on an existing image, colored and tinted to a specific color

This project uses the free LLMs from https://Pollinations.ai and is based on my PowerShell library [PollinationsAiPS](https://github.com/BananaAcid/PollinationsAiPS) (GitHub).

## Wikipedia Logo Example

![Examples](https://github.com/user-attachments/assets/c06a20f9-4857-40ad-96f1-7f2efae537bc)

[Wiki Logo](https://upload.wikimedia.org/wikipedia/en/thumb/8/80/Wikipedia-logo-v2.svg/960px-Wikipedia-logo-v2.svg.png) and [WikiComons/Banana](https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Banana_on_whitebackground.jpg/1280px-Banana_on_whitebackground.jpg)

## Usage
Works best with logos. Since most AI models have different output sizes. Set your Desktop background color to the same as in -BackgroundColor.

The commands below, are all run in PowerShell. <kbd>Win+R</kbd> -> `pwsh` or on older windows systems: <kbd>Win+R</kbd> -> `powershell`.

```ps1
# list all available free models that are compatible (some might not work)
.\Update-Wallpaper -List


# Test it with an image from the internet (default prompt: recolor and tint)
.\Update-Wallpaper -Image "https://upload.wikimedia.org/wikipedia/en/thumb/8/80/Wikipedia-logo-v2.svg/960px-Wikipedia-logo-v2.svg.png"


# get your image ready
Add-PollinationsAiFile .\myImage.jpg  # shows: https://media.pollinations.ai/dc4e764fed4d7a96
.\Update-Wallpaper -Image "https://media.pollinations.ai/dc4e764fed4d7a96"
```

### If you are ready to set automate it

1. edit `.\wallpaper_config.ps1` and add all your tested `-Param Value` as `$Param = "Value"` to it

2. add to windows task scheduler to always after run after 10 minutes when you logon and get to your desktop
    ```ps1
    .\Update-Wallpaper -Task Add -Inteval (New-TimeSpan -Minutes 10) -ConfigFile (Path-Resolve .\wallpaper_config.ps1)
    ```

To remove the task later on `.\Update-Wallpaper -Task Remove`

## Installation

1. Save at least the `Update-Wallpaper.ps1` to a folder (where it can stay: like  Documents)
2. To the same folder, you need to download the Set-Wallpaper script (Update 08/10/2020) from https://www.joseespitia.com/2017/09/15/set-wallpaper-powershell-function/  and save it as **`.\set-wallpaper.ps1`**
    - ⚠️ But DO NOT include the last line that says `Set-WallPaper -Image "C:\Wallpaper\Background.jpg" -Style Fit`
3. open powershell
4. `cd ~\Documents` or where you saved your scripts
5. Install dependency the very first time: `Install-Module PollinationsAiPS -Force ; Import-Module PollinationsAiPS`

5. Use `.\Update-Wallpaper`

## Advanced usage
```ps1
# test it with a custom prompt
$Content = "Make it glow in {Color} and fill background with {BackgroundColor} and show some outerspace but less to the image edges"    # we want to center it on the screen and fill the background with black
$Uri = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Banana_on_whitebackground.jpg/1280px-Banana_on_whitebackground.jpg"
$settings = @{ width = "2048"; height = "1152" }
.\Update-Wallpaper -Color yellow -Content $Content -Image $Uri -Settings $settings
```

### NOTES
All paths should be absolute, when using `-TaskScheduler` !!!

If a wallpaper_config.ps1 file is found, it will be used as the config

Logo Reference: https://en.wikipedia.org/wiki/File:Wikipedia-logo-v2.svg


## Parameters

| Param | Default | Type | Description |
| --- | --- | --- | --- |
| `-ConfigFile` | `".\wallpaper_config.ps1"` | string | Path to config file containing param defaults. Set to `$null` to disable. |
| `-ImageUri` | (Wikipedia Logo) | string | URL or local path to the base image to colorize. Can be first positional argument. |
| `-Color` | (random from `-Colors`) | string | Color to apply. If empty, picks random from `-Colors` list. |
| `-BackgroundColor` | `"black"` | string | Background fill color (uniform). |
| `-Model` | `"qwen-image"` | string | AI model to use. Use `"?"` to auto-select cheapest free model. |
| `-Force` | `$false` | switch | Always regenerate wallpaper, bypass PollinationsAI cache. |
| `-Settings` | `@{}` | hashtable | Extra model-specific API parameters (seed, quality, etc). E.g. `@{ width = "2048"; height = "1152" }` |
| `-Path` | `".\wallpapers"` | string | Directory to save generated wallpapers. |
| `-Colors` | Builtin `@("red", "green", ...)` | string[] | List of colors for random selection when `-Color` is empty. |
| `-Content` | Builtin default prompt | string | System prompt template. Use `{Color}` and `{BackgroundColor}` placeholders. |
| `-Test` | `$false` | switch | Preview only; do not actually set wallpaper. |
| `-ListModels` | `$false` | switch | List all free compatible image models and exit. |
| `-TaskScheduler` | | string | Add/Remove scheduled task: `"add"` or `"remove"`. |
| `  -Interval` | `(New-TimeSpan -Hours 1)` | TimeSpan | **Depends on: `-TaskScheduler add`** — Frequency to run task. |
| `-Debug` | $false | switch | Show used params. |
