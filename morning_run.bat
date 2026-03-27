@echo off
REM morning_run.bat
REM Runs the MLB model and pushes fresh data to GitHub Pages
REM Schedule this with Task Scheduler at 8:30 AM daily

echo.
echo ============================================================
echo   MLB Edge — Daily Run %date%
echo ============================================================

REM ── Step 1: Run the model ────────────────────────────────────
cd /d C:\Users\austi\OneDrive\Desktop\betting_model
echo.
echo [1/3] Running model...
python main.py --mode today
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Model run failed
    pause
    exit /b 1
)
echo Model complete.

REM ── Step 2: Copy JSON files to dashboard repo ────────────────
echo.
echo [2/3] Copying data files...
set DASH=C:\Users\austi\OneDrive\Desktop\mlb_dashboard\data\processed
if not exist "%DASH%" mkdir "%DASH%"

copy "data\processed\picks_today.json"     "%DASH%\picks_today.json"     /Y
copy "data\processed\series_schedule.json" "%DASH%\series_schedule.json" /Y
copy "data\processed\pitcher_cards.json"   "%DASH%\pitcher_cards.json"   /Y
copy "data\processed\picks_history.json"   "%DASH%\picks_history.json"   /Y
echo Files copied.

REM ── Step 3: Push to GitHub ───────────────────────────────────
echo.
echo [3/3] Pushing to GitHub Pages...
cd /d C:\Users\austi\OneDrive\Desktop\mlb_dashboard
git add data/processed/*.json
git commit -m "picks %date:~10,4%-%date:~4,2%-%date:~7,2%"
git push origin main
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Git push failed - check your connection
) else (
    echo Dashboard updated. Live in ~30 seconds.
)

echo.
echo ============================================================
echo   Done! Check your dashboard at:
echo   https://YOUR-USERNAME.github.io/mlb-dashboard/
echo ============================================================
echo.
