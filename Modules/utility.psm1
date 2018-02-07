<#
.Synopsis
   Write-Log writes a message to a specified log file with the current time stamp.
.DESCRIPTION
   The Write-Log function is designed to add logging capability to other scripts.
   In addition to writing output and/or verbose you can write to a log file for
   later debugging.
.NOTES
   Created by: Jason Wasser @wasserja
   Modified: 11/24/2015 09:30:19 AM  

.PARAMETER Message
   Message is the content that you wish to add to the log file. 
.PARAMETER Path
   The path to the log file to which you would like to write. By default the function will 
   create the path and file if it does not exist. 
.PARAMETER Level
   Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational)
.PARAMETER NoClobber
   Use NoClobber if you do not wish to overwrite an existing file.
.EXAMPLE
   Write-Log -Message 'Log message' 
   Writes the message to c:\Logs\PowerShellLog.log.
.EXAMPLE
   Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log
   Writes the content to the specified log file and creates the path and file specified. 
.EXAMPLE
   Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error
   Writes the message to the specified log file as an error message, and writes the message to the error pipeline.
.LINK
   https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0
#>
function Write-Log
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$Path='C:\Logs\PowerShellLog.log',
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",
        
        [Parameter(Mandatory=$false)]
        [switch]$NoClobber
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {
        
        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $NewLogFile = New-Item $Path -Force -ItemType File
            }

        else {
            # Nothing to see here yet.
            }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                $LevelText = 'ERROR:'
                }
            'Warn' {
                $LevelText = 'WARNING:'
                }
            'Info' {
                $LevelText = 'INFO:'
                }
            }
        
        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
    }
    End
    {
    }
}

function analyseEventLogStore([int] $acrossDays) {
    $eventLogStore = 'C:\Users\james.holloway\Google Drive\Daily Checks\eventLogStore.csv'
    $events = Import-Csv $eventLogStore `
        | Select @{Name="EventDate";Expression={Get-Date -date $_.TimeGenerated -f "dd/MM/yyyy"}} `
            ,Hostname `
            ,Source `
            ,EntryType `
            ,EventID `
            ,Message
    $eventIDHashTab = $events | Group-Object EventID -AsHashTable

    #Create Table object
    $table = New-Object system.Data.DataTable "EventsTable"

    #Define Columns
    $col1 = New-Object system.Data.DataColumn EventID,([Int32])
    $col2 = New-Object system.Data.DataColumn EventDate,([datetime])
    $col3 = New-Object system.Data.DataColumn Occurences,([Int32])
    $col4 = New-Object system.Data.DataColumn Message,([String])
    $col5 = New-Object system.Data.DataColumn EntryType,([String])
    $col6 = New-Object system.Data.DataColumn Source,([String])
    $col7 = New-Object system.Data.DataColumn Host,([String])
    #Add the columns
    $table.Columns.add($col1)
    $table.Columns.add($col2)
    $table.Columns.add($col3)
    $table.Columns.add($col4)
    $table.Columns.add($col5)
    $table.Columns.add($col6)
    $table.Columns.add($col7)
 
    foreach ($EventIDKey in $eventIDHashTab.GetEnumerator()) { 

    $EventsByDate = $EventIDKey.Value | Group EventDate -AsHashTable
    foreach ($EventDateKey in $EventsByDate.GetEnumerator()) {
        
        $EventsByHost = $EventDateKey.Value | Group Hostname -AsHashTable

        foreach ($EventHostKey in $EventsByHost.GetEnumerator()) {
            #Create a row
            if (!$EventHostKey) {continue}
            $row = $table.NewRow()
            $row.EventID = [int]$EventIDKey.Name
            $row.EventDate = (Get-Date -date $EventDateKey.Name).Date
            $row.Host = $EventHostKey.Name
            $row.Occurences = $EventHostKey.Value.Count
            $row.Message = $EventHostKey.Value[0].Message
            $row.EntryType = $EventHostKey.Value[0].EntryType
            $row.Source = $EventHostKey.Value[0].Source
            $table.Rows.Add($row)
            }
        }
    }
    $pivot = @()
    foreach ($EventID in $table.EventID | Select -Unique | Sort) {

        $eventHosts = ($table.where({ $_.EventID -eq $EventID})).Host
 
        foreach ($sqlHost in $eventHosts | Select -Unique | Sort) {
            $Props = [ordered]@{ EventID = $EventID }
            $Props += @{ EntryType = $table.where( {$_.EventID -eq $EventID} )[0].EntryType }
            $Props += @{ Source = $table.where( {$_.EventID -eq $EventID} )[0].Source }
            $Props += @{ Message = $table.where( {$_.EventID -eq $EventID} )[0].Message }
            $Props += @{ Host = $sqlHost }
        
            foreach ($EventDate in $table.EventDate | Select -Unique | Sort) {
                $Occurrences = ($table.where({ $_.EventID -eq $EventID `
                    -and $_.EventDate -eq $EventDate `
                    -and $_.Host -eq $sqlHost })).Occurences 
                $Props += @{ $(Get-Date -date $EventDate -Format d) = $Occurrences }
            }
            $pivot += New-Object -TypeName PSObject -Property $Props
        }
    }
    $dateString = [string] (get-date -f "yyyy") + [string] (get-date -f "MM") + [string] (get-date -f "dd")
    $pivot | export-csv ('C:\Users\james.holloway\Google Drive\Daily Checks\EventViewer_'+ $dateString +'.csv') -NoTypeInformation
    
}

