# 
param(
    [switch] $Debug,
    [switch] $Verbose,
    [switch] $Elevated
)
if ($Verbose) {
    Write-Output "# Options: Debug=$Debug Verbose=$Verbose"
}

# write-OUtput "Debug=$Debug"

# This should only be part of the bootstrap (unless we switch it to Chocolatey)
# Download the winget app list to a temporary file
# $AppListUrl = "https://raw.githubusercontent.com/dsmk/windows-dev-configuration/main/winget-app.json"
# $AppList = New-TemporaryFile
# Invoke-WebRequest -Uri $AppListUrl -OutFile $AppList

# Write-Output "Filename is $AppList"

# # Now make certain that all the packages have been gotten
# if ($Debug) {
#     Write-Output "WOULD execute winget import"
# } else {
#     winget import -i "$AppList"
# }

# 
# Make certain that the git config is set properly
#
function Set-GitGlobalConfig {
    param (
        [string]$ConfigOption,
        [string]$ConfigValue
    )

    # Get the current value
    $CurrentValue = git config --global "$ConfigOption"

    Write-Debug "${ConfigOption}: current=(${CurrentValue}) desired=(${ConfigValue})"
    if ($CurrentValue -eq $ConfigValue) {
        if ($Verbose) {
            Write-Output "Set-GitGlobalConfig(${ConfigOption}): Value already set to ${ConfigValue}"
        }
    } else {
        if ($Debug) {
            Write-Output "Set-GitGlobalConfig(${ConfigOption}): WOULD set value to ${ConfigValue}"
        } else {
            git config --global "$ConfigOption" "$ConfigValue"
            Write-Output "Set-GitGlobalConfig(${ConfigOption}): Set value to ${ConfigValue}"
        }
    }
}
function Set-WindowsOptionalFeature {
    param (
        [string]$Feature
    )

    if (-not $Elevated) {
        Write-Output "Set-WindowsOptionalFeature(${Feature}): bypassing as PowerShell is not elevated"
        return
    }

    $state = Get-WindowsOptionalFeature -Online -FeatureName $Feature | ForEach-Object State
    if ($state -eq "Disabled") {
        if ($Debug) {
            write-Output "Set-WindowsOptionalFeature(${Feature}): WOULD enable feature"
        } else {
            Write-Output "Set-WindowsOptionalFeature(${$Feature}): enabling feature"
            Enable-WindowsOptionalFeature -Online -FeatureName $Feature
        }
    } elseif ($Verbose) {
        write-Output "Set-WindowsOptionalFeature($Feature): feature already enabled"
    }
}

# We store a global variable for the packages
$ChocolateyPackages = @{}

function Get-ChocolateyPackages {
    # use variable to determine if Chocolatey is already installed
    if (-not $env:ChocolateyInstall) {
        Write-Error "Get-ChocolateyPackages: chocolatey has not been installed"
        return $ChocolateyPackages
    }

    if ($ChocolateyPackages.Count -eq 0) {
        $choco_output = chocolatey list -l

        foreach ($line in $choco_output) {
            $name, $ver = $line.split(' ')
            # Write-Output "#### name=$name ver=$ver line=$line\n"
            $ChocolateyPackages[$name] = $ver
        }
    }
    return $ChocolateyPackages
}

function Add-ChocolateyPackage {
    param (
        [string]$Package
    )
    # Get the chocolatey packages
    $packages = Get-ChocolateyPackages

    if ($Verbose) {
        Write-Output "Add-ChocolateyPackage($Package): version=$packages[$Package]"
    }

    if ($packages.Count -eq 0) {
        Write-Output "Add-ChocolateyPackage($Package): chocolatey is not yet installed"
    } elseif ($packages[$Package]) {
        if ($Verbose) {
            Write-Output "Add-ChocolateyPackage($Package): package already exists and version=${packages[$Package]}"
        } 
    } else {
        if ($Debug) {
            Write-Output "Add-ChocolateyPackage($Package): WOULD install package"
        } else {
            Write-Output "Add-ChocolateyPackage($Package): installing package"
            choco install "$Package"
        }
    }
}

function Add-Directory {
    param (
        [string]$Directory
    )

    if (Test-Path -Path $Directory) {
        if ($Verbose) {
            Write-Output "Add-Directory($Directory): already exists"
        } 
    } else {
        if ($Debug) {
            Write-Output "Add-Directory($Directory): WOULD create directory"
        } else {
            Write-Output "Add-Directory($Directory): creating directory"
            New-Item -itemtype directory -path "$Directory"
        }
    }
}

Add-ChocolateyPackage "awscli"
# Add-ChocolateyPackage "liquidtext"

Set-GitGlobalConfig "user.email" "dsmk@bu.edu"
Set-GitGlobalConfig "user.name" "David King"

Set-WindowsOptionalFeature VirtualMachinePlatform
Set-WindowsOptionalFeature Microsoft-Windows-Subsystem-Linux

# Get-ChildItem env:
#
# Now we go through the directories we need to make certain exist
#
Add-Directory "${env:USERPROFILE}\Documents\projects"

# 
# Clone a copy of configuration repo if not already done
#
$repourl = "https://github.com/dsmk/windows-dev-configuration.git"
$repodir = "${env:USERPROFILE}\windows-dev-configuration"
if (Test-Path -Path $repodir) {
    if ($Verbose) {
        Write-Output "Configuration-Repo: ${repodir} already exists"
    }
} else {
    if ($Debug) {
        Write-Output "Configuration-Repo: WOULD clone ${repourl} to ${repodir}"
    } else {
        write-Output "Configuration-Repo: cloning ${repourl} to ${repodir}"
        git clone "$repourl" "$repodir"
    }
}

# 
# Prepare the 
# 
# Configuration EnvironmentVariable_Path
# {
#     param ()

#     Import-DscResource -ModuleName 'PSDscResources'

#     Node localhost
#     {
#         Environment CreatePathEnvironmentVariable
#         {
#             Name = 'TestPathEnvironmentVariable'
#             Value = 'TestValue'
#             Ensure = 'Present'
#             Path = $true
#             Target = @('Process', 'Machine')
#         }
#     }
# }

# EnvironmentVariable_Path -OutputPath:"./EnvironmentVariable_Path"

# This isn't needed but is a good security practice to complete
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

# $reg_winlogon_path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
# Set-ItemProperty -Path $reg_winlogon_path -Name AutoAdminLogon -Value 0
# Remove-ItemProperty -Path $reg_winlogon_path -Name DefaultUserName -ErrorAction SilentlyContinue
# Remove-ItemProperty -Path $reg_winlogon_path -Name DefaultPassword -ErrorAction SilentlyContinue

# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# $url = "https://raw.githubusercontent.com/jborean93/ansible-windows/master/scripts/Upgrade-PowerShell.ps1"
# $file = "$env:temp\Upgrade-PowerShell.ps1"
# $username = "Administrator"
# $password = "Password"

# (New-Object -TypeName System.Net.WebClient).DownloadFile($url, $file)
# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

# Version can be 3.0, 4.0 or 5.1
# &$file -Version 5.1 -Username $username -Password $password -Verbose

# This came from:  https://blog.danskingdom.com/allow-others-to-run-your-powershell-scripts-from-a-batch-file-they-will-love-you-for-it/
# If running in the console, wait for input before closing.
# if ($Host.Name -eq "ConsoleHost")
# {
#     Write-Host "Press any key to continue..."
#     $Host.UI.RawUI.FlushInputBuffer()   # Make sure buffered input doesn't "press a key" and skip the ReadKey().
#     $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
# }