<#
    .AUTHOR     Nabil Redmann - 2026-03-29
    .DEPENDENCY https://www.joseespitia.com/2017/09/15/set-wallpaper-powershell-function/
    .LICENSE    MIT
    .VERSION    1.0
    .SYNOPSIS
        Change the windows wallpaper with AI generated images, based on an existing image, colored and tinted to a specific color

        Works best with logos. Since most AI models have different output sizes. Set your Desktop background color to the same as in -BackgroundColor.
    .EXAMPLE
        # list all available free models
        .\Update-Wallpaper -List

        # manual parameters
        .\Update-Wallpaper -Color red -Image "https://upload.wikimedia.org/wikipedia/en/thumb/8/80/Wikipedia-logo-v2.svg/960px-Wikipedia-logo-v2.svg.png"

        # manual config
        $Content = "Make it glow in {Color} and fill background with {BackgroundColor} and show some outerspace but less to the image edges"    # we want to center it on the screen and fill the background with black
        $Uri = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Banana_on_whitebackground.jpg/1280px-Banana_on_whitebackground.jpg"
        .\Update-Wallpaper -Color yellow -Content $Content -Image $Uri
    
        # add to taskscheduler
        .\Update-Wallpaper -Task Add -Inteval (New-TimeSpan -Minutes 10) -ConfigFile (Path-Resolve .\wallpaper_config.ps1)
        .\Update-Wallpaper -Task Remove
    .NOTES
        All paths should be absolute, when using -TaskScheduler !!!

        If a wallpaper_config.ps1 file is found, it will be used as the config

        Logo Reference: https://en.wikipedia.org/wiki/File:Wikipedia-logo-v2.svg

#>
[CmdletBinding()] # allow -Debug
param (
    [AllowNull()]   # so you can disable the config file when testing:  -config $Null
    [string]$ConfigFile = "$PSScriptRoot\wallpaper_config.ps1",  # a config file, may include $env:POLLINATIONSAI_API_KEY and other params -- needed if run by task scheduler. CAN ALSO SET $Debug = $true to work like -Debug

    [Parameter(Position=0)]  # image url can be the first param with out needing -ImageUri
    [string]$ImageUri = "https://upload.wikimedia.org/wikipedia/en/thumb/8/80/Wikipedia-logo-v2.svg/960px-Wikipedia-logo-v2.svg.png",
        [string]$Color,                     # empty will get a random color
        [string]$BackgroundColor = "black", # background color
        
        [string]$Model = "qwen-image",      # "?" will get the first free model (presumably the cheapest). Sometimes the APIs for some models are broken, others might suddenly disappear. Currently, qwen-image seems to work.
        
        [switch]$Force = $false,            # will always generate a new wallpaer and overwrite the saved one
        
        [hashtable]$Settings = @{},         # in case more params are needed (model specific), see: https://enter.pollinations.ai/api/docs#tag/%EF%B8%8F-image-generation/GET/image/{prompt}
        [string]$Path = "$PSScriptRoot\wallpapers",   # "$env:TEMP\wallpapers"  - Best: "$([Environment]::GetFolderPath("MyPictures"))\wallpapers"

        [string[]]$Colors = @("red", "green", "blue", "black", "white", "orange", "purple", "golden", "silver", "bronze", "metallic"), # some colors for the random selection
        [string][Alias("Prompt")]$Content = "Change the logo to be in {Color} with tint in {Color}. Fill background with a uniform {BackgroundColor}.",   # the system prompt, in case someone wants to change it

        [switch]$Test,                      # will not actually change the wallpaper

    [switch]$ListModels,                    # will list all free models

    # -TaskScheduler will take the -ConfigFile  and use it as a param for new the scheduled task
    [ValidateSet("add", "remove", ErrorMessage = "TaskScheduler must be one of the following values: add, remove")]
    [string]$TaskScheduler,                 # will use Windows Task Scheduler
        [TimeSpan]$Interval = (New-TimeSpan -Hours 1) # default is 1 hour
)

# make sure we have the module
Import-Module PollinationsAiPS -ErrorAction SilentlyContinue
If (-not (Test-Path Function:\Get-PollinationsAiImage) -or -not (Test-Path Function:\Get-PollinationsAiByok)) {
    Write-Error "PollinationsAiPS is not loaded. Run 'Import-Module PollinationsAiPS' first, or install the latest version with 'Install-Module PollinationsAiPS -Force'."
    return
}


