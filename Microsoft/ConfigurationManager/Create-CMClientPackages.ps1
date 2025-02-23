function Import-CMPSModule() {
    Write-Host "Welcome to the Load-CMPSModule function."
    if ($env:SMS_ADMIN_UI_PATH -ne $null) {
        If (!(Get-Module -Name ConfigurationManager)) {
            Write-host "Found CM Console in Path, trying to import module."
            Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1) -Verbose:$false -Force
            if (Get-Module -Name ConfigurationManager) {
                Write-Host "$env:SMS_ADMIN_UI_PATH"
                Write-host "Successfully loaded CM Module from Installed Console"
                $Global:PSModulePath = $true
            }
        }
        Else {
            $Message = "CM Module is already loaded, no need to import module."
            Write-Verbose $Message
            Write-Host $Message
            $Global:PSModulePath = $true
        }
    }
    else {
        $Message = "CM Console is not in Path Variable. Unable to continue."
        Write-host $Message
        Write-Warning -Message $Message
		
        Set-Location $CurrentLocation
		
        exit 55378008
    }
	
}

$SiteCode = 'PS1'
$SiteServer = 'CM01.corp.viamonstra.com'

Write-Host "Importing SCCM PS Module"

# Load CM PowerShell Module
Import-CMPSModule

Set-Location "$($SiteCode):\"

# Values for ConfigMgr system
$CMSystemVersion = '2403'
$CMClientVersion = '5.00.9128.1007'

# CollectionID is used for the deployments at the bottom of the script. The collection ID must be changed to one of the newly created collections for the new version of the client.
# $CollectionID = 'PS10122F'

# $($CMClientVersion.Substring(0,9))

#region Create Program

$CMPackage = "SCCM $CMSystemVersion Client - $CMClientVersion"
$CMPackagePath = "\\corp.viamonstra.com\CMsource\Microsoft\ConfigMgr\$CMSystemVersion\Client\$CMClientVersion"
$CMPackageVersion = $CMClientVersion

$CMProgramName1 = "Install SCCM Client"
$CMProgramCommandLine1 = "install.cmd"

$CMProgramName2 = 'Install SCCM Client - Force Install'
$CMProgramCommandLine2 = 'InstallForce.cmd'

$CMProgramName3 = 'Install SCEP'
$CMProgramCommandLine3 = 'scepinstall /s /q'

$CMProgramName4 = 'Uninstall SCEP - Win7'
$CMProgramCommandLine4 = 'scepinstall /s /s'

$CMProgramName5 = 'Install SCCM Client - Run as Service'
$CMProgramCommandLine5 = 'InstallService.cmd'

#Create the package first
New-CMPackage -Name $CMPackage -Manufacturer "Microsoft" -Path $CMPackagePath -Language "English" -Version $CMPackageVersion
Set-CMPackage -Name $CMPackage -EnableBinaryDeltaReplication $true -CopyToPackageShareOnDistributionPoint $true -SendToPreferredDistributionPoint $true

# Distribute package content
Start-CMContentDistribution -PackageName $CMPackage -DistributionPointGroupName 'All DPs'

# Create Program 1
New-CMProgram -PackageName $CMPackage -CommandLine $CMProgramCommandLine1 -StandardProgramName $CMProgramName1 -ProgramRunType WhetherOrNotUserIsLoggedOn -RunMode RunWithAdministrativeRights -RunType Normal
Get-CMProgram -PackageName $CMPackage -ProgramName $CMProgramName1 | Set-CMProgram -StandardProgram -EnableTaskSequence $true -AfterRunningType NoActionRequired

# Create Program 2
New-CMProgram -PackageName $CMPackage -CommandLine $CMProgramCommandLine2 -StandardProgramName $CMProgramName2 -ProgramRunType WhetherOrNotUserIsLoggedOn -RunMode RunWithAdministrativeRights -RunType Normal
Get-CMProgram -PackageName $CMPackage -ProgramName $CMProgramName2 | Set-CMProgram -StandardProgram -EnableTaskSequence $true -AfterRunningType NoActionRequired

# Create Program 3
New-CMProgram -PackageName $CMPackage -CommandLine $CMProgramCommandLine3 -StandardProgramName $CMProgramName3 -ProgramRunType WhetherOrNotUserIsLoggedOn -RunMode RunWithAdministrativeRights -RunType Normal
Get-CMProgram -PackageName $CMPackage -ProgramName $CMProgramName3 | Set-CMProgram -StandardProgram -EnableTaskSequence $true -AfterRunningType NoActionRequired

# Create Program 4
New-CMProgram -PackageName $CMPackage -CommandLine $CMProgramCommandLine4 -StandardProgramName $CMProgramName4 -ProgramRunType WhetherOrNotUserIsLoggedOn -RunMode RunWithAdministrativeRights -RunType Normal
Get-CMProgram -PackageName $CMPackage -ProgramName $CMProgramName4 | Set-CMProgram -StandardProgram -EnableTaskSequence $true -AfterRunningType NoActionRequired

# Create Program 5
New-CMProgram -PackageName $CMPackage -CommandLine $CMProgramCommandLine5 -StandardProgramName $CMProgramName5 -ProgramRunType WhetherOrNotUserIsLoggedOn -RunMode RunWithAdministrativeRights -RunType Normal
Get-CMProgram -PackageName $CMPackage -ProgramName $CMProgramName5 | Set-CMProgram -StandardProgram -EnableTaskSequence $true -AfterRunningType NoActionRequired

#endregion Create Program

#region Deployment

# Deploy package to my test collection as available.
## New-CMPackageDeployment -CollectionId $CollectionID -StandardProgram -ProgramName $CMProgramName1 -PackageName $CMPackage -DeployPurpose Available -AvailableDateTime ([datetime]$AvailableDateTime = get-date -Hour 9 -Minute 0 -Second 0) -RunFromSoftwareCenter $true -RerunBehavior RerunIfFailedPreviousAttempt -FastNetworkOption DownloadContentFromDistributionPointAndRunLocally -SlowNetworkOption DoNotRunProgram

#Set Deadline to 4 days from now at 8AM
# [datetime]$RequiredDeadlineTime = (get-date -Hour 8 -Minute 0 -Second 0).AddDays(4)

#Create CM Schedule based on that Time we just created - Recuring Daily
# $NewScheduleDeadline = New-CMSchedule -Start $RequiredDeadlineTime -Nonrecurring

# Deploy package to my IS client deployment collection as required.
# New-CMPackageDeployment -CollectionId $CollectionID -StandardProgram -ProgramName $CMProgramName1 -PackageName $CMPackage -DeployPurpose Required -AvailableDateTime $((get-date -Hour 6 -Minute 0 -Second 0).AddDays(4)) -Schedule $NewScheduleDeadline -RunFromSoftwareCenter $false -RerunBehavior RerunIfFailedPreviousAttempt -FastNetworkOption DownloadContentFromDistributionPointAndRunLocally -SlowNetworkOption DoNotRunProgram -SoftwareInstallation $true
#endregion Deployment