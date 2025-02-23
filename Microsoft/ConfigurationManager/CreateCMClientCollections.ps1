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

#region Collections
##

$Schedule = New-CMSchedule -Start "01/01/2016 11:00 PM" -RecurInterval Days -RecurCount 7

$Coll = New-CMCollection -CollectionType Device -Name "SCCM Client Version = $CMSystemVersion" -LimitingCollectionId 'PS10001B' -RefreshSchedule $Schedule -Comment "Version $CMSystemVersion"

Move-CMObject -InputObject $Coll -FolderPath "$SiteCode:\DeviceCollection\Administrative\Client Versions"

Add-CMDeviceCollectionQueryMembershipRule -InputObject $Coll -RuleName "Version $CMSystemVersion" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like `"$($CMClientVersion.Substring(0,9)).%`""

##
##

$Coll = New-CMCollection -CollectionType Device -Name "SCCM Client Version $CMSystemVersion" -LimitingCollectionId 'SMS00001' -RefreshSchedule $Schedule -Comment "Version $CMSystemVersion"

Move-CMObject -InputObject $Coll -FolderPath "$SiteCode:\DeviceCollection\Administrative\Client Versions"

Add-CMDeviceCollectionQueryMembershipRule -InputObject $Coll -RuleName "Version $CMSystemVersion" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like `"$($CMClientVersion.Substring(0,9)).%`""

##
##

$Coll = New-CMCollection -CollectionType Device -Name "SCCM Client Versions < $CMSystemVersion All Systems" -LimitingCollectionId 'SMS00001' -RefreshSchedule $Schedule -Comment "Version $CMSystemVersion"

Move-CMObject -InputObject $Coll -FolderPath "$SiteCode:\DeviceCollection\Administrative\Client Versions"

Add-CMDeviceCollectionQueryMembershipRule -InputObject $Coll -RuleName "Version $CMSystemVersion" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion < `"$($CMClientVersion.Substring(0,9))%`""

##
##

$Coll = New-CMCollection -CollectionType Device -Name "SCCM Client Versions < $CMSystemVersion" -LimitingCollectionId 'PS10003A' -RefreshSchedule $Schedule -Comment "Version $CMSystemVersion"

Move-CMObject -InputObject $Coll -FolderPath "$SiteCode:\DeviceCollection\Administrative\Client Versions"

Add-CMDeviceCollectionQueryMembershipRule -InputObject $Coll -RuleName "Version $CMSystemVersion" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion < `"$($CMClientVersion.Substring(0,9))%`""

##
##

$Coll = New-CMCollection -CollectionType Device -Name "SCCM Client: OEMIS, ISXX, MRX00X, OMDFP2, MTX00X workstations < $CMSystemVersion" -LimitingCollectionName "SCCM Client Versions < $CMSystemVersion" -RefreshSchedule $Schedule -Comment "Version $CMSystemVersion"

Move-CMObject -InputObject $Coll -FolderPath "$SiteCode:\DeviceCollection\Administrative\Client Versions"

Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS1000C2'
Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS100533'

##
##

$Coll = New-CMCollection -CollectionType Device -Name "SCCM Client: OEMIS, ISXX, MRX00X, OMDFP2, MTX00X workstations = $CMSystemVersion" -LimitingCollectionName "SCCM Client Version = $CMSystemVersion" -RefreshSchedule $Schedule -Comment "Version $CMSystemVersion"

Move-CMObject -InputObject $Coll -FolderPath "$SiteCode:\DeviceCollection\Administrative\Client Versions"

Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS1000C2'
Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS100533'

##

##

$Coll = New-CMCollection -CollectionType Device -Name "SCCM Client: NCH Thin Clients < $CMSystemVersion" -LimitingCollectionName "SCCM Client Versions < $CMSystemVersion" -RefreshSchedule $Schedule -Comment "Version $CMSystemVersion"

Move-CMObject -InputObject $Coll -FolderPath "$SiteCode:\DeviceCollection\Administrative\Client Versions"

Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS100996'
#Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS100533'

##
##

$Coll = New-CMCollection -CollectionType Device -Name "SCCM Client: NCH Thin Clients = $CMSystemVersion" -LimitingCollectionName "SCCM Client Version = $CMSystemVersion" -RefreshSchedule $Schedule -Comment "Version $CMSystemVersion"

Move-CMObject -InputObject $Coll -FolderPath "$SiteCode:\DeviceCollection\Administrative\Client Versions"

Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS100996'
#Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS100533'

##
##

$Coll = New-CMCollection -CollectionType Device -Name "SCCM Client: General Workstations < $CMSystemVersion" -LimitingCollectionName "SCCM Client Versions < $CMSystemVersion" -RefreshSchedule $Schedule -Comment "Version $CMSystemVersion"

Move-CMObject -InputObject $Coll -FolderPath "$SiteCode:\DeviceCollection\Administrative\Client Versions"

Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS1000D4'
Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS1000D5'
Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS1000D6'

##
##

$Coll = New-CMCollection -CollectionType Device -Name "SCCM Client: General Workstations = $CMSystemVersion" -LimitingCollectionName "SCCM Client Version = $CMSystemVersion" -RefreshSchedule $Schedule -Comment "Version $CMSystemVersion"

Move-CMObject -InputObject $Coll -FolderPath "$SiteCode:\DeviceCollection\Administrative\Client Versions"

Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS1000D4'
Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS1000D5'
Add-CMDeviceCollectionIncludeMembershipRule -InputObject $Coll -IncludeCollectionId 'PS1000D6'

##