#region Parameters

Param(
    [String]$query,
    [ValidateSet("PhotoTexturePBR","PhotoTexturePlain","SBSAR","3DModel")][String]$type,
    [ValidateSet("Alphabet","Popular","Latest")][String]$sort,
    [String]$id,
    [String]$category,
    [String[]]$includeAttribute,
    [String[]]$excludeAttribute,

    [ValidateScript({
        Test-Path "$_"
    })][String]$downloadDirectory = "$PSScriptRoot",

    [String]$keyFile = "$PSScriptRoot\Patreon-Credentials.xml",
    [Switch]$noSubfolders,
    [Switch]$useTestEnvironment
)
$ErrorActionPreference = 'Stop'

#region Functions

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

    "{0:N2} {1}" -f $bytes, $suffix[$index]
}

#region Initializaton

#Select Environment
if($useTestEnvironment){
    $apiUrl = "https://test.cc0textures.com/api/v1/downloads_csv"
}else{
    $apiUrl = "https://cc0textures.com/api/v1/downloads_csv"
}

#Decide whether to use the Patreon key

if(Test-Path "$keyFile"){
    $usePatreon = $true
}else{
    $usePatreon = $false
}

#region Web Request

#Build HTTP GET parameters
$getParameters = @{
    q  = $query
    type = $type
    sort = $sort
    id = $id
    category = $category
    patreon=[int]$usePatreon
}

#Build GET query string (Because we need both GET and POST which means GET will have to be transmitted via the URL string)
$parameterArray=@()
$getParameters.Keys | ForEach-Object{
   $parameterArray += "{0}={1}" -f $_,$getParameters.Item($_)
}
$parameterString = $parameterArray -join "&"

#Build Post-Parameters and run
Write-Host "Loading downloads from CC0 Textures API...";
if($usePatreon){
    $postParameters = @{
        key = (Import-CliXml -Path "$PSScriptRoot\Patreon-Credentials.xml").GetNetworkCredential().password
    }
    $webRequest = Invoke-WebRequest -Uri "$($apiUrl)?$($parameterString)" -Method Post -Body $postParameters
} else{
    $webRequest = Invoke-WebRequest -Uri "$($apiUrl)?$($parameterString)"
}

#apply the attributes and count results

$downloadList = [array]($webRequest.Content | ConvertFrom-Csv)
foreach ($attribute in $includeAttribute) {
    $downloadList = ($downloadList | Where-Object {$_.DownloadAttribute.Split('-').Contains("$attribute")})
}
foreach ($attribute in $excludeAttribute) {
    $downloadList = ($downloadList | Where-Object { -Not ($_.DownloadAttribute.Split('-').Contains("$attribute"))})
}

$numberOfDownloads = $downloadList.Length
$totalSizeBytes = ($downloadList | Measure-Object -Property Size -Sum).Sum
$totalSizeFormatted = FormatSize($totalSizeBytes)

#region Confirmation

#Display the number of results and ask user whether to continue. Exit if nothing was found
if($numberOfDownloads -gt 0){
    write-host "Found $numberOfDownloads files with a total size of $totalSizeFormatted." -f green
    Write-Host "Files will be downloaded into $downloadDirectory" -NoNewline
    if($noSubfolders){
        write-host " (without subdirectories)"
    } else{
        write-host " (with subdirectories per AssetID)"
    }

} else{
    write-host "Could not find any downloads for these parameters. " -f red
    exit
}
Write-Host "Start downloading?" -f Yellow
pause

#region Downloading

$downloadedSizeBytes=0
$finishedDownloads=0

$downloadList | ForEach-Object{

    #Define output directory and final filename (depending on whether subfolder parameter is set)

    if($noSubfolders){
        $destinationDirectory = $downloadDirectory
    }else{
        $destinationDirectory = Join-Path -Path $downloadDirectory -ChildPath $_.AssetID
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
    $percentCompletedDisplay = $percentCompleted.ToString("0.00")
    $downloadedSizeFormatted = FormatSize($downloadedSizeBytes)
    $downloadStatus = "{0} of {1} / {2} of {3} ({4}%)" -f $finishedDownloads,$numberOfDownloads,$downloadedSizeFormatted,$totalSizeFormatted,$percentCompletedDisplay
    Write-Progress -Activity "Downloading Assets" -Status "$downloadStatus" -PercentComplete $percentCompleted;
    write-host "Downloading file: $destinationFile"
    Start-BitsTransfer -Source "$sourceUrl" -Destination "$destinationFile" -Description "$sourceUrl -> $destinationFile"
    $downloadedSizeBytes = $downloadedSizeBytes + $_.Size
    $finishedDownloads = $finishedDownloads + 1
}