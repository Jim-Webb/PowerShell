[CmdletBinding()]
Param (
	[Parameter(Mandatory=$true)]
	[string]$ReportServer,
    [string]$BackupDirectory
)

# The script was taken from the blog post below. The site is no longer available.
# http://www.sqlmusings.com/2011/03/28/how-to-download-all-your-ssrs-report-definitions-rdl-files-using-powershell/

# This is an article by Garth Jones that covers the use of this script.
# https://www.recastsoftware.com/resources/how-do-you-backup-all-of-your-custom-configmgr-reports/

# note this is tested on PowerShell v2 and SSRS 2008 R2
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Xml.XmlDocument");
[void][System.Reflection.Assembly]::LoadWithPartialName("System.IO");
 
If (!($ReportServer))
{
    Write-Warning "Report Server not found."
}
# At this point we assume the the URL is valid. A check may be added later.
$ReportServerUri = "https://$ReportServer/ReportServer/ReportService2005.asmx";
$Proxy = New-WebServiceProxy -Uri $ReportServerUri -Namespace SSRS.ReportingService2005 -UseDefaultCredential ;
 
# check out all members of $Proxy
# $Proxy | Get-Member
# http://msdn.microsoft.com/en-us/library/aa225878(v=SQL.80).aspx
 
#second parameter means recursive
$items = $Proxy.ListChildren("/", $true) | `
         Select-Object Type, Path, ID, Name | `
         Where-Object {$_.type -eq "Report"};
 
$Count = ($items.count)         
# create a new folder where we will save the files
# PowerShell datetime format codes http://technet.microsoft.com/en-us/library/ee692801.aspx
 
# create a timestamped folder, format similar to 2011-Mar-28-0850PM
$folderName = Get-Date -format "yyyy-MMM-dd-hhmmtt";
If ($BackupDirectory)
{
    If (Test-Path $BackupDirectory)
    {
        Write-Host "Path exists."
    }
    else {
        Write-Warning "Path doesn't exist."
        exit
    }

    $fullFolderName = Join-Path $BackupDirectory $folderName

    #$fullFolderName = "C:\Temp\" + $folderName;
}
[System.IO.Directory]::CreateDirectory($fullFolderName) | out-null
 
$i = 0
foreach($item in $items)
{
    [int]$percentComplete = ($i/$Count * 100)
    Write-Progress -Activity "Processing $($item.path)" -PercentComplete $percentComplete -Status ("Working - " + $percentComplete + "%")

    $i ++

    #need to figure out if it has a folder name
    $subfolderName = split-path $item.Path;
    $reportName = split-path $item.Path -Leaf;
    $fullSubfolderName = $fullFolderName + $subfolderName;
    if(-not(Test-Path $fullSubfolderName))
    {
        #note this will create the full folder hierarchy
        [System.IO.Directory]::CreateDirectory($fullSubfolderName) | out-null
    }
 
    $rdlFile = New-Object System.Xml.XmlDocument;
    [byte[]] $reportDefinition = $null;
    $reportDefinition = $Proxy.GetReportDefinition($item.Path);
 
    # note here we're forcing the actual definition to be 
    # stored as a byte array
    # if you take out the @() from the MemoryStream constructor, you'll 
    # get an error
    [System.IO.MemoryStream] $memStream = New-Object System.IO.MemoryStream(@(,$reportDefinition));
    $rdlFile.Load($memStream);
 
    $fullReportFileName = $fullSubfolderName + "\" + $item.Name +  ".rdl";
    #Write-Host $fullReportFileName;
    $rdlFile.Save( $fullReportFileName);
}