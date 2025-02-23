Function Get-ADDomainDNS ($SearchBase)
{
    Write-host "DN passed: $SearchBase." -Component "Get-ADDomainDNS"
    $Domain = $SearchBase -Split "," | ? {$_ -like "DC=*"}
    $Domain = $Domain -join "." -replace ("DC=", "")

    Write-host "Domain name to return: $Domain" -Component "Get-ADDomainDNS"
    return $Domain
}

$SourceOU = "OU=Workstations,DC=Corp,OU=ViaMonstra,DC=com"
$ComputerOUs = "OU=Temp-FileAssocTest,OU=Test,DC=Corp,OU=ViaMonstra,DC=com"

$ADDomain = Get-ADDomainDNS -SearchBase $SourceOU
$ADNetBIOSName = (Get-ADDomain -Server $ADDomain).NetBIOSName
$DCName = (Get-ADDomainController -DomainName $ADDomain -Discover).Name + "." + (Get-ADDomainController -DomainName $ADDomain -Discover).Domain

ForEach ($ComputerOU in $ComputerOUs)
{
    $GPOComputerLinks = get-adorganizationalunit $SourceOU -Server $DCName | select -expandproperty linkedGroupPolicyObjects | get-adobject -prop displayName | select -expandproperty displayname
    ForEach ($GPOComputerLink in $GPOComputerLinks)
    {
        try
        {
            Write-Host "Linking GPO $GPOComputerLink"
            New-GPLink -Name $GPOComputerLink -Target $ComputerOU -Server $DCName -ErrorAction Stop
        }
        catch
        {
            Write-Warning $_
        }
    }
}