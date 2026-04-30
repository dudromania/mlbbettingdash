# setup_tasks.ps1
$DASH = "C:\Users\austi\OneDrive\Desktop\mlb_complete_package\mlb_dashboard"

if (-not (Test-Path $DASH)) { Write-Host "ERROR: Path not found: $DASH"; exit 1 }

Write-Host "Setting up MLB Edge scheduled tasks..."

$settings = New-ScheduledTaskSettingsSet `
    -WakeToRun `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -MultipleInstances IgnoreNew `
    -RestartCount 2 `
    -RestartInterval (New-TimeSpan -Minutes 5)

$principal = New-ScheduledTaskPrincipal `
    -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
    -LogonType Interactive `
    -RunLevel Highest

$dailyAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$DASH\run_daily.ps1`"" `
    -WorkingDirectory $DASH

$refreshAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File `"$DASH\run_refresh.ps1`"" `
    -WorkingDirectory $DASH

Write-Host "Registering tasks..."

Register-ScheduledTask -TaskName "MLB Edge Daily" `
    -Action $dailyAction `
    -Trigger (New-ScheduledTaskTrigger -Daily -At "08:00AM") `
    -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "  [OK] MLB Edge Daily - 8:00 AM"

Register-ScheduledTask -TaskName "MLB Edge Refresh 1100" `
    -Action $refreshAction `
    -Trigger (New-ScheduledTaskTrigger -Daily -At "11:00AM") `
    -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "  [OK] MLB Edge Refresh 1100 - 11:00 AM"

Register-ScheduledTask -TaskName "MLB Edge Refresh 1300" `
    -Action $refreshAction `
    -Trigger (New-ScheduledTaskTrigger -Daily -At "01:00PM") `
    -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "  [OK] MLB Edge Refresh 1300 - 1:00 PM"

Register-ScheduledTask -TaskName "MLB Edge Refresh 1500" `
    -Action $refreshAction `
    -Trigger (New-ScheduledTaskTrigger -Daily -At "03:00PM") `
    -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "  [OK] MLB Edge Refresh 1500 - 3:00 PM"

Write-Host ""
Write-Host "Verifying..."
Get-ScheduledTask -TaskName "MLB Edge*" | Get-ScheduledTaskInfo | `
    Select-Object TaskName, NextRunTime | Format-Table -AutoSize

Write-Host "Settings check..."
Get-ScheduledTask -TaskName "MLB Edge*" | Select-Object TaskName, `
    @{N="WakeToRun";E={$_.Settings.WakeToRun}}, `
    @{N="StartWhenAvailable";E={$_.Settings.StartWhenAvailable}}, `
    @{N="AllowBattery";E={$_.Settings.AllowStartIfOnBatteries}} | `
    Format-Table -AutoSize

Write-Host ""
Write-Host "All done. Test with:"
Write-Host "  Start-ScheduledTask -TaskName 'MLB Edge Daily'"
Write-Host "  Start-Sleep -Seconds 30"
Write-Host "  Get-ScheduledTaskInfo -TaskName 'MLB Edge Daily' | Select LastRunTime, LastTaskResult"
