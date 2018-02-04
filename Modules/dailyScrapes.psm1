Import-Module .\security.psm1
Import-Module .\utility.psm1
$workingLocation = 'c:\temp\dailyScrapes\working\'
$saveLocation = 'c:\temp\dailyScrapes\'
$hostsArray = @(Get-Content c:\temp\hosts.txt)

function getHostDriveData([string] $fQDN) {
	$getDriveDetailsScriptBlock = {
		$driveInfo = @(get-psdrive | where { $_.name.Length -eq 1 -and $_.used -gt 0 }) 

		$outputArray = @()
		foreach ($drive in $driveInfo) {
			$driveObj = New-Object -TypeName PSObject
			$driveObj | Add-Member -MemberType NoteProperty -Name snapshotDate -Value $(Get-Date -Format d)
			$driveObj | Add-Member -MemberType NoteProperty -Name drive -Value $drive.Name
			$driveObj | Add-Member -MemberType NoteProperty -Name driveFreeBytes -Value $drive.Free
			$driveObj | Add-Member -MemberType NoteProperty -Name driveCapacityBytes -Value ($drive.Used + $drive.Free)
			$outputArray += $driveObj
		}
		$outputArray
	}
    Write-Host "Scraping drive details on $fQDN" -NoNewline
    Write-Log -m "Scraping drive details on $fQDN..." -Level Info -Path $($workingLocation + 'log.txt')
    $stopWatch = [Diagnostics.Stopwatch]::StartNew()
    try {
	    $returnObj = Invoke-Command -ComputerName $fQDN -ScriptBlock $getDriveDetailsScriptBlock -Credential $(getCredentialForHost $fQDN) -ErrorAction Stop
        Write-Host " [success]" -NoNewline
        Write-Log -m "(successful) Scraping drive details on $fQDN" -Level Info -Path $($workingLocation + 'log.txt')
    } catch [System.Management.Automation.Remoting.PSRemotingTransportException] {
        Write-Host " [failed]" -NoNewline
        Write-Log -m "(failed) Scraping drive details on $fQDN" -Level Error -Path $($workingLocation + 'log.txt')
        Write-Log -m $_ -Level Error -Path $($workingLocation + 'log.txt')
    }
    $stopWatch.Stop()
    Write-Host $(" " + $stopWatch.Elapsed)

	$returnObj | Select -Property snapshotDate,@{Name="hostname";Expression={$_.PSComputerName}},drive,driveFreeBytes,driveCapacityBytes

}

function doDriveScrapes() {
    $storePath = $($workingLocation + 'driveSpaceStore.csv')
    $snapshotData = Import-CSV $storePath
    $snapshotData += $hostsArray | foreach { getHostDriveData $_ }
    $snapshotData | Export-Csv $storePath -NoTypeInformation
}

function getEventLogData([string] $fQDN) {
    $getEventLogScriptBlock= {
        $entryTypes = 'Information','Warning','Error'
        $logNames = 'Application','System','Security'
        foreach ($entryType in $entryTypes) {
            foreach ($logName in $logNames) {
                Get-Eventlog `
                    -newest 1000 `
                    -LogName $logName `
                    -EntryType $entryType `
                    -ErrorAction SilentlyContinue `
                    -After (Get-Date).AddDays(-1)
            }
        }
    }
    
    Write-Host "Scraping EventLog details on $fQDN" -NoNewline
    Write-Log -m "Scraping EventLog details on $fQDN..." -Level Info -Path $($workingLocation + 'log.txt')
    $stopWatch = [Diagnostics.Stopwatch]::StartNew()
    try {
	    $events = Invoke-Command -ComputerName $fQDN -ScriptBlock $getEventLogScriptBlock -Credential $(getCredentialForHost $fQDN) -ErrorAction Stop
        Write-Host " [success]" -NoNewline
        Write-Log -m "(successful) Scraping EventLog details on $fQDN" -Level Info -Path $($workingLocation + 'log.txt')
    } catch [System.Management.Automation.Remoting.PSRemotingTransportException] {
        Write-Host " [failed]" -NoNewline
        Write-Log -m "(failed) Scraping EventLog details on $fQDN" -Level Error -Path $($workingLocation + 'log.txt')
        Write-Log -m $_ -Level Error -Path $($workingLocation + 'log.txt')
    }
    $stopWatch.Stop()
    Write-Host $(" " + $stopWatch.Elapsed)

    $events | Select-Object TimeGenerated,@{Name="Hostname";Expression={$_.PSComputerName}},Source,EntryType,EventID,Message
}

function doEventLogScrapes() {
    $storePath = $($workingLocation + 'eventLogStore.csv')
    $eventsData = @(Import-CSV $storePath)
    $eventsData += $hostsArray | foreach { getEventLogData $_ }
    $eventsData | Export-Csv $storePath -NoTypeInformation
}

function doDailyScrapes() {
    doDriveScrapes
    doEventLogScrapes
}
Export-ModuleMember doDailyScrapes