#Requires -Version 5.1
<#
.Synopsis
Joins Intune.
.Description
Creates a scheduled task to run the profile migration script and then installs the Intune provisioning package.
.Notes
Author: Chrysillis Collier
Email: ccollier@micromenders.com
Date: 01/05/2022
#>


#Defines script name.
$App = "Join Intune"
#States the current version of this script
$Version = "1.5.7"
#Today's date and time
$Date = Get-Date -Format "MM-dd-yyyy-HH-mm-ss"
#Destination for application logs
$LogFilepath = "C:\Logs\" + $date + "-Intune-Logs.log"
#Path to the Intune package
$Pkg = "C:\Deploy\client.ppkg"


function Set-Task {
    process {
        try {
            $TS = New-TimeSpan -Minutes 3
            $Time = (Get-Date) + $TS
            $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Bypass -File "C:\Deploy\Migrate-Profiles.ps1"'
            $trigger = New-ScheduledTaskTrigger -Once -At $Time
            $principal = New-ScheduledTaskPrincipal -GroupId "NT Authority\System"
            Unregister-ScheduledTask -TaskName "Join Intune" -Confirm:$false | Out-Null
            Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "Migrate Profiles" -Description "Migrates profiles to Azure AD."
            Write-Host "Scheduled task to execute migration of profiles to Azure AD 3 minutes from now..."
        }
        catch {
            Throw "There was an unrecoverable error: $($_.Exception.Message) Unable to register task."
        }
    }
}
#Begins the logging process to capture all output.
Start-Transcript -Path $LogFilepath -Force
Write-Host "$(Get-Date): Successfully started $App $Version on $env:computername"
#Sets the task to migrate profiles1
Set-Task
Write-Host "Installing provisioning package now..."
#Installs the client specific Intune provisioning package
Install-ProvisioningPackage -PackagePath $Pkg -QuietInstall -ForceInstall
#Ends the logging process.
Stop-Transcript
#Terminates the script.
exit