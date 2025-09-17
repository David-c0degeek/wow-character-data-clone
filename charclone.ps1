[CmdletBinding(SupportsShouldProcess)]
param(
    # Root WoW install directory (contains _classic_era_, _classic_, _retail_)
    [string]$WowRoot = "C:\Program Files (x86)\World of Warcraft",

    # Extras
    [switch]$BackupTarget,
    [switch]$AlsoCopyAccountWide,
    [switch]$DryRun,
    [switch]$VerboseAccounts
)

# ---------- Helpers ----------
function Resolve-PathSafe { param([Parameter(Mandatory)][string]$Path) [System.IO.Path]::GetFullPath($Path) }
function Get-Dirs { param([string]$Path) if (Test-Path $Path) { (Get-ChildItem -Path $Path -Directory | Select-Object -ExpandProperty Name) } else { @() } }
function Confirm-YesNo($Message) { (Read-Host "$Message (y/n)") -eq 'y' }

function Truncate-Join {
    param([string[]]$Items,[int]$maxChars = 50)
    if (-not $Items -or $Items.Count -eq 0) { return "-" }
    $s = [string]::Join(", ", $Items)
    if ($s.Length -le $maxChars) { return $s }
    $out = ""
    foreach ($it in $Items) {
        if (($out.Length + $it.Length + 2) -gt $maxChars) { $out += "…" ; break }
        if ($out.Length -gt 0) { $out += ", " }
        $out += $it
    }
    return $out
}

function Build-AccountPreview {
    param([string]$AccountPath)
    $realmDirs = Get-ChildItem -Path $AccountPath -Directory | Where-Object { $_.Name -ne "SavedVariables" }
    if (-not $realmDirs) { return "(no realms)" }
    $parts = @()
    foreach ($realm in $realmDirs) {
        $chars = Get-Dirs $realm.FullName
        $charsStr = Truncate-Join -Items $chars -maxChars 40
        $parts += ("{0}: {1}" -f $realm.Name, $charsStr)
    }
    Truncate-Join -Items $parts -maxChars 90
}

function Pick-FromList {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][array]$Options,
        [string]$LabelProp = $null
    )
    if (-not $Options -or $Options.Count -eq 0) { throw "No options to select for $Title." }

    Write-Host "`n=== $Title ==="
    for ($i=0; $i -lt $Options.Count; $i++) {
        $label = if ($LabelProp) { $Options[$i].$LabelProp } else { $Options[$i].ToString() }
        Write-Host ("[{0}] {1}" -f ($i+1), $label)
    }

    while ($true) {
        $raw = (Read-Host "Select [1-$($Options.Count)] (or 'q' to cancel)").Trim()
        if ($raw -eq '' ) { continue }
        if ($raw -match '^[qQ]$') { throw "Cancelled by user." }

        # robust numeric parse
        $idx = 0
        if (-not [int]::TryParse($raw, [ref]$idx)) { Write-Host "Please enter a number between 1 and $($Options.Count)."; continue }
        if ($idx -lt 1 -or $idx -gt $Options.Count) { Write-Host "Out of range."; continue }

        return $Options[$idx-1]
    }
}

# Clear screen before each picker for clarity
function Pick {
    param([string]$Title,[array]$Options,[string]$LabelProp)
    Clear-Host
    return Pick-FromList -Title $Title -Options $Options -LabelProp $LabelProp
}

# ---------- Auto-detect WoW branch ----------
$branches = @("_classic_era_","_classic_","_retail_") # priority order
$EraRoot = $null
foreach ($b in $branches) {
    $p = Join-Path $WowRoot $b
    if (Test-Path $p) { $EraRoot = Resolve-PathSafe $p; break }
}
if (-not $EraRoot) { throw "Could not find any of: $($branches -join ', ') under $WowRoot" }
Write-Host "Using branch: $EraRoot"

$WtfRoot      = Resolve-PathSafe (Join-Path $EraRoot "WTF")
$AccountsRoot = Resolve-PathSafe (Join-Path $WtfRoot "Account")
if (-not (Test-Path $AccountsRoot)) { throw "Not found: $AccountsRoot  (Check WowRoot / install.)" }

# ---------- Accounts list (filter junk) ----------
# Keep folders that look like WoW license IDs (e.g., 53135513#1) and ignore 'SavedVariables'
$accountDirs = Get-ChildItem -Path $AccountsRoot -Directory | Where-Object {
    $_.Name -ne "SavedVariables" -and ($_.Name -match '^\d+(#\d+)?$' -or $_.Name -match '#')
}
if (-not $accountDirs) { throw "No account folders found under $AccountsRoot" }

