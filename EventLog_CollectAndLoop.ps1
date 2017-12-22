# EventLog: Collect and loop
# Loop through $hostsArray hosts and fire off EventLog_Retrieve script remotely to gather eventlog events
$hostsArray = Get-Content 'C:\Users\james.holloway\Google Drive\Toolkit\DBA\esendexHosts.txt'
$eventsLogScript = 'C:\Users\james.holloway\Google Drive\cmd and powershell\EventLog_Retrieve.ps1'
$credential = Get-Credential
$eventsArray = @()

foreach ($sqlHost in $hostsArray) {
    $session = New-PSSession -ComputerName $sqlHost -Credential $credential
    $eventsArray += Invoke-Command -Session $session -FilePath $eventsLogScript
    Remove-PSSession -Session $session
}
$eventIDHashTab = $eventsArray | Group-Object EventID -AsHashTable

#Create Table object
$table = New-Object system.Data.DataTable "EventsTable"

#Define Columns
$col1 = New-Object system.Data.DataColumn EventID,([Int32])
$col2 = New-Object system.Data.DataColumn EventDate,([datetime])
$col3 = New-Object system.Data.DataColumn Occurences,([Int32])
$col4 = New-Object system.Data.DataColumn Message,([String])
$col5 = New-Object system.Data.DataColumn Host,([String])
#Add the columns
$table.Columns.add($col1)
$table.Columns.add($col2)
$table.Columns.add($col3)
$table.Columns.add($col4)
$table.Columns.add($col5)

foreach ($EventIDKey in $eventIDHashTab.GetEnumerator()) { 

    #Write-Host "$($EventIDKey.Name): $($EventIDKey.Value)"
    $EventsByDate = $EventIDKey.Value | Group EventDate -AsHashTable

    foreach ($EventDateKey in $EventsByDate.GetEnumerator()) {
        
        $EventsByHost = $EventDateKey.Value | Group PSComputerName -AsHashTable

        foreach ($EventHostKey in $EventsByHost.GetEnumerator()) {
            #Create a row
            if (!$EventHostKey) {continue}
            $row = $table.NewRow()
            $row.EventID = [int]$EventIDKey.Name
            $row.EventDate = (Get-Date -date $EventDateKey.Name).Date
            $row.Host = $EventHostKey.Name
            $row.Occurences = $EventHostKey.Value.Count
            $row.Message = $EventHostKey.Value[0].Message
            $table.Rows.Add($row)
        }
        
    }

}
$pivot = @()
foreach ($EventID in $table.EventID | Select -Unique | Sort) {

    $eventHosts = ($table.where({ $_.EventID -eq $EventID})).Host
 
    foreach ($sqlHost in $eventHosts | Select -Unique | Sort) {
        $Props = [ordered]@{ EventID = $EventID }
        $Props += @{ Message = $table.where( {$_.EventID -eq $EventID} )[0].Message }
        $Props += @{ Host = $sqlHost }
        
        foreach ($EventDate in $table.EventDate | Select -Unique | Sort) {
            $Occurrences = ($table.where({ $_.EventID -eq $EventID `
                -and $_.EventDate -eq $EventDate `
                -and $_.Host -eq $sqlHost })).Occurences 
            $Props += @{ $EventDate = $Occurrences }
        }
        $pivot += New-Object -TypeName PSObject -Property $Props
    }
}
$pivot | export-csv 'C:\Users\james.holloway\Desktop\test.csv'