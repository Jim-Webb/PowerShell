function Set-LimitingCollection
{
       param (
              $CollectionID,
              $LimitingCollectionID,
              $SCCMServer,
              $SCCMSite
       )
       If (($COL = Get-WmiObject -ComputerName "$SCCMServer" -Namespace "root\sms\site_$SCCMSite" -Query "Select * From SMS_Collection Where CollectionID = '$CollectionID'"))
       {
              If (($NEWCOL = Get-WmiObject -ComputerName "$SCCMServer" -Namespace "root\sms\site_$SCCMSite" -Query "Select CollectionID From SMS_Collection Where CollectionID = '$LimitingCollectionID'"))
              {
                     $COL.LimitToCollectionID = $NEWCOL.CollectionID
                     $COL.Put()
                     return, $true
              }
              Else
              {
                     return, $false
              }
       }
       Else
       {
              return, $false
       }
}

# Example format
# Set-LimitingCollection -CollectionID PS10018C -LimitingCollectionID PS10017C -SCCMServer CM01 -SCCMSite PS1

#
$CollID = Get-Content -Path C:\temp\ServerLimitingCollections.txt

foreach ($Collection in $CollID)
{
    Write-Host "Setting limiting collection for $collection to HOS00066."
    Set-LimitingCollection -CollectionID $Collection -LimitingCollectionID PS100066 -SCCMServer CM01 -SCCMSite PS1
}