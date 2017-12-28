$htmlHead = @"
<style>
*, *:before, *:after {
  -moz-box-sizing: border-box;
  -webkit-box-sizing: border-box;
  box-sizing: border-box;
}

body {
  font-family: 'Nunito', sans-serif;
  color: #384047;
}

table {
  max-width: 960px;
  margin: 10px auto;
}

caption {
  font-size: 1.6em;
  font-weight: 400;
  padding: 10px 0;
}

thead th {
  font-weight: 400;
  background: #8a97a0;
  color: #FFF;
}

tr {
  background: #f4f7f8;
  border-bottom: 1px solid #FFF;
  margin-bottom: 5px;
}

tr:nth-child(even) {
  background: #e8eeef;
}

th, td {
  text-align: left;
  padding: 20px;
  font-weight: 300;
}

tfoot tr {
  background: none;
}

tfoot td {
  padding: 10px 2px;
  font-size: 0.8em;
  font-style: italic;
  color: #8a97a0;
}

</style>
"@
<#
$getDriveDetails = {
    # Create an array and add to it - even if only one result this ensures an array exists
    $driveInfo = @() 
    $driveInfo += get-psdrive | where { $_.name.Length -eq 1 -and $_.used -gt 0 }

    $outputArray = @()
    foreach ($drive in $driveInfo) {
        $obj = New-Object -TypeName PSObject
        $obj | Add-Member -MemberType NoteProperty -Name Name -Value $drive.Name
        $obj | Add-Member -MemberType NoteProperty -Name Free -Value $drive.Free
        $obj | Add-Member -MemberType NoteProperty -Name Capacity -Value ($drive.Used + $drive.Free)
        $outputArray += $obj
    }
    $outputArray
}
$resultsArray = @()
$resultsArray += Invoke-Command -ComputerName 52.166.179.143 -ScriptBlock $getDriveDetails -Credential $cred
$resultsArray | Select @{Name='Capture Date';Expression={Get-Date -f d}}, PSComputerName, Name, Free, Capacity | Export-CSV -Append -Force 'C:\Users\james.holloway\Desktop\test.csv'
#>

$resultsArray = Import-Csv 'C:\Users\Kayl\Documents\PowerShell-Scripts\Dev\test.csv'

# for each host
# for each drive
# get last 3 results
# use days between calculation and difference in usage to get average daily usage
$outputArray = @()
$daysUsed  = 3
foreach ($hostName in ($resultsArray | Sort PSComputerName | Select -Unique PSComputerName).PSComputerName) {

    foreach ($drive in ($resultsArray | Where { $_.PSComputerName -eq $hostName } | Sort Name | Select -Unique Name).Name) {

        $lastDay = ($resultsArray | Where { ($_.PSComputerName -eq $hostName) -and ($_.Name -eq $drive) } | Sort -Desc 'Capture Date' | Select -First 1)
        $firstDay = ($resultsArray | Where { ($_.PSComputerName -eq $hostName) -and ($_.Name -eq $drive) } | Sort -Desc 'Capture Date' | Select -First $daysUsed | Sort 'Capture Date' | Select -First 1)
        $daysBetween = (New-TimeSpan $firstDay.'Capture Date' $lastDay.'Capture Date').Days
        $spaceDiff = $firstDay.Free - $lastDay.Free # negative if free space has grown
        $diffPerDay = $spaceDiff / $daysBetween
        $daysRemaining = $lastDay.Capacity / $diffPerDay
        
        $obj = New-Object -TypeName PSObject
        $obj | Add-Member -MemberType NoteProperty -Name Host -value $hostName
        $obj | Add-Member -MemberType NoteProperty -Name Drive -value $drive
        $obj | Add-Member -MemberType NoteProperty -Name DaysUsed -value ([math]::Max($daysBetween,$daysUsed))
        $obj | Add-Member -MemberType NoteProperty -Name 'AverageUsage (mb)' -value ([math]::Round(($diffPerDay / 1MB)))
        $obj | Add-Member -MemberType NoteProperty -Name DaysRemaining -value ([math]::Round($daysRemaining,1))
        
        $outputArray += $obj
       
    }
}

$outputArray | ConvertTo-Html -head $htmlHead  | Sort -Descending 'Capture Date', Free | Out-File 'C:\Users\Kayl\Documents\PowerShell-Scripts\Dev\test.html'