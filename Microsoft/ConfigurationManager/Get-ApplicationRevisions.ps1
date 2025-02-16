<#PSScriptInfo

.VERSION 1.0.8

.GUID 8742616c-beaf-4c11-835d-3335ac9b6041

.AUTHOR Jim Webb

.COPYRIGHT 2023

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
 Used to get the revision of applications deployed to a computer 

#> 

Param (
	[string]$ComputerName = $env:COMPUTERNAME,
    [string]$Application
)

Write-Host "Getting information from computer $ComputerName."

$RepositoryObject = @()

if ($Application)
{
    $Apps = Get-WmiObject -ComputerName $ComputerName -Namespace root\ccm\clientsdk -Class CCM_Application | Where-Object {$_.Name -like "*$Application*" } #| Select-Object Name, Revision, InstallState, ApplicabilityState, ConfigureState | Sort-Object Name | Format-Table -AutoSize
    # Get-WmiObject -ComputerName $ComputerName -Namespace root\ccm\clientsdk -Class CCM_Application | Where-Object {$_.Name -like "*$Application*" } | Select-Object Name, Revision, InstallState, ApplicabilityState, ConfigureState | Sort-Object Name | Format-Table -AutoSize

    foreach ($App in $Apps)
    {

        $props = [pscustomobject]@{
            PSTypeName = 'AppInfo'
            'Name'=$App.Name
            'Revision'=$App.Revision
            'InstallState'=$App.InstallState
            'ApplicabilityState'=$App.ApplicabilityState
            'ConfigureState'=$App.ConfigureState
    }

    $RepositoryObject += $props
    }
}
else
{
    $Apps = Get-WmiObject -ComputerName $ComputerName -Namespace root\ccm\clientsdk -Class CCM_Application # | Select-Object Name, Revision, InstallState, ApplicabilityState, ConfigureState | Sort-Object Name | Format-Table -AutoSize
    # Get-WmiObject -ComputerName $ComputerName -Namespace root\ccm\clientsdk -Class CCM_Application | Select-Object Name, Revision, InstallState, ApplicabilityState, ConfigureState | Sort-Object Name | Format-Table -AutoSize

    foreach ($App in $Apps)
    {

        $props = [pscustomobject]@{
            PSTypeName = 'AppInfo'
            'Name'=$App.Name
            'Revision'=$App.Revision
            'InstallState'=$App.InstallState
            'ApplicabilityState'=$App.ApplicabilityState
            'ConfigureState'=$App.ConfigureState
    }

    $RepositoryObject += $props
    }

}

    $fmt = "$env:TEMP\appinfo.format.ps1xml"
    $RepositoryObject[0] | New-PSFormatXML -Prop 'Name', 'Revision', 'InstallState', 'ApplicabilityState','ConfigureState' -path $fmt
    $RepositoryObject[0] | New-PSFormatXML -FormatType Table -GroupBy 'Name' -path $fmt -append

    Update-FormatData -PrependPath "$env:TEMP\appinfo.format.ps1xml"

    Return $RepositoryObject | Sort-Object Name