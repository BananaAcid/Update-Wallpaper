# This example config will overwrite any parameters from the command line
# The config file is optional, but useful when running from task scheduler
# Any param can be used in the config file



$Content = "Make it glow in {Color} and fill background with {BackgroundColor} and show some outerspace but less to the image edges"    # we want to center it on the screen and fill the background with black
$ImageUri = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Banana_on_whitebackground.jpg/1280px-Banana_on_whitebackground.jpg"

#$Colors = "red", "blue"  # limit the colors
#$Color = "yellow"  # if not set, it will get a random color

#$Settings = @{ width = "1920"; height = "1080"; }

$Force = $false
$Debug = $true  # set -Debug from within code
