# run_daily.ps1 - FIXED VERSION
$MODEL = "C:\Users\austi\OneDrive\Desktop\mlb_complete_package\mlb_betting_model"
$DASH  = "C:\Users\austi\OneDrive\Desktop\mlb_complete_package\mlb_dashboard"
$DATE  = Get-Date -Format "yyyy-MM-dd"
$TIME  = Get-Date -Format "HH:mm"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  MLB Edge - $DATE" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] Running model..." -ForegroundColor Yellow
Set-Location $MODEL
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

Write-Host "Files copied." -ForegroundColor Green
Write-Host ""

Write-Host "[3/3] Pushing to GitHub..." -ForegroundColor Yellow
Set-Location $DASH

git checkout main
git pull origin main
git add data\processed\*.json
git commit -m "picks $DATE $TIME"
git push origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Dashboard live in 60 seconds" -ForegroundColor Green
    Write-Host "https://mlb-bets26.pages.dev" -ForegroundColor Cyan
} else {
    Write-Host "Push failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Cyan
