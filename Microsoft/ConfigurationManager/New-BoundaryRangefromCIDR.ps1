[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string]$RangeName,
    [Parameter(Mandatory = $true)]
    [string]$RangeCIDR,
    [switch]$AddRangetoBoundaryGroup,
    [string]$BoundaryGroupName,
    [switch]$OverwriteName,
    [Parameter()]
    [string]$SiteCode = "PS1",
    [Parameter()]
    [string]$SiteServer = "CM01.corp.viamonstra.com"
)

function Get-Subnet {
    param ( 
        [parameter(ValueFromPipeline)]
        [String]
        $IP,

        [ValidateRange(0, 32)]
        [int]
        $MaskBits,

        [switch]
        $SkipHosts
    ) 
    Begin {
        function Convert-IPtoINT64 ($ip) { 
            $octets = $ip.split(".") 
            [int64]([int64]$octets[0] * 16777216 + [int64]$octets[1] * 65536 + [int64]$octets[2] * 256 + [int64]$octets[3]) 
        } 
 
        function Convert-INT64toIP ([int64]$int) { 
            (([math]::truncate($int / 16777216)).tostring() + "." + ([math]::truncate(($int % 16777216) / 65536)).tostring() + "." + ([math]::truncate(($int % 65536) / 256)).tostring() + "." + ([math]::truncate($int % 256)).tostring() )
        } 

        If (-not $IP -and -not $MaskBits) { 
            $LocalIP = (Get-NetIPAddress | Where-Object {$_.AddressFamily -eq 'IPv4' -and $_.PrefixOrigin -ne 'WellKnown'})

            $IP = $LocalIP.IPAddress
            $MaskBits = $LocalIP.PrefixLength
        }
    }
    Process {
        If ($IP -match '/\d') { 
            $IPandMask = $IP -Split '/' 
            $IP = $IPandMask[0]
            $MaskBits = $IPandMask[1]
        }
        
        $IPAddr = [Net.IPAddress]::Parse($IP)

        $Class = Switch ($IP.Split('.')[0]) {
            {$_ -in 0..127} { 'A' }
            {$_ -in 128..191} { 'B' }
            {$_ -in 192..223} { 'C' }
            {$_ -in 224..239} { 'D' }
            {$_ -in 240..255} { 'E' }
            
        }
        
        If (-not $MaskBits) {
            $MaskBits = Switch ($Class) {
                'A' { 8 }
                'B' { 16 }
                'C' { 24 }
                default { Throw 'Subnet mask size was not specified and could not be inferred.' }
            }

            Write-Warning "Subnet mask size was not specified. Using default subnet size for a Class $Class network of /$MaskBits."
        }

        If ($MaskBits -lt 16 -and -not $SkipHosts) {
            Write-Warning "It may take some time to calculate all host addresses for a /$MaskBits subnet. Use -SkipHosts to skip."
        }
    
        $MaskAddr = [Net.IPAddress]::Parse((Convert-INT64toIP -int ([convert]::ToInt64(("1" * $MaskBits + "0" * (32 - $MaskBits)), 2))))
        
        $NetworkAddr = New-Object net.ipaddress ($MaskAddr.address -band $IPAddr.address) 
        $BroadcastAddr = New-Object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $MaskAddr.address -bor $NetworkAddr.address))
     
        $HostStartAddr = (Convert-IPtoINT64 -ip $NetworkAddr.ipaddresstostring) + 1
        $HostEndAddr = (Convert-IPtoINT64 -ip $broadcastaddr.ipaddresstostring) - 1
        
        If (-not $SkipHosts) {
            $HostAddresses = for ($i = $HostStartAddr; $i -le $HostEndAddr; $i++) {
                Convert-INT64toIP -int $i
            }
        }

        $HostStartAddr = Convert-INT64toIP -int $HostStartAddr
        $HostEndAddr = Convert-INT64toIP -int $HostEndAddr
    
        [pscustomobject]@{
            IPAddress        = $IPAddr
            MaskBits         = $MaskBits
            NetworkAddress   = $NetworkAddr
            BroadcastAddress = $broadcastaddr
            SubnetMask       = $MaskAddr
            NetworkClass     = $Class
            Range            = "$networkaddr ~ $broadcastaddr"
            StartAddress     = "$NetworkAddr"
            EndAddress       = "$BroadcastAddr"
            HostStartAddr    = "$HostStartAddr"
            HostEndAddr      = "$HostEndAddr"    
            HostAddresses    = $HostAddresses
        }
    }
    End {}
}

