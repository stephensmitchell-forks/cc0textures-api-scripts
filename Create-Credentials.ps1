$wshell = New-Object -ComObject Wscript.Shell
$wshell.Popup("Press OK and enter the Key and its KeyID as username and password.",0,"Done",0x0)
try{
    Get-Credential | Export-CliXml -Path "$PSScriptRoot\Patreon-Credentials.xml"
    write-host "Your credentials were saved in $PSScriptRoot\Patreon-Credentials.xml" -ForegroundColor Green
}catch{
    Write-Error "Your Credentials could not be saved.`n`n`n"
}