$accountOptions = foreach ($acc in $accountDirs) {
    $prev = Build-AccountPreview -AccountPath $acc.FullName
    $disp = if ([string]::IsNullOrWhiteSpace($prev)) { "no realms" } else { $prev }
    [pscustomobject]@{
        Name  = $acc.Name
        Path  = $acc.FullName
        Label = "{0}  ({1})" -f $acc.Name, $disp
    }
}

if ($VerboseAccounts) {
    Write-Host "`n--- Full WTF\Account tree ---"
    foreach ($a in $accountOptions) {
        Write-Host "Account: $($a.Name)"
        Get-ChildItem -Path $a.Path -Directory | Where-Object { $_.Name -ne "SavedVariables" } | ForEach-Object {
            Write-Host "  Realm: $($_.Name)"
            Get-ChildItem -Path $_.FullName -Directory | ForEach-Object { Write-Host "    Char: $($_.Name)" }
        }
    }
    Write-Host "--------------------------------`n"
}

# ---------- Pick SOURCE ----------
$srcAccObj      = Pick -Title "Pick SOURCE Account" -Options $accountOptions -LabelProp "Label"
Write-Host "Chosen SOURCE Account: $($srcAccObj.Name)"

$srcRealmList   = Get-Dirs $srcAccObj.Path | Where-Object { $_ -ne "SavedVariables" }
if (-not $srcRealmList) { throw "No realms in $($srcAccObj.Path)" }
$srcRealm       = Pick -Title "Pick SOURCE Realm" -Options $srcRealmList
Write-Host "Chosen SOURCE Realm: $srcRealm"

$srcRealmRoot   = Join-Path $srcAccObj.Path $srcRealm
$srcChars       = Get-Dirs $srcRealmRoot
if (-not $srcChars) { throw "No characters in $srcRealmRoot" }
$srcChar        = Pick -Title "Pick SOURCE Character" -Options $srcChars
Write-Host "Chosen SOURCE Character: $srcChar"
$srcCharPath    = Join-Path $srcRealmRoot $srcChar

# ---------- Pick TARGET ----------
$tgtAccObj      = Pick -Title "Pick TARGET Account" -Options $accountOptions -LabelProp "Label"
Write-Host "Chosen TARGET Account: $($tgtAccObj.Name)"

$tgtRealmList   = Get-Dirs $tgtAccObj.Path | Where-Object { $_ -ne "SavedVariables" }
if (-not $tgtRealmList) { throw "No realms in $($tgtAccObj.Path)" }
$tgtRealm       = Pick -Title "Pick TARGET Realm" -Options $tgtRealmList
Write-Host "Chosen TARGET Realm: $tgtRealm"

$tgtRealmRoot   = Join-Path $tgtAccObj.Path $tgtRealm
$tgtCharsRaw    = Get-Dirs $tgtRealmRoot
$tgtOptions     = @()
if ($tgtCharsRaw) {
    # exclude identical source toon only if same account+realm
    $tgtOptions += ($tgtCharsRaw | Where-Object { $_ -ne $srcChar -or $srcRealm -ne $tgtRealm -or $srcAccObj.Name -ne $tgtAccObj.Name })
}
$tgtOptions    += "[Create new character folder]"
$tgtPick        = Pick -Title "Pick TARGET Character" -Options $tgtOptions

if ($tgtPick -eq "[Create new character folder]") {
    do { $tgtChar = (Read-Host "Enter NEW target character name (exact in-game name)").Trim() }
    while ([string]::IsNullOrWhiteSpace($tgtChar))
} else {
    $tgtChar = $tgtPick
}
Write-Host "Chosen TARGET Character: $tgtChar"
$tgtCharPath = Join-Path $tgtRealmRoot $tgtChar

# ---------- Summary & confirm ----------
Write-Host "`n--- SUMMARY ---"
Write-Host "SOURCE: $($srcAccObj.Name)  | $srcRealm  | $srcChar"
Write-Host "TARGET: $($tgtAccObj.Name)  | $tgtRealm  | $tgtChar"
Write-Host "From:   $srcCharPath"
Write-Host "To:     $tgtCharPath"
if (-not (Confirm-YesNo "Proceed with clone?")) { Write-Host "Cancelled."; exit }

