<# 
.Synopsis 
   Write-Log writes a message to a specified log file with the current time stamp. 
.DESCRIPTION 
   The Write-Log function is designed to add logging capability to other scripts. 
   In addition to writing output and/or verbose you can write to a log file for 
   later debugging. 
.NOTES 
   Created by: Jason Wasser @wasserja 
   Modified: 11/24/2015 09:30:19 AM   
.LINK 
   https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0 
#> 
function Write-Log 
{ 
    [CmdletBinding()] 
    Param 
    ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
 
        [Parameter(Mandatory=$false)] 
        [Alias('LogPath')] 
        [string]$Path='C:\Logs\PowerShellLog.log', 
         
        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info", 
         
        [Parameter(Mandatory=$false)] 
        [switch]$NoClobber 
    ) 
 
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process 
    { 
         
        # If the file already exists and NoClobber was specified, do not write to the log. 
        if ((Test-Path $Path) -AND $NoClobber) { 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
            } 
 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        elseif (!(Test-Path $Path)) { 
            Write-Verbose "Creating $Path." 
            $NewLogFile = New-Item $Path -Force -ItemType File 
            } 
 
        else { 
            # Nothing to see here yet. 
            } 
 
        # Format Date for our Log File 
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
 
        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        switch ($Level) { 
            'Error' { 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
                } 
            'Warn' { 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
                } 
            'Info' { 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
                } 
            } 
         
        # Write log entry to $Path 
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
    } 
    End 
    { 
    } 
}

#Create the log file if it doesnt exist
#Syntax: Write-Log -Message "" -Path $LogFile -Level Info
New-Item -Path C:\temp -Name patch.log -ItemType file -ErrorAction SilentlyContinue
$LogFile = "C:\temp\patch.log"

Write-Log -Message "Begin." -Path $LogFile -Level Info

#Kick off the Updates Scan Cycle & Updates Deployment Evaluation
([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000113}')| Out-Null
Write-Log -Message "Software Updates Scan Cycle has kicked off. Please wait 60 seconds for this process to complete." -Path $LogFile -Level Info
Start-Sleep 60
([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000108}')| Out-Null
Write-Log -Message "Software Updates Deployment Evaluation has kicked off. Please wait 60 seconds for this process to complete." -Path $LogFile -Level Info
Start-Sleep 60

#Get the missing updates
Write-Log -Message "Querying for missing updates." -Path $LogFile -Level Info
[System.Management.ManagementObject[]] $MissingUpdates = @(get-wmiobject -query "SELECT * FROM CCM_SoftwareUpdate WHERE ComplianceState = '0'" -namespace "ROOT\ccm\ClientSDK")
If ($MissingUpdates.count -ne 0) { 
$MissingUpdatesList = $MissingUpdates | Format-List -Property Name
$MissingUpdatesList | Out-File -Append $LogFile

Function Restart-WhenPendingReboot {
    <#
    .SYNOPSIS
        This will check if the SCCM Client 2012R2 has a reboot pending.
    .DESCRIPTION
        This will query the WMI value 'RebootPending' in the Namespace 'ROOT\ccm\ClientSDK' 
        http://blog.compower.org/2014/03/30/install-software-updates-sccm-2012r2-client-by-powershell/
    #>
    param (
        [string]$computer = $env:COMPUTERNAME
    )
    $IsRebootPending = (gwmi -Namespace 'ROOT\ccm\ClientSDK' -Class 'CCM_ClientUtilities' -list).DetermineIfRebootPending().RebootPending
    If ($IsRebootPending) { 
        Write-Log -Message "The server has a pending reboot and the server will reboot." -Path $LogFile -Level Warn            
    }
    return $IsRebootPending
}

<#Install the missing updates and reboot/quit
Modified version of:
http://blog.compower.org/2014/03/30/install-software-updates-sccm-2012r2-client-by-powershell/#>
([wmiclass]'ROOT\ccm\ClientSDK:CCM_SoftwareUpdatesManager').InstallUpdates($MissingUpdates)
    Do {
        Start-Sleep 180
        [array]$InstallPendingUpdates = @(get-wmiobject -query "SELECT * FROM CCM_SoftwareUpdate WHERE EvaluationState = 6 or EvaluationState = 7" -namespace "ROOT\ccm\ClientSDK")
        Write-Log -Message "The number of pending updates for installation is: $($InstallPendingUpdates.count)" -Path $LogFile -Level Warn
        }
    While ($InstallPendingUpdates.Count -ne 0)
    If (Restart-WhenPendingReboot) {
	Write-Log -Message "Rebooting in 10 seconds." -Path $LogFile -Level Info
	Start-Sleep 10
	(Get-WmiObject -Namespace 'ROOT\ccm\ClientSDK' -Class 'CCM_ClientUtilities' -list).RestartComputer()
	}
}
Else {Write-Log -Message "All action items complete." -Path $LogFile -Level Info}
Write-Log -Message "End." -Path $LogFile -Level Info
#Exit 0