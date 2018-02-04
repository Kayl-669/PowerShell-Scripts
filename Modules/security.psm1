$credentialMap = @{}
$pathToDefaultUsers = 'c:\temp\defaultUsers.txt'
$defaultUsersMap = Get-Content -Raw $pathToDefaultUsers | ConvertFrom-StringData

function getCredentialForHost([string] $fQDN) {
	$domain = ($fQDN -split '\.',2)[1]
	if (!$credentialMap[$domain]) {
		try {
			$credentialMap[$domain] = Get-Credential $($defaultUsersMap[$domain]+'@'+$domain)
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