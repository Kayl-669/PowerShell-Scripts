$events = Get-WinEvent `
    -ComputerName sql-03.datacentre.esendex.com
    -LogName application `
    -ea SilentlyContinue `
    | Where-Object { $_.TimeCreated -gt (Get-Date).AddDays(-1) }

#$events.id
$events.timecreated

get-help get-winevent