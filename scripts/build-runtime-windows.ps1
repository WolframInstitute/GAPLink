$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Version = "4.16.1"
$SystemID = "Windows-x86-64"
$InstallerName = "gap-$Version-x86_64.exe"
$PackagesName = "packages-required-v$Version.tar.gz"
$InstallerHash = "b26346c3febb31f3e44600973207a37f50dd36c65cd22668264d55617b43081a"
$CoreHash = "b4433a540a2f746d14b1645a0e95b3d499afb180aa421ebfd62b427f2b0cf74f"
$PackagesHash = "fb9350f66ec4febf09858f5475abe31dd91a97e827477e1da9eb393d07f311a8"
$ReleaseURL = "https://github.com/gap-system/gap/releases/download/v$Version"
$RepositoryRoot = Split-Path $PSScriptRoot -Parent
$SourceDirectory = Join-Path $RepositoryRoot "build/runtime-sources"
$OutputDirectory = Join-Path $RepositoryRoot "build/runtimes/$SystemID"

function Get-VerifiedFile($Name, $ExpectedHash) {
    $Path = Join-Path $SourceDirectory $Name
    if (-not (Test-Path $Path)) {
        Write-Host "Downloading $Name..."
        & curl.exe --fail --location --retry 3 --output "$Path.part" "$ReleaseURL/$Name"
        if ($LASTEXITCODE -ne 0) {
            throw "Could not download $Name"
        }
        Move-Item "$Path.part" $Path
    }
    if ((Get-FileHash $Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedHash) {
        throw "Bad checksum: $Name"
    }
    $Path
}

if (Test-Path $OutputDirectory) {
    throw "Run make clean before rebuilding $SystemID"
}

New-Item -ItemType Directory -Force $SourceDirectory | Out-Null
$Installer = Get-VerifiedFile $InstallerName $InstallerHash
$PackagesArchive = Get-VerifiedFile $PackagesName $PackagesHash

$TemporaryRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$InstallDirectory = Join-Path $TemporaryRoot "gaplink-$([Guid]::NewGuid())"
$InstallLog = "$InstallDirectory.log"
$Runtime = Join-Path $OutputDirectory "runtime"
$RequiredPackages = @("gapdoc", "perfgrp", "primgrp", "smallgrp", "transgrp")

try {
    Write-Host "Installing GAP..."
    $Arguments = @(
        "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/NOICONS",
        "/CURRENTUSER", "/DIR=$InstallDirectory", "/LOG=$InstallLog"
    )
    $Process = Start-Process $Installer -ArgumentList $Arguments -Wait -PassThru
    if ($Process.ExitCode -ne 0) {
        if (Test-Path $InstallLog) { Get-Content $InstallLog -Tail 80 }
        throw "GAP installer failed with exit code $($Process.ExitCode)"
    }

    $GapRoot = Join-Path $InstallDirectory "runtime/opt/gap-$Version"
    $GapExecutable = Join-Path $GapRoot "gap.exe"
    if (-not (Test-Path $GapExecutable)) {
        $GapExecutable = Get-ChildItem $InstallDirectory -Filter "gap.exe" -File -Recurse |
            Select-Object -First 1
        if ($null -eq $GapExecutable) {
            if (Test-Path $InstallLog) { Get-Content $InstallLog -Tail 80 }
            throw "GAP executable was not installed"
        }
        $GapRoot = $GapExecutable.DirectoryName
    }

    Write-Host "Copying runtime..."
    New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
    & robocopy $InstallDirectory $Runtime /E /XD (Join-Path $GapRoot "pkg") `
        /MT:8 /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -gt 7) {
        throw "Could not copy GAP runtime"
    }
    $RuntimeGapRoot = Join-Path $Runtime "runtime/opt/gap-$Version"
    $RuntimePackages = Join-Path $RuntimeGapRoot "pkg"
    New-Item -ItemType Directory -Force $RuntimePackages | Out-Null
    tar -xzf $PackagesArchive -C $RuntimePackages
    if ($LASTEXITCODE -ne 0) {
        throw "Could not extract required GAP packages"
    }
    foreach ($Package in $RequiredPackages) {
        if (-not (Test-Path (Join-Path $RuntimePackages $Package))) {
            throw "Required package is missing: $Package"
        }
    }
    Remove-Item (Join-Path $Runtime "unins*") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $Runtime "gap-mintty.bat") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $Runtime "gapicon.ico") -Force -ErrorAction SilentlyContinue

    Write-Host "Checking runtime..."
    $RuntimeGap = Join-Path $Runtime "gap.bat"
    if (-not (Test-Path $RuntimeGap)) {
        throw "GAP launcher was not copied"
    }
    $FoundVersion = (& $RuntimeGap -q -n -A -r --nointeract `
        -c 'Print(GAPInfo.Version,"\n");QUIT_GAP(0);').Trim()
    if ($LASTEXITCODE -ne 0 -or $FoundVersion -ne $Version) {
        throw "Built GAP returned version $FoundVersion"
    }
    & $RuntimeGap -q -n -A -r --nointeract `
        -c 'if LoadPackage("gapdoc")=fail then Error("gapdoc failed");fi;QUIT_GAP(0);'
    if ($LASTEXITCODE -ne 0) {
        throw "Required GAP package failed"
    }

    $Details = @(
        "GAP $Version"
        "System: $SystemID"
        "Installer: $ReleaseURL/$InstallerName"
        "Installer SHA-256: $InstallerHash"
        "Core source: $ReleaseURL/gap-$Version-core.tar.gz"
        "Core source SHA-256: $CoreHash"
        "Required packages: $ReleaseURL/packages-required-v$Version.tar.gz"
        "Required packages SHA-256: $PackagesHash"
    ) -join "`n"
    [IO.File]::WriteAllText(
        (Join-Path $Runtime "RUNTIME.txt"),
        "$Details`n",
        [Text.UTF8Encoding]::new($false)
    )
    $LicenseDirectory = Join-Path $Runtime "licenses"
    New-Item -ItemType Directory -Force $LicenseDirectory | Out-Null
    $Notice = @(
        "GAP license: runtime/opt/gap-$Version/LICENSE"
        "Cygwin notices: runtime/usr/share/doc"
        "Cygwin package list: runtime/etc/setup/installed.db"
    ) -join "`n"
    [IO.File]::WriteAllText(
        (Join-Path $LicenseDirectory "README.txt"),
        "$Notice`n",
        [Text.UTF8Encoding]::new($false)
    )

    Write-Host "Compressing runtime..."
    $ArchiveName = "GAPLink-runtime-$SystemID.tar.gz"
    $Archive = Join-Path $OutputDirectory $ArchiveName
    tar -czf $Archive -C $OutputDirectory runtime
    if ($LASTEXITCODE -ne 0) {
        throw "Could not create runtime archive"
    }
    $ArchiveHash = (Get-FileHash $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText(
        "$Archive.sha256",
        "$ArchiveHash  $ArchiveName`n",
        [Text.UTF8Encoding]::new($false)
    )
    Write-Host "OK: $Runtime | GAP $FoundVersion"
}
finally {
    $Uninstaller = Join-Path $InstallDirectory "unins000.exe"
    if (Test-Path $Uninstaller) {
        Start-Process $Uninstaller `
            -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
    }
    if (Test-Path $InstallDirectory) {
        Remove-Item $InstallDirectory -Recurse -Force
    }
}
