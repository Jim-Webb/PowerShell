# Folder \Assets and Compliance\Overview\Device Collections\Deployments
$CMMWFolderID = '16778284'
[string]$SiteCode = "PS1"
[string]$SiteServer = 'CM01.corp.viamonstra.com'

$DeployCollections = Get-WmiObject -ComputerName $SiteServer -Namespace "ROOT\SMS\Site_$SiteCode" -Query "select * from SMS_Collection where CollectionID is in(select InstanceKey from SMS_ObjectContainerItem where ObjectType='5000' and ContainerNodeID='$CMMWFolderID') and CollectionType='2'"

# $Collection = $DeployCollections | where {$_.Name -eq "Deploy: Early Adopter Ring Unenrollment"}
# $Collection = $DeployCollections | where {$_.Name -eq "Deploy: EndNote 20 (Available)"}
# $Collection = $DeployCollections | where {$_.Name -eq "Deploy: Zoom (Available)"}

Foreach ($Collection in $DeployCollections)
{
    Write-host "Processing collection `"$($Collection.Name)`"."
    $Applications = Get-CMDeployment -CollectionName $($Collection.Name) -FeatureType "Application"
    # If (Get-CMDeployment -CollectionName $($Collection.Name) -FeatureType "Application")
    If ($Applications)
    {
        Foreach ($Application in $Applications)
        {
            # ($(Get-CMDeployment -CollectionName $($Collection.Name) -FeatureType "Application").count -gt 1)

            Write-Host "Application"

            $ApplicationName = (Get-CMApplicationDeployment -CollectionName $($Collection.Name) -Name $Application.ApplicationName)

            $($Application.SoftwareName)

            If ($ApplicationName)
            {
                $AppObj = Get-CMApplication -Name $ApplicationName.ApplicationName

                # Write-host "Application: $($AppObj.LocalizedDisplayName)."

                Write-Host "Collection: `"$($Collection.CollectionID) - $($Collection.Name)`" - Application: `"$($AppObj.LocalizedDisplayName)`"."
    
                "Collection: `"$($Collection.CollectionID) - $($Collection.Name)`" - Application: `"$($AppObj.LocalizedDisplayName)`"." | Out-File -FilePath C:\Temp\AppTest.log -Append -NoClobber

                Set-CMApplication -InputObject $AppObj -SendToProtectedDistributionPoint $true
            }
        }
 
    }
    elseif (Get-CMDeployment -CollectionName $($Collection.Name) -FeatureType "Package")
    {
        Write-Host "Package"

        $Package = Get-CMPackageDeployment -CollectionName $($Collection.Name)

        If ($Package)
        {
            $PackageObj = Get-CMPackage -Id $Package.PackageID -Fast

            Write-Host "Collection: `"$($Collection.CollectionID) - $($Collection.Name)`" - Package: `"$($PackageObj.Name)`"."

            Set-CMPackage -InputObject $PackageObj -SendToPreferredDistributionPoint $true
        }
    }
}