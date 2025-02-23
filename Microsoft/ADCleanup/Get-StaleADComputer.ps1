<#
.SYNOPSIS
This script scans AD looking for computer objects that have not logged into AD in a certain amount of time.

.DESCRIPTION
This script scans AD looking for computer objects that have not logged into AD in a certain amount of time. The script then expports a CSV file, a object XML export, and sends
and email with the relevent information.

.AUTHOR
Jim Webb

.REVISION HISTORY
-- '24.12.13.1' - Add functionality to retrieve the new LAPS password and include the the CSV export.
-- '24.12.13.1' - Changed to year, month, day, and revision numering scheme.
#>
[CmdletBinding()]
Param (
	[Parameter(mandatory=$true)]
	[string]$SearchBase,
    [string][ValidateSet('All', 'OnlyInactiveComputers', 'OnlyNeverLoggedOn')]
    $SearchScope = 'All',
	[string]$TimeSinceLogin = '180',
    [bool]$ComputerEnabled = $true,
	[string]$FileOutLocation = ($MyInvocation.MyCommand.Path).Replace(('\{0}' -f $MyInvocation.MyCommand.Name),''),
    [switch]$SendEmail,
    [switch]$OutPutObject
)

#region Functions

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

function ValidateOU ($SearchBase)
{
    Write-Log -Message "OU to validate: $SearchBase." -Component "ValidateOU" -Type 1
    try 
    {

        $OUInfo = Get-ADOrganizationalUnit -Server $DCName -Properties * -Identity $SearchBase -ErrorAction SilentlyContinue

        If ($OUInfo)
        {
            Write-Log -Message "OU is valid." -Component "ValidateOU" -Type 1
            Return $true
        }
        else
        {
            Write-Log -Message "OU is not valid." -Component "ValidateOU" -Type 1
            return $false    
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
    {
        Write-Log -Message "The OU `"$SearchBase`" doesn't exist." -Component "ValidateOU" -Type 1
        Write-Warning "The OU `"$SearchBase`" doesn't exist."
        return $false
    }
    Catch
    {
        Write-Warning "An error has occured."
        Write-Warning -Message "An error has occured during script execution."
        Write-Log -Message "An error has occured during script execution." -Component "ValidateOU-Catch" -Type 3
        Get-ErrorInformation -incomingError $_
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
	$LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
	
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

function SendEmail($NeedToSend)
{
	if ($EmailEnabled -eq $true)
	{
		if ($script:Debug) { Write-Log -Message "DEBUG: Sending email is enabled. Requested email will be sent." -Component "SendEmail" -Type 1 }
		If ($NeedToSend -eq $true)
		{
			If (test-path $OutPutFileCSV)
            {
                # Write-Host $EmailBody
                Write-Log -Message "Sending email with attachment." -Component "SendEmail" -Type 1
                $script:EmailBody += "Sending email with attachment.<br>"
			    Send-MailMessage -From $From -to $To -Subject $Subject -Body $script:EmailBody -SmtpServer $SMTPServer -BodyAsHtml -Attachments $OutPutFileCSV
            }
            else
            {
                Write-Log -Message "File `"$OutPutFileCSV`" could not be attached to this email" -Component "SendEmail" -Type 3
                $script:EmailBody += "File `"$OutPutFileCSV`" could not be attached to this email.<br>"
                # Write-Host $EmailBody
			    Send-MailMessage -From $From -to $To -Subject $Subject -Body $script:EmailBody -SmtpServer $SMTPServer -BodyAsHtml
            }
		}
		else
		{
			$Message = "Nothing to do. No need to send an email."
			Write-Verbose $Message
			Write-Log -Message $Message -Component "SendEmail" -Type 1
		}
	}
	Else
	{
		Write-Log -Message "Sending email is disabled. Requested email will NOT be sent." -Component "SendEmail" -Type 1
	}
}

Function Backup-Files($Source, $FileOut)
{
    If (!($Script:FilesToKeep))
    {
        $Script:FilesToKeep = 5
    }

	$directoryInfo = Get-ChildItem $Source -Force -ErrorAction SilentlyContinue | Measure-Object
	Write-Log -Message "Number of files in $Source - $($directoryInfo.count)." -Component 'Backup-Files' -Type 1
	If (Test-Path $Source)
	{
		# Gather various info to use later.
		$FileName = [io.path]::GetFileNameWithoutExtension($FileOut)
		$DirectoryName = [IO.Path]::GetDirectoryName($FileOut)
		$CompleteFileName = [IO.Path]::GetFileName($FileOut)
		$FileExtension = [IO.Path]::GetExtension($FileOut)
		$FileNameWithoutExtension = [IO.Path]::GetFileNameWithoutExtension($FileOut)
		
		Write-Log -Message "Log files exist in $Source." -Component 'Backup-Files' -Type 1
		try
		{
			Write-Log -Component 'Backup-Files' -Message "Source = $Source." -Type 1
			Write-Log -Component 'Backup-Files' -Message "FileOut = $FileOut." -Type 1
			
			$TempLocation = "C:\Windows\temp\LogBackup\Logs"
			
			Write-Log -Component 'Backup-Files' -Message "TempLocation = $TempLocation." -Type 1
			
			If (!(Test-Path $TempLocation))
			{
				Write-Log -Component 'Backup-Files' -Message "Create $TempLocation." -Type 1
				New-Item $TempLocation -ItemType Directory -Force
			}
			else
			{
				Write-Log -Component 'Backup-Files' -Message "TempLocation exists, removing previous files." -Type 1
				Remove-Item "$TempLocation\*" -Force -Recurse
			}
			
            $SourceType = Get-Item $Source

            If ($SourceType -is [System.IO.DirectoryInfo])
            {
                Copy-Item "$Source\*" -Destination $TempLocation -Force
            }
            elseif (($SourceType -is [System.IO.DirectoryInfo]) -eq $false)
            {
                Write-Log -Component 'Backup-Files' -Message "Copying files to backup location." -Type 1
			    Copy-Item "$Source" -Destination $TempLocation -Force
            }
			
			Write-Log -Component 'Backup-Files' -Message "If $FileOut exists, remove the file." -Type 1
			# If (Test-path $FileOut) { Remove-item $FileOut }
			
			If (Test-path $FileOut)
			{
				Write-Log -Component 'Backup-Files' -Message "Renaming existing file." -Type 1
				Rename-item -Path $FileOut -NewName "$DirectoryName\$FileName-$(get-date -Format yyyy-MM-dd-HHmmss)$FileExtension"
			}
			
			Write-Log -Component 'Backup-Files' -Message "Creating zip file $FileOut." -Type 1
			Add-Type -assembly "system.io.compression.filesystem"
			[io.compression.zipfile]::CreateFromDirectory($TempLocation, $FileOut)
			
			#File cleanup so we don't end up to a bunch of zip files.
			$a = Get-ChildItem "$DirectoryName\$FileName*" -File
			
			Write-Log -Component 'Backup-Files' -Message "Current number of zip files: $($a.Count)." -Type 1
			Write-Log -Component 'Backup-Files' -Message "Number of zip files to keep: $FilesToKeep." -Type 1
			
			# If number of current files is greater than the number set in $FilesToKeep, remove the oldest files.
			If ($a.count -gt $FilesToKeep)
			{
				Write-Log -Component 'Backup-Files' -Message "Removing older zip files." -Type 1
				$a | Sort-Object lastwritetime | Select-Object -First ($a.count - $FilesToKeep) | remove-item
			}
			
			Write-Log -Component 'Backup-Files' -Message "Everything seems to have worked. Return true." -Type 1
			
			return $true
		}
		Catch
		{
			Write-Log -Component 'Backup-Files' -Message "No log files exist in $Source." -Type 1
			Write-Log -Component 'Backup-Files' -Message "Error: "($_.exception.Message) -Type 1
		}
	}
	else
	{
		Write-Log -Component 'Backup-Files' -Message "No files exist in $Source. Return false." -Type 1
		return $false
	}
}


#endregion

#region #################################### START GLOBAL VARIABLES ####################################>

#Current Version information for script
# Added support for multiple domains so the Research domain could be scanned.
# Updated search so "*OU=VirtualWorkstations,*" is now "*OU=VirtualWorkstations*,*". This should make sure that Imprivata computers are also out of scope.
[version]$ScriptVersion = '24.12.13.1'

$Global:logfile = Prepare-logfile -LogFileName "Get-StaleADComputers" -LogFileLocation ScriptLocation

[bool]$Global:EnableLogWriteVerbose = $true
[bool]$Global:EmailEnabled = $true
[bool]$script:Debug = $true

[string]$script:CurrentLocation = ($MyInvocation.MyCommand.Path).Replace(('\{0}' -f $MyInvocation.MyCommand.Name),'')

$OUSimpleName = (($SearchBase -split 'OU=|,OU=')[1] -split ',')[0]

$ADDomain = Get-ADDomainDNS -SearchBase $SearchBase

$ADNetBIOSName = (Get-ADDomain -Server $ADDomain).NetBIOSName

$DCName = (Get-ADDomainController -DomainName $ADDomain -Discover).Name + "." + (Get-ADDomainController -DomainName $ADDomain -Discover).Domain

# Info required to send an email
$From = 'PSScript@corp.viamonstra.com'
$To = 'Important.Person@corp.viamonstra.com'
$Subject = "AD Stale Computer Report - $ADNetBIOSName - $OUSimpleName - $([cultureinfo]::InvariantCulture.DateTimeFormat.GetMonthName((Get-Date).Month)) $((Get-Date).Year)"
$SMTPServer = "smtp.corp.viamonstra.com"

# Number of file backups to keep
$Script:FilesToKeep = 5
$Today = [datetime]::Today.ToString('MM/dd/yyyy')

#endregion #################################### END GLOBAL VARIABLES ####################################>

try
{
	Try
	{
		#Import Modules & Snap-ins
    	Import-Module ActiveDirectory -Verbose:$false -ErrorAction Stop

		Import-Module LAPS -Verbose:$false -ErrorAction Stop
	}
	Catch
	{
		write-warning "An error occurred importing required PowerShell modules. Unable to continue."
		Write-Log -Message "An error occurred importing required PowerShell modules. Unable to continue." -Component "Catch" -Type 3
		Get-ErrorInformation -incomingError $_ 
		return 9999
	}

    Write-Host "Please use -verbose to get console output."

    Write-Log -Message "----------------------------------------------------------" -Component "Startup" -Type 1

    $EmailBody = "<h1>AD Computer Cleanup Report</h1>"

    Write-Log -Message "Script version: $ScriptVersion" -Component "Startup" -Type 1
    $EmailBody += "Script version: $ScriptVersion<br>"

    Write-Log -Message "Stale AD computer scan starting..." -Component "Startup" -Type 1
    $EmailBody += "Stale AD computer scan starting...<br>"

    $InactiveDate = (Get-Date).AddDays(-$TimeSinceLogin) # The 90 is the number of days from today since the last logon.

    Write-Log -Message "Using domain controller: $DCName" -Component "Startup" -Type 1

    Write-Log -Message "Domain: $ADNetBIOSName" -Component "Startup" -Type 1
    $EmailBody += "Domain: $ADNetBIOSName<br>"

    Write-Log -Message "Domain FQDN: $ADDomain" -Component "Startup" -Type 1
    $EmailBody += "Domain FQDN: $ADDomain<br>"

    Write-Log -Message "Domain controller: $DCName" -Component "Startup" -Type 1
    $EmailBody += "Domain controller: $DCName<br>"

    Write-Log -Message "OU to scan: $SearchBase" -Component "Startup" -Type 1
    $EmailBody += "OU to scan: $SearchBase<br>"
    
    if ($Change){Write-Host "Change: $change"}
    
    Write-Log -Message "Time since login: $TimeSinceLogin" -Component "Startup" -Type 1
    $EmailBody += "Time since login: $TimeSinceLogin<br>"
    
    Write-Log -Message "File out location: $fileoutlocation" -Component "Startup" -Type 1
    $EmailBody += "File out location: $fileoutlocation<br>"
    
    Write-Log -Message "Date threshold: $($InactiveDate.ToString())" -Component "Startup" -Type 1
    $EmailBody += "Date threshold: $($InactiveDate.ToString())<br>"
    
    $DomainDN = $SearchBase.Substring($SearchBase.IndexOf("DC="))
    Write-Log -Message "Domain to search: $Domain" -Component "Startup" -Type 1

    If (!(Test-Path $FileOutLocation))
    {
        throw "Something bad happened. File path $FileOutLocation doesn't exist."
    }

    If (!(ValidateOU -SearchBase $SearchBase))
    {
        write-warning "Something bad happened."
        break
    }

    If ($SendEmail)
    {
        Write-Log -Message "Send email: Enabled." -Component "Main" -Type 1
        $SendEmail = $true
    }
    else 
    {
        Write-Log -Message "Send email: Disabled." -Component "Main" -Type 1
        $SendEmail = $false
    }

    Write-Log -Message "Simple OU name: $OUSimpleName" -Component "Startup" -Type 1
    $EmailBody += "Simple OU name: $OUSimpleName<br>"

    $OutPutFileCSV = "$fileoutlocation\ADCleanup-$ADNetBIOSName-$OUSimpleName-ByDate${TimeSinceLogin}Days.csv"

	$OutPutFileXML = "$fileoutlocation\ADCleanup-$ADNetBIOSName-$OUSimpleName-ByDate${TimeSinceLogin}Days.xml"

    Write-Log -Message "Output file: $OutPutFileCSV" -Component "Startup" -Type 1
    $EmailBody += "Output file: $OutPutFileCSV<br>"
        
    # Export list to CSV
    # $Results = Get-ADComputer -Property Name, DistinguishedName, operatingSystem, lastLogonDate, PasswordLastSet, Enabled, Description, ms-Mcs-AdmPwd, ms-Mcs-AdmPwdExpirationTime -Filter { ((lastLogonDate -lt $InactiveDate) -and (operatingSystem -like "*Windows*")) } -SearchBase ($SearchBase) | Where-Object { ($_.DistinguishedName -notlike "*OU=VirtualWorkstations,*")} |Sort-Object -property lastlogondate | Select-Object Name, DistinguishedName, operatingSystem, lastLogonDate, PasswordLastSet, Enabled, Description, ms-Mcs-AdmPwd, @{n='AdmPwdExpirationTime';e={ [datetime]::FromFileTime($_.'ms-Mcs-AdmPwdExpirationTime')}} #| Export-Csv -Path "$fileoutlocation\ADCleanup-$OUSimpleName-ByDate${TimeSinceLogin}Days.csv" -NoTypeInformation

    Switch ($SearchScope) {
        'All'
        {
            Write-Verbose "SearchScope: All"
            #$Results = Get-ADComputer -Filter { (LastLogonDate -lt $InactiveDate -or LastLogonDate -notlike "*") -and (Enabled -eq $ComputerEnabled)} -SearchBase $SearchBase -Properties LastLogonDate | Select-Object Name, DistinguishedName, lastLogonDate, PasswordLastSet, Enabled, operatingSystem, Description, ms-Mcs-AdmPwd, @{n='ms-Mcs-AdmPwdExpirationTime';e={ [datetime]::FromFileTime($_.'ms-Mcs-AdmPwdExpirationTime')}}
            $Results = Get-ADComputer -Server $DCName -Filter { ((lastLogonDate -lt $InactiveDate) -or (lastLogonDate -notlike "*") -and (Enabled -eq $ComputerEnabled)) } -SearchBase ($SearchBase) -Property Name, DistinguishedName, operatingSystem, lastLogonDate, PasswordLastSet, Enabled, Description, ms-Mcs-AdmPwd, ms-Mcs-AdmPwdExpirationTime | Where-Object { ($_.DistinguishedName -notlike "*OU=VirtualWorkstations*,*") -and ($_.operatingSystem -notlike "*Mac OS X*")} | Select-Object Name, DistinguishedName, operatingSystem, lastLogonDate, PasswordLastSet, Enabled, Description, ms-Mcs-AdmPwd, @{n='AdmPwdExpirationTime';e={ [datetime]::FromFileTime($_.'ms-Mcs-AdmPwdExpirationTime')}},msLAPS-EncryptedPassword,@{n='msLAPS-PasswordExpirationTime';e={ [datetime]::FromFileTime($_.'msLAPS-PasswordExpirationTime')}} | Sort-Object -property lastlogondate
        }

        'OnlyInactiveComputers'
        {
            Write-Verbose "SearchScope: OnlyInactiveComputers"

            $Results = Get-ADComputer -Server $DCName -Filter { LastLogonDate -lt $InactiveDate -and Enabled -eq $ComputerEnabled } -SearchBase $SearchBase -Properties Name, DistinguishedName, operatingSystem, lastLogonDate, PasswordLastSet, Enabled, Description, ms-Mcs-AdmPwd, ms-Mcs-AdmPwdExpirationTime | Select-Object Name, DistinguishedName, lastLogonDate, PasswordLastSet, Enabled, operatingSystem, Description, ms-Mcs-AdmPwd, @{n='ms-Mcs-AdmPwdExpirationTime';e={ [datetime]::FromFileTime($_.'ms-Mcs-AdmPwdExpirationTime')}},msLAPS-EncryptedPassword,@{n='msLAPS-PasswordExpirationTime';e={ [datetime]::FromFileTime($_.'msLAPS-PasswordExpirationTime')}}
        }

        'OnlyNeverLoggedOn'
        {
            Write-Verbose "SearchScope: OnlyNeverLoggedOn"

            $Results = Get-ADComputer -Server $DCName -Filter { LastLogonDate -notlike "*" -and Enabled -eq $ComputerEnabled} -SearchBase $SearchBase -Properties Name, DistinguishedName, operatingSystem, lastLogonDate, PasswordLastSet, Enabled, Description, ms-Mcs-AdmPwd, ms-Mcs-AdmPwdExpirationTime | Select-Object Name, DistinguishedName, lastLogonDate, PasswordLastSet, Enabled, operatingSystem, Description, ms-Mcs-AdmPwd, @{n='ms-Mcs-AdmPwdExpirationTime';e={ [datetime]::FromFileTime($_.'ms-Mcs-AdmPwdExpirationTime')}},msLAPS-EncryptedPassword,@{n='msLAPS-PasswordExpirationTime';e={ [datetime]::FromFileTime($_.'msLAPS-PasswordExpirationTime')}}
        }

        Default
        {
            Write-Warning -Message "Error: An unknown error occcurred. Can't determine search scope. Exiting."
            Break
        }
    }

    If ($OutPutObject)
    {
        Write-Log -Message "Returning output as an object." -Component "Startup" -Type 3
        Write-Output $Results
    }
    else
    {
		$Result = Backup-Files -Source "$OutPutFileCSV" -FileOut "$OutPutFileCSV.zip"
        
		If ($Results)
		{
			# We need to use a custom object so we can add the existing properties in addition to the new LAPS decrypted password.
			$ExportObject = @()

			$Export = $Results| ForEach-Object -Process {
				$LapsPassword = Get-LapsADPassword -Identity $_.Name -AsPlainText
					$props = [pscustomobject]@{
					Name = $_.Name
					DistinguishedName = $_.DistinguishedName
					operatingSystem= $_.operatingSystem
					lastLogonDate = $_.lastLogonDate
					PasswordLastSet = $_.PasswordLastSet
					Enabled = $_.Enabled
					Description = $_.Description
					'ms-Mcs-AdmPwd' = $_.'ms-Mcs-AdmPwd'
					AdmPwdExpirationTime = $_.AdmPwdExpirationTime
					'msLAPS-PasswordExpirationTime' = $_.'msLAPS-PasswordExpirationTime'
					'msLAPS-DecryptedPassword' = $_.'msLAPS-DecryptedPassword'
					}
			
					$ExportObject += $props
			}
			
			$ExportObject | Export-Csv -Path $OutPutFileCSV -NoTypeInformation
		}

		if ($OutPutFileXML)
		{
			$Result = Backup-Files -Source "$OutPutFileXML" -FileOut "$OutPutFileXML.zip"
		}

		$Results | Export-Clixml -Path $OutPutFileXML

        Write-Log -Message "Number of stale computer accounts: $($results.count)" -Component "Main" -Type 1
        $EmailBody += "Number of stale computer accounts: $($results.count)<br>"

        If (($Results.count) -gt 100)
        {
            $EmailBody += "<b>Stale computer count greater than 100, cleanup needed.</b><br>"
            Write-Log -Message "Stale computer count greater than 100, cleanup needed." -Component "Main" -Type 1
        }

        Write-Log -Message "CSV file located on server: $env:computername." -Component "Startup" -Type 1
        $EmailBody += "CSV file located on server: $env:computername.<br>"

        Write-Log -Message "CSV file name: $OutPutFileCSV." -Component "Main" -Type 1
        $EmailBody += "CSV file name: $OutPutFileCSV.<br>"

		Write-Log -Message "End of script." -Component "Main" -Type 1
        $EmailBody += "End of script.<br>"
    }

	If (($EmailBody) -and ($SendEmail -eq $true))
	{
        Write-Log -Message "Preparing to send email." -Component "Main" -Type 1
		SendEmail -NeedToSend $true
	}
}
catch
{
    Write-Warning -Message "An error has occured during script execution."
    Write-Log -Message "An error has occured during script execution." -Component "Catch" -Type 3
    Get-ErrorInformation -incomingError $_ 
}