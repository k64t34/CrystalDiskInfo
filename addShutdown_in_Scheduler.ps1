param (
    [string]$Script    
)
$version="20260602-1700"
$scriptFullPathNameExt=$MyInvocation.MyCommand.Definition 
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFullPathNameExt)
$Host.UI.RawUI.WindowTitle = "Set task shutdown in scheduler"
Write-Host "*********************************************************" -ForegroundColor Cyan
Write-Host "$($Host.UI.RawUI.WindowTitle) (c) Skorik $version" -ForegroundColor Cyan
Write-Host "*********************************************************" -ForegroundColor Cyan
Write-Host $scriptFullPathNameExt -ForegroundColor Gray
$scriptFolder = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
if (!$Script) {
	Write-Host "Parameter -Script not specified" -ForegroundColor Red
	return
	}

Import-Module ScheduledTasks -ErrorAction SilentlyContinue

$TaskName = "Shutdown.2"
# Создание действия
$Action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
	-Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$Script`""
# Создание триггера 
$Trigger = New-ScheduledTaskTrigger  -Daily -At "17:01"
$Settings = New-ScheduledTaskSettingsSet -WakeToRun
# Регистрация задачи (Force перезапишет, если существует)
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -User "SYSTEM" -Force -ErrorAction SilentlyContinue | Out-Null
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue ) {
    Write-Host  "OK. Task '$TaskName' exist and active"  -ForegroundColor Green
	Get-ScheduledTask $TaskName | Get-ScheduledTaskInfo | Format-List NextRunTime 	| Out-String -Stream  | Where-Object { $_ -ne '' }	
	$Task = Get-ScheduledTask -TaskName $TaskName	
	#$Task.Triggers | Format-List *		
$Task.Actions | Format-Table Execute,Arguments -HideTableHeaders | Out-String -Stream  | Where-Object { $_ -ne '' }
	} else {
    Write-Host  "Fail. Task '$TaskName' not found" -ForegroundColor Red
	}


