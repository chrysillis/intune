#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.Synopsis
Migrate profiles from domain to Intune.
.Description
Utilizes ForensIT profile migration tool to migrate domain profiles to their Intune counterparts.
.Notes
Author: Chrysillis Collier
Email: ccollier@micromenders.com
Date: 01/05/2022
#>


#Defines script name
$App = "Leave Domain"
#States the current version of this script
$Version = "3.2.1"
#Today's date and time
$Date = Get-Date -Format "MM-dd-yyyy-HH-mm-ss"
#Destination for application logs
$LogFilepath = "C:\Logs\" + $date + "-Domain-Logs.log"
#Path to the client package
$Pkg = "https://rmm.micromenders.com/labtech/transfer/Scripts/AIMLP/Intune.zip"
#Client secrets
$Username = "contoso\administrator"
$Password = "Welcome!"


function Get-Files {
    <#
    .Synopsis
    Downloads the profile migration tool.
    .Description
    Call the function with "Get-Files -URL https://example.com/" and the function will proceed to download and verify the file.
    #>
    [Cmdletbinding(DefaultParameterSetName = "URL")]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = "URL")]
        [ValidateNotNullOrEmpty()]    
        [String]
        $URL
    )
    process {
        try {
            if (-Not (Test-Path -Path "C:\Deploy")) {
                Write-Verbose -Message "Creating new directory."
                New-Item -ItemType Directory -Force -Path C:\Deploy | Out-Null
            }
            $FileOut = "C:\Deploy\profwiz.zip"
            Write-Host "$(Get-Date): Downloading $URL to $FileOut..."
            $FileJob = Measure-Command { (New-Object System.Net.WebClient).DownloadFile($URL, $FileOut) }
            $FileTime = $FileJob.TotalSeconds
            if (Test-Path $FileOut) {
                Write-Host "$(Get-Date): Files downloaded successfully in $FileTime seconds..."
            }
            else {
                Write-Host "$(Get-Date): Download failed, please check your connection and try again..." -ForegroundColor Red
                Remove-Item "C:\Deploy" -Force -Recurse
                exit
            }
            Expand-Archive -LiteralPath $FileOut -DestinationPath C:\Deploy
            if (Test-Path "C:\Deploy\Profwiz.exe") {
                Write-Host "$(Get-Date): Files expanded successfully..."
            }
            else {
                Write-Host "$(Get-Date): Files failed to expand, archive may be corrupted..." -ForegroundColor Red
                Remove-Item "C:\Deploy" -Force -Recurse
                exit
            }
        }
        catch {
            Throw "There was an unrecoverable error: $($_.Exception.Message) Unable to download files."
        }
    }
}
function Get-Domain {
    process {
        try {
            $status = dsregcmd /status
            $azuread = $status | select-string -pattern 'azureadjoined' -simplematch
            $domain = $status | select-string -pattern 'domainjoined' -simplematch
            $azuread = $azuread.tostring()

            if ($azuread -match "NO" -and $domain -match "NO") {
                Write-Host "$(Get-Date): Not AzureAD joined or domain joined, joining to AzureAD now..."
                Set-Task
                Restart-Computer -Force
            }
            elseif ($domain -match "YES") {
                Write-Host "$(Get-Date): Domain joined confirmed, removing from domain..."
                Set-Task
                Remove-Domain
            }
            elseif ($azuread -match "YES") {
                Write-Host "$(Get-Date): AzureAD joined confirmed, cancelling script..."
                Remove-Item "C:\Deploy" -Force -Recurse
                exit
            }
            else {
                Write-Host "$(Get-Date): Unable to determine status..."
                Remove-Item "C:\Deploy" -Force -Recurse
                exit
            }    
        }
        catch {
            Throw "There was an unrecoverable error: $($_.Exception.Message) Unable to determine status of domain."
        }
    }
}
function Remove-Domain {
    process {
        try {
            $secureStringPwd = $password | ConvertTo-SecureString -AsPlainText -Force 
            $Creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $secureStringPwd
            Remove-Computer -UnjoinDomaincredential $Creds -PassThru -Verbose -Restart -Force
            $status = dsregcmd /status
            $domain = $status | select-string -pattern 'domainjoined' -simplematch
            if ($domain -match "NO") {
                Write-Host "$(Get-Date): Removing from the domain succeeded."
                Restart-Computer -Force
            }
            elseif ($domain -match "YES") {
                throw "Removing from the domain failed..."
            }
        }
        catch {
            Throw "Unable to remove from domain: $($_.Exception.Message)"
            Remove-Item "C:\Deploy" -Force -Recurse
        }
    }
}
function Set-Task {
    process {
        try {
            $TS = New-TimeSpan -Minutes 2
            $Time = (Get-Date) + $TS
            $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Bypass -File "C:\Deploy\Join-Intune.ps1"'
            $trigger = New-ScheduledTaskTrigger -Once -At $Time
            $principal = New-ScheduledTaskPrincipal -GroupId "NT Authority\System"
            Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "Join Intune" -Description "Joins device to Azure AD."
            Write-Host "$(Get-Date): Scheduled task to execute join to Azure AD 2 minutes from now..."
        }
        catch {
            Throw "There was an unrecoverable error: $($_.Exception.Message) Unable to register task."
        }
    }
}
#Checks if the log path exists and if not, creates it.
if (-Not (Test-Path -Path "C:\Logs")) {
    Write-Host -Message "Creating new log folder."
    New-Item -ItemType Directory -Force -Path C:\Logs | Out-Null
}
#Begins the logging process to capture all output.
Start-Transcript -Path $LogFilepath -Force
Write-Host "$(Get-Date): Successfully started $App $Version on $env:computername"
if (Test-Path "C:\Deploy\Profwiz.exe") {
    Write-Host "$(Get-Date): This script has already been run on $env:computername, terminating script..."
    exit
}
#Downloads the client specific Intune scripts and packages.
Get-Files -URL $Pkg
#Determins the status of whether the PC is joined to a domain or Azure AD.
Get-Domain
#Ends the logging process.
Stop-Transcript
#Terminates the script.
exit