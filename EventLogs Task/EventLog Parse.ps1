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
    $EventsByDate = $EventIDKey.Value | Group { Get-Date $_.TimeGenerated -format d }

    foreach ($EventDate in $EventsByDate) {
        #Create a row
        $row = $table.NewRow()
        $row.EventID = [int]$EventIDKey.Name
        $row.EventDate = $EventDate.Name
        $row.Occurences = $EventDate.Count
        $row.Message = $Evev
        $table.Rows.Add($row)
    }
}
#$table = $table | Select @{l="EventID";e={$_.EventID/1}}, EventDate, Occurences

$table

$pivot = @()
foreach ($EventDate in $table.EventDate | Select -Unique | Sort) {
    $Props = [ordered]@{ EventDate = $EventDate }

    foreach ($EventID in $table.EventID | Select -Unique | Sort) { 
        $Occurences = ($table.where({ $_.EventID -eq $EventID -and 
                    $_.EventDate -eq $EventDate })).Occurences
        $Props += @{ $EventID = $Occurences }

    }
    $pivot += New-Object -TypeName PSObject -Property $Props
}
$pivot