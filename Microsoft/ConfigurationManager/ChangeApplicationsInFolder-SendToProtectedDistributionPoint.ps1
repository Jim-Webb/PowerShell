[string]$SiteCode = "PS1"
[string]$SiteServer = 'CM01.corp.viamonstra.com'

Application\PatchMyPC

$Applications = (Get-WmiObject -Namespace "ROOT\SMS\Site_$Sitecode" -ComputerName $SiteServer -Query "select * from SMS_ApplicationLatest where ObjectPath = '/CrowdStrike'").LocalizedDisplayName

Foreach ($Application in $Applications)
{
    Set-CMApplication -Name $Application -SendToProtectedDistributionPoint $true
}

(Get-WmiObject -Namespace "ROOT\SMS\Site_$Sitecode" -ComputerName $SiteServer -Query "select * from SMS_Package where ObjectPath = '/Microsoft'").Name