# get free models, cheapest first
Function Get-FreeModels { return Get-PollinationsAiImage -List -Details |? paid_only -eq $false |? input_modalities -contains image |? output_modalities -contains image | sort -Property { [bool]($null -ne $_.pricing.promptTextTokens), $_.pricing.completionImageTokens } }

if ($ListModels) { return Get-FreeModels }

Function Invoke-UpdateWallpaper {

    # load the config file into current scope, if it exists
    If (Test-Path $ConfigFile -ErrorAction SilentlyContinue) { 
        Write-Output "ℹ️  Using config file: $ConfigFile"
        . $ConfigFile

        if ($Debug) { # from config
            $DebugPreference = 'Continue'
        }
    }

    # Help with setting up a key, if missing 
    if (-not $env:POLLINATIONSAI_API_KEY) {
        Get-PollinationsAiByok -Add
        if (-not $env:POLLINATIONSAI_API_KEY) {
            return
        }
    }


    # list of colors for random selection
    $Color = If ($Color) {$Color} else {Get-Random $Colors}

    # get the first free model
    If ($model -eq "?") {
        # be aware, some models are always broken ... this is not reliable. 
        $Model = Get-FreeModels | Select-Object -First 1 -ExpandProperty Name
    }

    Write-Output "⭐ Wallpaper in color $Color"

    # create wallpaper folder, if missing
    mkdir $Path -ErrorAction SilentlyContinue | Out-Null


    # known working sizes
    $sizes = switch ($Model) {
        "qwen-image" { @{ width = "2048"; height = "1152" } }
        "seedream" { @{ width = "3440"; height = "1440" } }
        default { @{} } # PollinationsAI seems to be @{"width" = 1021,"height" = 1021}
    }


    Write-Debug "_File:           $Path\wp_$BackgroundColor-$Color.jpg"
    Write-Debug "Path:            $Path"
    Write-Debug "ImageUri:        $ImageUri"
    Write-Debug "Model:           $Model"
    Write-Debug "Color:           $Color"
    Write-Debug "Colors:          $Colors"
    Write-Debug "BackgroundColor: $BackgroundColor"
    Write-Debug "_Sizes:          $($sizes | ConvertTo-JSON -Compress)"
    Write-Debug "Settings:        $($Settings | ConvertTo-JSON -Compress)"
    Write-Debug "Content:`n$Content"


    # Only generate if it does not exist, for speed (reduces unnecessary calls and the model takes its time)
    # You can add for seedream `width = "3440"; height = "1440";` and qwen-image `width = "2048"; height = "1152";` or whatever you need, to the -Settings to force the output size
    if (-not (Test-path "$Path\wp_$BackgroundColor-$Color.jpg") -or $Force) {
        
        # Get-PollinationsAiImage might return a cached image from PollinationsAI without any cost (if not -Force is used to bypass the PollinationsAI cache)
        $params = @{}
        if ($Force) { $params.bypassCache = $true }

        Write-Output "Generating new image ..."
        $newImage = Get-PollinationsAiImage `
            -Content ($Content -ireplace "{Color}",$Color -ireplace "{BackgroundColor}",$BackgroundColor) `
            -Settings (@{ image = $ImageUri; } + $sizes + $Settings) `
            -Model $Model `
            -Out "$Path\wp_$BackgroundColor-$Color.jpg" `
            @params `
            # -Debug
    }
    else {
        $newImage = "$Path\wp_$BackgroundColor-$Color.jpg"
    }

    if (-not $newImage -or -not (Test-path $newImage)) {
        Write-Error "Image not created: $Path\wp_$BackgroundColor-$Color.jpg"
        return
    }

    Write-Output "Using image: $newImage"

    # if -Test was used, do not continue
    if ($Test) { return }

    if (-not (Test-Path $PSScriptRoot\set-wallpaper.ps1)) {
        Write-Error "Set-Wallpaper.ps1 not found"
        Write-Warning "You need to download the Set-Wallpaper script (Update 08/10/2020) from`n  https://www.joseespitia.com/2017/09/15/set-wallpaper-powershell-function/`n  and save it as .\set-wallpaper.ps1`n ⚠️ But DO NOT include the last line that says Set-WallPaper -Image `"C:\Wallpaper\Background.jpg`" -Style Fit"
        return
    }

    # import the Set-Wallpaper function
    . $PSScriptRoot\set-wallpaper.ps1 | Out-Null

    Write-Output "Setting wallpaper to $Color"


    # set the new wallpaper
    Set-Wallpaper -Image $newImage -Style Center

    Write-Output "Done"
}

$argString = ""
foreach ($key in $PSBoundParameters.Keys) {
    $value = $PSBoundParameters[$key]
    if ($value -eq $true) {
        # This handles [switch] and [bool] where value is true
        $argString += "-$key "
    } elseif ($value -ne $false) {
        # This handles strings and other values
        $argString += "-$key `"$value`" "
    }
}

