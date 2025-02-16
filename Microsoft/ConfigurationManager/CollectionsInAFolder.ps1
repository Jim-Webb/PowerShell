$FolderID = 16779269 # Use the WMI tool to get the FolderID
$CollectionsInSpecficFolder = Get-WmiObject -ComputerName CMServer -Namespace "ROOT\SMS\Site_HOS" -Query "select * from SMS_Collection where CollectionID is in(select InstanceKey from SMS_ObjectContainerItem where ObjectType='5000' and ContainerNodeID='$FolderID') and CollectionType='2'"

$SelectedFolder = $CollectionsInSpecficFolder | Select-Object Name, CollectionID, MemberCount | Sort-Object Name | Out-GridView -Title "Select the destination collection:" -OutputMode Single

$CollectionsInSpecficFolder.Name
