# MLB Edge Dashboard

Live MLB betting model output. Updates daily.

## Setup (one time)

### 1. Create GitHub repo
- Go to github.com → New repository
- Name it `mlb-dashboard`
- Set to **Public** (required for free GitHub Pages)
- Don't initialize with anything

### 2. Push this folder to GitHub
Open Command Prompt in this folder and run:
```
git init
git add .
git commit -m "initial"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/mlb-dashboard.git
git push -u origin main
```

### 3. Enable GitHub Pages
- Go to your repo on GitHub
- Settings → Pages
- Source: Deploy from branch → main → / (root)
- Save

Your dashboard will be live at:
`https://YOUR-USERNAME.github.io/mlb-dashboard/`

Takes about 2 minutes the first time.

### 4. Schedule daily updates
- Edit `morning_run.bat` to point to your model and dashboard folders
- Open Task Scheduler → Create Basic Task
- Set trigger: Daily at 8:30 AM
- Action: Start a program → browse to `morning_run.bat`

## Daily workflow (automated)
```
morning_run.bat runs automatically:
  1. python main.py --mode today   (runs model)
  2. copies JSON files to dashboard
  3. git push                      (dashboard updates in ~30s)
```

## File structure
```
mlb-dashboard/
  index.html                  ← the full dashboard (single file)
  data/
    processed/
      picks_today.json        ← today's predictions (written by model)
      series_schedule.json    ← series context + predictions
      pitcher_cards.json      ← SP profiles + K predictions
      picks_history.json      ← graded historical picks
  morning_run.bat             ← daily automation script
```
