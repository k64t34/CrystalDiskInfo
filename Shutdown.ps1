Start-Transcript -Path "c:\Program Files\CrystalDiskInfo\script_debug.txt" -Append -Force
$version="20260602-1700"
$scriptFullPathNameExt=$MyInvocation.MyCommand.Definition 
$global:scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFullPathNameExt)
$global:scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$MutexName = "Global\MyUniqueScript_" + (Get-FileHash $MyInvocation.MyCommand.Path).Hash
try {
    $Mutex = [System.Threading.Mutex]::OpenExisting($MutexName)
    Write-Host "Другой экземпляр скрипта уже запущен"
    exit
	}
catch {    
    $Mutex = New-Object System.Threading.Mutex($false, $MutexName) # Mutex не найден — создаём его
	}
try {
$LibFile="${scriptDirectory}\${scriptName}.psm1"    
    if (-not(Test-Path -Path $LibFile -PathType Leaf))
    { 
        Write-Host "ERR" -ForegroundColor White  -BackgroundColor Red  -NoNewline
        Write-Host "No lib file $LibFile"
        exit 
    }		
Import-module  -Name  $LibFile   -Force 

$Host.UI.RawUI.WindowTitle = "make shutdown"
Write-Host "*********************************************************" -ForegroundColor Cyan
Write-Host "$($Host.UI.RawUI.WindowTitle) by Skorik $version" -ForegroundColor Cyan
Write-Host "*********************************************************" -ForegroundColor Cyan
Write-Host $scriptFullPathNameExt -ForegroundColor Gray
Write-Host 
$FolderScript = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Start-Log $(Join-Path -Path $scriptDirectory -ChildPath "log.txt")
Write-Log "Shutdown request." -NoNewline #[System.IO.File]::AppendAllText($logFilePath,"`r`n$(Now) Shutdown request.") 

$UserSessionStatus=$(GetUserSessionStatus)
Write-Host $UserSessionStatus 
Write-Log " $UserSessionStatus" -NoNewline #[System.IO.File]::AppendAllText($logFilePath, ' '+$UserSessionStatus )
if (!$UserSessionStatus){
	Write-Log " No user session." -NoNewline# [System.IO.File]::AppendAllText($logFilePath," No user session. Shutdown")	
	$(Shutdown)
	}
else 
	{	
	if ($UserSessionStatus -eq 'WTSActive')
		{		
		if ($(showShutdownWarningToUserDeskTop) -ne 0){Write-Log " Error running form"}
		}
	else { # $UserSessionStatus = WTSDisconnected
		$UserResponse=$(ShutdownWarningLockScreen)
		if ($UserResponse -eq 'timeout'){Write-Log " $(Now) Timeout." -NoNewline;$(Shutdown)}	
		elseif ($UserResponse -eq 'shutdown'){Write-Log " $(Now) User wanted." -NoNewline;$(Shutdown)}	
		elseif ($UserResponse -eq 'cancel'){Write-Log " $(Now) Canceled by user"}
		elseif ($UserResponse -eq 'noresult'){Write-Log " $(Now) No response"}		
		elseif ($UserResponse -eq 'error'){Write-Log " $(Now) Error creating system message window"}		
		else {Write-Log " $(Now) Unknown response"}		
		}	
	}

} finally {$Mutex.Dispose()}
Stop-Transcript