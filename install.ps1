# 
param(
    [switch] $Debug,
    [switch] $Verbose,
    [switch] $Elevated,
    [string] $ComputerName = $env:COMPUTERNAME
)

# Load configuration from a hosts file
$jsonname = ".\hosts\${ComputerName}.json"
if (Test-Path -Path $jsonname) {
    $config = Get-Content $jsonname | ConvertFrom-Json
} else {
    Write-Output "Config ${jsonname} not found; use -ComputerName to set alternate name"
    exit
}

if ($Verbose) {
    Write-Output "# Options: Debug=$Debug Verbose=$Verbose Elevated=$Elevated"
    Write-Output "# Packages: ${config.packages}"
    Write-Output "# Gitconfig: ${config.gitconfig}"
}

# write-OUtput "Debug=$Debug"

#$AppListFile = "win11.json"


# Download the winget app list to a temporary file
#$AppList = New-TemporaryFile
#Invoke-WebRequest -Uri $AppListUrl -OutFile $AppList

#Write-Output "Filename is $AppList"

# Now make certain that all the packages have been gotten
# if ($Debug) {
#     Write-Output "WOULD execute winget import"
# } else {
#     # winget import -i "$AppListFile"
# }
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
        # Write-Error "Get-ChocolateyPackages: chocolatey has not been installed"
        # return $ChocolateyPackages
        if ($Elevated) {
            $execpolicy = get-executionpolicy
            # Write-Error "Get-ChocolateyPackages: installing chocolatey"
            Set-ExecutionPolicy Bypass -Scope Process -Force 
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072 
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            set-executionpolicy $execpolicy -scope Process

        } else {
            # Write-Error "Get-ChocolateyPackages: chocolatey not installed - run in admin shell with -Elevated to install"
            return $ChocolateyPackages
        }
    }

    # Write-Output "packages($ChocolateyPackages.Count): $ChocolateyPackages"
    if ($ChocolateyPackages.Count -eq 0) {
        $choco_output = choco list -r 

        foreach ($line in $choco_output) {
            $name, $ver = $line.split('[|')
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
        $pkg_info = $packages[$Package]
        Write-Output "Add-ChocolateyPackage($Package): version=$pkg_info"
    }

    if ($packages.Count -eq 0) {
        Write-Output "Add-ChocolateyPackage($Package): chocolatey is not yet installed"
    } elseif ($packages[$Package]) {
        if ($Verbose) {
            $pkg_ver = $packages[$Package]
            Write-Output "Add-ChocolateyPackage($Package): package already exists and version=$pkg_ver"
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

function Add-WingetPackage {
    param (
        [string]$PackageId,
        [string]$Label
    )

    # easy hack to determine if valid = 5 lines is found
    $package = winget list --exact --id $PackageId | select-string "$PackageId"
    $isPackageInstalled = $package

    if ($Verbose) {
        Write-Output "Add-WingetPackage($Label): id=${PackageId} isInstalled=$isPackageInstalled version=${package.Version}"
    }

    if ($isPackageInstalled) {
        if ($Verbose) {
            Write-Output "Add-WingetPackage($Label): package already exists and version=${packages[$Package]}"
        } 
    } else {
        # 
        # if (-not $Elevated) {
        #     Write-Output "Add-ChocolateyPackage(${Package}): would install package if -Elevated is used"
        #     return
        # }
    
        if ($Debug) {
            Write-Output "Add-WingetPackage($Label): WOULD install package"
        } else {
            Write-Output "Add-WingetPackage($Label): installing package"
            winget install $PackageId  --accept-source-agreements --accept-package-agreements --disable-interactivity
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

function Enable-WSL {
    # determine if we have the kernel module
    # Windows Subsystem for Linux Update
    $pkg = Get-Package "Windows Subsystem for Linux Update"
    if ($pkg) {
        if ($Verbose) {
            Write-Output "Enable-WSL: already installed kernel"
        }
    } else {
        if ($Debug) {
            Write-Output "Enable-WSL: WOULD install WSL kernel"
        } else {
            Write-Output "Enable-WSL: installing WSL kernel package"
            # download the installer
            $url = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
            $systype = systeminfo | find "System Type"
            if ($systype -match 'ARM64-based') {
                $url = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_arm64.msi"
            }
            Invoke-WebRequest -Uri $url -OutFile "./wsl_update.msi"
            Start-Process ./wsl_update.msi -Wait
            Remove-Item "./wsl_update.msi"
        }
    }
}

function Add-WSLDistribution {
    param (
        [string]$Name,
        [string]$Comment
    )

    #Enable-WSL
    $distros = Get-WSLDistributions

    if ($Verbose) {
        Write-Output "Add-WSLDistribution($Name): comment=$Comment value=${distros[$Name]}"
    }

    if ($distros[$Name] -eq "yes") {
        if ($Verbose) {
            Write-Output "Add-WSLDistribution($Name): distribution already exists"
        } 
    } else {
        # 
        # if (-not $Elevated) {
        #     Write-Output "Add-ChocolateyPackage(${Package}): would install package if -Elevated is used"
        #     return
        # }
    
        if ($Debug) {
            Write-Output "Add-WSLDistribution($Name): WOULD install distribution"
        } else {
            Write-Output "Add-WSLDistribution($Name): installing distribution"
            wsl --install --distribution "$Name"
            # The following does not work since the install finishes before the installation is complete
            # $windir = $env:USERPROFILE.Substring(2).Replace("\","/")
            # wsl -d "$Name" -- ln -s "${windir}" win
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
function Set-UserEnvironmentVariable {
    param(
        [string]$Key,
        [string]$Value
    )

    $current = [Environment]::GetEnvironmentVariable($Key, 'User')
    if ($current -eq $Value) {
        if ($Verbose) {
            Write-Output "Set-UserEnvironmentVariable($Key): already set to $Value"
        }
    } else {
        if ($Debug) {
            Write-Output "Set-UserEnvironmentVariable($Key): WOULD set to $Value"
        } else {
            Write-Output "Set-UserEnvironmentVariable($Key): setting to $Value"
            [Environment]::SetEnvironmentVariable($Key, $Value, "User")
        }
    }
}

foreach ($package in $config.packages) {
    #Write-Output "pkg=$package"
    Add-WingetPackage $package.id $package.label
}

foreach ($package in $config.chocolatey) {
    Write-Output "choco pkg=$package"
    Add-ChocolateyPackage $package
}
# Add-ChocolateyPackage "awscli"
# Add-ChocolateyPackage "liquidtext"

foreach ($git in $config.gitconfig) {
    Set-GitGlobalConfig $git.option $git.value
}
# Set-GitGlobalConfig "user.email" "dsmk@bu.edu"
# Set-GitGlobalConfig "user.name" "David King"

foreach ($feature in $config.optionalfeatures) {
    Set-WindowsOptionalFeature "$feature"
}
# Set-WindowsOptionalFeature VirtualMachinePlatform
# Set-WindowsOptionalFeature Microsoft-Windows-Subsystem-Linux

foreach ($distro in $config.wsl) {
    Add-WSLDistribution $distro.name $distro.comment
}

# Get-ChildItem env:
#
# Now we go through the directories we need to make certain exist
#
# projects directory
$projdir = "${env:USERPROFILE}\Documents\projects"

Set-UserEnvironmentVariable "Proj" "${projdir}"
Add-Directory "${projdir}"
foreach ($project in $config.projects) {
    $path = Join-Path -Path $projdir $project.name
    Add-GitCloneDirectory $project.url $path
}
# 2022 iam projects
#Add-GitCloneDirectory "https://github.com/bu-ist/iam-DirectoryModernization-SourceDB.git" "${projdir}\iam-DirectoryModernization-SourceDB"
# 
# Clone a copy of configuration repo if not already done
#
Add-GitCloneDirectory "https://github.com/dsmk/windows-dev-configuration.git" "${env:USERPROFILE}\windows-dev-configuration"
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