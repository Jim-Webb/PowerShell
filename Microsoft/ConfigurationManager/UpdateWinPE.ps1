# Steps from https://learn.microsoft.com/en-us/windows/deployment/customize-boot-image?tabs=powershell

$WorkLocation = "C:\Temp\WinPE"

If (-NOT (Test-Path $(join-path $WorkLocation "Mount")))
{
    New-Item -Path $(join-path $WorkLocation "Mount") -ItemType Directory -Force
    $MountLocation = $(join-path $WorkLocation "Mount")
}
else
{
    $MountLocation = $(join-path $WorkLocation "Mount")
}

If (-Not (Test-Path $(join-path $WorkLocation "Updates")))
{
    New-Item -Path $(join-path $WorkLocation "Updates") -ItemType Directory -Force
    $UpdateLocation = $(join-path $WorkLocation "Updates")
}
else
{
    $UpdateLocation = $(join-path $WorkLocation "Updates")
}

# Step 1: Download and install ADK
# Step 2: Download cumulative update (CU)
# Step 3: Backup existing boot image
# Only need to do this step once
Copy-Item "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim" "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.bak.wim"

# Step 4: Mount boot image to mount folder
Mount-WindowsImage -Path $MountLocation -ImagePath "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim" -Index 1 -Verbose

# Step 5: Add drivers to boot image (optional)
# For Microsoft Configuration Manager and Microsoft Deployment Toolkit (MDT) boot images, don't manually add drivers to the boot image using the above steps. Instead, add drivers to the boot images via Microsoft Configuration Manager or Microsoft Deployment Toolkit (MDT)

# Step 6: Add optional components to boot image

# Step 6-1. Add any desired optional components to the boot image
$WinPEComponents = @('WinPE-Scripting.cab','WinPE-WDS-Tools.cab','WinPE-WMI.cab','WinPE-SecureStartup.cab','WinPE-NetFx.cab','WinPE-PowerShell.cab','WinPE-Dot3Svc.cab','WinPE-HTA.cab','WinPE-DismCmdlets.cab','WinPE-MDAC.cab')

foreach ($Component in $WinPEComponents)
{
    Add-WindowsPackage -PackagePath "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\$Component" -Path $MountLocation -Verbose
}

# Step 6-2. Add the language-specific component for that optional component.

$WinPEComponentLang = @('WinPE-Scripting_en-us.cab','WinPE-WDS-Tools_en-us.cab','WinPE-WMI_en-us.cab','WinPE-SecureStartup_en-us.cab','WinPE-NetFx_en-us.cab','WinPE-PowerShell_en-us.cab','WinPE-Dot3Svc_en-us.cab','WinPE-HTA_en-us.cab','WinPE-DismCmdlets_en-us.cab','WinPE-MDAC_en-us.cab')

Foreach ($Lang in $WinPEComponentLang)
{
    Add-WindowsPackage -PackagePath "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\$Lang" -Path "$MountLocation" -Verbose
}

# Step 7: Add cumulative update (CU) to boot image
# Download updates from https://catalog.update.microsoft.com/
# Use the search term "<year>-<month> cumulative update for windows <x>" where year is the four-digit current year, <month> is the two-digit current month, and <x> is the version of Windows that Windows PE is based on.
# Currently 2023-10 Cumulative Update for Windows 11 Version 22H2 for x64-based Systems (KB5031354)
$SelectedUpdate = Get-ChildItem $UpdateLocation -Filter *.msu | Out-GridView -Title "Select an update:" -PassThru

Add-WindowsPackage -PackagePath $($SelectedUpdate.FullName) -Path $MountLocation -Verbose

# Step 8: Copy boot files from mounted boot image to ADK installation path
# Backup doesn't need to happen every time. Only when the ADK is updated and you want to backup the original version.
Copy-Item "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\Media\bootmgr.efi" "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\Media\bootmgr.bak.efi"

Copy-Item "$MountLocation\Windows\Boot\EFI\bootmgr.efi" "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\Media\bootmgr.efi" -force

# Backup doesn't need to happen every time. Only when the ADK is updated and you want to backup the original version.
Copy-Item "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\Media\EFI\Boot\bootx64.efi" "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\Media\EFI\Boot\bootx64.bak.efi"

Copy-Item "$MountLocation\Windows\Boot\EFI\bootmgfw.efi" "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\Media\EFI\Boot\bootx64.efi" -force

# Step 9: Perform component cleanup
Start-Process "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" -ArgumentList " /Image:`"$MountLocation`" /Cleanup-image /StartComponentCleanup /Resetbase /Defer" -Wait -LoadUserProfile

Start-Process "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe" -ArgumentList " /Image:`"$MountLocation`" /Cleanup-image /StartComponentCleanup /Resetbase" -Wait -LoadUserProfile

# Step 10: Verify all desired packages have been added to boot image
Get-WindowsPackage -Path "$MountLocation"

# Step 11: Unmount boot image and save changes
Dismount-WindowsImage -Path "$MountLocation" -Save -Verbose

# Step 12: Export boot image to reduce size

# 1. Once the boot image has been unmounted and saved, its size can be further reduced by exporting it:
Export-WindowsImage -SourceImagePath "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim" -SourceIndex 1 -DestinationImagePath "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe-export.wim" -CompressionType max -Verbose

# 2a. Delete the original updated boot image:
Remove-Item -Path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim" -Force

# 2b. Rename the exported boot image with the name of the original boot image:
Rename-Item -Path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe-export.wim" -NewName "winpe.wim"

