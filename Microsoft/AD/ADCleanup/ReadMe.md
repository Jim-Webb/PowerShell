# AD Cleanup
ADStaleComputerScanScheduledTask.ps1
Used to run Get-StaleADComputers.ps1 with the appropriate parameters as part of the scheduled task.

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -noninteractive -File "E:\Scripts\ADCleanup\ADStaleComputerScanScheduledTask.ps1"
```

Example contents of ADStaleComputerScanScheduledTask.ps1. The file simply runs Get-StaleADComputer.ps1 with the need parameters.

# Finds computers in the Endpoints OU that have not logged in for 180 days. Sends an email with the results.
e:\Scripts\ADCleanup\Get-StaleADComputer.ps1 -SearchBase 'OU=Workstations,DC=Corp,DC=ViaMonstra,DC=Com' -TimeSinceLogin 180 -SendEmail

## Get-StaleADComputer.ps1
The Get-StaleADComputers.ps1 supports both the Hospital and Research domains.

Below are the parameters for Get-StaleADComputer.ps1.

```powershell
Get-StaleADComputer.ps1 [-SearchBase] <string> [[-SearchScope] <string>] [[-TimeSinceLogin] <string>] [[-ComputerEnabled] <bool>] [[-FileOutLocation] <string>] [-SendEmail] [-OutPutObject] [<CommonParameters>]
```
-SearchBase is the OU to search

-SearchScope - This parameter is used to tell the script what should be returned when searching AD. All is the default if nothing is passed for this parameter.
- All - Return all computers, including inactive and computers that have never logged on.
- OnlyInactiveComputers - Only return inactive computers which are computers that have not logged in to AD in the number of days passed by TimeSinceLogin. 
- OnlyNeverLoggedOn - Only return computers that have never logged into AD. This is determined by the LastLogonDate attribute being blank.

-TimeSinceLogin is the days the computer hasn't logged into AD.

-ComputerEnabled, which defaults to $True, tells the script to only look for enabled computers in AD.

-FileOutLocation - The location to out the CSV file created by the script. The default location is the directory the script is running from.

-SendEmail - Tells the script to send the results of the script as an email.

-OutPutObject - Output the results as an object so it can be passed to another script.

In addition to outputting a CSV file, the script also outputs an XML file that contains the output as an object using the Export-Clixml command. This allows the output of the command to be passed to one of the other scripts at a later time using the Import-Clixml command as seen below. Using the output in an object allows full control of what will be disable or deleted in AD. Only the computers found when Get-StaleADComputers.ps1 was ran will be in the XML, which removes the chance of additional computers being accidently disabled or removed.

The files created will also contain the Domain in the name.

Examples:

`ADCleanup-ViaMonstra-Workstations-ByDate180Days.xml`
 
`ADCleanup-Contoso-Servers-ByDate180Days.csv`

## Set-StaleADComputerStatus.ps1
Used to disable the computer accounts found when Get-StaleADComputer.ps1 was ran.

Below are the parameters of Get-StaleADComputer.ps1.

```powershell
Set-StaleADComputerStatus.ps1 [-Name] <string> [-DistinguishedName] <string> [[-Change] <string>] [[-Action] <string>] [-WhatIf] [-Confirm] [<CommonParameters>]
```
-Name - Computer to be either enabled or disabled.

-Change - The change number that allows these changes to be made. The change number is added to the description of the computer when it's disabled.

-Action - Either enable or disable a computer.

The script accepts piped input which means you can pipe a list of computers or the stored object using Import-Clixml.

Below is an example of the Set-StaleADComputerStatus.ps1 command line.

```powershell
Import-Clixml .\ADCleanup-Workstations-ByDate180Days.xml | .\Set-StaleADComputerStatus.ps1 -Change CHG00012345 -Action Disable
```

## Remove-StaleADComputer.ps1 
Used to delete the computer accounts found when Get-StaleADComputer.ps1 was ran.

Below are the parameters of Remove-StaleADComputer.ps1.

```powershell
Remove-StaleADComputer.ps1 [-Name] <string> [-DistinguishedName] <string> [-Change] <string> [[-Action] <string>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

-Name - Computer to be removed from AD.

-Change - Change number to use as a search parameter. Only computers that have the change in the description will be delete.

-Action - The only option is Delete. This will cause the computer to be deleted from AD.

The script accepts piped input which means you can pipe a list of computers or the stored object using Import-Clixml.

Below is an example of the Remove-StaleADComputer.ps1 command line.

```powershell
Import-Clixml .\ADCleanup-Workstations-ByDate180Days.xml | .\Remove-StaleADComputer.ps1 -Change CHG00012345 -Action Delete
```