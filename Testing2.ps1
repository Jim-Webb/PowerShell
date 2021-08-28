#region SCCM site coonnection

# Site configuration
$SiteCode = "HOS" # Site code 
$ProviderMachineName = "H1PWSCCM01.COLUMBUSCHILDRENS.NEt" # SMS Provider machine name

# Customizations
$initParams = @{ }
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if ((Get-Module ConfigurationManager) -eq $null)
{
	Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams
}

# Connect to the site's drive if it is not already present
if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null)
{
	New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

#Endregion SCCM site coonnection

$date = [datetime]::Today.ToString('yyyy-MM')

$NewSUGName = "Monthly Updates - Third Party Patching $Date*"

$SUGUpdates = Get-CMSoftwareUpdateGroup -Name $NewSUGName | Get-CMSoftwareUpdate -fast | Select-Object LocalizedDisplayName
				
If ($SUGUpdates.Count -ge 1)
{
    Write-Host "The SUG `"$NewSUGName`" has updates."
}