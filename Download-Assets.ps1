#region Parameters

Param(
    [String]$Query,
    [ValidateSet("PhotoTexturePBR","PhotoTexturePlain","SBSAR","3DModel")][String]$Type,
    [ValidateSet("Alphabet","Popular","Latest")][String]$Sort,
    [String]$Id,
    [String]$Category,
    [String[]]$IncludeAttribute,
    [String[]]$ExcludeAttribute,
    [ValidateScript({
        #Test-Path "$_"
        if( -Not (Test-Path "$_")){
            Throw "The download directory $_ does not exist."
        }else{
            $True
        }
    })][String]$DownloadDirectory = "$PSScriptRoot",
    [Switch]$NoSubfolders,
    [Switch]$SkipExisting,
    [Switch]$UseTestEnvironment
)
$ErrorActionPreference = 'Stop'

#region Functions

#Slightly modified version of https://stackoverflow.com/a/40887001
function FormatSize($Bytes)
{
    $Suffix = "B", "KB", "MB", "GB", "TB"
    $Index = 0
    while ($Bytes -gt 1kb) 
    {
        $Bytes = $Bytes / 1kb
        $Index++
    }

    "{0:N2} {1}" -f $Bytes, $Suffix[$Index]
}

#region Initializaton

#Select Environment
if($UseTestEnvironment){
    $ApiUrl = "https://test.cc0textures.com/api/v1/downloads_csv"
}else{
    $ApiUrl = "https://cc0textures.com/api/v1/downloads_csv"
}

#region Web Request

#Build HTTP GET parameters
$GetParameters = @{
    q  = $Query
    type = $Type
    sort = $Sort
    id = $Id
    category = $Category
}

#Build Post-Parameters and run
Write-Host "Loading downloads from CC0 Textures API...";

Write-Host "Calling '$ApiUrl'"
try{
    $WebRequest = Invoke-WebRequest -Uri "$ApiUrl" -Method "Get" -Body $GetParameters
}catch {
    switch ($_.Exception.Response.StatusCode.Value__)                         
    {                        
        404{Throw "HTTP Error 404`nThe requested document could not be found. This probably means that the API has been changed or removed but the script has not yet been updated."}
        404{Throw "HTTP Error 500`nInternal server error."}
    }
}

#apply the attributes and count results

$DownloadList = [array]($WebRequest.Content | ConvertFrom-Csv)
foreach ($Attribute in $IncludeAttribute) {
    [array]$DownloadList = ($DownloadList | Where-Object {$_.DownloadAttribute.Split('-').Contains("$Attribute")})
}
foreach ($Attribute in $ExcludeAttribute) {
    [array]$DownloadList = ($DownloadList | Where-Object { -Not ($_.DownloadAttribute.Split('-').Contains("$Attribute"))})
}

$NumberOfDownloads = $DownloadList.Length
$TotalSizeBytes = ($DownloadList | Measure-Object -Property Size -Sum).Sum
$TotalSizeFormatted = FormatSize($TotalSizeBytes)

#region Confirmation

#Display the number of results and ask user whether to continue. Exit if nothing was found
if($NumberOfDownloads -gt 0){
    write-host "Found $NumberOfDownloads files with a total size of $TotalSizeFormatted." -f green
    Write-Host "Files will be downloaded into $DownloadDirectory" -NoNewline
    if($NoSubfolders){
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

$DownloadedSizeBytes=0
$FinishedDownloads=0

$DownloadList | ForEach-Object{

    #Define output directory and final filename (depending on whether subfolder parameter is set)

    if($NoSubfolders){
        $DestinationDirectory = $DownloadDirectory
    }else{
        $DestinationDirectory = Join-Path -Path $DownloadDirectory -ChildPath $_.AssetID
    }
    
    $DestinationFile = Join-Path -Path $DestinationDirectory -ChildPath ("{0}_{1}.{2}" -f $_.AssetID,$_.DownloadAttribute,$_.Filetype)
    $SourceUrl = if($_.PrettyDownloadLink -eq ''){$_.RawDownloadLink}else{$_.PrettyDownloadLink}

    if( (Test-Path -Path "$DestinationFile") -and $SkipExisting ){
        Write-Host "File exists, skipping: $DestinationFile"
    } else{
        #Create an output directory if it does not exist

        if(!(Test-Path $DestinationDirectory)){
            New-Item -Path $DestinationDirectory -ItemType "directory" | Out-Null
            write-host "Created directory: $DestinationDirectory"
        }

        #Calculate progression in percent and create loading bar
        $PercentCompleted = (($DownloadedSizeBytes / $TotalSizeBytes) * 100)
        $PercentCompletedDisplay = $PercentCompleted.ToString("0.00")
        $DownloadedSizeFormatted = FormatSize($DownloadedSizeBytes)
        $DownloadStatus = "{0} of {1} / {2} of {3} / {4}%" -f $FinishedDownloads,$NumberOfDownloads,$DownloadedSizeFormatted,$TotalSizeFormatted,$PercentCompletedDisplay
        Write-Progress -Activity "Downloading Assets" -Status "$DownloadStatus" -PercentComplete $PercentCompleted;
        write-host "Downloading file: $DestinationFile"
        Start-BitsTransfer -Source "$SourceUrl" -Destination "$DestinationFile" -Description "$SourceUrl -> $DestinationFile"
    }
    $DownloadedSizeBytes = $DownloadedSizeBytes + $_.Size
    $FinishedDownloads = $FinishedDownloads + 1
}