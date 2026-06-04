New-Variable -name "ShutdownLib" -value "20260528-1544"
function Now {return $(Get-Date -Format  "dd.MM.yyyy HH:mm:ss")} 
function Shutdown(){Write-Log " Shutdown" 
& $env:systemroot\system32\shutdown.exe /s /t 60
}
#********************************************************************
function showShutdownWarningToUserDeskTop() {
#********************************************************************	
#Add-Type -AssemblyName System.Management.Automation
$Code = @"
using System;
using System.Runtime.InteropServices;

public class ProcessLauncher {
    [DllImport("wtsapi32.dll", SetLastError = true)]
    public static extern bool WTSQueryUserToken(uint sessionId, out IntPtr token);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr handle);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool CreateProcessAsUserW(
        IntPtr hToken,
        string lpApplicationName,
        string lpCommandLine,
        IntPtr lpProcessAttributes,
        IntPtr lpThreadAttributes,
        bool bInheritHandles,
        uint dwCreationFlags,
        IntPtr lpEnvironment,
        string lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo,
        out PROCESS_INFORMATION lpProcessInformation
    );

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public int dwX;
        public int dwY;
        public int dwXSize;
        public int dwYSize;
        public int dwXCountChars;
        public int dwYCountChars;
        public int dwFillAttribute;
        public int dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess;
        public IntPtr hThread;
        public int dwProcessId;
        public int dwThreadId;
    }

    public static int LaunchAsCurrentUser(string command) {
        // 1. Динамически определяем ID АКТИВНОЙ сессии вместо жестко прописанной единицы
        uint sessionId = (uint)System.Diagnostics.Process.GetProcessesByName("explorer").Length > 0 
            ? (uint)System.Diagnostics.Process.GetProcessesByName("explorer")[0].SessionId 
            : 1;

        IntPtr userToken = IntPtr.Zero;
        if (!WTSQueryUserToken(sessionId, out userToken)) {
            return -1; // Не удалось получить токен (пользователь не залогинен)
        }

        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(si);
        // Указываем запуск на интерактивном рабочем столе пользователя
        si.lpDesktop = "winsta0\\default"; 

        PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
        
        // Передаем команду. null в первом параметре позволяет парсить всю строку
        bool success = CreateProcessAsUserW(
            userToken,
            null,
            command,
            IntPtr.Zero,
            IntPtr.Zero,
            false,
            0, // dwCreationFlags
            IntPtr.Zero,
            null,
            ref si,
            out pi
        );

        if (success) {
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);
            CloseHandle(userToken);
            return 0; // Успешно запущено
        }

        CloseHandle(userToken);
        return Marshal.GetLastWin32Error(); // Возвращаем код системной ошибки Win32
    }
}
"@

