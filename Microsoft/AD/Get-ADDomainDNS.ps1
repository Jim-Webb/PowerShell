Function Get-ADDomainDNS ($SearchBase)
{
    $domain = $SearchBase -Split "," | ? {$_ -like "DC=*"}
    $domain = $domain -join "." -replace ("DC=", "")
    return $domain
}


Get-ADDomainDNS -SearchBase "CN=Computer1,OU=Workstations,DC=Corp,DC=ViaMonstra,DC=Com"