# ---------- Validate & prep ----------
foreach ($p in @($EraRoot,$WtfRoot,$AccountsRoot,$srcAccObj.Path,$srcRealmRoot,$srcCharPath)) {
    if (-not (Test-Path $p)) { throw "Required path not found: $p" }
}
if (-not (Test-Path $tgtCharPath)) {
    Write-Host "Creating target character folder: $tgtCharPath"
    if (-not $DryRun) { New-Item -ItemType Directory -Path $tgtCharPath | Out-Null }
}

# Optional backup
if ($BackupTarget -and (Test-Path $tgtCharPath) -and (Get-ChildItem -Path $tgtCharPath -Force | Where-Object { -not $_.PSIsContainer -or (Get-ChildItem $_.FullName -ErrorAction SilentlyContinue) })) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir = Join-Path $tgtAccObj.Path "_Backups"
    if (-not (Test-Path $backupDir) -and -not $DryRun) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
    $zipName = "${tgtRealm}_${tgtChar}_backup_${timestamp}.zip"
    $zipPath = Join-Path $backupDir $zipName
    Write-Host "Backing up TARGET to: $zipPath"
    if (-not $DryRun) {
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        Compress-Archive -Path (Join-Path $tgtCharPath "*") -DestinationPath $zipPath -Force
    }
}

# ---------- Copy per-character ----------
Write-Host "Cloning per-character settings..."
if ($DryRun) {
    Write-Host "[DryRun] Would copy (robocopy) $srcCharPath -> $tgtCharPath"
} else {
    # /E recurse incl. empty dirs, /XO skip older, quiet logs
    robocopy $srcCharPath $tgtCharPath /E /XO /NFL /NDL /NJH /NJS /NP | Out-Null
}

# Ensure key files present
$perCharItems = @(
    "bindings-cache.wtf","macros-cache.txt","chat-cache.txt",
    "config-cache.wtf","layout-local.txt","AddOns.txt","SavedVariables"
)
foreach ($item in $perCharItems) {
    $src = Join-Path $srcCharPath $item
    $dst = Join-Path $tgtCharPath $item
    if (Test-Path $src) {
        if ($DryRun) { Write-Host "[DryRun] Ensure copy: $src -> $dst" }
        else {
            if (Test-Path $src -PathType Container) { robocopy $src $dst /E /XO /NFL /NDL /NJH /NJS /NP | Out-Null }
            else { Copy-Item -Path $src -Destination $dst -Force }
        }
    }
}

# ---------- Optional account-wide ----------
if ($AlsoCopyAccountWide) {
    Write-Host "`n[AlsoCopyAccountWide] WARNING: affects ALL characters on the TARGET account."
    if (Confirm-YesNo "Copy source account-wide bindings/macros/global SavedVariables to TARGET account?") {
        $srcAccBindings = Join-Path $srcAccObj.Path "bindings-cache.wtf"
        $srcAccMacros   = Join-Path $srcAccObj.Path "macros-cache.txt"
        $srcAccSV       = Join-Path $srcAccObj.Path "SavedVariables"

        $tgtAccBindings = Join-Path $tgtAccObj.Path "bindings-cache.wtf"
        $tgtAccMacros   = Join-Path $tgtAccObj.Path "macros-cache.txt"
        $tgtAccSV       = Join-Path $tgtAccObj.Path "SavedVariables"

        foreach ($pair in @(@($srcAccBindings,$tgtAccBindings), @($srcAccMacros,$tgtAccMacros))) {
            $s,$d = $pair
            if (Test-Path $s) {
                if ($DryRun) { Write-Host "[DryRun] Copy: $s -> $d" }
                else { Copy-Item -Path $s -Destination $d -Force }
            }
        }
        if (Test-Path $srcAccSV) {
            if ($DryRun) { Write-Host "[DryRun] Copy global SavedVariables: $srcAccSV -> $tgtAccSV" }
            else { robocopy $srcAccSV $tgtAccSV /E /XO /NFL /NDL /NJH /NJS /NP | Out-Null }
        }
    } else {
        Write-Host "Skipped account-wide copy."
    }
}

Write-Host "`nDone."
Write-Host "Per-character: WTF\\Account\\<Account>\\<Realm>\\<Char>\\bindings-cache.wtf (and SavedVariables)"
Write-Host "Account-wide:  WTF\\Account\\<Account>\\bindings-cache.wtf | macros-cache.txt | SavedVariables\\*.lua"
