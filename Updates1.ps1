Import-Module "C:\Users\jrw011\OneDrive - Nationwide Children's Hospital\PowerShell\Configuration Manager\Updates\Get-UpdateClassificationType.ps1"

Function Get-CMSoftwareUpdates{
    Param(
        $ComputerName = $env:COMPUTERNAME
    )
 
    $NameSpace = "ROOT\ccm\SoftwareUpdates\UpdatesStore"
    $Query = "Select * FROM CCM_UpdateStatus"
    $Class = "CCM_UpdateStatus"
    
    $Results = Get-WmiObject -ComputerName $ComputerName -Namespace $NameSpace -Class $class
    #$Results = Get-WmiObject -ComputerName $ComputerName -Namespace $NameSpace -Class $class -Query $Query
 
    return $Results
}

$Test = get-CMSoftwareUpdates -ComputerName "MRX00XTCHE102"

$Test = get-CMSoftwareUpdates -ComputerName "OEMIS2LTzz119"

$test | select title, status, article, Bulletin, RevisionNumber | where {$_.status -eq "Missing"} | ft -AutoSize

$test | select title, status, article, Bulletin, RevisionNumber, UpdateClassification | ft -AutoSize

$test | select title, status, article, Bulletin, RevisionNumber | where { $_.status -eq "Installed" } | ft -AutoSize


# Test
# Test
# Test