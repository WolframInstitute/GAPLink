$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Version = "4.16.1"
$SystemID = "Windows-x86-64"
$InstallerName = "gap-$Version-x86_64.exe"
$InstallerHash = "b26346c3febb31f3e44600973207a37f50dd36c65cd22668264d55617b43081a"
$CoreHash = "b4433a540a2f746d14b1645a0e95b3d499afb180aa421ebfd62b427f2b0cf74f"
$PackagesHash = "fb9350f66ec4febf09858f5475abe31dd91a97e827477e1da9eb393d07f311a8"
$ReleaseURL = "https://github.com/gap-system/gap/releases/download/v$Version"
$RepositoryRoot = Split-Path $PSScriptRoot -Parent
$SourceDirectory = Join-Path $RepositoryRoot "build/runtime-sources"
$OutputDirectory = Join-Path $RepositoryRoot "build/runtimes/$SystemID"
$Installer = Join-Path $SourceDirectory $InstallerName

if (Test-Path $OutputDirectory) {
    throw "Run make clean before rebuilding $SystemID"
}

New-Item -ItemType Directory -Force $SourceDirectory, $OutputDirectory | Out-Null
if (-not (Test-Path $Installer)) {
    Invoke-WebRequest "$ReleaseURL/$InstallerName" -OutFile "$Installer.part"
    Move-Item "$Installer.part" $Installer
}

$Hash = (Get-FileHash $Installer -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Hash -ne $InstallerHash) {
    throw "Bad checksum: $InstallerName"
}

$TemporaryRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$InstallDirectory = Join-Path $TemporaryRoot "gaplink-$([Guid]::NewGuid())"
$Runtime = Join-Path $OutputDirectory "runtime"
$RequiredPackages = @("gapdoc", "perfgrp", "primgrp", "smallgrp", "transgrp")

try {
    $Arguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER /DIR=`"$InstallDirectory`""
    $Process = Start-Process $Installer -ArgumentList $Arguments -Wait -PassThru
    if ($Process.ExitCode -ne 0) {
        throw "GAP installer failed with exit code $($Process.ExitCode)"
    }

    $GapRoot = Join-Path $InstallDirectory "runtime/opt/gap-$Version"
    $GapExecutable = Join-Path $GapRoot "gap.exe"
    if (-not (Test-Path $GapExecutable)) {
        throw "GAP executable was not installed"
    }

    Get-ChildItem (Join-Path $GapRoot "pkg") -Directory |
        Where-Object { $RequiredPackages -notcontains $_.Name.ToLowerInvariant() } |
        Remove-Item -Recurse -Force
    Copy-Item $InstallDirectory $Runtime -Recurse
    Remove-Item (Join-Path $Runtime "unins*") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $Runtime "gap-mintty.bat") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $Runtime "gapicon.ico") -Force -ErrorAction SilentlyContinue

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