# Проверяем, добавлен ли тип, чтобы избежать ошибок при повторном запуске в одной сессии
if (-not ([System.Management.Automation.PSTypeName]'ProcessLauncher').Type) {
    Add-Type -TypeDefinition $Code
}
# Формируем строку запуска для PowerShell с флагами отображения GUI
$CommandLine = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -File `""+$global:scriptDirectory+"\ShutdownWarningDeskTop.ps1`""
# Запускаем метод
try {
$ExitCode = [ProcessLauncher]::LaunchAsCurrentUser($CommandLine)
}
catch{Write-Host $($_.Exception.Message)}
Write-Host "ExitCode=$ExitCode"
return ($ExitCode)
}
#********************************************************************
function ShutdownWarningLockScreen() {
#********************************************************************	
$WTSMessageCode = @"
using System;
using System.Runtime.InteropServices;

public class WTSMessageBox {
    [DllImport("wtsapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool WTSSendMessage(
        IntPtr hServer,
        int SessionId,
        string pTitle,
        int TitleLength,
        string pMessage,
        int MessageLength,
        int Style,
        int Timeout,
        out int pResponse,
        bool bWait
    );
}
"@
# Загружаем API в память
if (-not ([System.Management.Automation.PSTypeName]'WTSMessageBox').Type) {
    Add-Type -TypeDefinition $WTSMessageCode
}
# Параметры окна
$SessionId = 1 # Экран приветствия Windows обычно живет в Session 1 или 2
$Title = "Системное уведомление"
$Style = 0x00000034  # MB_YESNO 6 7  + MB_ICONWARNING
$Timeout =  60 # Сколько секунд окно будет висеть до автозакрытия
$Response = 0
$Result='noresult'
$script:RemainingSeconds=60

for (; $RemainingSeconds -gt 0; $RemainingSeconds=$RemainingSeconds-1) 
	{	
	$Message = "Компьютер будет выключен через $RemainingSeconds мин, так как нет активных сессий.`n`nВыключить компьютер?"

	$Success =[WTSMessageBox]::WTSSendMessage([IntPtr]::Zero, $SessionId, $Title, $Title.Length * 2, $Message, $Message.Length * 2, $Style, $Timeout, [ref]$Response, $true)
	if ($Success) {
		if ($Response -eq  6) {
			#Write-Host "Пользователь нажал Y. Выключение подверждено."
			$Result='shutdown'
			break 
			}
		if ($Response -eq  7) {
			#Write-Host "Пользователь нажал N. Выключение отменено."
			$Result='cancel'
			break 
			}		
		}
	else {
		$Response = -1
		$Result="error"
		$ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
		$Exception = New-Object System.ComponentModel.Win32Exception($ErrorCode)
		$ErrorMessage = $Exception.Message
		#Write-Host "Ошибка при создании системного окна сообщения: Errorcode:$ErrorCode Message:$ErrorMessage"
		break 
		#Частые коды ошибок при работе с WTSSendMessage:2 (ERROR_FILE_NOT_FOUND) / 1257 (ERROR_CTX_MODEM_RESPONSE_TIMEOUT) — Сессия с указанным $SessionId сейчас не существует или находится в процессе смены состояния (например, пользователь только что вышел).5 (ERROR_ACCESS_DENIED) — Отказано в доступе. Самая частая ошибка. Возникает, если скрипт запущен от имени обычного пользователя или даже локального Администратора, но пытается отправить сообщение в чужую или системную сессию. Для исправления скрипт нужно запускать от имени SYSTEM (например, через Планировщик задач или psexec).1702 (ERROR_INVALID_CREDENTIALS) — Проблема с правами удаленного рабочего стола, если вы пытаетесь передать дескриптор сервера отличный от [IntPtr]::Zero.
		}	
	}
if ($Response -eq 32000) {
    $Result='timeout'
	#Write-Host "Время истекло. Выполняется выключение..."    
	}	
return ($Result)
}
#********************************************************************
function GetUserSessionStatus() {
#********************************************************************
$WTSCode = @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class WTSHelper {
    [DllImport("wtsapi32.dll", SetLastError = true)]
    public static extern IntPtr WTSOpenServer(string pServerName);

    [DllImport("wtsapi32.dll")]
    public static extern void WTSCloseServer(IntPtr hServer);

    [DllImport("wtsapi32.dll", SetLastError = true)]
    public static extern int WTSEnumerateSessions(IntPtr hServer, int Reserved, int Version, ref IntPtr ppSessionInfo, ref int pCount);

    [DllImport("wtsapi32.dll")]
    public static extern void WTSFreeMemory(IntPtr pMemory);

    [DllImport("Wtsapi32.dll", SetLastError = true)]
    public static extern bool WTSQuerySessionInformation(IntPtr hServer, int sessionId, int wtsInfoClass, out IntPtr ppBuffer, out uint pBytesReturned);

    [StructLayout(LayoutKind.Sequential)]
    public struct WTS_SESSION_INFO {
        public int SessionID;
        [MarshalAs(UnmanagedType.LPStr)]
        public string pWinStationName;
        public int State;
    }

    public enum WTS_CONNECTSTATE_CLASS {
        WTSActive, WTSConnected, WTSConnectQuery, WTSShadow, WTSDisconnected, WTSIdle, WTSListen, WTSReset, WTSDown, WTSInit
    }

    public static object[] GetActiveSessions() {
        IntPtr hServer = WTSOpenServer(null); // Local server
        IntPtr ppSessionInfo = IntPtr.Zero;
        int count = 0;
        var retval = new List<object>();

        if (WTSEnumerateSessions(hServer, 0, 1, ref ppSessionInfo, ref count) != 0) {
            int structSize = Marshal.SizeOf(typeof(WTS_SESSION_INFO));
            long current = (long)ppSessionInfo;

            for (int i = 0; i < count; i++) {
                WTS_SESSION_INFO si = (WTS_SESSION_INFO)Marshal.PtrToStructure((IntPtr)current, typeof(WTS_SESSION_INFO));
                current += structSize;

                IntPtr userPtr = IntPtr.Zero;
                uint bytesReturned = 0;
                string username = "";

                // 5 = WTSUserName
                if (WTSQuerySessionInformation(hServer, si.SessionID, 5, out userPtr, out bytesReturned)) {
                    username = Marshal.PtrToStringAnsi(userPtr);
                    WTSFreeMemory(userPtr);
                }

                if (!string.IsNullOrEmpty(username)) {
                    retval.Add(new {
                        SessionId = si.SessionID,
                        UserName  = username,
                        State     = ((WTS_CONNECTSTATE_CLASS)si.State).ToString()
                    });
                }
            }
            WTSFreeMemory(ppSessionInfo);
        }
        WTSCloseServer(hServer);
        return retval.ToArray();
    }
}
"@
# Добавляем тип в текущую сессию PowerShell
Add-Type -TypeDefinition $WTSCode
# Вызываем метод (безопасно отработает даже из-под SYSTEM)

$sessions = [WTSHelper]::GetActiveSessions()
if ($sessions -eq $null) {$result=$null	}
else { $result='WTSDisconnected'
	foreach ($session in $sessions) {	
		if ($session.State -eq 'WTSActive')
			{								
			if ($(isLockScreen)) {
				#Write-Host "Экран заблокирован (LockScreen active)"
				$result='WTSDisconnected'
			} else {
				#Write-Host "Пользователь работает в рабочем столе"
				$result='WTSActive'
			}
			break	
			}    
		}
	}
return ($result)
}
#********************************************************************
function isLockScreen () {
#********************************************************************	
$activeSessionId = $null
$consoleLine = qwinsta 2>$null | Select-String "console"    
if ($consoleLine -and ($consoleLine -match '(\d+)\s+Active')) {
	$activeSessionId = [int]$Matches[1]
	}
# Подстраховка: если qwinsta не дала результат, ищем сессию через активный explorer.exe
if ($null -eq $activeSessionId) {
	$activeSessionId = (Get-Process -Name "explorer" -ErrorAction SilentlyContinue | 
						Sort-Object StartTime -Descending | 
						Select-Object -First 1).SessionId
	}
# Если активная сессия вообще не найдена (WTSDisconnected / нет вошедших пользователей)
if ($null -eq $activeSessionId) {
	return $true
	}
# 2. Проверяем, запущен ли процесс экрана блокировки (LogonUI) строго в этой сессии
$logonUiInSession = Get-Process -Name "LogonUI" -ErrorAction SilentlyContinue | 
					Where-Object { $_.SessionId -eq $activeSessionId }
# 3. Возвращаем результат
if ($logonUiInSession) {
	# Экран заблокирован (LockScreen) -> Пользователь НЕ работает
	return $true
	} else {
	# Экран разблокирован -> Пользователь РАБОТАЕТ в рабочем столе
	return $false
	}
}
#********************************************************************
$global:FileLog
function Start-Log() { #1. Определяет $global:FileLog, 2. Создает файл log, если еще нет и пишет первую строку datatime Log-file created,3. Проверяет, что в конце файла есть перевод строки  
[CmdletBinding()]
    param(
        [Parameter(Position=0,ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$FileLog
	)		
if ( [string]::IsNullOrWhiteSpace($global:FileLog))
	{	
	
	if ([string]::IsNullOrWhiteSpace($local:FileLog)) {
		$global:FileLog = [System.IO.Path]::ChangeExtension($MyInvocation.ScriptName, '.log')		
		}
	else
		{	
		$global:FileLog	= $local:FileLog
		}
	}	
if (-not (Test-Path -LiteralPath $global:FileLog -PathType Leaf )) 
	{	Write-Log 'Log-file created'}
else 
	{		
	$fs = [System.IO.File]::Open($global:FileLog, 'Open', 'Read', 'ReadWrite')
	try {
		if ($fs.Length -ge 3)
			{			
			$fs.Seek(-2, [System.IO.SeekOrigin]::End) | Out-Null
			$b1 = $fs.ReadByte() ; 	$b2 = $fs.ReadByte()
			if ($b1 -ne 0x0D -or $b2 -ne 0x0A) {Write-Output '`r`n'  | Out-File -FilePath $FileLog -Append  -Encoding UTF8}
			}
		}
	finally {$fs.Dispose()}
	}
}
$global:FileLogNoNewline=$false
function Write-Log () {
#********************************************************************	
    [CmdletBinding()]
    param(
        [Parameter(Position=0,ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$LogText,    
    
        [Parameter()]
        [switch]$NoNewline    
    )	
    #Write-Output "global:FileLogNoNewline=$global:FileLogNoNewline NoNewline=$NoNewline"  | Out-File -FilePath $FileLog -Append  -Encoding UTF8 
    if (!$global:FileLogNoNewline) {Write-Output "$(Now) "  | Out-File -FilePath $global:FileLog -Append  -Encoding UTF8 -NoNewline }
    Write-Output $LogText  | Out-File -FilePath $global:FileLog -Append  -Encoding UTF8 -NoNewline:$NoNewline
    $global:FileLogNoNewline=$NoNewline
}
#********************************************************************
function Write-Host {
#********************************************************************	
    [CmdletBinding(HelpUri='go.microsoft.com', RemotingCapability='None')]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [System.Object]$Object,

        [Parameter()]
        [System.ConsoleColor]$ForegroundColor,

        [Parameter()]
        [System.ConsoleColor]$BackgroundColor,

        [Parameter()]
        [switch]$NoNewline,

        # НАШ НОВЫЙ ПАРАМЕТР
        [Parameter()]
        [switch]$Log,

        [Parameter(ValueFromRemainingArguments=$true)]
        [System.Object[]]$RemainingArguments
    )   
        # 1. Вызываем оригинальный Write-Host через префикс Microsoft.PowerShell.Utility
        # Передаем все параметры, кроме нашего собственного -Log        
        if ($Log) {Write-Log $Object -NoNewline:$NoNewline}
        $PSBoundParameters.Remove('Log') | Out-Null
        Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
}