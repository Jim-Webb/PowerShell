# https://smsagent.blog/2021/04/20/get-the-current-patch-level-for-windows-10-with-powershell/
# https://techcommunity.microsoft.com/t5/windows-it-pro-blog/getting-to-know-the-windows-update-history-pages/ba-p/355079

function Get-CurrentPatchInfoByBuild
{

[CmdletBinding()]
Param(
    [switch]$ListAllAvailable,
    [switch]$ExcludePreview,
    [switch]$ExcludeOutofBand,
    [ValidateSet("Win10", "Win11")]
    [string]$OS,
    [string]$OSBuild
)
$ProgressPreference = 'SilentlyContinue'
switch ($OS)
{
	'Win10'
	{
		$URI = "https://support.microsoft.com/en-us/help/4464619/windows-10-update-history" # Windows 10 release history
	}
	'Win11'
	{
		$URI = "https://aka.ms/WindowsUpdateHistory" # Windows 11 release history
	}
	default
	{
		$FullOS = 'Unknown'
        break
	}
}

# $URI = "https://aka.ms/WindowsUpdateHistory" # Windows 11 release history
# $URI = "https://support.microsoft.com/en-us/help/4464619/windows-10-update-history" # Windows 10 release history

Write-Information -MessageData "URI: $URI" -InformationAction Continue

Function Get-MyWindowsVersion {
        [CmdletBinding()]
        Param
        (
            $ComputerName = $env:COMPUTERNAME
        )

        $Table = New-Object System.Data.DataTable
        $Table.Columns.AddRange(@("ComputerName","Windows Edition","Version","OS Build"))
        # $ProductName = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' –Name ProductName).ProductName
        $ProductName = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        Try
        {
            $Version = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' –Name ReleaseID –ErrorAction Stop).ReleaseID
        }
        Catch
        {
            $Version = "N/A"
        }
        $CurrentBuild = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' –Name CurrentBuild).CurrentBuild
        $UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' –Name UBR).UBR
        $OSVersion = $CurrentBuild + "." + $UBR
        $TempTable = New-Object System.Data.DataTable
        $TempTable.Columns.AddRange(@("ComputerName","Windows Edition","Version","OS Build"))
        [void]$TempTable.Rows.Add($env:COMPUTERNAME,$ProductName,$Version,$OSVersion)

        Return $TempTable
}

Function Get-MyWindowsVersion2 {
        $Table = New-Object System.Data.DataTable
        $Table.Columns.AddRange(@("OS Build"))

        $CurrentBuild = $OSBuild
        $UBR = '0000'
        $OSVersion = $CurrentBuild + "." + $UBR
        $TempTable = New-Object System.Data.DataTable
        $TempTable.Columns.AddRange(@("OS Build"))
        [void]$TempTable.Rows.Add($OSVersion)

        Return $TempTable
}

Function Convert-ParsedArray {
    Param($Array)
    
    $ArrayList = New-Object System.Collections.ArrayList
    foreach ($item in $Array)
    {      
        [void]$ArrayList.Add([PSCustomObject]@{
            Update = $item.outerHTML.Split('>')[1].Replace('</a','').Replace('&#x2014;',' – ')
            KB = "KB" + $item.href.Split('/')[-1]
            InfoURL = "https://support.microsoft.com" + $item.href
            OSBuild = $item.outerHTML.Split('(OS ')[1].Split()[1] # Just for sorting
        })
    }
    Return $ArrayList
}

If ($PSVersionTable.PSVersion.Major -ge 6)
{
    $Response = Invoke-WebRequest –Uri $URI –ErrorAction Stop
}
else 
{
    $Response = Invoke-WebRequest –Uri $URI –UseBasicParsing –ErrorAction Stop
}
    
If (!($Response.Links))
{ throw "Response was not parsed as HTML"}
$VersionDataRaw = $Response.Links | where {$_.outerHTML -match "supLeftNavLink" -and $_.outerHTML -match "KB"}
$CurrentWindowsVersion = Get-MyWindowsVersion2 –ErrorAction Stop

If ($ListAllAvailable)
{
    If ($ExcludePreview -and $ExcludeOutofBand)
    {
        $AllAvailable = $VersionDataRaw | where {$_.outerHTML -match $CurrentWindowsVersion.'OS Build'.Split('.')[0] -and $_.outerHTML -notmatch "Preview" -and $_.outerHTML -notmatch "Out-of-band"}
    }
    ElseIf ($ExcludePreview)
    {
        $AllAvailable = $VersionDataRaw | where {$_.outerHTML -match $CurrentWindowsVersion.'OS Build'.Split('.')[0] -and $_.outerHTML -notmatch "Preview"}
    }
    ElseIf ($ExcludeOutofBand)
    {
        $AllAvailable = $VersionDataRaw | where {$_.outerHTML -match $CurrentWindowsVersion.'OS Build'.Split('.')[0] -and $_.outerHTML -notmatch "Out-of-band"}
    }
    Else
    {
        $AllAvailable = $VersionDataRaw | where {$_.outerHTML -match $CurrentWindowsVersion.'OS Build'.Split('.')[0]}
    }
    $UniqueList = (Convert-ParsedArray –Array $AllAvailable) | Sort OSBuild –Descending –Unique
    $Table = New-Object System.Data.DataTable
    [void]$Table.Columns.AddRange(@('Update','KB','InfoURL'))
    foreach ($Update in $UniqueList)
    {
        [void]$Table.Rows.Add(
            $Update.Update,
            $Update.KB,
            $Update.InfoURL
        )
    }
    Return $Table
}

$CurrentPatch = $VersionDataRaw | where {$_.outerHTML -match $CurrentWindowsVersion.'OS Build'} | Select –First 1
If ($ExcludePreview -and $ExcludeOutofBand)
{
    $LatestAvailablePatch = $VersionDataRaw | where {$_.outerHTML -match $CurrentWindowsVersion.'OS Build'.Split('.')[0] -and $_.outerHTML -notmatch "Out-of-band" -and $_.outerHTML -notmatch "Preview"} | Select –First 1
}
ElseIf ($ExcludePreview)
{
    $LatestAvailablePatch = $VersionDataRaw | where {$_.outerHTML -match $CurrentWindowsVersion.'OS Build'.Split('.')[0] -and $_.outerHTML -notmatch "Preview"} | Select –First 1
}
ElseIf ($ExcludeOutofBand)
{
    $LatestAvailablePatch = $VersionDataRaw | where {$_.outerHTML -match $CurrentWindowsVersion.'OS Build'.Split('.')[0] -and $_.outerHTML -notmatch "Out-of-band"} | Select –First 1
}
Else
{
    $LatestAvailablePatch = $VersionDataRaw | where {$_.outerHTML -match $CurrentWindowsVersion.'OS Build'.Split('.')[0]} | Select –First 1
}
    
If ($LatestAvailablePatch)
{
    $LU = $LatestAvailablePatch.outerHTML.Split('>')[1].Replace('</a','').Replace('&#x2014;',' – ')

    $Table = New-Object System.Data.DataTable
    [void]$Table.Columns.AddRange(@('LatestAvailableUpdate','LastestAvailableUpdateKB','LastestAvailableUpdateInfoURL','UBR'))
    [void]$Table.Rows.Add(
        $LatestAvailablePatch.outerHTML.Split('>')[1].Replace('</a','').Replace('&#x2014;',' – '),
        "KB" + $LatestAvailablePatch.href.Split('/')[-1],
        "https://support.microsoft.com" + $LatestAvailablePatch.href,
        $LU.Substring($LU.IndexOf($Build),10)
    )
    Return $Table
}
else
{
    Write-Warning -Message "No results returned."
}

}

