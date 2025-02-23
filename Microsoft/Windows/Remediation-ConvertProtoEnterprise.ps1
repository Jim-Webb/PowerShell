# KMS client key from https://learn.microsoft.com/en-us/windows-server/get-started/kms-client-activation-keys
# Windows 10/11 Pro
# $ProductKey = 'W269N-WFGWX-YVC9B-4J6C9-T83GX'
# Windows 10/11 Enterprise KMS
$ProductKey = 'NPPR9-FWDCX-D2C8J-H872K-2YT43'
# Windows 10/11 Pro for Workstations
# $ProductKey = 'NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J'

# SKU 125 = LTSB/LTSC
# SKU 4 = Enterprise
# SKU 48 = Professional
# SKU 161 = Pro for Workstations

$LogFile = "C:\Windows\Logs\Software\Remediation-WindowsEdition.log"

Function Get-OSBuildInfo ()
{
    $object1 = New-Object PSObject
    # Collect current Windows edition info
    # Get-WmiObject win32_operatingsystem | select Caption,Version,OperatingSystemSKU
    $WindowsInfo = Get-WmiObject win32_operatingsystem

    Add-Member -InputObject $object1 -MemberType NoteProperty -Name Caption -Value $WindowsInfo.Caption
    Add-Member -InputObject $object1 -MemberType NoteProperty -Name Version -Value $WindowsInfo.Version
    Add-Member -InputObject $object1 -MemberType NoteProperty -Name SKU -Value $WindowsInfo.OperatingSystemSKU
    Add-Member -InputObject $object1 -MemberType NoteProperty -Name Edition -Value (Get-WindowsEdition -Online).edition
    Add-Member -InputObject $object1 -MemberType NoteProperty -Name ProductType -Value $WindowsInfo.ProductType
    
    # $OSCaption = $WindowsInfo.Caption
    # [version]$OSVersion = $WindowsInfo.Version
    # $OSSKU = $WindowsInfo.OperatingSystemSKU

    # $OSEdition = (Get-WindowsEdition -Online).edition
    return $object1
}

function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = $ModuleName,
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile
	    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
 
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}
 
	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
}
#endregion Functions

CMTraceLog -Message "----- Starting Remediation for Windows Edition -----" -Type 1 -LogFile $LogFile

CMTraceLog -Message "Desired OS Edition SKU: 4" -Type 1 -LogFile $LogFile

$OSBuildInfo = Get-OSBuildInfo

CMTraceLog -Message "Current OS Edition SKU: $($OSBuildInfo.SKU)" -Type 1 -LogFile $LogFile

CMTraceLog -Message "Windows Edition Change Before`n`nCaption: $($osbuildinfo.Caption)`nCurrent Edition: $($OSBuildInfo.Edition)`nCurrent Version: $($OSBuildInfo.Version)`nOS SKU: $($OSBuildInfo.SKU)" -Type 1 -LogFile $LogFile

$SLMGR = cscript.exe //Nologo C:\windows\System32\slmgr.vbs /dli

If ($SLMGR -like "*Partial Product Key: 2YT43*")
{
    CMTraceLog -Message "Product key 2YT43 installed." -Type 1 -LogFile $LogFile
    $KMSProductKey = $true
}
else
{
    CMTraceLog -Message "Product key 2YT43 not installed." -Type 1 -LogFile $LogFile
    $KMSProductKey = $false
}

If (($OSBuildInfo.SKU -ne '4' -and $OSBuildInfo.ProductType -eq '1' -and $OSBuildInfo.Version -match '10' -and $OSBuildInfo.SKU -ne '125') -or ($KMSProductKey -eq $false -and $OSBuildInfo.ProductType -eq '1' -and $OSBuildInfo.Version -match '10'))
{
    CMTraceLog -Message "The current edition needs converted to Enterprise" -Type 1 -LogFile $LogFile

    $sls = Get-WmiObject -Query 'SELECT * FROM SoftwareLicensingService'
    @($sls).foreach({
        $_.InstallProductKey($ProductKey)
        $_.RefreshLicenseStatus()
    })

    CMTraceLog -Message "Windows edition updated." -Type 1 -LogFile $LogFile

    $NewOSBuildInfo = Get-OSBuildInfo

    CMTraceLog -Message "Windows Edition Change After`n`nCaption: $($NewOSBuildInfo.Caption)`nCurrent Edition: $($NewOSBuildInfo.Edition)`nCurrent Version: $($NewOSBuildInfo.Version)`nOS SKU: $($NewOSBuildInfo.SKU)" -Type 1 -LogFile $LogFile

    CMTraceLog -Message "Current OS Edition SKU: $($NewOSBuildInfo.SKU)" -Type 1 -LogFile $LogFile

    # Hardware Inventory Cycle
    CMTraceLog -Message "Starting a hardware inventory scan." -Type 1 -LogFile $LogFile
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000001}"
    
    # Now that the edition has been changed, scan for updates that are available.
    CMTraceLog -Message "Checking for updates after edition change." -Type 1 -LogFile $LogFile

    # Software Update Scan Cycle
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000113}"

    # Software Update Scan Cycle
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000108}"

    CMTraceLog -Message "End of remediation." -Type 1 -LogFile $LogFile
}