function analyseReportSchedulerLog() {
    $pathToSchedulerLog = 'C:\Users\james.holloway\Google Drive\Daily Checks\com.esendex.scheduler.txt'
    $logLines = Get-Content $pathToSchedulerLog
    $preableFormat = '^\[(?<ts>\d\d\d\d-\d\d-\d\d\s\d\d:\d\d:\d\d),\d\d\d\]\s\[(?<th>.\d)\]\s\[(?<level>\w\w\w\w\s)\]\s-\s' 
    $runningReportPattern = '\d\d:\d\d Running report : (?<rn>.*)\s-\sdue\s(?<rd>\d\d\/\d\d\/\d\d\d\d)'
    $queryCompletePattern = 'Report (?<rn>.*)\s::\sQuery\s(?<qn>\d*)\sreturned\s(?<qr>\d*)(?<qnr>\w*)\srows'
    $reportCompletePattern = '\d\d:\d\d\sCompleted report\s-\s(?<rn>.*)\sin\s(?<cs>\d*\.\d)'

    #Create Table object
    $table = New-Object system.Data.DataTable "ReportRunsTable"
    #Define Columns
    $col1 = New-Object system.Data.DataColumn DueDate,([datetime])
    $col2 = New-Object system.Data.DataColumn Thread,([Int32])
    $col3 = New-Object system.Data.DataColumn ReportName,([String])
    $col4 = New-Object system.Data.DataColumn StartTime,([datetime])
    $col5 = New-Object system.Data.DataColumn EndTime,([datetime])
    $col6 = New-Object system.Data.DataColumn SecondsTaken,([float])
    $col7 = New-Object system.Data.DataColumn ErrorMessage,([String])
    $col8 = New-Object system.Data.DataColumn Query0Rows,([Int])
    $col9 = New-Object system.Data.DataColumn Query1Rows,([Int])
    $col10 = New-Object system.Data.DataColumn Query2Rows,([Int])
    #Add the columns
    $table.Columns.add($col1)
    $table.Columns.add($col2)
    $table.Columns.add($col3)
    $table.Columns.add($col4)
    $table.Columns.add($col5)
    $table.Columns.add($col6)
    $table.Columns.add($col7)
    $table.Columns.add($col8)
    $table.Columns.add($col9)
    $table.Columns.add($col10)

    foreach ($logLine in $logLines) {

        if ($logLine -match $($preableFormat + `
            '('+ $queryCompletePattern +'|'+$reportCompletePattern+'|' + $runningReportPattern +')')) {

            if ($matches['rd']) {
                $row = $table.NewRow()
                $row.DueDate = $matches.rd
                $row.Thread = $matches.th
                $row.ReportName = $matches.rn
                $row.StartTime = $matches.ts
                $table.Rows.Add($row)
            }
            elseif ($matches['qn'] -and $matches.qn -le 2) {
                $rowToUpdate = $table | where { $_.Thread -eq $matches.th -and $_.ReportName -eq $matches.rn -and $_.EndTime -eq [DBnull]::Value}
                if (!$rowToUpdate) { continue }
                $rowToUpdate = @($rowToUpdate)
                $rowToUpdate = $rowToUpdate | Sort StartTime -Descending | Select -First 1
                $rowToUpdate.$('Query'+$matches.qn+'Rows') = if ($matches.qnr -eq 'no') { 0 } else { $matches.qr } 
            }
            elseif ($matches['cs']) {
                $rowToUpdate = $table | where { $_.Thread -eq $matches.th -and $_.ReportName -eq $matches.rn -and $_.EndTime -eq [DBnull]::Value}
                if (!$rowToUpdate) { continue }
                $rowToUpdate = @($rowToUpdate)
                $rowToUpdate = $rowToUpdate | Sort StartTime -Descending | Select -First 1
                $rowToUpdate.EndTime = $matches.ts
                $rowToUpdate.SecondsTaken = $matches.cs
            }
        }
        else {
            # error info here
            $errInfo = @($logLine)
        }
    }
    $table | export-csv 'C:\Users\james.holloway\Google Drive\Daily Checks\parsedSchedulerLog.csv' -NoTypeInformation -Append
}

$driveDataCsvPath = 'C:\Users\james.holloway\Google Drive\Daily Checks\driveSpaceStore.csv'

function getUsageAnalysis([string] $hostname, [char] $drive, [int] $aveToUseInDays) {

	$driveData = $driveData `
		| Where { ($_.hostname -eq $hostName) -and ($_.drive -eq $drive) } `
		| Select -Property @{Name="snapshotDate";Expression={Get-Date -date $_.snapshotDate}},hostname,drive,driveFreeBytes,driveCapacityBytes `
		| Sort -Desc snapshotDate

	$mostRecentDay = $driveData | Select -First 1
    $earliestDay = $driveData `
		| Select -First $aveToUseInDays `
		| Sort snapshotDate `
		| Select -First 1
	
	$daysBetween = (New-TimeSpan $earliestDay.snapshotDate $mostRecentDay.snapshotDate).Days
	if ($daysBetweeen -eq 0) {
		$obj = New-Object -TypeName PSObject
		$obj | Add-Member -MemberType NoteProperty -Name Host -value $hostName
		$obj | Add-Member -MemberType NoteProperty -Name Drive -value $drive
		$obj | Add-Member -MemberType NoteProperty -Name 'FreeSpace (gb)' -value ([math]::Round($($mostRecentDay.driveFreeBytes /1Gb)))
		$obj | Add-Member -MemberType NoteProperty -Name $([string] $aveToUseInDays +'d '+'AverageUsage (mb)') -value -1
		$obj | Add-Member -MemberType NoteProperty -Name $([string] $aveToUseInDays +'d ' +'DaysRemaining') -value -1   
		return 0,$obj
	}

    $spaceDiff = $earliestDay.driveFreeBytes - $mostRecentDay.driveFreeBytes
	if ($spaceDiff -eq 0) {
		$obj = New-Object -TypeName PSObject
		$obj | Add-Member -MemberType NoteProperty -Name Host -value $hostName
		$obj | Add-Member -MemberType NoteProperty -Name Drive -value $drive
		$obj | Add-Member -MemberType NoteProperty -Name 'FreeSpace (gb)' -value ([math]::Round($($mostRecentDay.driveFreeBytes /1Gb)))
		$obj | Add-Member -MemberType NoteProperty -Name $([string] $aveToUseInDays +'d '+'AverageUsage (mb)') -value 0
		$obj | Add-Member -MemberType NoteProperty -Name $([string] $aveToUseInDays +'d ' +'DaysRemaining') -value -1   
		return 0,$obj
	}
	Write-Debug $("`$mostRecentDay.snapshotDate: " + $mostRecentDay.snapshotDate)
	Write-Debug $("`$earliest.snapshotDate: " + $earliestDay.snapshotDate)
	Write-Debug $("`$daysBetween: " + $daysBetween)
	Write-Debug $("`$spaceDiff: " + $spaceDiff)
	$diffPerDay = $spaceDiff / $daysBetween
	Write-Debug $("`$mostRecentDay.driveFreeBytes: " + $mostRecentDay.driveFreeBytes)
	$daysRemaining = $mostRecentDay.driveFreeBytes / $diffPerDay
	Write-Debug $("`$diffPerDay: " + $diffPerDay)
	Write-Debug $("`$daysRemaining: " + $daysRemaining)

    $obj = New-Object -TypeName PSObject
    $obj | Add-Member -MemberType NoteProperty -Name Host -value $hostName
    $obj | Add-Member -MemberType NoteProperty -Name Drive -value $drive
	$obj | Add-Member -MemberType NoteProperty -Name 'FreeSpace (gb)' -value ([math]::Round($($mostRecentDay.driveFreeBytes /1Gb)))
    #$obj | Add-Member -MemberType NoteProperty -Name $([string] $daysBetween +'d '+'AverageUsage (mb)') -value ([math]::Round(($diffPerDay / 1MB)))
    #$obj | Add-Member -MemberType NoteProperty -Name $([string] $daysBetween +'d ' +'DaysRemaining') -value ([math]::Round($daysRemaining,1))    
    $obj | Add-Member -MemberType NoteProperty -Name 'AverageUsage (mb)' -value ([math]::Round(($diffPerDay / 1MB)))
    $obj | Add-Member -MemberType NoteProperty -Name 'DaysRemaining' -value ([math]::Round($daysRemaining,1))    
    $daysBetween,$obj
}

function analyseDiskUsage {
    $driveData = Import-Csv $driveDataCsvPath

    $outputArray = @()
	# for all hosts in snapshot repo...
	foreach ($hostName in ($driveData | Sort hostname | Select -Unique @{Name="hostname";Expression={$_.hostName.toUpper()}}).hostname) {
		# for all drive labels for that host...
		Write-Debug "Entering host: $hostName"
		foreach ($drive in ($driveData | Where { $_.hostname -eq $hostName } | Sort drive | Select -Unique drive).drive) {
			Write-Debug "Entering drive: $drive"
			$daysBetween,$driveObj = getUsageAnalysis $hostname $drive 5
			Write-Debug $("`$daysBetween: $daysBetween")
			if ($daysBetween -eq 0) {continue}
			Write-Debug $("`$driveObj: $driveObj")

			#$daysRemainingSortPropName = [string] $daysBetween +'d DaysRemaining'

			$outputArray += $driveObj
		}
	}
	$outputArray | Export-Csv 'C:\Users\james.holloway\Google Drive\Daily Checks\analysedDriveSpace.csv' -NoTypeInformation

}
Export-ModuleMember Write-Log
Export-ModuleMember analyseReportSchedulerLog
Export-ModuleMember analyseDiskUsage
Export-ModuleMember analyseEventLogStore