# Get-CurrentPatchInfo -ListAllAvailable -ExcludePreview -ExcludeOutofBand
$Build = '19045'
$Build = '22621'
$Build = '22631'

$HashArguments = @{
  OSBuild = "22621"
  OS = "Win11"
  ExcludePreview = $true
}

$P = Get-CurrentPatchInfoByBuild -ExcludePreview -ExcludeOutofBand -OSBuild $Build -OS Win11
$P = Get-CurrentPatchInfoByBuild -ListAllAvailable -OSBuild $Build -OS Win11
$P = Get-CurrentPatchInfoByBuild -ExcludePreview -ExcludeOutofBand -OSBuild $Build -OS Win10
$P = Get-CurrentPatchInfoByBuild @HashArguments

$P | where {$_.LatestAvailableUpdate -match '22621'}

$P.LatestAvailableUpdate | Select-String -Pattern '22621'

$VersionUBR = ($P.LatestAvailableUpdate.Substring($P.LatestAvailableUpdate.IndexOf($Build) + 0)).trim(")")
$VersionUBR = ($P.LatestAvailableUpdate.Substring($P.LatestAvailableUpdate.IndexOf($Build) + 10)).trim(")")
$VersionUBR = $P.LatestAvailableUpdate.Substring($P.LatestAvailableUpdate.IndexOf($Build),10)

$Version,$UBR = $VersionUBR.Split('.')

