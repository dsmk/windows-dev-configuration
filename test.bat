@REM This is a bat file
SET ThisScriptsDirectory=%~dp0
SET PowerShellScriptPath=%ThisScriptsDirectory%test.ps1
Powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%PowerShellScriptPath%"
@REM Powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "& '%PowerShellScriptPath%';"
@REM Powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PowerShellScriptPath%'";
@ECHO OFF
@REM If the script needs Admin permissions:
@REM PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%PowerShellScriptPath%""' -Verb RunAs}";
@REM PowerShell -NoProfile -ExecutionPolicy RemoteSigned -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%PowerShellScriptPath%""' -Verb RunAs}";