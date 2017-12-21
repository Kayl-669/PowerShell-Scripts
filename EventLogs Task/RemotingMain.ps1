#$eventsScript = Get-Content 'C:\Users\james.holloway\Google Drive\cmd and powershell\EventLogs Task\EventLog Parse.ps1'
#& $eventsScript

$credential = Get-Credential
$session = New-PSSession -ComputerName sql-d.datacentre.esendex.com -Credential $credential
$pivot = Invoke-Command -Session $session -FilePath 'C:\Users\james.holloway\Google Drive\cmd and powershell\EventLogs Task\EventLog Parse.ps1'
Remove-PSSession -Session $session 
$pivot | Out-GridView