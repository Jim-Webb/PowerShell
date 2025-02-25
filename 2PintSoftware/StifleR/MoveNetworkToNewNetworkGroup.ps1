$Subnet = '192.168.5.0'
$NetworkGroupName = 'VPN Clients'

$NetworkGroup = Get-WmiObject -Class NetworkGroups -Namespace root\stifler | where {$_.Name -eq $NetworkGroupName}

If ($NetworkGroupName)
{
    Write-Host "Moving subnet $Subnet to NetworkGroup $($NetworkGroup.Name)"
    $Network = Get-WmiObject -Class Networks -Namespace root\stifler | where {$_.NetworkId -eq $Subnet}

    $Network.MoveToNewNetworkGroup($($NetworkGroup.ID))
}

