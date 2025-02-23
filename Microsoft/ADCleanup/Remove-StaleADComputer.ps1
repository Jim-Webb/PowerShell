[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = 'High')]
Param (
	#[Parameter(mandatory=$true, ValueFromPipeline=$true)]
    [Parameter(mandatory=$true, ValueFromPipelineByPropertyName)]
    #[Parameter(mandatory=$true, ValueFromPipelineByPropertyName=$true)]
	[string]$DistinguishedName,
    [Parameter(mandatory=$false, ValueFromPipelineByPropertyName)]
    [string]$Name,
    [parameter(mandatory=$true)]
    [string]$Change,
    [validateset('Delete')]
    [string]$Action
)



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
        $Domain = $SearchBase -Split "," | Where-Object {$_ -like "DC=*"}
        $Domain = $Domain -join "." -replace ("DC=", "")
    
        Write-Log -Message "Domain name to return: $Domain" -Component "Get-ADDomainDNS" -Type 1
        return $Domain
    }

    #Current Version information for script
    [version]$ScriptVersion = '2.0.2312.1'

    $Global:logfile = Prepare-logfile -LogFileName "Remove-StaleADComputers" -LogFileLocation ScriptLocation
    [bool]$Global:EnableLogWriteVerbose = $true

    Write-Log -Message "----------------------------------------------------------" -Component "Begin" -Type 1
    Write-Log -Message "Script version: $ScriptVersion" -Component "Begin" -Type 1
    Write-Log -Message "Remove Stale AD computer starting..." -Component "Begin" -Type 1

      Write-Log -Message "Script action: $action" -Component "Begin" -Type 1

    If ($Change)
    {
        Write-Log -Message "Change request: $Change" -Component "Begin" -Type 1
    } 
 
  }

  Process {
    # Executes once for each pipeline object
    $ComputerDescription = "Disabled via change $Change."
    
    try {

        #Import Modules & Snap-ins
        Import-Module ActiveDirectory -Verbose:$false

        Write-Log -Message "Processing computer $DistinguishedName." -Component "Process" -Type 1

        # Get additioanl info regarding the AD doamin
        $ADDomain = Get-ADDomainDNS -SearchBase $DistinguishedName

        $ADNetBIOSName = (Get-ADDomain -Server $ADDomain).NetBIOSName

        $DCName = (Get-ADDomainController -DomainName $ADDomain -Discover).Name + "." + (Get-ADDomainController -DomainName $ADDomain -Discover).Domain
        Write-Log -Message "Using domain controller: $DCName" -Component "Startup" -Type 1
        #

        Write-Log -Message "Distinguished Name: $DistinguishedName" -Component "Begin" -Type 1

        If ($Action -eq "Delete")
        {
            $Computer = Get-ADComputer -Server $DCName -Filter {(DistinguishedName -eq $DistinguishedName) -and (Enabled -eq 'False') -and (Description -eq $ComputerDescription )}

            If (!($computer))
            {
                Write-Warning "Computer $Name not found in AD or search criteria not met. No changes made. Moving on to next item."
                return
            }

            if($PSCmdlet.ShouldProcess($DistinguishedName,"Delete computer")){
                Write-Log -Message "Deleting computer $DistinguishedName from AD." -Component "Process" -Type 1
                Write-Host "Deleting computer $DistinguishedName from AD." -ForegroundColor Green

                try{
                    $Message = "Attemtping to delete computer $DistinguishedName..."
                    Write-Output $Message
                    Write-Log -Message "$Message" -Type 1 -Component "General Information"
            
                    $Computer | Remove-ADComputer -Server $DCName -ErrorAction Stop -Confirm:$false
            
                    $Message = "Computer $DistinguishedName was deleted sucessfully."
                    Write-Output $Message
                    Write-Log -Message "$Message" -Type 1 -Component "General Information"
                }
                catch [Microsoft.ActiveDirectory.Management.ADException]
                {
                    $Message = "An error occured deleting $Name."
                    Write-Warning $Message
                    Write-Log -Message "$Message" -Type 3 -Component "Catch"
                    if ($Error[0].Exception.Message -eq "The directory service can perform the requested operation only on a leaf object")
                    {
                        $Message = "Computer $DistinguishedName is a leaf object. Attempting delete using Remove-ADObject instead of Remove-ADComputer."
                        Write-Output $Message
                        Write-Log -Message "$Message" -Type 3 -Component "Catch"
                        try{
                            # Delete computer accounts that are leaf objects.
                            $Computer | Remove-ADObject -Server $DCName -Recursive -Confirm:$false
                            $Message = "Computer $Name was deleted sucessfully."
                            Write-Output $Message
                            Write-Log -Message "$Message" -Type 1 -Component "Catch"
                        }
                        Catch
                        {
                            $Message = "Failed to delete leaf object computer."
                            Write-Warning $Message
                            Write-Log -Message "$Message" -Type 1 -Component "Catch"
            
                            $Message = -Message "Error: "($_.exception.Message)
                            Write-Warning -Message $Message
                            Write-Log -Message "$Message" -Type 1 -Component "Catch"
            
                        }
                    }
                }
            


                # Set-ADComputer $Name -Enabled $true -Clear Description
            }
        }
    }
    catch
    {
        Write-Warning -Message "An error has occured during script execution."
        Write-Log -Message "An error has occured during script execution." -Component "Catch" -Type 3
        Get-ErrorInformation -incomingError $_ 
    }
  }

  End {
    # Executes once after last pipeline object is processed
    Write-Log -Message "End of script." -Component "End" -Type 1
  }