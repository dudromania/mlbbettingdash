# run_daily.ps1
# Usage: powershell -ExecutionPolicy Bypass -File run_daily.ps1

$MODEL = "C:\Users\austi\OneDrive\Desktop\mlb_complete_package\mlb_betting_model"
$DASH  = "C:\Users\austi\OneDrive\Desktop\mlb_complete_package\mlb_dashboard"
$DATE  = Get-Date -Format "yyyy-MM-dd"

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
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "Model complete." -ForegroundColor Green

Write-Host ""
Write-Host "[2/3] Copying data files..." -ForegroundColor Yellow
$src = "$MODEL\data\processed"
$dst = "$DASH\data\processed"

Copy-Item "$src\picks_today.json"     "$dst\picks_today.json"     -Force
Copy-Item "$src\series_schedule.json" "$dst\series_schedule.json" -Force
Copy-Item "$src\pitcher_cards.json"   "$dst\pitcher_cards.json"   -Force
Copy-Item "$src\picks_history.json"   "$dst\picks_history.json"   -Force
Copy-Item "$src\nrfi_data.json" "$dst\nrfi_data.json" -Force
Write-Host "Files copied." -ForegroundColor Green

Write-Host ""
Write-Host "[3/3] Pushing to GitHub..." -ForegroundColor Yellow
Set-Location $DASH

git add data\processed\picks_today.json
git add data\processed\series_schedule.json
git add data\processed\pitcher_cards.json
git add data\processed\picks_history.json
git add data\processed\nrfi_data.json

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Dashboard live in 60 seconds" -ForegroundColor Green
    Write-Host "https://mlb-bets26.pages.dev" -ForegroundColor Cyan
} else {
    Write-Host "Push failed - trying rebase..." -ForegroundColor Yellow
    git pull origin main --rebase
    git push origin main
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Cyan
Write-Host ""
