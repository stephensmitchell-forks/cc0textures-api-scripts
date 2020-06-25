Param(
    [String]$query,
    [ValidateSet("PhotoTexturePBR","PhotoTexturePlain","SBSAR","3DModel")][String]$type,
    [ValidateSet("Alphabet","Popular","Latest")][String]$sort,
    [String]$id
)

$apiUrl = "https://cc0textures.com/api/v1/downloads_csv"
$attributeRegex = [RegEx]("")
$filetypeRegex = [RegEx]("")
$downloadDirectory = "$PSScriptRoot\Downloads"

$getParameters = @{
    q  = $query
    type = $type
    sort = $sort
    id = $id
}

$webRequest = Invoke-WebRequest -Uri "$apiUrl" -Body $getParameters
$apiOutput = ($webRequest.Content | ConvertFrom-Csv)

$apiOutput.Count
pause

$apiOutput | Where-Object{ $_.DownloadAttribute -match $attributeRegex -and $_.Filetype -match $filetypeRegex } | ForEach-Object{

    $destinationDirectory = Join-Path -Path $downloadDirectory -ChildPath $_.AssetID
    $destinationFile = Join-Path -Path $destinationDirectory -ChildPath ("{0}_{1}.{2}" -f $_.AssetID,$_.DownloadAttribute,$_.Filetype)
    $sourceUrl = if($_.PrettyDownloadLink -eq ''){$_.RawDownloadLink}else{$_.PrettyDownloadLink}

    if(!(Test-Path $destinationDirectory)){
        New-Item -Path $destinationDirectory -ItemType "directory" | Out-Null
        write-host "Created directory: $destinationDirectory"
    }

    "{0}/{1} ({2} Bytes)" -f $_.AssetID,$_.DownloadAttribute,$_.Size
    Start-BitsTransfer -Source $sourceUrl -Destination $destinationFile
}