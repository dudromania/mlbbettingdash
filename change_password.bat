@echo off
REM change_password.bat
REM Run this whenever you want to change the dashboard password.
REM It updates the hash in index.html automatically.

echo.
echo ============================================================
echo   MLB Edge — Change Dashboard Password
echo ============================================================
echo.

set /p NEW_PW="Enter new password: "

REM Use Python to compute SHA-256 and update the HTML
python3 -c "
import hashlib, sys, re

pw   = sys.argv[1]
h    = hashlib.sha256(pw.encode()).hexdigest()
path = 'index.html'

with open(path) as f:
    content = f.read()

# Replace the hash line
old_pattern = r\"const PASS_HASH = '[a-f0-9]{64}';\"
new_line     = f\"const PASS_HASH = '{h}';\"
updated = re.sub(old_pattern, new_line, content)

# Replace the hint (invisible dev reference)
hint_pattern = r'<div id=\"auth-hint\">[^<]*</div>'
new_hint     = f'<div id=\"auth-hint\">{pw}</div>'
updated = re.sub(hint_pattern, new_hint, updated)

with open(path, 'w') as f:
    f.write(updated)

print(f'Password updated to: {pw}')
print(f'SHA-256: {h}')
print('Push to GitHub to make it live.')
" "%NEW_PW%"

echo.
echo Pushing update to GitHub...
git add index.html
git commit -m "update password"
git push origin main

echo.
echo Done. New password is live.
echo Anyone already logged in stays logged in for 7 days.
echo.
pause
