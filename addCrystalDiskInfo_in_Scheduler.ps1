#OK TODO:Разбудить ПК для выполнения 
#TODO: Замена XML абсолютного пути на runtime

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$version="20260602-1700"
$scriptFullPathNameExt=$MyInvocation.MyCommand.Definition 
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFullPathNameExt)
$Host.UI.RawUI.WindowTitle = "Set Crystal Disk Info scheduler"
Write-Host "*********************************************************" -ForegroundColor Cyan
Write-Host "$($Host.UI.RawUI.WindowTitle) by Skorik $version" -ForegroundColor Cyan
Write-Host "*********************************************************" -ForegroundColor Cyan
Write-Host $scriptFullPathNameExt -ForegroundColor Gray
Write-Host 
$scriptFolder = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

Import-Module ScheduledTasks -ErrorAction SilentlyContinue

$TaskName = "CrystalDiskInfo.2"
$fileXML  = Join-Path -Path $scriptFolder -ChildPath "$TaskName.xml"
[xml]$taskXML = Get-Content -Path $fileXML


#region Replace abs psth to runtime
$currentValue = $($taskXML.Task.Actions.Exec.Arguments) # Использование простой структуры  работает. Но если есть заданный xmlns, то лучше использовать XPath 
#При сохранении нужно учитывать исходную кодировку (в шапке — UTF-16).
if ($currentValue -ne $null) {        
	Write-Host $currentValue    
    # Определяем старый путь для замены (экранируем слеши для regex)
    #$oldPathRegex = 'c:\\Program Files\\CrystalDiskInfo'    
    # Заменяем старый путь на новый из переменной $Spath
    #$newValue = $currentValue -replace $oldPathRegex, $Spath    
    # Обновляем значение узла
    #$argumentsNode.InnerText = $newValue    
    # Сохраняем изменения обратно в файл    
    #Write-Host "Путь успешно заменён на: $Spath"
} else {
	Write-warning "Tag <Argunets> not found. Default path used"
}
#endregion

Register-ScheduledTask -TaskName $TaskName -XML $taskXML.OuterXml -Force  | Out-Null

#$ProgramPath = "C:\Program Files\CrystalDiskInfo\DiskInfo64.exe"  # Путь к программе
#$ProgramPath = "%ComSpec%"
#$Arguments = "/c start `"`" `"echo %date% %time:~0,8% >> c:\slog.txt & %ProgramFiles%\CrystalDiskInfo\DiskInfo64.exe`" & %SystemRoot%\system32\timeout /t 10 /nobreak >nul & %SystemRoot%\system32\taskkill /f /im DiskInfo64.exe"
# Создание действия
#$Action = New-ScheduledTaskAction -Execute $ProgramPath -Argument $Arguments
#$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"c:\Program Files\CrystalDiskInfo\execCrystalDiskInfor.ps1`" "
# Создание триггера 
#$Trigger1 = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Thursday -At "12:15"
#$Trigger2 = New-ScheduledTaskTrigger -AtStartup 
#$Triggers = @($Trigger1, $Trigger2)
# Создание principal для запуска независимо от входа (SYSTEM)
#$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Регистрация задачи (Force перезапишет, если существует)
#Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger1 -Principal $Principal -Force -ErrorAction SilentlyContinue | Out-Null
#Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -User "SYSTEM" -Force -ErrorAction SilentlyContinue | Out-Null
#schtasks /Create /TN $taskName /SC MONTHLY /D 15 /ST 02:00 /TR "powershell.exe -File C:\Scripts\MyScript.ps1" /RU "SYSTEM" /F

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue ) {
    Write-Host  "OK. Task '$TaskName' exist and active"  -ForegroundColor Green
	Get-ScheduledTask $TaskName | Get-ScheduledTaskInfo | Format-List LastRunTime,LastTaskResult,NextRunTime,NumberOfMissedRuns | Out-String -Stream  | Where-Object { $_ -ne '' }	
	$Task = Get-ScheduledTask -TaskName $TaskName	
	#$Task.Triggers | Format-List *		
	$Task.Actions | Format-Table Execute,Arguments -HideTableHeaders | Out-String -Stream  | Where-Object { $_ -ne '' }	
} else {
    Write-Host  "Fail. Task '$TaskName' not found" -ForegroundColor Red
}
Stop-Service -Name "Schedule" -Force -ErrorAction SilentlyContinue | Out-Null
Start-Service -Name "Schedule" -ErrorAction SilentlyContinue

# Проверка статуса
$Status = Get-Service -Name "Schedule"
if ($Status.Status -eq "Running") {
    Write-Host " Service 'Schedule' restarted successful. Status: $($Status.Status)" -ForegroundColor Green
} else {
    Write-Host "Fail! Service 'Schedule' status: $($Status.Status)" -ForegroundColor Red
}