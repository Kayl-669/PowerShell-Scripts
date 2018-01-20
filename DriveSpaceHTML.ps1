﻿$htmlHead = @"
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

$hostsArray = Get-Content 'C:\Users\james.holloway\Google Drive\Toolkit\DBA\esendexHosts.txt'
if (!$datacentreCredential) {
    $datacentreCredential = Get-Credential -Credential 'datacentre\x'
}
if (!$datacentreCredential) { exit }
if (!$cSSMSCredential) {
    $cSSMSCredential = Get-Credential -Credential 'cssms\x'
}
if (!$cSSMSCredential) { exit }
if (!$cSVoiceCredential) {
    $cSVoiceCredential = Get-Credential -Credential 'csvoice\x'
}
if (!$devLabCredential) {
    $devLabCredential = Get-Credential -Credential 'dev.lab\x'
}
if (!$cSVoiceCredential) { exit }

$getDriveDetails = {
    # ensure an array exists
    $driveInfo = @(get-psdrive | where { $_.name.Length -eq 1 -and $_.used -gt 0 }) 

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

foreach ($sqlHost in $hostsArray) {
    if ($sqlHost -match "datacentre") {
        $thisCredential = $datacentreCredential
    }
    elseif ($sqlHost -match "cssms") {
        $thisCredential = $cSSMSCredential
    }
    elseif ($sqlHost -match "csvoice") {
        $thisCredential = $cSVoiceCredential
    }
    elseif ($sqlHost -match "dev.lab") {
        $thisCredential = $devLabCredential
    }
    Write-Host "Starting on $sqlHost"
    $resultsArray += Invoke-Command -ComputerName $sqlHost -ScriptBlock $getDriveDetails -Credential $thisCredential
    Write-Host "Finished on $sqlHost"

}
$resultsArray | Select @{Name='Capture Date';Expression={Get-Date -f d}}, PSComputerName, Name, Free, Capacity | Export-CSV -Append -Force 'C:\Users\james.holloway\Google Drive\Daily Checks\DriveSpace.csv' -NoTypeInformation

# --------------


$resultsArray = Import-Csv 'C:\Users\james.holloway\Google Drive\Daily Checks\DriveSpace.csv'

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
        $daysBetween = (New-TimeSpan $lastDay.'Capture Date' $firstDay.'Capture Date').Days
        $spaceDiff = $lastDay.Free - $firstDay.Free  # negative if free space has grown
        if (!$daysBetween) {
            $diffPerDay = -1
            $daysRemaining = -1
        } 
        Else {
            $diffPerDay = $spaceDiff / $daysBetween
            if ($diffPerDay = 0) {$daysRemaining = -1} else {$daysRemaining = $lastDay.Capacity / $diffPerDay}
        }
        
        $obj = New-Object -TypeName PSObject
        $obj | Add-Member -MemberType NoteProperty -Name Host -value $hostName
        $obj | Add-Member -MemberType NoteProperty -Name Drive -value $drive
        $obj | Add-Member -MemberType NoteProperty -Name DaysUsed -value ([math]::Max($daysBetween,$daysUsed))
        $obj | Add-Member -MemberType NoteProperty -Name 'AverageUsage (mb)' -value ([math]::Round(($diffPerDay / 1MB)))
        $obj | Add-Member -MemberType NoteProperty -Name DaysRemaining -value ([math]::Round($daysRemaining,1))
        
        $outputArray += $obj

    }
}
$outputArray #| ConvertTo-Html -head $htmlHead | Sort -Descending 'Capture Date', Free | Out-File 'C:\Users\james.holloway\Google Drive\Daily Checks\test.html'