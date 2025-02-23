function ConvertFrom-DN {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [string[]]$DistinguishedName
    )
    process {
        foreach ($DN in $DistinguishedName) {
            Write-Verbose $DN
            $CanonNameSlug = ''
            $DC = ''
            foreach ( $item in ($DN.replace('\,', '~').split(','))) {
                if ( $item -notmatch 'DC=') {
                    $CanonNameSlug = $item.Substring(3) + '/' + $CanonNameSlug
                }
                else {
                    $DC += $item.Replace('DC=', ''); $DC += '.'
                }
            }
            $CanonicalName = $DC.Trim('.') + '/' + $CanonNameSlug.Replace('~', '\,').Trim('/')
            [PSCustomObject]@{
                'CanonicalName' = $CanonicalName;
            }
        }
    }
}

ConvertFrom-DN -DistinguishedName 'OU=General Workstations,OU=Research,DC=Corp,DC=ViaMonstra,DC=Com'