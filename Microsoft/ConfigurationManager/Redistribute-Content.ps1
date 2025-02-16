Function Redistribute-Content { 
    [CMDletBinding()] 
    param ( 
    [Parameter(Mandatory=$True)] 
    [ValidateNotNullorEmpty()] 
    [String]$DistributionPoint, 
    [Parameter()] 
    [ValidateNotNullorEmpty()] 
    [String]$SiteCode = 'PS1',
    [Parameter()] 
    [ValidateNotNullorEmpty()] 
    [String]$PrimaryServer = 'CM01'
    ) 
    Process {
    Write-Host "Site server: $PrimaryServer"
    Write-Host "Site code: $SiteCode"
    $query = 'SELECT * FROM SMS_PackageStatusDistPointsSummarizer WHERE State = 2 OR State = 3' 
    $Packages = Get-WmiObject -ComputerName $PrimaryServer -Namespace "root\SMS\Site_$($SiteCode)" -Query $query | Select-Object PackageID, @{N='DistributionPoint';E={$_.ServerNalPath.split('\')[2]}} 
    $FailedPackages = $Packages | Where-Object {$_.DistributionPoint -like "$DistributionPoint*"} | Select-Object -ExpandProperty PackageID

    Write-Host "Packages that failed to distribute to $DistributionPoint. `n $FailedPackages."

    foreach ($PackageID in $FailedPackages) { 
        $List = Get-WmiObject -ComputerName $PrimaryServer -Namespace "root\SMS\Site_$($SiteCode)" -Query "Select * From SMS_DistributionPoint WHERE PackageID='$PackageID' AND ServerNALPath like '%$DistributionPoint%'"
        Write-Host "Refreshing package $PackageID on $DistributionPoint."
        $List.RefreshNow = $True 
        $List.Put() | Out-Null
        } 
    } 
}

