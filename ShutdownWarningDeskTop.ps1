#Start-Transcript -Path "c:\Program Files\CrystalDiskInfo\script_debug.txt" -Append -Force
#$version="20260602-1700"
function Now {return $(Get-Date -Format  "dd.MM.yyyy HH:mm:ss")} 
#********************************************************************
function ShutdownWarningDeskTop() {
#********************************************************************	
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()
#[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

$script:RemainingSeconds=3600

$StopFlag = $false
$Message = "Компьютер будет выключен через"

$Form = New-Object System.Windows.Forms.Form
$Form.ControlBox    = $false             # нет кнопок Свернуть/Развернуть/Закрыть
$Form.FormBorderStyle = 'None'           # нет рамки и заголовка
$Form.StartPosition  = 'CenterScreen'    # по центру экрана
$Form.Size           = New-Object System.Drawing.Size(850,200)
$Form.Font = New-Object System.Drawing.Font("Segoe UI", 32)
$Form.BackColor = [System.Drawing.Color]::Yellow
$Form.ForeColor  = [System.Drawing.Color]::Black
$Form.ShowInTaskbar = $false
$Form.Add_Shown({
    $Form.Activate()
})
$Label = New-Object System.Windows.Forms.Label
$Label.Text = $Message + " " + $RemainingSeconds + "с"
$Label.AutoSize = $false
$Label.width=$Form.width
$Label.Height=64
$Label.BackColor = [System.Drawing.Color]::Transparent
#$Label.Location = New-Object System.Drawing.Point(20,20)
$Label.Location.X = 0
$label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

$Button = New-Object System.Windows.Forms.Button
$Button.BackColor= [System.Drawing.Color]::Green
$Button.ForeColor  = [System.Drawing.Color]::White
$Button.Text = "Отменить выключение"
$Button.Height = 48
$Button.Location.X=0

$Button.Add_Click({	
    $StopFlag = $true
	#shutdown -a
    #[System.Windows.Forms.MessageBox]::Show("Выключение отменено.","Выключение")	
	$Form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$Form.Close()
})

$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 1000  # 1 секунда
$Timer.Add_Tick(
	{	
    if ($StopFlag) {$Timer.Stop()}
	else 
		{		
		$script:RemainingSeconds--
		$Label.Text = $Message +" "+ $script:RemainingSeconds + "с"
		#$Label.Invalidate()
		#$Form.Update()
		
		$rand = New-Object System.Random
		$floatrand = $rand.NextDouble()   
		
		if ($floatrand -le 0.5) 	{
			$Form_BackColor = $Form.BackColor
			$Form_ForeColor  = $Form.ForeColor
			$Form.BackColor = [System.Drawing.Color]::Black
			$Form.ForeColor  = [System.Drawing.Color]::White
			Start-Sleep -Milliseconds 200		
			$Form.BackColor = $Form_BackColor
			$Form.ForeColor  = $Form_ForeColor
			$Form.TopMost = $true 
		}
		if ($RemainingSeconds -le 600) {
			$Form.BackColor = [System.Drawing.Color]::Red
			$Form.ForeColor  = [System.Drawing.Color]::White
		}
			

		if ($RemainingSeconds -le 0) {        
			#& $env:systemroot\system32\shutdown.exe /s /t 60			
			$StopFlag = $true
			$Form.DialogResult = [System.Windows.Forms.DialogResult]::OK
			$Form.Close()			
			}
		}
	})

$Form.Controls.Add($Label)
$Form.Controls.Add($Button)
$Button.Width  = $Form.ClientSize.Width-5-5


$Button.Location = [System.Drawing.Point]::new(
    $Button.Location.X+5,
    $Form.Height - $Button.Height-5
	)
$Timer.Start()
$Form.ShowDialog()

$Timer.Stop()
$Form.Dispose()
$Timer.Dispose()
$Label.Dispose()
$Button.Dispose()

$Form    = $null
$Timer   = $null
$Label   = $null
$Button  = $null

}
$FolderScript = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$global:FileLog = Join-Path -Path $FolderScript -ChildPath "log.txt"

if ($(ShutdownWarningDeskTop) -eq 'Cancel'){
	[System.IO.File]::AppendAllText($FileLog," $(Now) Canceled by user`r`n")			
	}
else {			
	[System.IO.File]::AppendAllText($FileLog," $(Now) Timeout. Shutdown`r`n")
	& $env:systemroot\system32\shutdown.exe /s /t 60
	}	
			
#Stop-Transcript			

