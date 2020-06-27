write-host "Enter your KeyID and your key in the pop-up."
pause
Get-Credential | Export-CliXml -Path "$PSScriptRoot\Patreon-Credentials.xml"
write-host "Your credentials were saved in $PSScriptRoot\Patreon-Credentials.xml"