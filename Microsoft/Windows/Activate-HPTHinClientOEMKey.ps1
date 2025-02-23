function Write-CMTraceLog {
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
	$Message,
    [Parameter(Mandatory=$false)]
    $ErrorMessage,
    [Parameter(Mandatory=$false)]
    $Component = "Office365",
    [Parameter(Mandatory=$false)]
    [int]$Type,
    [Parameter(Mandatory=$false)]
    $LogFile = $Global:logfile
)

    # Write-Verbose "Called by: $((Get-PSCallStack)[1].Command)"

    $WhatIfPreference = $false

    Write-Debug "Log file: $LogFile"
    Write-Debug "Component: $Component"

    If ($Global:LogFile)
    {
        $LogFile = $Global:LogFile
        Write-Debug "Log file changed to: $LogFile"
    }

    <#
        Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
 
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}

        If ($EnableLogWriteVerbose -eq $false)
        {
            Write-Debug "Verbose log messages disabled."
        }
        else
        {
            Write-Verbose -Message "[$((Get-PSCallStack)[1].Command)] $Message"
        }

        $LogPath = Split-Path -path $LogFile

        If (!(Test-Path $LogPath))
        {
            Write-Verbose -Message "Directory $LogPath does not exist and will be created."
            # New-Item -Path $LogPath -ItemType Directory -Force
            [void][System.IO.Directory]::CreateDirectory($LogPath)
        }

	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
        Write-Debug $LogMessage
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile -Confirm:$false
}

function Install-ProductKey($key)
{
	$IPK = cscript.exe //Nologo $slmgr /ipk $Key[0]
	
	if ($IPK -like "*Installed product key $($key[0]) successfully.*")
	{
		$Message = "$($key[2]) product key installed."
		Write-Information $Message
		Write-CMTraceLog -Message $Message -Type 1 -Component "Install-ProductKey"
	}
	
	return $IPK
}

function Activate-InstalledProductKey($IPK, $key)
{
	if ($IPK -like "*Installed product key $($key[0]) successfully.*")
	{
		$Message = "$($key[2]) product key has been installed. Time to activate."
		Write-Information $Message
		Write-CMTraceLog -Message $Message -Type 1 -Component "Activate-InstalledProductKey"
		
		$DLV = cscript.exe //Nologo $slmgr /dlv
		
		If ($DLV -like '*IoTEnterpriseS*')
		{
			$Message = "IoTEnterpriseS product has been added."
			Write-Verbose $Message
			Write-CMTraceLog -Message $Message -Type 1 -Component "Activate-InstalledProductKey"

            $ATO = cscript.exe //Nologo $slmgr /ato

            if ($ATO -like "Product activated successfully.")
			{
				$Message = "Windows 10 activated for $($key[2])."
				Write-Information $Message
				Write-CMTraceLog -Message $Message -Type 1 -Component "Activate-InstalledProductKey"
                
                return $true
			}
		}
	}
	Else
	{
		$Message = "Error: $IPK."
		Write-Information $Message
		Write-CMTraceLog -Message $Message -Type 1 -Component "Activate-InstalledProductKey"
		
		$Message = "Product key not installed. Unable to continue."
		Write-Information $Message
		Write-CMTraceLog -Message $Message -Type 1 -Component "Activate-InstalledProductKey"
		exit 999
	}
}

$Global:logfile = "C:\Windows\Logs\Software\HPThinClientIoTLicenseActivation.log"

$slmgr = Get-Command slmgr.vbs | Select-Object -ExpandProperty Path

$SupportedModels = @("HP Elite t655 Thin Client", "HP t640 Thin Client")
$SupportedOSs = @([version]"10.0.19044")

$Model = Get-CimInstance Win32_ComputerSystem | select -ExpandProperty Model
Write-CMTraceLog -Message "Model: $Model" -Component "Startup" -Type 1

$OperatingSystem = Get-CimInstance Win32_operatingsystem

# wmic path SoftwareLicensingService get OA3xOriginalProductKey

$WinOEMLicenseInfo = Get-CimInstance -ClassName SoftwareLicensingService -Namespace root\CIMv2

$OriginalProductKey = $WinOEMLicenseInfo.OA3xOriginalProductKey
Write-CMTraceLog -Message "OriginalProductKey: $OriginalProductKey" -Component "Startup" -Type 1

$OriginalProductKeyDescription = $WinOEMLicenseInfo.OA3xOriginalProductKeyDescription
Write-CMTraceLog -Message "OriginalProductKeyDescription: $OriginalProductKeyDescription" -Component "Startup" -Type 1

$Caption = $operatingsystem.Caption
Write-CMTraceLog -Message "Windows Edition: $Caption" -Component "Startup" -Type 1
[version]$OSVersion = $operatingsystem.Version

Write-CMTraceLog -Message "Windows Version: $($OSVersion.tostring())" -Component "Startup" -Type 1
$BuildNumber = $operatingsystem.BuildNumber

$OperatingSystemSKU = $operatingsystem.OperatingSystemSKU
Write-CMTraceLog -Message "Windows SKU: $OperatingSystemSKU" -Component "Startup" -Type 1

$CurrentInfo = @("$OriginalProductKey", $OriginalProductKeyDescription, "$Caption", "$($OSVersion.ToString())")

If (($Model -in $SupportedModels) -and ($OriginalProductKeyDescription -like "*EnterpriseS*") -and ($OSVersion -in $SupportedOSs))
{
    Write-CMTraceLog -Message "We are running on a supported model, OS, and OS version." -Component "Startup" -Type 1
    
    If ($OriginalProductKey)
    {
        Write-CMTraceLog -Message "Time to activate OEM product key." -Component "Startup" -Type 1
        $IPKResult = Install-ProductKey -key $CurrentInfo

        $CheckIPKResult = Activate-InstalledProductKey -IPK $IPKResult -key $CurrentInfo

        If ($CheckIPKResult -eq $true)
        {
            Write-CMTraceLog -Message "Script executed successfully, exit with code 0." -Component "Startup" -Type 1
            return 0
        }
        else
        {
            Write-CMTraceLog -Message "Script execution failed, exit with code 1." -Component "Startup" -Type 1
            return 1
        }
    }
}