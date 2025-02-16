$Global:ScriptVersion   = "1.2204.1"
$Global:CMLogFilePath   = "C:\Windows\Logs\Software\SoftwareUninstall.log"
$Global:CMLogFileSize   = "40"

#############################################################################
#If Powershell is running the 32-bit version on a 64-bit machine, we 
#need to force powershell to run in 64-bit mode .
#############################################################################
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
write-warning "Y'arg Matey, we're off to 64-bit land....."
if ($myInvocation.Line) {
    &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
}else{
    &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
}
exit $lastexitcode
}
function Start-CMTraceLog
{
# Checks for path to log file and creates if it does not exist
param (
    [Parameter(Mandatory = $true)]
    [string]$Path
        
)

$indexoflastslash = $Path.lastindexof('\')
$directory = $Path.substring(0, $indexoflastslash)

if (!(test-path -path $directory))
{
    New-Item -ItemType Directory -Path $directory
}
else
{
    # Directory Exists, do nothing    
}
}
function Write-CMTraceLog
{
param (
    [Parameter(Mandatory = $true)]
    [string]$Message,
        
    [Parameter()]
    [ValidateSet(1, 2, 3)]
    [int]$LogLevel = 1,

    [Parameter()]
    [string]$Component,

    [Parameter()]
    [ValidateSet('Info','Warning','Error')]
    [string]$Type
)
$LogPath = $Global:CMLogFilePath

Switch ($Type)
{
    Info {$LogLevel = 1}
    Warning {$LogLevel = 2}
    Error {$LogLevel = 3}
}

# Get Date message was triggered
$TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"

$Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'

# When used as a module, this gets the line number and position and file of the calling script
# $RunLocation = "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)"

$LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), $Component, $LogLevel
$Line = $Line -f $LineFormat

# Write new line in the log file
Add-Content -Value $Line -Path $LogPath

# Roll log file over at size threshold
if ((Get-Item $Global:CMLogFilePath).Length / 1KB -gt $Global:CMLogFileSize)
{
    $log = $Global:CMLogFilePath
    Remove-Item ($log.Replace(".log", ".lo_"))
    Rename-Item $Global:CMLogFilePath ($log.Replace(".log", ".lo_")) -Force
}
} 

# Function to find MSI-based Uninstallers and Run their uninstall silently
function Remove-MSISoftware
{
param(
    [string]$DisplayName,
    [switch]$OfficeShim
)

Write-CMTraceLog -Message "Start Detection of: $DisplayName" -Type "Info" -Component "Main"
    
# determine if X64 Process, used to know where to look for app information in the registry
[boolean]$Is64Bit = [boolean]((Get-WmiObject -Class 'Win32_Processor' -ErrorAction 'SilentlyContinue' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)

$path = "\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$pathwow6432 = "\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

# =============================================================================
# -----------------------------------------------------------------------------
# Run regular code to check for install status
# Note that this code chunk probably should be updated to the 2020 version~
# -----------------------------------------------------------------------------
# Pre-Flight Null
$32bit = $false
$64bit = $false
$Installed = $null
$Installedwow6432 = $null
# write-host "Software Name:    $DisplayName"
# write-host "Software Version: $Version"

$Installed = Get-ChildItem HKLM:$path -Recurse -ErrorAction Stop | Get-ItemProperty -name DisplayName -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like $DisplayName}
if ($is64bit)
{
    $Installedwow6432 = Get-ChildItem HKLM:$pathwow6432 -Recurse -ErrorAction Stop | Get-ItemProperty -name DisplayName -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like $DisplayName}
}

# If found in registry,
if ($null -ne $Installed)
{
    Write-CMTraceLog -Message "   App detected in registry tree" -Type "Info" -Component "Main"

    foreach ($Entry in $Installed)
    {
        write-host "Removing $($Entry.displayname)"
        $Guid = $entry.Pschildname
        $RegistryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$GUID"
        
        if ($OfficeShim) {
           $UninstallString = (Get-ItemPropertyValue -Path $RegistryPath -Name "UninstallString")
           }
        Else {
           $UninstallString = (Get-ItemPropertyValue -Path $RegistryPath -Name "UninstallString") + " /qn /norestart"
            
           if ($UninstallString -like("*/I*")){
           $UninstallString = $UninstallString -replace "/I", "/X"
           }
        }

        $filepath = $UninstallString.Split(" ","2")[0]
        $argumentlist = $UninstallString.Split(" ","2")[1]
        Write-Host $filepath $argumentlist
       
            Write-CMTraceLog -Message "   Attempting to uninstall $GUID | $UninstallString" -Type "Info" -Component "Main"

            $exitCode = (Start-process -FilePath $filepath -ArgumentList $argumentlist -Wait -passthru).ExitCode

            Write-CMTraceLog -Message "   Uninstall completed with exit code $($exitCode)" -Type "Info" -Component "Main"
        
    }
}

# If found in registry under Wow6432 path,
if ($null -ne $Installedwow6432)
{
    Write-CMTraceLog -Message "   App detected in Wow6432 registry tree" -Type "Info" -Component "Main"

    foreach ($Entry in $Installedwow6432)
    {
        write-host "Removing $($Entry.displayname)"
        $Guid = $entry.Pschildname
        $RegistryPath = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$GUID"
        if (Test-Path $RegistryPath)
        {
            if ($OfficeShim) {
                $UninstallString = (Get-ItemPropertyValue -Path $RegistryPath -Name "UninstallString")
            }
            Else {
                $UninstallString = (Get-ItemPropertyValue -Path $RegistryPath -Name "UninstallString") + " /qn"
            
                if ($UninstallString -like("*/I*")){
                    $UninstallString = $UninstallString -replace "/I", "/X"
                }
            }

            $filepath = $UninstallString.Split(" ","2")[0]
            $argumentlist = $UninstallString.Split(" ","2")[1]

            Write-CMTraceLog -Message "   Attempting to uninstall $GUID | $UninstallString" -Type "Info" -Component "Main"

            $exitCode = (Start-process -FilePath $filepath -ArgumentList $argumentlist -Wait -passthru).ExitCode

            Write-CMTraceLog -Message "   Uninstall completed with exit code $($exitCode)" -Type "Info" -Component "Main"
        }
    }
}
}

Start-CMTraceLog -Path $Global:CMLogFilePath

Remove-MSISoftware -DisplayName "Software Name*"