###PARAMETERS###

Param(
    [String]$query,
    [ValidateSet("PhotoTexturePBR","PhotoTexturePlain","SBSAR","3DModel")][String]$type,
    [ValidateSet("Alphabet","Popular","Latest")][String]$sort,
    [String]$id,
    [String]$attribute="",
    [ValidateScript({Test-Path $_})][String]$downloadPath = "$PSScriptRoot\CC0Textures-Downloads",
    [String]$keyFile = "$PSScriptRoot\Patreon-Credentials.xml",
    [Boolean]$makeSubfolders=$true,
    [Boolean]$useTestEnvironment=$false
)
$ErrorActionPreference = 'Stop'
###FUNCTIONS###

#Slightly modified version of https://stackoverflow.com/a/40887001
function FormatSize($bytes)
{
    $suffix = "B", "KB", "MB", "GB", "TB"
    $index = 0
    while ($bytes -gt 1kb) 
    {
        $bytes = $bytes / 1kb
        $index++
    }

    "{0:N1} {1}" -f $bytes, $suffix[$index]
}

###MAIN SCRIPT###

#Initialize variables for the rest of the script

if($useTestEnvironment){
    $apiUrl = "https://test.cc0textures.com/api/v1/downloads_csv"
}else{
    $apiUrl = "https://cc0textures.com/api/v1/downloads_csv"
}
$attributeRegex = [RegEx]("$attribute")
$downloadDirectory = Resolve-Path -Path "$downloadPath"

#Decide whether to use the Patreon key

if(Test-Path $keyFile){
    $usePatreon = $true
}else{
    $usePatreon = $false
}

#Build HTTP parameters

$getParameters = @{
    q  = $query
    type = $type
    sort = $sort
    id = $id
    patreon=[int]$usePatreon
}

#Build GET query string
$parameterString=@()
$getParameters.Keys | ForEach-Object{
   $parameterString += "{0}={1}" -f $_,$getParameters.Item($_)
}
$parameterString = $parameterString -join "&"

#Run
Write-Host "Loading downloads from CC0 Textures API...";
if($usePatreon){
    $postParameters = @{
        key = (Import-CliXml -Path "$PSScriptRoot\Patreon-Credentials.xml").GetNetworkCredential().password
    }
    $webRequest = Invoke-WebRequest -Uri "$($apiUrl)?$($parameterString)" -Method Post -Body $postParameters
} else{
    $webRequest = Invoke-WebRequest -Uri "$($apiUrl)?$($parameterString)"
}

#Run the webrequest and apply the regexes

$apiOutput = [array]($webRequest.Content | ConvertFrom-Csv | Where-Object{ $_.DownloadAttribute -match $attributeRegex})
$numberOfDownloads = $apiOutput.Length
$totalSizeBytes = ($apiOutput | Measure-Object -Property Size -Sum).Sum
$totalSizeFormatted = FormatSize($totalSizeBytes)

#Display the number of results and ask user whether to continue
if($numberOfDownloads -gt 0){
    write-host "Found $numberOfDownloads files with a total size of $totalSizeFormatted." -f green
    Write-Host "Files will be downloaded into $downloadDirectory" -NoNewline
    if($makeSubfolders){
        write-host " (with subdirectories per AssetID)"
    } else{
        write-host " (without subdirectories)"
    }

} else{
    write-host "Could not find any downloads for these parameters. " -f red
    exit
}

pause

#Loop over API output and perform downloads

$downloadedSizeBytes=0

$apiOutput | ForEach-Object{

    #Define output directory and final filename (depending on whether subfolder parameter is set)

    if($makeSubfolders){
        $destinationDirectory = Join-Path -Path $downloadDirectory -ChildPath $_.AssetID
    }else{
        $destinationDirectory = $downloadDirectory
    }
    
    $destinationFile = Join-Path -Path $destinationDirectory -ChildPath ("{0}_{1}.{2}" -f $_.AssetID,$_.DownloadAttribute,$_.Filetype)
    $sourceUrl = if($_.PrettyDownloadLink -eq ''){$_.RawDownloadLink}else{$_.PrettyDownloadLink}

    #Create an output directory if it does not exist

    if(!(Test-Path $destinationDirectory)){
        New-Item -Path $destinationDirectory -ItemType "directory" | Out-Null
        write-host "Created directory: $destinationDirectory"
    }

    #Calculate progression in percent and create loading bar
    $percentCompleted = (($downloadedSizeBytes / $totalSizeBytes) * 100)
    $percentCompletedDisplay = $percentCompleted.ToString("0.0000")
    $downloadStatus = "{0}% completed" -f $percentCompletedDisplay
    Write-Progress -Activity "Downloading Assets" -Status "$downloadStatus" -PercentComplete $percentCompleted;

    
    Start-BitsTransfer -Source $sourceUrl -Destination $destinationFile -Description "$sourceUrl -> $destinationFile"
    $downloadedSizeBytes = $downloadedSizeBytes + $_.Size
}