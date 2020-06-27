###PARAMETERS###

Param(
    [String]$query,
    [ValidateSet("PhotoTexturePBR","PhotoTexturePlain","SBSAR","3DModel")][String]$type,
    [ValidateSet("Alphabet","Popular","Latest")][String]$sort,
    [String]$id,
    [String]$attribute,
    [String]$filetype,
    [Boolean]$makeSubfolders=$true
)

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

$apiUrl = "https://cc0textures.com/api/v1/downloads_csv"
$attributeRegex = [RegEx]("$attribute")
$filetypeRegex = [RegEx]("$filetype")
$downloadDirectory = "$PSScriptRoot\Downloads"

$getParameters = @{
    q  = $query
    type = $type
    sort = $sort
    id = $id
}

#Run the webrequest

$webRequest = Invoke-WebRequest -Uri "$apiUrl" -Body $getParameters
$apiOutput = ($webRequest.Content | ConvertFrom-Csv | Where-Object{ $_.DownloadAttribute -match $attributeRegex -and $_.Filetype -match $filetypeRegex})

#Display the number of results and ask user whether to continue
#TODO Display more info (such as total size)


$numberOfDownloads = $apiOutput.Count
$totalSizeBytes = ($apiOutput | Measure-Object -Property Size -Sum).Sum
$totalSizeFormatted = FormatSize($totalSizeBytes)
$downloadedSizeBytes=0

write-host "Found $numberOfDownloads files with a total size of $totalSizeFormatted " -f green
pause

#Loop over API output and perform downloads


$apiOutput | ForEach-Object{

    #Define output directory and final filename

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

    #Calculate progression in percent

    $percentCompleted = (($downloadedSizeBytes / $totalSizeBytes) * 100).ToString("00.0")

    #Display what's being downloaded and start the download
    "[{0}%] {1}_{2} ({3})" -f $percentCompleted,$_.AssetID,$_.DownloadAttribute,(FormatSize($_.Size))
    Start-BitsTransfer -Source $sourceUrl -Destination $destinationFile
    $downloadedSizeBytes = $downloadedSizeBytes + $_.Size
}
Write-Host "Completed."