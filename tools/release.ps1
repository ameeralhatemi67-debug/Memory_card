<#
.SYNOPSIS
  Builds the release APK and prepares, or publishes, a GitHub release.

.DESCRIPTION
  Reads the version from app\pubspec.yaml, builds app-release.apk, and writes
    release\MemoryCard.apk          the file to attach to the release (constant name, so the
                                    README's .../releases/latest/download/MemoryCard.apk link always works)
    release\MemoryCard-<ver>.apk    the same file with the version in its name, for your own archive
    release\MemoryCard.apk.sha256   its SHA-256
  Then, if the GitHub CLI (gh) is installed and signed in, creates the release v<ver> with the notes from
  docs\releases\<ver>.md (or -NotesFile). Without gh it prints how to upload the file by hand.

  The release folder and *.apk are gitignored: APKs are 150 MB and live on GitHub Releases, not in git.

.EXAMPLE
  tools\release.ps1                # build, name, hash; create the release when gh is available
  tools\release.ps1 -SkipBuild     # reuse the APK that is already in app\build\app\outputs\flutter-apk
  tools\release.ps1 -NoPublish     # stop after release\MemoryCard.apk and its SHA-256
  tools\release.ps1 -ApkPath C:\x\app-release.apk   # package an APK built elsewhere (implies -SkipBuild)
#>
param(
  [switch]$SkipBuild,
  [switch]$NoPublish,
  [string]$NotesFile,
  [string]$ApkPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$app = Join-Path $root 'app'

$pubspec = Get-Content (Join-Path $app 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)') { throw 'No "version: x.y.z+n" line in app\pubspec.yaml' }
$version = $Matches[1]
$buildNumber = $Matches[2]
Write-Host "Memory Card $version (build $buildNumber)"

# A release should be what is on GitHub: warn when the checkout has unpushed or uncommitted work.
$dirty = git -C $root status --porcelain -- app content fonts
if ($dirty) { Write-Warning "Uncommitted changes in app, content or fonts: the APK will not match the repository.`n$dirty" }
$ahead = git -C $root rev-list --count '@{upstream}..HEAD' 2>$null
if ($ahead -and [int]$ahead -gt 0) { Write-Warning "$ahead commit(s) are not pushed yet: push before publishing the release." }

if ($ApkPath) { $SkipBuild = $true }
if (-not $SkipBuild) {
  Push-Location $app
  try {
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed (exit $LASTEXITCODE)" }
  } finally { Pop-Location }
}

$built = if ($ApkPath) { $ApkPath } else { Join-Path $app 'build\app\outputs\flutter-apk\app-release.apk' }
if (-not (Test-Path $built)) { throw "No APK at $built. Build it first (drop -SkipBuild)." }

$out = Join-Path $root 'release'
New-Item -ItemType Directory -Force $out | Out-Null
$apk = Join-Path $out 'MemoryCard.apk'
Copy-Item $built $apk -Force
Copy-Item $built (Join-Path $out "MemoryCard-$version.apk") -Force

$sha = (Get-FileHash $apk -Algorithm SHA256).Hash.ToLower()
$shaFile = "$apk.sha256"
"$sha  MemoryCard.apk" | Set-Content -Encoding ascii $shaFile
$mb = [math]::Round((Get-Item $apk).Length / 1e6, 1)   # decimal MB, the way browsers and phones show it
Write-Host "$apk  ($mb MB)"
Write-Host "SHA-256 $sha"

# Release notes: what changed, then the same install steps the README gives.
# The app's update card shows the first three "- " bullets of the notes: one short sentence each, the point first
# (about 70 characters). Start the notes with "Important:" for an urgent fix; the card then says so.
if (-not $NotesFile) { $NotesFile = Join-Path $root "docs\releases\$version.md" }
$changes = if (Test-Path $NotesFile) { (Get-Content $NotesFile -Raw).TrimEnd() } else { "Memory Card $version." }
$notes = @"
$changes

## Install

1. On your Android phone, download **MemoryCard.apk** below (about $mb MB).
2. Open it. If Android says it may not install unknown apps from this source, tap **Settings**, switch on **Allow from this source**, and go back.
3. Tap **Install**. If Play Protect warns about an unrecognised developer, tap **More details**, then **Install anyway**.

An update installs over the old version and keeps your cards. Full guide and fixes for common problems: https://github.com/ameeralhatemi67-debug/Memory_card#install-it-on-your-android-phone

SHA-256 of ``MemoryCard.apk``: ``$sha``
"@
$notesPath = Join-Path $out "notes-$version.md"
$notes | Set-Content -Encoding utf8 $notesPath

if ($NoPublish) { Write-Host "Stopped before publishing (-NoPublish). Release notes: $notesPath"; return }

$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
  gh auth status *> $null
  if ($LASTEXITCODE -eq 0) {
    gh release create "v$version" $apk $shaFile --title "Memory Card $version" --notes-file $notesPath --latest
    if ($LASTEXITCODE -ne 0) { throw "gh release create failed (exit $LASTEXITCODE)" }
    Write-Host "Published: https://github.com/ameeralhatemi67-debug/Memory_card/releases/tag/v$version"
    return
  }
  Write-Warning 'gh is installed but not signed in: run "gh auth login" and run this script again.'
}

Write-Host @"

Upload by hand:
  1. https://github.com/ameeralhatemi67-debug/Memory_card/releases/new
  2. Tag: v$version (create it on publish, target main). Title: Memory Card $version.
  3. Paste the text of $notesPath as the description.
  4. Drag in $apk and $shaFile, then Publish release.
"@
