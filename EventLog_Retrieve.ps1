$allEvents = @()
#Enter data in the row
$allEvents += get-eventlog `
    -newest 1000 `
    -LogName system `
    -EntryType Warning `
    -ErrorAction SilentlyContinue `
    -After (Get-Date).AddDays(-7)

$allEvents += get-eventlog `
    -newest 1000 `
    -LogName security `
    -EntryType Warning `
    -ErrorAction SilentlyContinue `
    -After (Get-Date).AddDays(-7)

$allEvents += get-eventlog `
    -newest 1000 `
    -LogName application `
    -EntryType Warning `
    -ErrorAction SilentlyContinue `
    -After (Get-Date).AddDays(-7)

$eventObjs = @()
foreach ( $event in $allEvents )  {
    $properties = @{
        'EventID' = $event.EventID;
        'Message' = $event.Message;
        'EventDate' = Get-Date -date $event.TimeGenerated -f "dd/MM/yyyy"
        'Source' = $event.Source;
    }
    $eventObjs += New-Object -TypeName PSObject -Property $properties
}
$eventObjs