function Load-CMPSModule() {
    Write-Log -Message "Welcome to the Load-CMPSModule function." -Component "Load-CMPSModule" -Type 1
    if ($env:SMS_ADMIN_UI_PATH -ne $null) {
        If (!(Get-Module -Name ConfigurationManager)) {
            Write-Log -Message "Found CM Console in Path, trying to import module." -Component "Load-CMPSModule" -Type 1
            Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1) -Verbose:$false -Force
            if (Get-Module -Name ConfigurationManager) {
                Write-Log -Message "$env:SMS_ADMIN_UI_PATH" -Component "Load-CMPSModule" -Type 1
                Write-Log -Message "Successfully loaded CM Module from Installed Console" -Component "Load-CMPSModule" -Type 1
                $Global:PSModulePath = $true
            }
        }
        Else {
            $Message = "CM Module is already loaded, no need to import module."
            Write-Verbose $Message
            Write-Log -Message $Message -Component "Load-CMPSModule" -Type 1
            $Global:PSModulePath = $true
        }
    }
    else {
        $Message = "CM Console is not in Path Variable. Unable to continue."
        Write-Log -Message $Message -Component "Load-CMPSModule" -Type 3
        Write-Warning -Message $Message
		
        Set-Location $CurrentLocation
		
        exit 55378008
    }
	
}

function Write-Log {
    Param (
        [Parameter(Mandatory = $false)]
        $Message,
        [Parameter(Mandatory = $false)]
        $Component,
        [Parameter(Mandatory = $false)]
        [ValidateSet(1, 2, 3)]
        [int]$Type,
        [Parameter(Mandatory = $false)]
        $LogFile = $Global:logfile
    )
    <#
		Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
	#>
    $Time = Get-Date -Format "HH:mm:ss.ffffff"
    $Date = Get-Date -Format "MM-dd-yyyy"
	
    if ($Component -eq $null) { $Component = " " }
    if ($Type -eq $null) { $Type = 1 }
	
    If ($EnableLogWriteVerbose) {
        Write-Verbose -Message $Message
    }
	
    $SavedLocation = Get-Location
    Set-Location $myDirName
	
    $LogMessage = "<![LOG[$Message" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
	
    Set-Location $SavedLocation
}

