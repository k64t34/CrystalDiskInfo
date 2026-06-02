$FolderFrom = "\\skorik10\c$\Users\skorik\Repository\CrystalDiskInfo"

$hosts = @(
    "disp104-1",
	"disp104-2",
	"disp104-3",
	"disp104-4",
	"disp104-5",
	"disp104-6",
	"utc104-30",    
    "utc104-1",
    "utc104-2",
    "utc104-3",
    "utc104-4",
    "utc104-5",
    "utc104-6",
    "utc104-7",
    "utc104-8",
    "utc104-9"
    "utc104-15",
    "kettler"	
)

$files = @(
    "Shutdown.ps1",
    "Shutdown.psm1",
    "ShutdownWarningDeskTop.ps1",
    "execCrystalDiskInfor.ps1"
)

$destPath = "c$\Program Files\CrystalDiskInfo"
Write-Host "-------------------------------"
Write-Host "From $FolderFrom" 
Write-Host "To $destPath" 
Write-Host "Hosts:"
foreach ($h in $hosts) {	Write-Host $h }	
Write-Host "Files:"
foreach ($file in $files) {Write-Host $file}
Write-Host "-------------------------------"
foreach ($h in $hosts) {
    Write-Host $h -NoNewLine
    
    # Проверка пинга
    $pingResult = Test-Connection -ComputerName $h -Count 1 -Quiet
    if ($pingResult) {
        Write-Host " ping" -NoNewLine -ForegroundColor Green
    } else {
        Write-Host " fail" -ForegroundColor Red
        continue
    }
    
    # Копирование файлов
    foreach ($file in $files) {		
        $source = Join-Path $FolderFrom $file
        $dest = "\\$h\$destPath\"	
        
        try {
            Copy-Item -Path $source -Destination $dest -Force -ErrorAction Stop			
            Write-Host " $file" -NoNewLine -ForegroundColor Green
        } catch {
            Write-Host " $file " -NoNewLine -ForegroundColor Red
			break
        }
    }
	Write-Host
}