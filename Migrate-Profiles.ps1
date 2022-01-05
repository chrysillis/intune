#Requires -Version 5.1
<#
.Synopsis
Migrates Profiles
.Description
Runs Profwiz to migrate profiles from AD to Azure AD
.Notes
Author: Chrysillis Collier
Email: ccollier@micromenders.com
Date: 01/05/2022
#>

#Defines script name
$App = "Migrate Profiles"
#States the current version of this script
$Version = "1.5.6"
#Today's date and time
$Date = Get-Date -Format "MM-dd-yyyy-HH-mm-ss"
#Destination for application logs
$LogFilepath = "C:\Logs\" + $date + "-Profile-Logs.log"


#Begins the logging process to capture all output.
Start-Transcript -Path $LogFilepath -Force
Write-Host "$(Get-Date): Successfully started $App $Version on $env:computername"
Write-Host "Beginning profile migration now..."
$arguments = '/SILENT'
$Proc = Start-Process -PassThru -FilePath 'C:\Deploy\Profwiz.exe' -Verb RunAs -ArgumentList $arguments
$Proc.WaitForExit()
Write-Host "Cleaning up scheduled tasks..."
#Deletes the scheduled tasks as it's no longer needed.
Unregister-ScheduledTask -TaskName "Migrate Profiles" -Confirm:$false | Out-Null
Write-Host "Cleaning up download directory..."
#Clears the deploy directory.
Remove-Item "C:\Deploy" -Force -Recurse
#Ends the logging process.
Stop-Transcript
Restart-Computer -Force