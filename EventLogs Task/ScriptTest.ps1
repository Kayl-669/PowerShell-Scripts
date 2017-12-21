$services = Get-Service
$services | where Status -eq 'Stopped'