Function Invoke-AsAdmin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "This script must be run as admin. Starting powershell as admin..."
        
        # start powershell as admin
        $interpreter = (Get-Process -Id $PID).Name + ".exe"
        $arguments = "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`" $argString"

        Start-Process $interpreter -Verb RunAs -ArgumentList $arguments
        
        exit
    }
}

Function Add-UpdateWallpaperScheduledTask {
    Invoke-AsAdmin

    if (-not $env:POLLINATIONSAI_API_KEY) {
        Write-Warning "You need to set the `$env:POLLINATIONSAI_API_KEY environment variable in your config file or in your profile."
        Write-Warning "The current profile is: $PROFILE"
        Write-Warning "The current config file is: $ConfigFile"
        Write-Warning "To set the key, you can also run (in this session): Get-PollinationsAiByok -Add"
    }

    # Define the script path and name for the task
    $scriptPath = "$PSCommandPath"
    $taskName = "ChangeWallpaperHourlyAtLogon"
    $taskDescription = "Runs Update-Wallpaper every hour after user login"

    # Check if pwsh.exe (preferred) or powershell.exe is available
    $interpreter = Get-Command pwsh.exe, powershell.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source

    # Define the action (start powershell.exe with arguments)
    #$action = New-ScheduledTaskAction -WorkingDirectory "$PSScriptRoot" -Execute "$interpreter" -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -ConfigFile `"$ConfigFile`" " # -WindowStyle Hidden # --> DEBUG: -noExit
    
    # This works better: no console window flashing
    $action = New-ScheduledTaskAction -WorkingDirectory "$PSScriptRoot" -Execute "C:\Windows\System32\conhost.exe" -Argument "--headless `"$interpreter`" -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -ConfigFile `"$ConfigFile`" "

    # Define the trigger (at logon, repeating every hour indefinitely)
    # The -AtLogOn trigger doesn't directly support RepetitionInterval in one line
    # We must use a workaround by setting the Repetition properties after creating the task
    $trigger = New-ScheduledTaskTrigger -AtLogOn

    # Define the principal (runs as the current user when logged in)
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

    # Register the initial task (without the repetition settings configured directly)
    Register-ScheduledTask -TaskName $taskName -Description $taskDescription -Action $action -Trigger $trigger -Principal $principal -Force -ErrorAction Stop | Out-Null

    # Retrieve the newly created task object to modify its repetition settings
    $task = Get-ScheduledTask -TaskName $taskName

    # Set the repetition interval and duration
    $task.Triggers.Repetition.Interval = "PT$([Math]::Round($Interval.TotalMinutes, 0))M"
    $task.Triggers.Repetition.StopAtDurationEnd = $false

    # Update the task with the modified trigger settings
    $task | Set-ScheduledTask
}

function Remove-UpdateWallpaperScheduledTask {
    Invoke-AsAdmin

    $taskName = "ChangeWallpaperHourlyAtLogon"

    # Check if the task exists before trying to remove it
    if ($task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Write-Host "Removing scheduled task: $taskName..." -ForegroundColor Yellow
        
        # -Confirm $false suppresses the "Are you sure?" prompt
        Unregister-ScheduledTask -InputObject $task -Confirm:$false -ErrorAction Stop
        
        Write-Host "Task successfully removed." -ForegroundColor Green
    } else {
        Write-Host "Task '$taskName' not found." -ForegroundColor Gray
    }
}


If ($TaskScheduler -eq "add") { return Add-UpdateWallpaperScheduledTask }
If ($TaskScheduler -eq "remove") { return Remove-UpdateWallpaperScheduledTask }


# Else
Invoke-UpdateWallpaper