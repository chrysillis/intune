<#
.Synopsis
    Migrates Profiles

.Description
    Runs Profwiz to migrate profiles from AD to Azure AD

.Example
    .\Migrate-Profiles.ps1

.Outputs
    Log files stored in C:\Logs\Intune.

.Notes
    Author: Chrysi
    Link:   https://github.com/DarkSylph/intune
    Date:   01/21/2022
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Requires -Version 5.1

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script version
$ScriptVersion = "v3.2.2"
#Script name
$App = "Migrate Profiles"
#Today's date
$Date = Get-Date -Format "MM-dd-yyyy-HH-mm-ss"
#Destination to store logs
$LogFilePath = "C:\Logs\Intune\" + $date + "-Migrate-Logs.log"

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Sets up a destination for the logs
if (-Not (Test-Path -Path "C:\Logs")) {
    Write-Host "$(Get-Date): Creating new log folder."
    New-Item -ItemType Directory -Force -Path C:\Logs | Out-Null
}
if (-Not (Test-Path -Path "C:\Logs\Intune")) {
    Write-Host "$(Get-Date): Creating new log folder."
    New-Item -ItemType Directory -Force -Path C:\Logs\Intune | Out-Null
}
#Begins the logging process to capture all output
Start-Transcript -Path $logfilepath -Force
Write-Host "$(Get-Date): Successfully started $app install script $ScriptVersion on $env:computername"
#Starts the migration process
Write-Host "$(Get-Date): Beginning profile migration now..."
$arguments = '/SILENT'
$Proc = Start-Process -PassThru -FilePath 'C:\Deploy\Intune\Profwiz.exe' -Verb RunAs -ArgumentList $arguments
$Proc.WaitForExit()
Write-Host "$(Get-Date): Cleaning up scheduled tasks..."
#Deletes the scheduled tasks as it's no longer needed
Unregister-ScheduledTask -TaskName "Migrate Profiles" -Confirm:$false | Out-Null
Write-Host "$(Get-Date): Cleaning up download directory..."
#Clears the deploy directory
Remove-Item "C:\Deploy" -Force -Recurse
#Ends the logging process
Stop-Transcript
Restart-Computer -Force