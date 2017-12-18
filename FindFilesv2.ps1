#TODO
# Output formatting / ordering
# Choose between mixture of search filters including date modified, text, size

# Configuration
$searchLocation = "C:\Users\james.holloway\Google Drive\diary\"
$modifiedSearch = "01/08/2016"
$sizeSearch = $null
$textSearch = "*tariff*.sql"

function updateSearchLocation($newDir) {
  (Get-Content -Path $Script:MyInvocation.MyCommand.Path) `
    -replace '^\$searchLocation.*',('$searchLocation = "' + $newDir + '"') `
    | Set-Content -path $Script:MyInvocation.MyCommand.Path
  cls
  & $Script:MyInvocation.MyCommand.Path
  break
}
function updateModifiedSearch($newDate) {
  (Get-Content -Path $Script:MyInvocation.MyCommand.Path) `
    -replace '^\$modifiedSearch.*',('$modifiedSearch = "' + (Get-Date -date $newDate -f "dd/MM/yyyy") + '"') `
    | Set-Content -path $Script:MyInvocation.MyCommand.Path
  #cls
  & $Script:MyInvocation.MyCommand.Path
  break
}

function updateTextSearch($newPattern) {
  Set-Variable textSearch -Value $newPattern -Scope 1
  (Get-Content -Path $Script:MyInvocation.MyCommand.Path) `
    -replace '^\$textSearch.*',('$textSearch = ' `
      + $(if ($newPattern -ne '*') {'"' + $newPattern  + '"'} else {'$null'})) `
    | Set-Content -path $Script:MyInvocation.MyCommand.Path
}

function doMenu() {
  #cls
  Write-Host -BackgroundColor Black -ForegroundColor White "*------------*"
  Write-Host -BackgroundColor Black -ForegroundColor White "* Find Files *"
  Write-Host -BackgroundColor Black -ForegroundColor White "*------------*"
  Write-Host `r`n
  Write-Host -BackgroundColor Black -ForegroundColor White "Current Location:"
  Write-Host -BackgroundColor Black -ForegroundColor Yellow $searchLocation
  Write-Host `r  
  
  if ($textSearch -or $modifiedSearch -or $sizeSearch) {
    Write-Host -BackgroundColor Black -ForegroundColor White "Current Filters:"
  }
  if ($textSearch) {
    Write-Host -BackgroundColor Black -ForegroundColor White -NoNewline "Name like: "
    Write-Host -BackgroundColor Black -ForegroundColor Yellow $textSearch
  }
  if ($modifiedSearch) {
    Write-Host -BackgroundColor Black -ForegroundColor White -NoNewline "Modified since: "
    Write-Host -BackgroundColor Black -ForegroundColor Yellow $modifiedSearch
  }
  if ($sizeSearch) {
    Write-Host -BackgroundColor Black -ForegroundColor White -NoNewline "Bigger than: "
    Write-Host -BackgroundColor Black -ForegroundColor Yellow $sizeSearch
  }
  if ($textSearch -or $modifiedSearch -or $sizeSearch) {
    Write-Host `r`n
  }
  Write-Host -BackgroundColor Black -ForegroundColor White "Options:"
  Write-Host -BackgroundColor Black -ForegroundColor Green "(1) Change search location"
  Write-Host -BackgroundColor Black -ForegroundColor Green "(2) Change modified filter"
  Write-Host -BackgroundColor Black -ForegroundColor Green "[Else] Search with pattern"
  Write-Host `r`n
  Write-Host '------------------'
  #Write-Host -BackgroundColor Black -ForegroundColor Red -NoNewLine 'Input> '
  Write-Host -BackgroundColor Black -ForegroundColor Red -NoNewLine `
        'File name like [Default: use last search. ''*'' to find all]> ' 
  Read-Host
}

function doSearch() {
  cls
  $searchResults = Get-ChildItem -Path $searchLocation -Recurse -Filter *$textSearch*
  
  foreach ($result in ($searchResults | Sort -property LastWriteTime -Descending)) {
    $obj = New-Object PSObject
    $obj | Add-Member Filename $result.Name 
    $obj | Add-Member "Relative Dir" ($result.Directory | Resolve-Path -Relative)
    $obj | Add-Member "Last Modified" (Get-Date -f "dd/MM/yyyy" -date $result.LastWriteTime)

    Write-Output $obj
  
    <#Write-Host -BackgroundColor Black -ForegroundColor Cyan -NoNewline $result.Name
        Write-Host -BackgroundColor Black -ForegroundColor White "`t`t" + ($result.Directory | Resolve-Path -Relative)
  #>  }
  
  #| Resolve-Path -Relative
}

$userInput = doMenu

switch ($userInput) {
  1 { # Change search location
      Write-Host -BackgroundColor Black -ForegroundColor Red -NoNewLine `
        'Enter new search location> '
      $userInput = Read-Host
      if ($userInput.length -gt 0) {
        updateSearchLocation($userInput)
      }
    }
  2 { # Change/Add last modified filter
      Write-Host -BackgroundColor Black -ForegroundColor Red -NoNewLine `
        'Filter for files modified on or after (Format: DDMM)> '
      $userInput = Read-Host
      if ($userInput -match "^[0-3]\d[0-1]\d$") {
        $assembledDate = (Get-Date -date (`
            $userInput.Substring(0,2)+ '/' + $userInput.Substring(2,2) + '/' + (get-date -f yyyy)
        ))
        if ($assembledDate.toString("yyyy-M-dd") -gt (Get-Date).toString("yyyy-M-dd")) {
          Set-Variable -name assembledDate -value ($userInput.Substring(0,2)+ '/' + $userInput.Substring(2,2) + '/' + ((get-date -f yyyy)-1))
        }
        updateModifiedSearch($assembledDate)
      }
      else {
        Write-Host "Incorrect format, returning to main menu..."
      }
    }

  default {
    if ($userInput) {
      updateTextSearch($userInput)
    }
    doSearch
  }

}

