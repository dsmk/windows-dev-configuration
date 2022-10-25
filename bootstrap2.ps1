# 
param(
    [switch] $Debug,
    [switch] $Verbose,
    [switch] $Elevated,
    [string] $ComputerName = $env:COMPUTERNAME
)

# We are adapted from install.ps1 but hardcoded tocreate an initial install
#


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

# We store a global variable for the packages
$ChocolateyPackages = @{}

function Get-ChocolateyPackages {
    # use variable to determine if Chocolatey is already installed
    if (-not $env:ChocolateyInstall) {
        # Write-Error "Get-ChocolateyPackages: chocolatey has not been installed"
        # return $ChocolateyPackages
        if ($Elevated) {
            $execpolicy = get-executionpolicy
            Write-Error "Get-ChocolateyPackages: installing chocolatey"
            Set-ExecutionPolicy Bypass -Scope Process -Force 
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072 
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            set-executionpolicy $execpolicy -scope Process

        } else {
            Write-Error "Get-ChocolateyPackages: chocolatey not installed - run in admin shell with -Elevated to install"
            return $ChocolateyPackages
        }
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
        Write-Output "Add-ChocolateyPackage($Package): version=${packages[$Package].toString}"
    }

    if ($packages.Count -eq 0) {
        Write-Output "Add-ChocolateyPackage($Package): chocolatey is not yet installed"
    } elseif ($packages[$Package]) {
        if ($Verbose) {
            Write-Output "Add-ChocolateyPackage($Package): package already exists and version=${packages[$Package]}"
        } 
    } else {
        # 
        if (-not $Elevated) {
            Write-Output "Add-ChocolateyPackage(${Package}): would install package if -Elevated is used"
            return
        }
    
        if ($Debug) {
            Write-Output "Add-ChocolateyPackage($Package): WOULD install package"
        } else {
            Write-Output "Add-ChocolateyPackage($Package): installing package"
            choco install "$Package"
        }
    }
}


function Get-WSLDistributions {
    $ret = @{}
    $wsldistros = wsl --list
    foreach ($line in $wsldistros) {
        $name = [string]($line.Split(' '))[0]
        if (! $ret[$name]) {
            $ret.add($name, "yes")
        }
    }
    return $ret
}


function Add-GitCloneDirectory {
    param(
        [string]$RepoUrl,
        [string]$Directory
    )

    if (Test-Path -Path $Directory) {
        if (Test-Path -Path "${Directory}\.git") {
            if ($Verbose) {
                Write-Output "Add-GitCloneDirectory($RepoUrl): $Directory already a git clone"
            }
        } else {
            Write-Output "Add-GitCloneDirectory($RepoUrl): $Directory exists but not a git clone"
        }
    } else {
        if ($Debug)  {
            Write-Output "Add-GitCloneDirectory($RepoUrl): WOULD clone to $Directory"
        } else {
            Write-Output "Add-GitCloneDirectory($RepoUrl): cloning to $Directory"
            git clone "$RepoUrl" "$Directory"
        }
    }
}

# ####
# Install Choco and some basic packages if necessary
#
Add-ChocolateyPackage git


# ####
# Clone a copy of the configuration repo if not already done
#
$repourl = "https://github.com/dsmk/windows-dev-configuration.git"
$repodir = "${env:USERPROFILE}\windows-dev-configuration"
Add-GitCloneDirectory $repourl $repodir

# Set-GitGlobalConfig "user.email" "dsmk@bu.edu"
# Set-GitGlobalConfig "user.name" "David King"

# $repourl = "https://github.com/dsmk/windows-dev-configuration.git"
# $repodir = "${env:USERPROFILE}\windows-dev-configuration"
# if (Test-Path -Path $repodir) {
#     if ($Verbose) {
#         Write-Output "Configuration-Repo: ${repodir} already exists"
#     }
# } else {
#     if ($Debug) {
#         Write-Output "Configuration-Repo: WOULD clone ${repourl} to ${repodir}"
#     } else {
#         write-Output "Configuration-Repo: cloning ${repourl} to ${repodir}"
#         git clone "$repourl" "$repodir"
#     }
# }

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