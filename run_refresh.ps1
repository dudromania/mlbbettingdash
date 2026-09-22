# run_refresh.ps1
$MODEL   = "C:\Users\austi\OneDrive\Desktop\mlb_complete_package\mlb_betting_model"
$DASH    = "C:\Users\austi\OneDrive\Desktop\mlb_complete_package\mlb_dashboard"
$DATE    = Get-Date -Format "yyyy-MM-dd"
$TIME    = Get-Date -Format "HHmm"
$LOGFILE = "$DASH\logs\refresh_$DATE.log"

New-Item -ItemType Directory -Force -Path "$DASH\logs" | Out-Null

function Log($msg) {
    $ts   = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] $msg"
    Write-Host $line
    Add-Content -Path $LOGFILE -Value $line
}

# ---------------------------------------------------------------------------
# GIT HANG GUARDS
# ---------------------------------------------------------------------------
# These jobs were not failing, they were hanging. git push asked for a
# credential no headless task could answer and blocked forever; Task Scheduler
# killed the PowerShell parent at its time limit but the git child survived,
# leaving one stuck git.exe per run (116 of them had piled up by 9/22). With
# MultipleInstances=IgnoreNew, a run still hanging when the next one was due
# made that next run get skipped outright.
#
# Two layers so this cannot recur:
#   1. GIT_TERMINAL_PROMPT=0 / GCM_INTERACTIVE=never - git returns an error
#      instead of waiting for input that will never come.
#   2. Invoke-GitTimed - a hard wall-clock cap that kills the whole git process
#      tree (git spawns credential-helper children) if it ever blocks anyway.
$env:GIT_TERMINAL_PROMPT = "0"
$env:GCM_INTERACTIVE     = "never"

function Invoke-GitTimed {
    param(
        [Parameter(Mandatory=$true)][string[]]$GitArgs,
        [int]$TimeoutSec = 120
    )
    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath "git.exe" -ArgumentList $GitArgs -NoNewWindow -PassThru `
                           -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            Log "  git $($GitArgs -join ' ') exceeded ${TimeoutSec}s - killing process tree"
            # /T kills the credential-helper children too, which is what was
            # surviving and accumulating before.
            & taskkill.exe /T /F /PID $p.Id 2>&1 | Out-Null
            return 124
        }
        foreach ($f in @($outFile, $errFile)) {
            Get-Content $f -ErrorAction SilentlyContinue |
                Where-Object { $_ -ne "" } | ForEach-Object { Log "  $_" }
        }
        return $p.ExitCode
    } catch {
        Log "  git $($GitArgs -join ' ') failed to start: $($_.Exception.Message)"
        return 125
    } finally {
        Remove-Item $outFile, $errFile -Force -ErrorAction SilentlyContinue
    }
}

Log "============================================"
Log "  MLB Edge Refresh - $DATE $TIME"
Log "============================================"

# Clear stale odds cache so model fetches fresh lines
Remove-Item "$MODEL\data\odds\odds_$DATE.json" -ErrorAction SilentlyContinue
# Clear K lines cache so fresh prop lines are fetched
Remove-Item "$MODEL\data\processed\.k_lines_cache_$DATE.json" -ErrorAction SilentlyContinue
Log "Cleared stale caches."

# Force Python to use UTF-8 encoding on Windows
$env:PYTHONUTF8 = "1"

Log "[1/2] Running model + export..."
Set-Location $MODEL
python main.py --mode today 2>&1 | Tee-Object -Append -FilePath $LOGFILE
if ($LASTEXITCODE -ne 0) {
    Log "ERROR: Model failed"
    exit 1
}
Log "Model + export complete."

Log "[2/2] Pushing to GitHub..."
$src = "$MODEL\data\processed"
$dst = "$DASH\data\processed"
New-Item -ItemType Directory -Force -Path $dst | Out-Null

$files = @(
    "picks_today.json",
    "series_schedule.json",
    "pitcher_cards.json",
    "picks_history.json",
    "nrfi_data.json",
    "live_scores.json",
    "strikeout_props.json",
    "bullpen_report.json",
    "prop_picks_history.json"
)

foreach ($f in $files) {
    if (Test-Path "$src\$f") {
        Copy-Item "$src\$f" "$dst\$f" -Force
        Log "  Copied $f"
    }
}

Set-Location $DASH
if ((Invoke-GitTimed -GitArgs @("fetch","origin","main") -TimeoutSec 60) -ne 0) {
    Log "WARNING: fetch failed - continuing, push will reconcile or fail fast"
}

foreach ($f in $files) {
    if (Test-Path "$dst\$f") {
        Invoke-GitTimed -GitArgs @("add","-f","data/processed/$f") -TimeoutSec 30 | Out-Null
    }
}

$TS = Get-Date -Format "yyyy-MM-dd HH:mm"
$commitRc = Invoke-GitTimed -GitArgs @("commit","-m","refresh $DATE $TIME") -TimeoutSec 60
if ($commitRc -ne 0) {
    Log "Nothing to commit (or commit failed, rc=$commitRc) - skipping push."
    Log "Done!"
    exit 0
}

$pushRc = Invoke-GitTimed -GitArgs @("push","origin","main") -TimeoutSec 120
if ($pushRc -ne 0) {
    Log "Push rejected (rc=$pushRc) - rebasing and retrying once..."
    Invoke-GitTimed -GitArgs @("pull","--rebase","origin","main") -TimeoutSec 120 | Out-Null
    $pushRc = Invoke-GitTimed -GitArgs @("push","origin","main") -TimeoutSec 120
}

if ($pushRc -eq 0) {
    Log "Dashboard updated: https://mlb-bets26.pages.dev"
    Log "Done!"
    exit 0
} else {
    # rc 124 means the hard timeout fired, i.e. the old hang would have
    # started here. It is now a logged failure in seconds, not a 2h block.
    Log "ERROR: Push failed (rc=$pushRc)"
    Log "Done!"
    exit 1
}
