[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [string]$SCApplicationName
)

try
{
    
    $SCApplication = Get-WmiObject -Namespace "root\ccm\ClientSDK" -Class CCM_Application | where {$_.Name -eq $SCApplicationName}

    If ($SCApplication)
    {

        If ($SCApplication.InstallState -eq 'NotInstalled')
        {
            [hashtable]$Arguments = @{Id = $SCApplication.Id;IsMachineTarget = $SCApplication.IsMachineTarget;Revision = $SCApplication.Revision}

            [cimclass]$CCMCimClass = Get-CimClass -Namespace 'Root\ccm\clientsdk' -ClassName 'CCM_Application'

            Invoke-CimMethod -CimClass $CCMCimClass -MethodName 'Install' -Arguments $Arguments
        }
        else
        {
            Write-Output "The application `"$SCApplicationName`" is already installed."
        }
    }
    else
    {
        Write-Output "The application `"$SCApplicationName`" was not found in WMI. Check that a device deployment exists."
    }
}
catch
{
    Write-Warning $_
    Write-Output $_
}