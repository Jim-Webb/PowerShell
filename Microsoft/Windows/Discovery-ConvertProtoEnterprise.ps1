$LogFile = "C:\Windows\Logs\Software\Discovery-WindowsEdition.log"

# SKU 125 = LTSB/LTSC
# SKU 4 = Enterprise
# SKU 48 = Professional
# SKU 161 = Pro for Workstations

# Collect current Windows edition info
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

CMTraceLog -Message "----- Starting Discovery for Windows Edition -----" -Type 1 -LogFile $LogFile

CMTraceLog -Message "Desired OS Edition SKU: 4" -Type 1 -LogFile $LogFile

$OSBuildInfo = Get-OSBuildInfo

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
    CMTraceLog -Message "Current OS Edition SKU: $($OSBuildInfo.SKU)" -Type 1 -LogFile $LogFile
    CMTraceLog -Message "KMSProductKey: $KMSProductKey" -Type 1 -LogFile $LogFile

    CMTraceLog -Message "SLMGR Info: $SLMGR" -Type 1 -LogFile $LogFile

    CMTraceLog -Message "Windows Edition Non-Compliant." -Type 1 -LogFile $LogFile

    CMTraceLog -Message "End of discovery." -Type 1 -LogFile $LogFile
    return "Current OS Edition SKU: $($OSBuildInfo.SKU)"
}
else
{
    CMTraceLog -Message "Current OS Edition SKU: $($OSBuildInfo.SKU)" -Type 1 -LogFile $LogFile
    CMTraceLog -Message "KMSProductKey: $KMSProductKey" -Type 1 -LogFile $LogFile
    CMTraceLog -Message "Windows Edition Compliant." -Type 1 -LogFile $LogFile
    CMTraceLog -Message "End of discovery." -Type 1 -LogFile $LogFile
    return 'Compliant'
}