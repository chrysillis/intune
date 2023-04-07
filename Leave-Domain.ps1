<#
.Synopsis
    Migrate to Intune

.Description
    Leaves any Active Directory domain and setups a scheduled task to join the workstation to Intune

.Example
    .\Leave-Domain.ps1

.Outputs
    Log files stored in C:\Logs\Intune

.Notes
    Author: Chrysi
    Link:   https://github.com/DarkSylph/intune
    Date:   01/25/2022
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Requires -Version 5.1
#Requires -RunAsAdministrator

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script version
$ScriptVersion = "v3.2.4"
#Script name
$App = "Leave Domain"
#Today's date
$Date = Get-Date -Format "MM-dd-yyyy-HH-mm-ss"
#Destination to store logs
$LogFilePath = "C:\Logs\Intune\" + $date + "-Leave-Logs.log"
#Path to the client package
$Pkg = "https://contoso.com/intune.zip"
#Client secrets
$Username = "contoso\administrator"
$Password = "Welcome!"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Get-Files {
    <#
    .Synopsis
    Downloads the profile migration tool
    .Description
    Call the function with "Get-Files -URL https://example.com/" and the function will proceed to download and verify the file
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
                Write-Host "$(Get-Date): Creating Deploy directory."
                New-Item -ItemType Directory -Force -Path C:\Deploy\ | Out-Null
            }
            if (-Not (Test-Path -Path "C:\Deploy\Intune")) {
                Write-Host "$(Get-Date): Creating Intune Deploy directory."
                New-Item -ItemType Directory -Force -Path C:\Deploy\Intune | Out-Null
            }
            $FileOut = "C:\Deploy\Intune\profwiz.zip"
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
            if (Test-Path "C:\Deploy\Intune\Profwiz.exe") {
                Write-Host "$(Get-Date): Files expanded successfully..."
            }
            else {
                Write-Host "$(Get-Date): Files failed to expand, archive may be corrupted..." -ForegroundColor Red
                Remove-Item "C:\Deploy" -Force -Recurse
                exit
            }
        }
        catch {
            Throw "Unable to download files: $($_.Exception.Message)"
        }
    }
}
function Get-Domain {
    <#
    .Synopsis
    Leaves Active Directory
    .Description
    Checks the current status of the workstation whether it is domain joined, workgroup, or Azure AD joined
    Then it removes from the domain if it is domain joined and creates a task to join to Intune
    #>
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
            Throw "Unable to determine status of domain: $($_.Exception.Message)"
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
            Get-ScheduledJob | Unregister-ScheduledJob -Force
            $TS = New-TimeSpan -Minutes 1
            $Time = (Get-Date) + $TS
            $Path = "C:\Deploy\Intune\Join-Intune.ps1"
            $Trigger = New-JobTrigger -Once -At $Time
            $Options = New-ScheduledJobOption -StartIfOnBattery
            Register-ScheduledJob -Name "Join Intune" -FilePath $Path -Trigger $Trigger -ScheduledJobOption $Options
            Write-Host "$(Get-Date): Scheduled task to execute join to Azure AD 1 minutes from now..."
        }
        catch {
            Throw "Unable to register task: $($_.Exception.Message)"
        }
    }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Sets up a destination for the logs
if (-Not (Test-Path -Path "C:\Logs")) {
    Write-Host "$(Get-Date): Creating Logs folder."
    New-Item -ItemType Directory -Force -Path C:\Logs | Out-Null
}
if (-Not (Test-Path -Path "C:\Logs\Intune")) {
    Write-Host "$(Get-Date): Creating Intune Logs folder."
    New-Item -ItemType Directory -Force -Path C:\Logs\Intune | Out-Null
}
#Begins the logging process to capture all output
Start-Transcript -Path $logfilepath -Force
Write-Host "$(Get-Date): Successfully started $App $ScriptVersion on $env:computername"
if (Test-Path "C:\Deploy\Intune\Profwiz.exe") {
    Write-Host "$(Get-Date): This script has already been run on $env:computername, terminating script..."
    exit
}
#Downloads the client specific Intune scripts and packages
Get-Files -URL $Pkg
#Determins the status of whether the PC is joined to a domain or Azure AD
Get-Domain
#Ends the logging process
Stop-Transcript
#Terminates the script
exit