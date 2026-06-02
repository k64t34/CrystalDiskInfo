$version="20260602-1700"
$scriptFullPathNameExt=$MyInvocation.MyCommand.Definition 
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFullPathNameExt)
$Host.UI.RawUI.WindowTitle = "run Crystal Disk Info"
Write-Host "*********************************************************" -ForegroundColor Cyan
Write-Host "$($Host.UI.RawUI.WindowTitle) by Skorik $version" -ForegroundColor Cyan
Write-Host "*********************************************************" -ForegroundColor Cyan
Write-Host $scriptFullPathNameExt -ForegroundColor Gray
Write-Host 
$FolderScript = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Write-Host "Current folder $FolderScript"

$logFilePath = Join-Path -Path $FolderScript -ChildPath "log.txt"
$currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
[System.IO.File]::AppendAllText($logFilePath,"`r`n$currentDateTime CrystalDiskInfo")
$DiskInfo64="DiskInfo64.exe"
$DiskInfo64file  = Join-Path -Path $FolderScript -ChildPath $DiskInfo64
if (-not (Test-Path $DiskInfo64file)) {
    Write-Error "File $DiskInfo64file not found"
    [System.IO.File]::AppendAllText($logFilePath," ERR:File $DiskInfo64file not found")
    exit 1
}

try {    
	$DiskInfo64Process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$DiskInfo64file`"" -WindowStyle Hidden	
    Write-Host "Running $DiskInfo64 with ID: $($DiskInfo64Process.Id)"
}
catch {
    Write-Error "Failed $DiskInfo64 : $($_.Exception.Message)"
    [System.IO.File]::AppendAllText($logFilePath," ERR: No run $DiskInfo64 : $($_.Exception.Message)")
    exit 1
}

Write-Host "Waiting 60 sec..."
Start-Sleep -Seconds 60

try {
    $diskInfoProcesses = Get-Process -Name "DiskInfo64" -ErrorAction SilentlyContinue
    if ($diskInfoProcesses) {
        Write-Host "Killing process $DiskInfo64" -nonewline 
        $diskInfoProcesses | ForEach-Object {
            Write-Host " with  ID: $($_.Id)..." -nonewline 
            $_.Kill()
            $_.WaitForExit()
        }
        Write-Host "killed "
        #Add-Content -Path $logFilePath -Value "DiskInfo64file killed"
    } else {
        Write-Host "Process $DiskInfo64 not found"
        [System.IO.File]::AppendAllText($logFilePath," ERR: Process $DiskInfo64  has not been started")
    }
}
catch {
    Write-Error "Error on killing process $DiskInfo64 $($_.Exception.Message)"
    [System.IO.File]::AppendAllText($logFilePath," ERR: $($_.Exception.Message)")
}

# 5. Записываем в файл log.txt текст "Done"
[System.IO.File]::AppendAllText($logFilePath," Done")
Write-Host "Script Finished"
