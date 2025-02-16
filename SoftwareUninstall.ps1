[CmdletBinding()]
Param (
	[Parameter(Mandatory=$true)]
	[string]$Software
)

Function CheckRegistryInstalledSoftware($SoftwareName)
{
    $array = @()

    $computername=$env:COMPUTERNAME

    #Define the variable to hold the location of Currently Installed Programs

    $UninstallKey="SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall" 

    #Create an instance of the Registry Object and open the HKLM base key

    $reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$computername) 

    #Drill down into the Uninstall key using the OpenSubKey Method

    $regkey=$reg.OpenSubKey($UninstallKey) 

    #Retrieve an array of string that contain all the subkey names

    $subkeys=$regkey.GetSubKeyNames() 

    #Open each Subkey and use GetValue Method to return the required values for each

    foreach($key in $subkeys){

        $thisKey=$UninstallKey+"\\"+$key 

        $thisSubKey=$reg.OpenSubKey($thisKey) 

        $obj = New-Object PSObject

        $obj | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value $computername

        $obj | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $($thisSubKey.GetValue("DisplayName"))

        $obj | Add-Member -MemberType NoteProperty -Name "DisplayVersion" -Value $($thisSubKey.GetValue("DisplayVersion"))

        $obj | Add-Member -MemberType NoteProperty -Name "InstallLocation" -Value $($thisSubKey.GetValue("InstallLocation"))

        $obj | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $($thisSubKey.GetValue("Publisher"))

        $obj | Add-Member -MemberType NoteProperty -Name "UninstallString" -Value $($thisSubKey.GetValue("UninstallString"))

        $obj | Add-Member -MemberType NoteProperty -Name "GUID" -Value $key

        $array += $obj
    } 
    if ($array | Where-Object {$_.DisplayName -like "*$SoftwareName*"})
    {
        return $array | Where-Object {$_.DisplayName -like "*$SoftwareName*"}
    }
}

$InstalledSoftware = CheckRegistryInstalledSoftware("$Software")

If ($InstalledSoftware)
{
    $DisplayName = $InstalledSoftware.DisplayName
    $DisplayVersion = $InstalledSoftware.DisplayVersion
    $Publisher = $InstalledSoftware.Publisher
    $UninstallString = $InstalledSoftware.UninstallString
    $GUID = $InstalledSoftware.GUID
}

$DisplayName
$DisplayVersion
$Publisher
$UninstallString
$GUID