function Prepare-logfile() {
    Param
    (
        [Parameter(Mandatory = $True)]
        $LogFileName,
        [Parameter(Mandatory = $True)]
        [ValidateSet('ScriptLocation', 'WindowsLogsSoftware')]
        $LogFileLocation
    )
	
    function get-scriptdirectory {
        if ($hostinvocation -ne $null) {
            Split-Path $hostinvocation.MyCommand.path
        }
        else {
            #$invocation = (get-variable MyInvocation -Scope 1).Value
            Split-Path -Parent $Script:MyInvocation.MyCommand.Path
        }
    }
	
    function get-scriptname {
        if ($hostinvocation -ne $null) {
            return Split-Path $hostinvocation.MyCommand.path -leaf
        }
        else {
            Split-Path $Script:MyInvocation.MyCommand.Path -Leaf
        }
    }
	
    $global:myDirName = get-scriptdirectory
    $global:MyScriptName = get-scriptname
	
    Write-Verbose "Script directory: $myDirName"
    Write-Verbose "Script name: $MyScriptName"
	
    $ScriptName = [IO.Path]::GetFileNameWithoutExtension($MyScriptName)
	
    Write-Verbose "Script name with extension: $ScriptName"
	
    Write-Verbose "Desired log file location: $LogFileLocation."
	
    Switch ($LogFileLocation) {
        ScriptLocation { $LogDir = "$myDirName\" }
        WindowsLogsSoftware {
            $WindowsDir = $env:SystemRoot
			
            Write-Verbose "Windows directory = $WindowsDir"
			
            $WindowsLogsSoftware = Test-Path -Path "$WindowsDir\Logs\Software"
			
            Write-Verbose "Path $WindowsDir\Logs\Software exists."
			
            If (!$WindowsLogsSoftware) {
                New-Item "$WindowsDir\Logs\Software" -type directory | Out-Null
            }
			
            $LogDir = "$WindowsDir\Logs\Software\"
        }
    }
	
    $Logfile = "$LogDir$LogFileName.log"
	
    Write-Verbose "Log file name: $logfile"
	
    return $Logfile
}

function Get-ErrorInformation() {
    [cmdletbinding()]
    param ($incomingError)
	
    if ($incomingError -and (($incomingError | Get-Member | Select-Object -ExpandProperty TypeName -Unique) -eq 'System.Management.Automation.ErrorRecord')) {
        Write-Host `n"Error information:"`n
        Write-Log -Message "Error information:" -Component "Get-ErrorInformation" -Type 1
        Write-Host `t"Exception type for catch: [$($IncomingError.Exception | Get-Member | Select-Object -ExpandProperty TypeName -Unique)]"`n
        Write-Log -Message "Exception type for catch: [$($IncomingError.Exception | Get-Member | Select-Object -ExpandProperty TypeName -Unique)]" -Component "Get-ErrorInformation" -Type 1
		
        if ($incomingError.InvocationInfo.Line) {
            Write-Host `t"Command                 : [$($incomingError.InvocationInfo.Line.Trim())]"
            Write-Log -Message "Command: [$($incomingError.InvocationInfo.Line.Trim())]" -Component "Get-ErrorInformation" -Type 1
        }
        else {
            Write-Host `t"Unable to get command information! Multiple catch blocks can do this :("`n
            Write-Log -Message "Unable to get command information! Multiple catch blocks can do this :(" -Component "Get-ErrorInformation" -Type 1
        }
		
        Write-Host `t"Exception               : [$($incomingError.Exception.Message)]"`n
        Write-Log -Message "Exception: [$($incomingError.Exception.Message)]" -Component "Get-ErrorInformation" -Type 1
        Write-Host `t"Target Object           : [$($incomingError.TargetObject)]"`n
        Write-Log -Message "Target Object: [$($incomingError.TargetObject)]" -Component "Get-ErrorInformation" -Type 1
    }
    Else {
        Write-Host "Please include a valid error record when using this function!" -ForegroundColor Red -BackgroundColor DarkBlue
        Write-Log -Message "Please include a valid error record when using this function!" -Component "Get-ErrorInformation" -Type 1
    }
}

function Exit-Script
{
    Set-Location $CurrentLocation
    break
}

#Current Version information for script
[version]$ScriptVersion = '1.0.2205.5'

$Global:logfile = Prepare-logfile -LogFileName "New-BoundaryRangefromCIDR" -LogFileLocation ScriptLocation
[bool]$Global:EnableLogWriteVerbose = $true

try{

    Write-Log -Message "----------------------------------------------------------------------------" -Component "Startup" -Type 1

    Write-Log -Message "Script version: $ScriptVersion" -Component "Startup" -Type 1
    Write-Log -Message "Site Code: $SiteCode" -Component "Startup" -Type 1
    Write-Log -Message "Site Server: $SiteServer" -Component "Startup" -Type 1

    Write-Host "Boundary name: $RangeName"
    Write-Log -Message "Boundary name: $RangeName" -Component "Startup" -Type 1

    Write-Host "CIDR: $RangeCIDR"
    Write-Log -Message "CIDR: $RangeCIDR" -Component "Startup" -Type 1

    $IPInfo = Get-Subnet -IP $RangeCIDR
    
    if ($IPInfo)
    {
        Write-host "Start address: $($IPInfo.HostStartAddr)"
        Write-Log -Message "Start address: $($IPInfo.HostStartAddr)" -Component "Startup" -Type 1

        Write-host "End address: $($IPInfo.HostEndAddr)"
        Write-Log -Message "End address: $($IPInfo.HostEndAddr)" -Component "Startup" -Type 1

        $CurrentLocation = Get-Location

        # Load CM PowerShell Module
        Load-CMPSModule

        Set-Location "$($SiteCode):\"

        $BoundaryCheck = Get-CMBoundary | Where-Object {$_.Value -eq "$($IPInfo.HostStartAddr)-$($IPInfo.HostEndAddr)"}

        If ($BoundaryCheck)
        {
            Write-Host "Boundary range already exists."
            Write-Log -Message "Boundary range already exists." -Component "Startup" -Type 1
            $RangeExists = $true
            If ($BoundaryCheck.DisplayName -eq $RangeName)
            {
                Write-Host "Range with correct name already exists."
                Write-Log -Message "Range with correct name already exists." -Component "Startup" -Type 1
                $CheckGroupMembership = $true
            }
            ElseIf ($BoundaryCheck.DisplayName -ne $RangeName)
            {
                Write-Warning "Range exists but has a different name. Use the -OverwriteName parameter to change the name."
                Write-Log -Message "Range exists but has a different name." -Component "Startup" -Type 1

                Write-Warning "Existing range name is `"$($BoundaryCheck.DisplayName)`"."
                Write-Log -Message "Existing range name is `"$($BoundaryCheck.DisplayName)`"" -Component "Startup" -Type 1
        
                If ($OverwriteName)
                {
                    Write-Host "Overwritename passed."
                    Write-Log -Message "Overwritename parameter passed." -Component "Startup" -Type 1

                    Set-CMBoundary -InputObject $BoundaryCheck -NewName $RangeName

                    Write-Host "Boundary renamed."
                    Write-Log -Message "Boundary renamed." -Component "Startup" -Type 1

                    $CheckGroupMembership = $true
                }
            }
        }
        else

        <# if (Get-CMBoundary -BoundaryName $RangeName)
        {
            Write-host "Boundary $($NewBoundaryRange.DisplayName) exists."
            $BoundaryNameExists = $true
        } #>

        # If (!(Get-CMBoundary -BoundaryName $RangeName))
        {
            $NewBoundaryRange = New-CMBoundary -Name $RangeName -Type IPRange -Value "$($IPInfo.HostStartAddr)-$($IPInfo.HostEndAddr)"
            Write-Host "New range: $($NewBoundaryRange.DisplayName)"
            Write-Log -Message "New range: $($NewBoundaryRange.DisplayName)" -Component "Startup" -Type 1
        }

        if ($NewBoundaryRange -and $AddRangetoBoundaryGroup -or $CheckGroupMembership -eq $true)
        {
            If ($BoundaryGroupName)
            {
                Write-Log -Message "Using boundarygroup passed as a parameter." -Component "Startup" -Type 1
                if (Get-CMBoundaryGroup -Name $BoundaryGroupName)
                {
                    $SelectedBG = $BoundaryGroupName
                }
                else
                {
                    Write-error "Boundarygroup parameter not valid." -RecommendedAction "Check the parameter."
                    Write-Log -Message "Boundarygroup parameter not valid." -Component "Startup" -Type 3
                    Exit-Script
                }
            }
            else
            {
                Write-Log -Message "Using Out-GridView to prompt for Boundary Group." -Component "Startup" -Type 1
                $SelectedBG = Get-CMBoundaryGroup | Select-Object Name, Description, Membercount | Sort-Object Name| Out-GridView -Title "Select a boundary group:" -OutputMode Single | Select-Object -ExpandProperty Name
            }
            Write-Log -Message "Boundary group `"$SelectedBG`" selected." -Component "Startup" -Type 1

            $RangePresentinGroup = Get-CMBoundary -BoundaryGroupName $SelectedBG | Where-Object {$_.DisplayName -eq $RangeName}

            Write-Log -Message "Check to see if `"$RangeName`" is a member of `"$SelectedBG`"." -Component "Startup" -Type 1

            If (!($RangePresentinGroup))
            {
                Write-Host "Range $RangeName is not present in boundary group $SelectedBG"
                Write-Log -Message "Range $RangeName is not present in boundary group $SelectedBG." -Component "Startup" -Type 1

                Add-CMBoundaryToGroup -BoundaryGroupName $SelectedBG -BoundaryName $RangeName

                Write-Host "New range `"$RangeName`" has been added to $SelectedBG."
                Write-Log -Message "New range `"$RangeName`" has been added to $SelectedBG." -Component "Startup" -Type 1
            }
            else
            {
                write-host "`"$RangeName`" is already a member of `"$SelectedBG`"."
                Write-Log -Message "`"$RangeName`" is already a member of `"$SelectedBG`"." -Component "Startup" -Type 1
            }
        }
    }
    else
    {
        Write-Warning "Something went wrong. No IP info present."
        Write-Log -Message "Something went wrong. No IP info present." -Component "Startup" -Type 3
    }
}
catch
{
    Write-Warning -Message "An error has occured during script execution."
    Write-Log -Message "An error has occured during script execution." -Component "Catch" -Type 3
    Get-ErrorInformation -incomingError $_
}

write-host "End of script."
Write-Log -Message "End of script" -Component "Startup" -Type 1

Set-Location $CurrentLocation