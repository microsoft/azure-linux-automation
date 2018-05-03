$xmlText = "<Tests>"
$xmlText += Get-Content .\*.xml
$xmlText += "</Tests>"
$TestToRegionMapping = [xml](Get-Content ..\TestToRegionMapping.xml)

$xmlData = [xml]$xmlText

#Get Unique Platforms
$Platforms = $xmlData.Tests.test.Platform  | Sort-Object | Get-Unique
Write-Host $Platforms
$Categories = $xmlData.Tests.test.Category | Sort-Object | Get-Unique
Write-Host $Categories
$Areas =$xmlData.Tests.test.Area | Sort-Object | Get-Unique
Write-Host $Areas
$Tags =$xmlData.Tests.test.Tags.Split(",") | Sort-Object | Get-Unique
Write-Host $Tags
$TestIDs = $xmlData.Tests.test.TestID | Sort-Object | Get-Unique
Write-Host $TestIDs


$jenkinsFile =  "platform`tcategory`tarea`tregion`n"
#Generate Jenkins File
foreach ( $platform in $Platforms )
{
    $Categories = ($xmlData.Tests.test | Where-Object { $_.Platform -eq "$platform" }).Category
    foreach ( $category in $Categories)
    {
        $Regions =$TestToRegionMapping.enabledRegions.global.Split(",")
        $Areas = ($xmlData.Tests.test | Where-Object { $_.Platform -eq "$platform" } | Where-Object { $_.Category -eq "$category" }).Area
        if ( $TestToRegionMapping.enabledRegions.Category.$category )
        {
            $Regions = ($TestToRegionMapping.enabledRegions.Category.$category).Split(",")
        }
        foreach ($area in $Areas)
        {
            if ( [string]::IsNullOrEmpty($TestToRegionMapping.enabledRegions.Category.$category))
            {
                if ($TestToRegionMapping.enabledRegions.Area.$area)
                {
                    $Regions = ($TestToRegionMapping.enabledRegions.Area.$area).Split(",")
                }
            }
            else
            {
                $Regions = ($TestToRegionMapping.enabledRegions.Category.$category).Split(",")
                if ( $TestToRegionMapping.enabledRegions.Area.$area )
                {
                    $tempRegions = @()
                    $AreaRegions = ($TestToRegionMapping.enabledRegions.Area.$area).Split(",")
                    foreach ( $arearegion in $AreaRegions )
                    {
                        if ( $Regions.Contains($arearegion))
                        {
                            $tempRegions += $arearegion
                        }
                    }
                    if ( $tempRegions.Count -ge 1)
                    {
                        $Regions = $tempRegions
                    }
                    else
                    {
                        $Regions = "no_region_available"
                    }
                }
            }
            foreach ( $region in $Regions)
            {
                $jenkinsFile += "$platform`t$category`t$area`t$region`n"
            }
        }
        if ( $(($Areas | Get-Unique).Count) -gt 1)
        {
            foreach ( $region in $Regions)
            {
                $jenkinsFile += "$platform`t$category`tAll`t$region`n"
            }
        }
    }
    if ( $(($Categories | Get-Unique).Count) -gt 1)
    {
        foreach ( $region in $Regions)
        {
            $jenkinsFile += "$platform`tAll`tAll`t$region`n"
        }
    }
}
Set-Content -Value $jenkinsFile -Path .\jenkinsfile -Force
(Get-Content .\jenkinsfile) | Where-Object {$_.trim() -ne "" } | set-content .\jenkinsfile

$tagsFile = "tag`tregion`n"
foreach ( $tag in $Tags)
{
    $Regions =$TestToRegionMapping.enabledRegions.global.Split(",")
    if ( $tag )
    {
        if ( $TestToRegionMapping.enabledRegions.Tag.$tag )
        {
            $Regions = ($TestToRegionMapping.enabledRegions.Tag.$tag).Split(",")
        }
        foreach ( $region in $Regions)
        {
            $tagsFile += "$tag`t$region`n"
        }
    }
}
Set-Content -Value $tagsFile -Path .\tagsFile -Force
(Get-Content .\tagsFile) | Where-Object {$_.trim() -ne "" } | set-content .\tagsFile

$testidFile = "testid`tregion`n"
foreach ( $testid in $TestIDs)
{
    $Regions =$TestToRegionMapping.enabledRegions.global.Split(",")
    if ( $TestToRegionMapping.enabledRegions.TestID.$testid )
    {
        $Regions = ($TestToRegionMapping.enabledRegions.TestID.$testid).Split(",")
    }
    if ( $testid )
    {
        foreach ( $region in $Regions)
        {
            $testidFile += "$testid`t$region`n"
        }
    }
}
Set-Content -Value $testidFile -Path .\testidFile -Force
(Get-Content .\testidFile) | Where-Object {$_.trim() -ne "" } | set-content .\testidFile