param(
    $directoryPath=".\scripts\package_building"
)
$debPackage = (Get-ChildItem -Path $directoryPath -Recurse | Where-Object { ($_.Name).EndsWith("amd64.deb") -and ($_.Name -inotmatch "-dbg_") -and ($_.Name -imatch "linux-image-") })
if ($debPackage.Count -eq 1)
{
    Write-Host "$($debPackage.FullName) -> .\testKernel.deb"
    Copy-Item -Path $debPackage.FullName -Destination .\testKernel.deb  -Force -Verbose
}

$rpmPackage = (Get-ChildItem -Path $directoryPath -Recurse | Where-Object { ($_.Name).EndsWith("x86_64.rpm") -and ($_.Name -inotmatch "devel")  -and ($_.Name -inotmatch "headers") -and ($_.Name -imatch "kernel-") })
if ($rpmPackage.Count -eq 1)
{
    Write-Host "$($rpmPackage.FullName) -> .\testKernel.rpm"
    Copy-Item -Path $rpmPackage.FullName -Destination .\testKernel.rpm  -Force -Verbose
}

