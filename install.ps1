# 
param(
    [switch] $Debug
)
# write-OUtput "Debug=$Debug"

$AppListUrl = "https://raw.githubusercontent.com/dsmk/windows-dev-configuration/main/winget-app.json"

# Download the winget app list to a temporary file
$AppList = New-TemporaryFile
Invoke-WebRequest -Uri $AppListUrl -OutFile $AppList

Write-Output "Filename is $AppList"

# Now make certain that all the packages have been gotten
if ($Debug) {
    Write-Output "WOULD execute winget import"
} else {
    winget import -i "$AppList"
}

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
        Write-Output "Set-GitGlobalConfig(${ConfigOption}): Value already set to ${ConfigValue}"
    } else {
        if ($Debug) {
            Write-Output "Set-GitGlobalConfig(${ConfigOption}): WOULD set value to ${ConfigValue}"
        } else {
            git config --global "$ConfigOption" "$ConfigValue"
            Write-Output "Set-GitGlobalConfig(${ConfigOption}): Set value to ${ConfigValue}"
        }
    }
}

Set-GitGlobalConfig "user.email" "dsmk@bu.edu"
Set-GitGlobalConfig "user.name" "David King"
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