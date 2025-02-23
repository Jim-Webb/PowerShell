Import-Module -Name "$(split-path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1"

cd PS1:

<#
$Schedule = New-CMSchedule -Start "08/10/2018 11:00 PM" -Nonrecurring
$PackageName = "Package1"
$ProgramName = "Program1"
$CollectionName = "Important Collection"
[datetime]$AvailableDateTime = Get-Date -Date "08/09/2018 09:00:00 AM"
#>

function Deploy-CMPackageDeployment ($PackageName, $ProgramName, $CollectionName, $AvailableDateTime, $Schedule)
{
New-CMPackageDeployment -StandardProgram -PackageName $PackageName `
    -ProgramName $ProgramName -DeployPurpose Required -Schedule `
    $Schedule -RerunBehavior RerunIfFailedPreviousAttempt -SoftwareInstallation $true `
    -FastNetworkOption DownloadContentFromDistributionPointAndRunLocally `
    -SlowNetworkOption DownloadContentFromDistributionPointAndLocally `
    -AvailableDateTime $AvailableDateTime `
    -CollectionName $CollectionName -Verbose

}

# Sample command line
# Deploy-CMPackageDeployment -PackageName $PackageName -ProgramName $ProgramName -CollectionName $CollectionName -AvailableDateTime $(Get-Date -Date "08/13/2018 07:00:00 AM") -Schedule $(New-CMSchedule -Start "08/13/2018 09:00 AM" -Nonrecurring)

######################################################################################################################################################################################################################################################################################################

#Web-Key Deployment 1
Deploy-CMPackageDeployment -PackageName $PackageName -ProgramName $ProgramName -CollectionName $CollectionName -AvailableDateTime $(Get-Date -Date "08/27/2018 07:00:00 AM") -Schedule $(New-CMSchedule -Start "08/27/2018 09:00 AM" -Nonrecurring)