# run_daily.ps1 - FIXED VERSION
$MODEL = "C:\Users\austi\OneDrive\Desktop\mlb_complete_package\mlb_betting_model"
$DASH  = "C:\Users\austi\OneDrive\Desktop\mlb_complete_package\mlb_dashboard"
$DATE  = Get-Date -Format "yyyy-MM-dd"
$TIME  = Get-Date -Format "HH:mm"

# This script only ever wrote to the console, so a scheduled run left no
# evidence behind. Mirror everything to a dated log like run_refresh does.
$LOGDIR  = "$DASH\logs"
$LOGFILE = "$LOGDIR\daily_$(Get-Date -Format 'yyyy-MM-dd').log"
New-Item -ItemType Directory -Force -Path $LOGDIR | Out-Null

function Log($msg) {
    $line = "[" + (Get-Date -Format "HH:mm:ss") + "] $msg"
    Write-Host $line
    Add-Content -Path $LOGFILE -Value $line -Encoding utf8
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

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  MLB Edge - $DATE" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] Refreshing 2026 team stats (offense/pitching)..." -ForegroundColor Yellow
Set-Location $MODEL
$yr = (Get-Date).Year
python mlbapi_team_stats.py --season $yr
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: team stats refresh failed - model will use last cached file" -ForegroundColor DarkYellow
}

Write-Host "[1/3] Running model..." -ForegroundColor Yellow
python main.py --mode today

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Model failed" -ForegroundColor Red
    exit 1
}

Write-Host "Model complete." -ForegroundColor Green
Write-Host ""

Write-Host "[2/3] Copying data files..." -ForegroundColor Yellow
Copy-Item "$MODEL\data\processed\picks_today.json"     "$DASH\data\processed\picks_today.json"     -Force
Copy-Item "$MODEL\data\processed\series_schedule.json" "$DASH\data\processed\series_schedule.json" -Force
Copy-Item "$MODEL\data\processed\pitcher_cards.json"   "$DASH\data\processed\pitcher_cards.json"   -Force
Copy-Item "$MODEL\data\processed\picks_history.json"   "$DASH\data\processed\picks_history.json"   -Force
Copy-Item "$MODEL\data\processed\nrfi_data.json"       "$DASH\data\processed\nrfi_data.json"       -Force
Copy-Item "$MODEL\data\processed\prop_picks_history.json" "$DASH\data\processed\prop_picks_history.json" -Force
Copy-Item "$MODEL\data\processed\strikeout_props.json"   "$DASH\data\processed\strikeout_props.json"   -Force -ErrorAction SilentlyContinue
Copy-Item "$MODEL\data\processed\bullpen_report.json"    "$DASH\data\processed\bullpen_report.json"    -Force -ErrorAction SilentlyContinue

Write-Host "Files copied." -ForegroundColor Green
Write-Host ""

Write-Host "[3/3] Pushing to GitHub..." -ForegroundColor Yellow
Set-Location $DASH

if ((Invoke-GitTimed -GitArgs @("checkout","main") -TimeoutSec 60) -ne 0) {
    Log "ERROR: could not switch to main - not pushing"; exit 1
}
if ((Invoke-GitTimed -GitArgs @("pull","origin","main") -TimeoutSec 120) -ne 0) {
    Log "WARNING: pull failed - continuing, push will reconcile or fail fast"
}
Invoke-GitTimed -GitArgs @("add","data/processed/*.json") -TimeoutSec 60 | Out-Null

$commitRc = Invoke-GitTimed -GitArgs @("commit","-m","picks $DATE $TIME") -TimeoutSec 60
if ($commitRc -ne 0) {
    Log "Nothing to commit (or commit failed, rc=$commitRc) - skipping push."
    exit 0
}

$pushRc = Invoke-GitTimed -GitArgs @("push","origin","main") -TimeoutSec 120
if ($pushRc -ne 0) {
    Log "Push rejected (rc=$pushRc) - rebasing and retrying once..."
    Invoke-GitTimed -GitArgs @("pull","--rebase","origin","main") -TimeoutSec 120 | Out-Null
    $pushRc = Invoke-GitTimed -GitArgs @("push","origin","main") -TimeoutSec 120
}

if ($pushRc -eq 0) {
    Write-Host ""
    Write-Host "Dashboard live in 60 seconds" -ForegroundColor Green
    Write-Host "https://mlb-bets26.pages.dev" -ForegroundColor Cyan
} else {
    # rc 124 means the hard timeout fired - the old hang would have started
    # here. Now a logged failure in seconds, not a 2h block.
    Log "ERROR: Push failed (rc=$pushRc)"
    exit 1
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Cyan
