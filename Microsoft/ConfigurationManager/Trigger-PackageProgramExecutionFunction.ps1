Function Trigger-PackageProgramExecution ()
{

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)][string]
	$PackageID = 'PS101A56',
    $ProgramName = 'Rotate and Escrow Key'
)

$Packages = get-wmiobject -query "SELECT * FROM CCM_SoftwareDistribution" -namespace "root\ccm\policy\machine\actualconfig" | where {$_.PKG_PackageID -eq $PackageID}

If ($Packages.Count -ge 1)
{
    $Packages = $Packages[0]
    $AdvID = $Packages[0].ADV_AdvertisementID
}
else
{
    $AdvID = $Packages.ADV_AdvertisementID
}

$Sched = (get-wmiobject -query "SELECT * FROM CCM_Scheduler_ScheduledMessage WHERE ScheduledMessageID LIKE ""%-$($Packages.PKG_PackageID)-%""" -namespace "ROOT\ccm\policy\machine\actualconfig").ScheduledMessageID

[void](get-wmiobject -query "SELECT * FROM CCM_Scheduler_ScheduledMessage WHERE ScheduledMessageID='$Sched'" -namespace "ROOT\ccm\policy\machine\actualconfig")
$a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$AdvID',PKG_PackageID='$PackageID',PRG_ProgramID='$ProgramName'");$a.ADV_RepeatRunBehavior='RerunAlways';$a.Put()
$a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$AdvID',PKG_PackageID='$PackageID',PRG_ProgramID='$ProgramName'");$a.ADV_MandatoryAssignments=$True;$a.Put()
$a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$AdvID',PKG_PackageID='$PackageID',PRG_ProgramID='$ProgramName'");$a.PRG_Requirements='<?xml version=''1.0'' ?><SWDReserved>    <PackageHashVersion>4</PackageHashVersion>    <PackageHash.1></PackageHash.1>    <PackageHash.2>B290246BF29DA99C6ADAF5FB330669C936770C7091F0DB4D069B5E3A8FCE9AE3</PackageHash.2>    <NewPackageHash><Hash HashPreference="4" Algorithm="140789027962884" HashString="B290246BF29DA99C6ADAF5FB330669C936770C7091F0DB4D069B5E3A8FCE9AE3" SignatureHash="13F51176D7C1BAD32FF1FBC7837B1E803AA878317C81059F01031DC44BCE4B4F"/></NewPackageHash>    <ProductCode></ProductCode>    <DisableMomAlerts>false</DisableMomAlerts>    <RaiseMomAlertOnFailure>false</RaiseMomAlertOnFailure>    <BalloonRemindersRequired>false</BalloonRemindersRequired>    <PersistOnWriteFilterDevices>true</PersistOnWriteFilterDevices>    <DefaultProgram>false</DefaultProgram>    <PersistInCache>0</PersistInCache>    <DistributeOnDemand>true</DistributeOnDemand>    <Multicast>false</Multicast>    <MulticastOnly>false</MulticastOnly>    <MulticastEncrypt>false</MulticastEncrypt>    <DonotFallback>true</DonotFallback>    <PeerCaching>true</PeerCaching>    <OptionalPreDownload>false</OptionalPreDownload>    <PreDownloadRule></PreDownloadRule>    <Requirements></Requirements>    <AssignmentID></AssignmentID>    <ScheduledMessageID>HOS206FD-HOS01A56-4BA97153</ScheduledMessageID>    <OverrideServiceWindows>TRUE</OverrideServiceWindows>    <RebootOutsideOfServiceWindows>FALSE</RebootOutsideOfServiceWindows>    <WoLEnabled>FALSE</WoLEnabled>    <ContainsAdditionalProperties>FALSE</ContainsAdditionalProperties></SWDReserved>';$a.Put()

Foreach ($Item in $sched)
{
    ([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule("$item")

    #Invoke-WmiMethod -Namespace root\ccm -Class SMS_Client -Name TriggerSchedule -ArgumentList "$Sched"

    Write-Output "Triggered Package $PackageID, and program `"$ProgramName`"."
}

}

Trigger-PackageProgramExecution -PackageID 'PS101A56' -ProgramName 'Rotate and Escrow Key'