#
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#
# This script was auto-generated at '9/28/2023 12:58:42 PM'.

# Site configuration
$SiteCode = "PS1" # Site code 
$ProviderMachineName = "cm01.corp.viamonstra.com" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

$CurrentLocation = Get-Location

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

Write-Output "Getting deployed SCCM applications..."

$DeployedApplications = Get-CMApplicationDeployment

$TotalDeployedApps = $DeployedApplications.count

$i = 0

Foreach ($DeployedApplication in $DeployedApplications)
{
    $i++
    $percentComplete = ($i / $TotalDeployedApps) * 100
    Write-Progress -Activity "Item $i of $TotalDeployedApps" -PercentComplete $percentComplete -Status "$(([math]::Round((($i)/$TotalDeployedApps * 100),0))) % complete" -CurrentOperation "Enabling `"On-demand distribution`" for `"$($DeployedApplication.ApplicationName)`""

    # Read more: https://www.sharepointdiary.com/2021/11/progress-bar-in-powershell.html#ixzz90GhD0DDm
    # Write-Host "Processing `"$($DeployedApplication.ApplicationName)`"..."

    Set-CMApplication -Name ($DeployedApplication.ApplicationName) -SendToProtectedDistributionPoint $true
}

Set-Location $CurrentLocation