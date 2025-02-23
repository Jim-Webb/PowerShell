[CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact = 'High')]
Param (
    [Parameter(mandatory=$true, ValueFromPipelineByPropertyName=$true)]
    [string]$Name,
    [Parameter(mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [string[]]$DistinguishedName,
    [string]$Change,
    [validateset('Enable', 'Disable')]
    [string]$Action
)

# Import-Clixml .\ADCleanup-Endpoints-ByDate180Days.xml | .\Disable-StaleComputers.ps1 -Change ChangeNumber -Action Disable

Begin {
    # Executes once before first item in pipeline is processed

    function Write-Log
    {
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
        
        If ($EnableLogWriteVerbose)
        {
            Write-Verbose -Message $Message
        }
        
        $SavedLocation = Get-Location
        Set-Location $myDirName
        
        $LogMessage = "<![LOG[$Message" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
        $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile -WhatIf:$false -Confirm:$false
        
        Set-Location $SavedLocation
    }
    
    function Prepare-logfile()
    {
        Param
        (
            [Parameter(Mandatory = $True)]
            $LogFileName,
            [Parameter(Mandatory = $True)]
            [ValidateSet('ScriptLocation', 'WindowsLogsSoftware')]
            $LogFileLocation
        )
        
        function get-scriptdirectory
        {
            if ($hostinvocation -ne $null)
            {
                Split-Path $hostinvocation.MyCommand.path
            }
            else
            {
                #$invocation = (get-variable MyInvocation -Scope 1).Value
                Split-Path -Parent $Script:MyInvocation.MyCommand.Path
            }
        }
        
        function get-scriptname
        {
            if ($hostinvocation -ne $null)
            {
                return Split-Path $hostinvocation.MyCommand.path -leaf
            }
            else
            {
                Split-Path $Script:MyInvocation.MyCommand.Path -Leaf
            }
        }
        
        $global:myDirName = get-scriptdirectory
        $MyScriptName = get-scriptname
        
        Write-Verbose "Script directory: $myDirName"
        Write-Verbose "Script name: $MyScriptName"
        
        $ScriptName = [IO.Path]::GetFileNameWithoutExtension($MyScriptName)
        
        Write-Verbose "Script name with extension: $ScriptName"
        
        Write-Verbose "Desired log file location: $LogFileLocation."
        
        Switch ($LogFileLocation)
        {
            ScriptLocation { $LogDir = "$myDirName\" }
            WindowsLogsSoftware
            {
                $WindowsDir = $env:SystemRoot
                
                Write-Verbose "Windows directory = $WindowsDir"
                
                $WindowsLogsSoftware = Test-Path -Path "$WindowsDir\Logs\Software"
                
                Write-Verbose "Path $WindowsDir\Logs\Software exists."
                
                If (!$WindowsLogsSoftware)
                {
                    New-Item "$WindowsDir\Logs\Software" -type directory | Out-Null
                }
                
                $LogDir = "$WindowsDir\Logs\Software\"
            }
        }
        
        $Logfile = "$LogDir$LogFileName.log"
        
        Write-Verbose "Log file name: $logfile"
        
        return $Logfile
    }

    function Get-ErrorInformation()
    {
        [cmdletbinding()]
        param ($incomingError)
        
        if ($incomingError -and (($incomingError | Get-Member | Select-Object -ExpandProperty TypeName -Unique) -eq 'System.Management.Automation.ErrorRecord'))
        {
            Write-Host `n"Error information:"`n
            Write-Log -Message "Error information:" -Component "Get-ErrorInformation" -Type 1
            Write-Host `t"Exception type for catch: [$($IncomingError.Exception | Get-Member | Select-Object -ExpandProperty TypeName -Unique)]"`n
            Write-Log -Message "Exception type for catch: [$($IncomingError.Exception | Get-Member | Select-Object -ExpandProperty TypeName -Unique)]" -Component "Get-ErrorInformation" -Type 1
            
            if ($incomingError.InvocationInfo.Line)
            {
                Write-Host `t"Command                 : [$($incomingError.InvocationInfo.Line.Trim())]"
                Write-Log -Message "Command: [$($incomingError.InvocationInfo.Line.Trim())]" -Component "Get-ErrorInformation" -Type 1
            }
            else
            {
                Write-Host `t"Unable to get command information! Multiple catch blocks can do this :("`n
                Write-Log -Message "Unable to get command information! Multiple catch blocks can do this :(" -Component "Get-ErrorInformation" -Type 1
            }
            
            Write-Host `t"Exception               : [$($incomingError.Exception.Message)]"`n
            Write-Log -Message "Exception: [$($incomingError.Exception.Message)]" -Component "Get-ErrorInformation" -Type 1
            Write-Host `t"Target Object           : [$($incomingError.TargetObject)]"`n
            Write-Log -Message "Target Object: [$($incomingError.TargetObject)]" -Component "Get-ErrorInformation" -Type 1
        }
        Else
        {
            Write-Host "Please include a valid error record when using this function!" -ForegroundColor Red -BackgroundColor DarkBlue
            Write-Log -Message "Please include a valid error record when using this function!" -Component "Get-ErrorInformation" -Type 1
        }
    }

    Function Get-ADDomainDNS ($SearchBase)
{
    Write-Log -Message "DN passed: $SearchBase." -Component "Get-ADDomainDNS" -Type 1
    $Domain = $SearchBase -Split "," | ? {$_ -like "DC=*"}
    $Domain = $Domain -join "." -replace ("DC=", "")

    Write-Log -Message "Domain name to return: $Domain" -Component "Get-ADDomainDNS" -Type 1
    return $Domain
}

    Function Get-ComputerSafeToDisable ()
    {
    [CmdletBinding()]
    Param (
        [Parameter(mandatory=$true)]
        [string]$ComputerName,
        [string]$TimeSinceLogin = '30',
        [bool]$ComputerEnabled = $true
    )
        Write-Log -Message "Checking to see if it's safe to disable $ComputerName." -Component "Get-ComputerSafeToDisable" -Type 1
        $InactiveDate = (Get-Date).AddDays(-$TimeSinceLogin)

        $ComputerInfo = Get-ADComputer -Filter { Name -eq $ComputerName } -Server $DCName -Property lastLogonDate, Enabled

        If ($ComputerInfo)
        {
            Write-Log -Message "Computer found in AD" -Component "Get-ComputerSafeToDisable" -Type 1
            If ($ComputerInfo.LastLogonDate -lt $InactiveDate)
            {
                Write-Log -Message "$ComputerName has not logged into AD in the last $TimeSinceLogin days. Computer is safe to disable." -Component "Get-ComputerSafeToDisable" -Type 1
                return $true
            }
            else
            {
                Write-Log -Message "$ComputerName has logged into AD in the last $TimeSinceLogin days. Computer is not safe to disable." -Component "Get-ComputerSafeToDisable" -Type 1
                Write-Log -Message "Last login date: $($ComputerInfo.LastLogonDate)." -Component "Get-ComputerSafeToDisable" -Type 1
                return $false
            }
        }
        else
        {
            # No computer was returned from AD.
            Write-Log -Message "Computer not found in AD." -Component "Get-ComputerSafeToDisable" -Type 1
            Write-Verbose "Computer $ComputerName not found in AD."
            Return $false
        }

    }

    #Current Version information for script
    [version]$ScriptVersion = '2.0.2404.1'

    $Global:logfile = Prepare-logfile -LogFileName "Set-StaleADComputerStatus" -LogFileLocation ScriptLocation
    [bool]$Global:EnableLogWriteVerbose = $true

    Write-Log -Message "----------------------------------------------------------" -Component "Begin" -Type 1
    Write-Log -Message "Script version: $ScriptVersion" -Component "Begin" -Type 1
    Write-Log -Message "Stale AD computer status update starting..." -Component "Begin" -Type 1

    Write-Log -Message "Script action: $action" -Component "Begin" -Type 1

    If ($Change)
    {
        Write-Log -Message "Change request: $Change" -Component "Begin" -Type 1
    } 
 
    $TotalItems = $Input.Count
    Write-Log -Message "Number of items passed: $TotalItems" -Component "Begin" -Type 1

    [int]$Count = 0
  }

  Process {
    # Executes once for each pipeline object

    try {
        Write-Log -Message "--------------------------------" -Component "Process" -Type 1

        #Import Modules & Snap-ins
        Import-Module ActiveDirectory -Verbose:$false

        # Get additioanl info regarding the AD domain
        Write-Log -Message "Distinguished Name: $DistinguishedName" -Component "Begin" -Type 1

        $ADDomain = Get-ADDomainDNS -SearchBase $DistinguishedName

        Write-Log -Message "AD Domain: $ADDomain" -Component "Startup" -Type 1

        $ADNetBIOSName = (Get-ADDomain -Server $ADDomain).NetBIOSName

        Write-Log -Message "AD Domain Short Name: $ADNetBIOSName" -Component "Startup" -Type 1

        $DCName = (Get-ADDomainController -DomainName $ADDomain -Discover).Name + "." + (Get-ADDomainController -DomainName $ADDomain -Discover).Domain
        Write-Log -Message "Using domain controller: $DCName" -Component "Startup" -Type 1
        #

        # $Count++
        # [int]$percentComplete = ($Count/$TotalItems * 100)
        # [string]$Activity = "Processing computer $Name"
        # Write-Progress -Activity $Activity -PercentComplete $percentComplete -Status ("Working - " + $percentComplete + "%")

        Write-Log -Message "Processing computer $Name." -Component "Process" -Type 1

        If ($Action -eq "Enable")
        {
            Write-Log -Message "Enabling computer $Name and removing description." -Component "Process" -Type 1
            if($PSCmdlet.ShouldProcess($Name,"Enable Computer")){
                Set-ADComputer $Name -Enabled $true -Clear Description -Server $DCName
            }
        }
        elseif ($Action -eq "Disable")
        {
            # Get-ADComputer $name | Select-Object  Name, DistinguishedName
            Write-Log -Message "Disabling computer $Name and setting description to `"Disabled via change $Change`"." -Component "Process" -Type 1
            if($PSCmdlet.ShouldProcess($Name,"Set-ADComputer $Name -Enabled $false -Description `"Disabled via change $Change`"")){
                
                #Let's check to make sure the computer hasn't become active before we disable the computer account.
                If ((Get-ComputerSafeToDisable -ComputerName $Name) -eq $true)
                {                
                    Write-Log -Message "Disabling computer $Name." -Component "Process" -Type 1
                    Set-ADComputer $Name -Enabled $false -Description "Disabled via change $Change." -Server $DCName -Confirm:$false
                }
                else
                {
                    Write-Log -Message "Not disabling computer $Name." -Component "Process" -Type 1
                }
            }
        }
    }
    catch
    {
        Write-Warning -Message "An error has occured during script execution."
        Write-Log -Message "An error has occured during script execution." -Component "Catch" -Type 3
        Get-ErrorInformation -incomingError $_ 
    }
   
    <#else
    {
        Write-Host $_.name
        # Write-Host $_.DistinguishedName

        # $ComputerName = (($_.name -split 'CN=|,CN=')[1] -split ',')[0]

        Get-ADComputer "$($_.name)" -Properties *

        # Write-Host $DistinguishedName
    }#>
  }

  End {
    # Executes once after last pipeline object is processed
    Write-Log -Message "End of script." -Component "End" -Type 1
  }