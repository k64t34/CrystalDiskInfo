#TODO: Замена в ini абсолютного адреса на имя ПК
#$ExitCode=0	
$global:DebugPreference = "Continue"
$scriptFullPathNameExt=$MyInvocation.MyCommand.Definition
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFullPathNameExt)
$global:scriptNameExt = [System.IO.Path]::GetFileName($scriptFullPathNameExt)
$global:scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$version="20260602-1700"
#$global:FileLog=$env:TEMP+"\"+$scriptName+".log"
#$LibFile="${scriptDirectory}\${scriptName}.psm1"    
#if (-not(Test-Path -Path $LibFile -PathType Leaf))
#{ 
#	Write-Host "ERR" -ForegroundColor White  -BackgroundColor Red  -NoNewline
#	Write-Host "No lib file $LibFile"
#	exit
#}		
#Import-module  -Name  $LibFile   -Force 
	
$Host.UI.RawUI.WindowTitle = $scriptName    
#Write-Host $(Now)
if ($DebugPreference -eq "Continue"){Write-Debug "ON" }
Write-Host "***************************************************************************" -ForegroundColor Cyan
Write-Host "$scriptName                                  by Skorik $Version"  -ForegroundColor Cyan 
Write-Host "***************************************************************************"  -ForegroundColor Cyan

Write-Host $scriptFullPathNameExt  -ForegroundColor Green -NoNewline   
	Write-Host " on $env:COMPUTERNAME" -ForegroundColor Yellow  -NoNewline 
	Write-Host " by $env:USERNAME" -ForegroundColor Yellow  

#region test path install to
$AppPath=$env:ProgramFiles
if (-not(Test-Path -Path $AppPath -PathType Container )){
	Write-Host "Path $AppPath not found" -ForegroundColor Red
	return 
}
#endregion

#region create path install to
$AppPath=$AppPath+'\CrystalDiskInfo' 
if (-not(Test-Path -Path $AppPath -PathType Container )){
	Write-Host "Path $AppPath not found. Try create ..." -ForegroundColor Yellow -NoNewline
	New-Item -Path $AppPath -ItemType Directory -Force | Out-Null
	if (-not(Test-Path -Path $AppPath -PathType Container )){
		Write-Host ' Fail' -ForegroundColor Red
		return 
	}
	Write-Host  ' OK' -ForegroundColor Green
}
#endregion

Expand-Archive -Path $scriptDirectory'\CrystalDiskInfo9_8_0.zip' -DestinationPath $AppPath -force #copy app
Copy-Item -Path $scriptDirectory'\execCrystalDiskInfor.ps1'  -Destination $AppPath -force  # copy scripts
Copy-Item -Path $scriptDirectory'\Shutdown.ps1'   -Destination $AppPath -force  # copy scripts
Copy-Item -Path $scriptDirectory'\Shutdown.psm1'  -Destination $AppPath -force  # copy scripts
Copy-Item -Path $scriptDirectory'\ShutdownWarningDeskTop.ps1'  -Destination $AppPath -force  # copy scripts

& $scriptDirectory'\addCrystalDiskInfo_in_Scheduler.ps1' # run script to make task in scheduler
& $scriptDirectory'\addShutdown_in_Scheduler.ps1' -Script  $AppPath'\Shutdown.ps1' # run script to make task in scheduler

Write-Host "Finished" 
return 

#region Replace [mail] from=smart в DiskInfo.ini 
# Путь к INI‑файлу (измените на нужный)
$iniFilePath = "C:\path\to\your\config.ini"
# Получаем имя компьютера
$computerName = $env:COMPUTERNAME
# Проверяем существование файла
if (-not (Test-Path $iniFilePath)) {
    Write-Error "Файл не найден: $iniFilePath"
    exit 1
}
# Читаем файл построчно
$lines = Get-Content -Path $iniFilePath
# Флаг для отслеживания, нашли ли раздел [Mail]
$inMailSection = $false
# Флаг, чтобы отметить, что строка From уже обработана
$fromUpdated = $false
# Обрабатываем каждую строку
$newLines = @()
foreach ($line in $lines) {
    # Проверяем, начинается ли строка с [Mail] (с учётом пробелов)
    if ($line.Trim() -eq '[Mail]') {
        $inMailSection = $true
        $newLines += $line
        continue
    }
    # Если вышли из раздела [Mail] — сбрасываем флаг
    if ($inMailSection -and $line -match '^\[\w') {
        $inMailSection = $false
    }
    # Если в разделе [Mail] и строка начинается с From=
    if ($inMailSection -and $line -match '^From=') {
        # Заменяем значение после = на имя компьютера
        $line = "From=$computerName"
        $fromUpdated = $true
    }
    $newLines += $line
}
# Если раздел [Mail] найден, но строка From не была — добавляем её
if ($inMailSection -and -not $fromUpdated) {
    $newLines += "From=$computerName"
}
# Сохраняем изменения
$newLines | Set-Content -Path $iniFilePath -Encoding UTF8
Write-Host "Значение From обновлено на: $computerName" -ForegroundColor Green
#endregion
