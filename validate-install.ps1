# We use a boolean to determine whether we should error or not
$finalStatusIsError = $false

# Get OS Information
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem

# Get System Type (Windows 11 or Windows Server)
$osType = if ($osInfo.Caption -match "Windows 11") { "Windows 11" } elseif ($osInfo.Caption -match "Windows Server") { "Windows Server" } else { "Unknown OS" }

# Get OS Level (e.g., 22H2)
$osLevel = $osInfo.Version 

# Get Architecture Type (arm64 or x86)
$architecture = if ($osInfo.OSArchitecture -eq "64-bit") { 
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x86" } 
} else { "x86" }

# Output the information
Write-Host "Operating System Type: $osType"
Write-Host "Operating System Level: $osLevel"
Write-Host "Architecture: $architecture"
Write-Host "PATH: $env:PATH"
Write-Host ""

# There is a way that this is self-referential in that the install script uses similar logic.
# However, the goal is to detect regressions in the install.ps1

# Load the validation.json file
$config = Get-Content ".\hosts\validate-config.json" | ConvertFrom-Json

# Check that the winget packages are all installed
function Test-WingetInstalled {
    param (
        [string]$PackageId,
        [string]$Label
    )

    $pkg = winget list --exact --id $PackageId | select-string "$PackageId"
    return $pkg
}

foreach ($package in $config.packages) {
    $pkgLabel = $package.label
    if (Test-WingetInstalled $package.id $package.label) {
        Write-Output "OK Package found $pkgLabel"
    } else {
        Write-Output "ERR Package not found $pkgLabel"
        $finalStatusIsError = $true
    }
}
# Check that the choco packages are installed

# Validate the commands we find on our command line (this part of the json is )
foreach ($cmd in $config.commands) {
    $cmdInstalled = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($cmdInstalled) {
        write-Output "OK Command found $cmd"
    } else {
        Write-Output "ERR Command not found $cmd"
        $finalStatusIsError = $true
    }
}

# # Check if Chocolatey packages are installed
# $chromeInstalled = Get-Command "chrome" -ErrorAction SilentlyContinue
# $firefoxInstalled = Get-Command "firefox" -ErrorAction SilentlyContinue
# $7zipInstalled = Get-Command "7z" -ErrorAction SilentlyContinue

# # Assert that Chocolatey packages are found
# if (-not $chromeInstalled) { throw "Google Chrome not installed" }
# if (-not $firefoxInstalled) { throw "Firefox not installed" }
# if (-not $7zipInstalled) { throw "7-Zip not installed" }

# # Check if winget packages are installed
# $vscodeInstalled = Get-Command "code" -ErrorAction SilentlyContinue

# # Assert that winget packages are found
# if (-not $vscodeInstalled) { throw "VS Code not installed" }


# Example: Validate system settings
# $rdpEnabled = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections"
# if ($rdpEnabled -ne 0) { throw "Remote Desktop is not enabled" }


# 
if ($finalStatusIsError) {
    throw "Something was wrong - look at comments above"
}
# ... other validation logic ...