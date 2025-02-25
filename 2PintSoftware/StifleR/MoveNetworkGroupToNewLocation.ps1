$NetworkGroupName = 'New York Office Building'
$NewLocation = "1c20b999-7ca3-4c3a-ae89-e7fc7315da4d"

$NetworkGroup = Get-WmiObject -Class NetworkGroups -Namespace root\stifler | where {$_.Name -eq $NetworkGroupName}

$NetworkGroup.MoveToNewLocation($NewLocation)