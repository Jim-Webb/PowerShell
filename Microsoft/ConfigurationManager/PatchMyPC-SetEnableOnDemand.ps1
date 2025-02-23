# https://talhaqamar.com/2017/02/01/list-sccm-applications-in-folder-using-powershell/

# Folder \Software Library\Overview\Application Management\Applications\PatchMyPC
$CMMWFolderID = '16778777'
[string]$SiteCode = "PS1"
[string]$SiteServer = 'CM01.corp.viamonstra.com'

$Instancekeys = (Get-WmiObject -Namespace "ROOT\SMS\Site_$Sitecode" -ComputerName $SiteServer -query "select InstanceKey from SMS_ObjectContainerItem where ObjectType='6000' and ContainerNodeID='$CMMWFolderID'").instanceKey
foreach ($key in $Instancekeys)
{
    $ApplicationName = (Get-WmiObject -Namespace "ROOT\SMS\Site_$Sitecode" -ComputerName $SiteServer -Query "select * from SMS_Applicationlatest where ModelName = '$key'").LocalizedDisplayName

    Write-Host "Processing application: $ApplicationName."

    Set-CMApplication -Name $ApplicationName -SendToProtectedDistributionPoint $true
}