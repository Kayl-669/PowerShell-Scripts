Function Merge-Hashtables {
    $Output = @{}
    ForEach ($Hashtable in ($Input + $Args)) {
        If ($Hashtable -is [Hashtable]) {
            ForEach ($Key in $Hashtable.Keys) {
                $Output.$Key = $Hashtable.$Key
                $Output[$Key] = $Hashtable[$Key]
            }
        }
    }
    $Output
}

$tabName = "EventsTable"
#Create Table object
$table = New-Object system.Data.DataTable "$tabName"

#Define Columns
$col1 = New-Object system.Data.DataColumn EventID,([Int32])
$col2 = New-Object system.Data.DataColumn EventDate,([datetime])
$col3 = New-Object system.Data.DataColumn Occurences,([Int32])
$col4 = New-Object system.Data.DataColumn Message,([String])
#Add the columns
$table.Columns.add($col1)
$table.Columns.add($col2)
$table.Columns.add($col3)
$table.Columns.add($col4)

#Enter data in the row
$systemErrorHashTab = get-eventlog `
    -newest 1000 `
    -LogName system `
    -EntryType Error `
    -After (Get-Date).AddDays(-7) `
    | Group-Object EventID -AsHashTable

$systemWarningHashTab = get-eventlog `
    -newest 1000 `
    -LogName system `
    -EntryType Warning `
    -After (Get-Date).AddDays(-7) `
    | Group-Object EventID -AsHashTable

$appErrorHashTab = get-eventlog `
    -newest 1000 `
    -LogName application `
    -EntryType Error `
    -After (Get-Date).AddDays(-7) `
    | Group-Object EventID -AsHashTable

$EventIDHashTab = Merge-Hashtables $systemErrorHashTab $appErrorHashTab $systemWarningHashTab

if (!$EventIDHashTab) {
    Write-Host "No Error entries!"
    break
}

foreach ($EventIDKey in $EventIDHashTab.GetEnumerator()) { 

    #Write-Host "$($EventIDKey.Name): $($EventIDKey.Value)"
    $EventsByDate = $EventIDKey.Value | Group { Get-Date $_.TimeGenerated -format d } -AsHashTable

    foreach ($EventDateKey in $EventsByDate.GetEnumerator()) {
        #Create a row
        if (!$EventDateKey) {continue}
        $row = $table.NewRow()
        $row.EventID = [int]$EventIDKey.Name
        $row.EventDate = (Get-Date -date $EventDateKey.Name).Date
        $row.Occurences = $EventDateKey.Value.Count
        $row.Message = $EventDateKey.Value[0].Message
        $table.Rows.Add($row)
    }
}
#$table = $table | Select @{l="EventID";e={$_.EventID/1}}, EventDate, Occurences

$pivot = @()
foreach ($EventID in $table.EventID | Select -Unique | Sort) {
    $Props = [ordered]@{ EventID = $EventID }
    $Props += @{ Message = $table.where( {$_.EventID -eq $EventID} )[0].Message }

    foreach ($EventDate in $table.EventDate | Select -Unique | Sort) {
        $Occurences = ($table.where({ $_.EventID -eq $EventID -and 
            $_.EventDate -eq $EventDate })).Occurences
            $formattedDate = Get-Date -date $EventDate -f "dd/MM/yyyy"
        $Props += @{ $formattedDate = $Occurences }
    }
    $pivot += New-Object -TypeName PSObject -Property $Props
}
$pivot# | Export-csv 'C:\Users\james.holloway\Desktop\test.csv'