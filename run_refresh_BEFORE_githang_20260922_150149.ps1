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
git fetch origin main 2>&1 | Out-Null

foreach ($f in $files) {
    if (Test-Path "$dst\$f") {
        git add -f "data\processed\$f" 2>&1 | Out-Null
    }
}

$TS = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -m "refresh $DATE $TIME" 2>&1 | Tee-Object -Append -FilePath $LOGFILE

git push origin main 2>&1 | Tee-Object -Append -FilePath $LOGFILE
if ($LASTEXITCODE -ne 0) {
    Log "Push rejected - rebasing..."
    git pull --rebase origin main 2>&1 | Out-Null
    git push origin main 2>&1 | Tee-Object -Append -FilePath $LOGFILE
}

if ($LASTEXITCODE -eq 0) {
    Log "Dashboard updated: https://mlb-bets26.pages.dev"
} else {
    Log "ERROR: Push failed"
}
Log "Done!"
