<#
SCRIPT PARAMS
#>
param (
	[Parameter(Mandatory=$true, Position=0, HelpMessage="hosts to snapshot and report")] [string[]] $hostsArray
)
<#
HARDCODED CONFIG
#>
# Location of data store CSV
$dataStoreCSVPath = $PSScriptRoot + '\driveSpaceStore.csv'
$recordRetentionInDays = 30
$averagesToUseInDays = 2,5,15
$averageToSortByIndex = 1 # starts at 0
$credentialMap = @{} # holds domain -> credential mappings

function getCredentialForHost([string] $hostName) {
	$domain = ($hostName -split '\.',2)[1]
	if (!$credentialMap[$domain]) {
		try {
			$credentialMap[$domain] = Get-Credential $($domain + '\vagrant')
		} catch [System.Management.Automation.ParameterBindingException] {
			Write-Host "exception"
			$credentialMap = $null
			Throw "Credential not set"			
		}
		$credentialMap[$domain]
	}
	else {
		$credentialMap[$domain]
	}
}

function getHostDriveData([string] $hostName) {
	$getDriveDetailsScriptBlock = {
		$driveInfo = @(get-psdrive | where { $_.name.Length -eq 1 -and $_.used -gt 0 }) 

		$outputArray = @()
		foreach ($drive in $driveInfo) {
			$obj = New-Object -TypeName PSObject
			$obj | Add-Member -MemberType NoteProperty -Name snapshotDate -Value $(Get-Date -Format d)
			$obj | Add-Member -MemberType NoteProperty -Name drive -Value $drive.Name
			$obj | Add-Member -MemberType NoteProperty -Name driveFreeBytes -Value $drive.Free
			$obj | Add-Member -MemberType NoteProperty -Name driveCapacityBytes -Value ($drive.Used + $drive.Free)
			$outputArray += $obj
		}
		$outputArray
	}
	$returnObj = Invoke-Command -ComputerName $hostName -ScriptBlock $getDriveDetailsScriptBlock -Credential $(getCredentialForHost $hostName)
	Write-Host "finished on $hostname"
	$returnObj | Select -Property snapshotDate,@{Name="hostname";Expression={$_.PSComputerName}},drive,driveFreeBytes,driveCapacityBytes

}

function getUsageAnalysis([string] $hostname, [char] $drive, [int] $aveToUseInDays) {

	$snapShotData = $snapShotData `
		| Where { ($_.hostname -eq $hostName) -and ($_.drive -eq $drive) } `
		| Select -Property @{Name="snapshotDate";Expression={Get-Date -date $_.snapshotDate}},hostname,drive,driveFreeBytes,driveCapacityBytes `
		| Sort -Desc snapshotDate

	$mostRecentDay = $snapShotData | Select -First 1
    $earliestDay = $snapShotData `
		| Select -First $aveToUseInDays `
		| Sort snapshotDate `
		| Select -First 1
	
	if ($mostRecentDay.snapshotDate -eq $earliestDay.snapshotDate) {
		$obj = New-Object -TypeName PSObject
		$obj | Add-Member -MemberType NoteProperty -Name Host -value $hostName
		$obj | Add-Member -MemberType NoteProperty -Name Drive -value $drive
		$obj | Add-Member -MemberType NoteProperty -Name 'FreeSpace (gb)' -value ([math]::Round($($mostRecentDay.driveFreeBytes /1Gb)))
		$obj | Add-Member -MemberType NoteProperty -Name $([string] $aveToUseInDays +'d '+'AverageUsage (mb)') -value -1
		$obj | Add-Member -MemberType NoteProperty -Name $([string] $aveToUseInDays +'d ' +'DaysRemaining') -value -1   
		return 0,$obj
	}
    $daysBetween = (New-TimeSpan $earliestDay.snapshotDate $mostRecentDay.snapshotDate).Days
    $spaceDiff = $mostRecentDay.driveFreeBytes - $earliestDay.driveFreeBytes
	Write-Debug $("`$mostRecentDay.snapshotDate: " + $mostRecentDay.snapshotDate)
	Write-Debug $("`$earliest.snapshotDate: " + $earliestDay.snapshotDate)
	Write-Debug $("`$daysBetween: " + $daysBetween)
	Write-Debug $("`$spaceDiff: " + $spaceDiff)
	$diffPerDay = $spaceDiff / $daysBetween
	$daysRemaining = $mostRecentDay.driveCapacityBytes / $diffPerDay
	Write-Debug $("`$diffPerDay: " + $diffPerDay)
	Write-Debug $("`$daysRemaining: " + $daysRemaining)

    $obj = New-Object -TypeName PSObject
    $obj | Add-Member -MemberType NoteProperty -Name Host -value $hostName
    $obj | Add-Member -MemberType NoteProperty -Name Drive -value $drive
	$obj | Add-Member -MemberType NoteProperty -Name 'FreeSpace (gb)' -value ([math]::Round($($mostRecentDay.driveFreeBytes /1Gb)))
    $obj | Add-Member -MemberType NoteProperty -Name $([string] $daysBetween +'d '+'AverageUsage (mb)') -value ([math]::Round(($diffPerDay / 1MB)))
    $obj | Add-Member -MemberType NoteProperty -Name $([string] $daysBetween +'d ' +'DaysRemaining') -value ([math]::Round($daysRemaining,1))    
    $daysBetween,$obj
}

function main {

	$snapShotData = Import-CSV $dataStoreCSVPath
	# Remove records from CSV store file older than [retention param]
	$snapShotData = @($snapShotData | Where-Object { (Get-Date -date $_.snapshotDate) -ge $((Get-Date).AddDays(-$recordRetentionInDays-1)) })

	$snapshotData += $hostsArray | foreach { getHostDriveData $_ }
	
	$snapShotData | Export-Csv $dataStoreCSVPath -NoTypeInformation
	$outputArray = @()
	# for all hosts in snapshot repo...
	foreach ($hostName in ($snapShotData | Sort hostname | Select -Unique hostname).hostname) {
		# for all drive labels for that host...
		Write-Host "Entering host: $hostName"
		foreach ($drive in ($snapShotData | Where { $_.hostname -eq $hostName } | Sort drive | Select -Unique drive).drive) {
			Write-Host "Entering drive: $drive"
			Write-Debug $("`$averagesToUseInDays.length: " + $averagesToUseInDays.length)
			for ($i = 0; $i -lt $averagesToUseInDays.length; $i++) { 
				Write-Debug $("`$i: $i")
				if ($i -eq 0) {
					$daysBetween,$driveObj = getUsageAnalysis $hostname $drive $averagesToUseInDays[$i]
				}
				else {
					$daysBetween,$outObj = getUsageAnalysis $hostname $drive $averagesToUseInDays[$i]
					$aveUsagePropName = [string] $daysBetween +'d AverageUsage (mb)'
					$driveObj | Add-Member -Force -MemberType NoteProperty -Name $aveUsagePropName -Value $outObj.$aveUsagePropName
					$daysRemainingPropName = [string] $daysBetween +'d DaysRemaining'
					$driveObj | Add-Member -Force -MemberType NoteProperty -Name $daysRemainingPropName -Value $outObj.$daysRemainingPropName
				}
				if ($i -eq $averageToSortByIndex) {
					$daysRemainingSortPropName = [string] $daysBetween +'d DaysRemaining'
					Write-Debug $("`$daysRemainingSortPropName: $daysRemainingSortPropName")
				}
			}
			$outputArray += $driveObj
		}
	}
	$outputArray | Sort $daysRemainingSortPropName
}
main