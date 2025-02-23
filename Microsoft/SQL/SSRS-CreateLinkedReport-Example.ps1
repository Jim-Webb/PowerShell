[string]$webServiceUrl = "https://myreportserver.com/ReportServer/ReportService2010.asmx"

$ssrsProxy = New-WebServiceProxy -Uri $webServiceUrl -UseDefaultCredential

#File name of new linked item
$itemPath = "LinkedReportTest_JJ"
#Path of where the linked report should be created in
$parent = "/Test"
#Report we are basing our linked report on
$link = "/Test/My_Test_SSRS_Report"
#Create property object
$type = $ssrsProxy.GetType().Namespace
$linkPropertyType = ($type + '.Property')
$linkProperty = New-Object ($linkPropertyType)
$linkProperty.Name = "Description"
$linkProperty.Value = "Test Linked Report"

$ssrsProxy.CreateLinkedItem($itemPath,$parent,$link,$linkProperty)