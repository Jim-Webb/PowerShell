Function Get-PatchTuesday
{
  <#
    .SYNOPSIS
    Returns the patch Tuesday date for current month and year or based on supplied parameters.
 
    .EXAMPLE
    Get-PatchTuesday -Month 1 -Year 2018  
    .EXAMPLE
    Get-PatchTuesday -Month 9
     
   .PARAMETER Month
    The month parameter can be used to specify a specific month.
    .PARAMETER Year
    The year parameter can be used to specify a specific year.
  #>
  Param(
    [Parameter(Mandatory=$false,ValueFromPipeline=$true)] 
    [int]$Month = (Get-Date).Month,
    [Parameter(Mandatory=$false)]
    [int]$Year = (Get-Date).Year
  )
  Write-Verbose "Patch Tuesday Month                : $($Month)"
  Write-Verbose "Patch Tuesday Year                 : $($Year)"
  $FindNthDay = 2
  $WeekDay = "Tuesday"
  $WorkingDate = Get-Date -Month $Month -Year $Year
  $WorkingMonth = $WorkingDate.Month.ToString()
  $WorkingYear = $WorkingDate.Year.ToString()
  [datetime]$StrtMonth = $WorkingMonth + "/1/" + $WorkingYear
  while ($StrtMonth.DayofWeek -ine $WeekDay)
  {
    $StrtMonth = $StrtMonth.AddDays(1)
  }
  $PatchTuesday = $StrtMonth.AddDays(7*($FindNthDay-1))
  return $PatchTuesday
}

Get-PatchTuesday -Month 1 -Year 2021

$month = (Get-Date).Month
$Year = (Get-Date).Year

#ddd