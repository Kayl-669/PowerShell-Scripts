<#
Powershell script to transpose input data converting 
EventID/EventDate/Value columns into rows where
each EventID is a column and each EventDate is a row
Author: Sam Boutros 
11/30/2014 - v1.0 
04/19/2015 - v1.1 - cosmetic changes
#>

#Requires -Version 4

$a = Import-Csv 'C:\GOG Games\test.csv' | Select @{l="EventID";e={$_.EventID/1}}, EventDate, Occurences
#$a | FT -AutoSize

<# Sample output of $a

EventID  EventDate Value
------  -------- -----
EventID1 RAM      8    
EventID2 RAM      4    
EventID3 RAM      6    
EventID1 Cores    8    
EventID2 Cores    1    
EventID3 Cores    16   
EventID1 Disk1    128  
EventID2 Disk1    1024 
EventID3 Disk1    2048 
EventID1 Disk2    256  
EventID2 Disk2    4096 
EventID3 Disk2    1024 

#>

# Transpose by "EventDate", group by "EventID" 
# intersection of "EventDate X EventID = Value"

#foreach ($EventID in $a.EventID | Select -Unique) {$EventID}


#$Duration = Measure-Command {
    $b = @()
    foreach ($EventDate in $a.EventDate | Select -Unique) {
        $Props = [ordered]@{ EventDate = $EventDate }

        foreach ($EventID in $a.EventID | Select -Unique | Sort) { 
            $Occurences = ($a.where({ $_.EventID -eq $EventID -and 
                        $_.EventDate -eq $EventDate })).Occurences
            $Props += @{ $EventID = $Occurences }

        }
        $b += New-Object -TypeName PSObject -Property $Props
    }
    $b | Sort EventDate | Out-GridView
#}

<#
Write-Host "Finished transposing " -ForegroundColor Green -NoNewline
Write-Host "$(($a | Get-Member -MemberType Properties).count)/$($a.Count)" -ForegroundColor Yellow -NoNewline
Write-Host " columns/rows into " -ForegroundColor Green -NoNewline
Write-Host "$(($b | Get-Member -MemberType Properties).count)/$($b.Count)" -ForegroundColor Yellow -NoNewline
Write-Host " columns/rows in " -ForegroundColor Green -NoNewline
Write-Host $Duration.Milliseconds -ForegroundColor Yellow -NoNewline
Write-Host " Milliseconds" -ForegroundColor Green 

$b | FT -AutoSize
$b | Out-GridView
$b | Export-Csv .\table2.csv -NoTypeInformation 
#>
<# Sample output

Finished transposing 3/12 columns/rows into 4/4 columns/rows in 7 Milliseconds

EventDate EventID1 EventID2 EventID3
-------- ------- ------- -------
RAM      8       4       6      
Cores    8       1       16     
Disk1    128     1024    2048   
Disk2    256     4096    1024   

#>