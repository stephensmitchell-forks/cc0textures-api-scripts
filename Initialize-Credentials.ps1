$credential = Get-Credential
$credential | Export-CliXml -Path "$PSScriptRoot\Patreon-Credentials.xml"