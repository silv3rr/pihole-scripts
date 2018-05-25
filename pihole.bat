@( ECHO %* | find "ECHO_ON" >nul 2>&1 ) || @ECHO off
SET DEBUG=0 & ( ECHO %* | find "DEBUG" >nul 2>&1 ) && SET DEBUG=1
SET "script_name=%~nx0" & SETLOCAL EnableDelayedExpansion

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: pihole.bat - Simple Windows Batch file wrapper for Pi-Hole API
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Requires "curl" and optionally "jq" (available from chocolatey.org).
:: If curl (and/or jq) cant be found it'll try to use wget or powershell.
::
:: Set "auth=" to your API Token. Get it from:
::   http://pi.hole/admin > Login > Settings
::
::SET "auth=abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
SET "auth="
:: default api url and disable time in sec
SET "api=http://pi.hole/admin/api.php" & SET "sec=10"
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: end of config ::::

:: start script by setting vars, search paths for bins (curl, jq etc)
SET "curl=" & SET "wget=" & SET "powershell=" & SET "jq=" 
SET "param=" & SET "http_get=" & SET "jq_args="
SET search="%SystemRoot%\System32" "C:\ProgramData\chocolatey\bin" ^
					 "C:\tools\msys64\mingw64\bin" "C:\tools\msys32\mingw32\bin" ^
					 "C:\msys64\mingw64\bin" "C:\msys32\mingw32\bin" ^
					 "C:\tools\msys32\usr\bin" "C:\tools\msys64\usr\bin" ^
					 "C:\msys32\usr\bin" "C:\msys64\usr\bin" ^
					 "C:\cygwin\bin" "C:\cygwin64\bin" "C:\cygwin32\bin"
SET "bins=curl wget jq"
FOR %%a IN ( %search% ) DO (
	FOR %%b IN ( !%bins! ) DO (
		IF EXIST "%%~a\%%~b.exe" ( SET "%%b=%%~a\%%~b.exe" & SET bins=!bins:%%b=! )
	)
)
SET ps_path=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
IF EXIST "%ps_path%" (
	SET "powershell=%ps_path%"
	SET "ps_ts=([timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($x))).toString(\"s\")"
)
:: default is to use curl for http get and jq to format json, else use ps
SET "fmt=jq"
IF NOT DEFINED powershell (
	IF NOT DEFINED wget (
		IF NOT DEFINED curl (
				ECHO Could not find required curl.exe ^(or alternative^),
				ECHO please install cURL. & GOTO :EOF
			)
	)
) ELSE (
	IF NOT DEFINED jq ( SET "fmt=ps" )
)

:: args to force fmt: -[r|j|r] raw|jq|ps
IF /I "%~1"=="-r" ( SET "jq=" & SET fmt= & SHIFT
) ELSE IF /I "%~1"=="-j" ( SET "fmt=jq" & SHIFT
) ELSE IF /I "%~1"=="-p" ( SET "fmt=ps" & SHIFT )
IF /I "%~1"=="-t" (	GOTO :test )
:: if arg is not an api param, or -h: display help
SET a=%~1
IF /I "%~1"=="-h" (	GOTO :help )
IF "!a:~0,1!"=="-" ( GOTO :help )
IF "!a:~0,1!"=="/" ( GOTO :help )

:: api params
IF NOT "%~1"=="" (
	IF /I "%~1"=="enable" ( SET "param=?%~1&auth=%auth%" & GOTO :chk_param )
	IF /I "%~1"=="disable" ( (IF NOT "%~2"=="" (SET "sec=%~2")) & SET "param=?%~1=!sec!&auth=%auth%" )
	IF /I "%~1"=="overTimeData10mins" ( 
		SET jq_args=-r ". | keys[] as $p | .[] | keys[] as $k | \"\^($p^) \^($k^|tonumber^|todate^): \^(.[$k]^)\""
		SET ps_args="$jc = ($input | ConvertFrom-Json); $jn = ($jc | Get-Member -MemberType NoteProperty);"^
								"foreach ($j in $jn) { $k = $j.Name; $v = $jc.$k; $v.PSObject.Properties | foreach { $x = $_.Name; Write-Host ($j.Name) %ps_ts% ($_.Value) } }"
		GOTO :chk_param
	)
	IF /I "%~1"=="recentBlocked" ( SET "fmt=" & GOTO :chk_param )
	:: these params share the same options
	FOR %%i IN ( topItems getQuerySources getForwardDestinations getQueryTypes ) DO (
		IF /I "%~1"=="%%i" ( SET "param=?%~1&auth=%auth%" & SET jq_args=-r "." & SET ps_args="ConvertFrom-Json $input | ConvertTo-Json" & GOTO :chk_param )
	)
	IF /I "%~1"=="getAllQueries" (
		SET "param=?%~1&auth=%auth%"
		SET jq_args=-r ".data | .[][0] |= (tonumber|todate) | .[] | join(\" \")"
		SET ps_args="(ConvertFrom-Json $input).data | foreach { $x = ($_|select -First 1); Write-Host %ps_ts% ($_|select -Skip 1) }"
		GOTO :chk_param
	)
	:chk_param
	IF DEFINED param (
		ECHO "!param!" | find /i "auth=" >nul 2>&1 && CALL :auth_msg
	) ELSE ( 
		SET "param=?%~1"
	)
	GOTO :http_get
) ELSE (
	GOTO :help
)
GOTO :EOF

:: set bin to use to http get api
:http_get
IF NOT "%curl%"=="" (
	SET http_get=%curl% -s "%api%%param%"
) ELSE IF NOT "%wget%"=="" (
	SET http_get=%wget% -q -O - "%api%%param%"
	ECHO cURL not found, using Wget
) ELSE IF NOT "powershell"=="" (
	SET http_get=%powershell% -Command "(Invoke-WebRequest -Uri "%api%%param%").Content"
	ECHO cURL not found, using PowerShell
)
:: set bin to use to format output (json)
IF DEFINED http_get (
	echo:
	IF "%fmt%"=="jq" (
		IF NOT DEFINED jq_args (SET jq_args=-r "to_entries[] | .key + \": \" + (.value|tostring)" )
		IF %DEBUG% EQU 1 ( ECHO DEBUG: http_get %http_get% ^| %jq% !jq_args! & echo: )
		%http_get% | %jq% !jq_args!
	) ELSE IF "%fmt%"=="ps" (
		IF NOT DEFINED ps_args ( SET ps_args="ConvertFrom-Json $input | Format-List" )
		IF %DEBUG% EQU 1 ( ECHO DEBUG: http_get %http_get% ^| %powershell% !ps_args! & echo: )
		%http_get% | %powershell% !ps_args!
	) ELSE (
		IF %DEBUG% EQU 1 ( ECHO DEBUG: http_get %http_get% & echo: )
		%http_get%
		echo:
	)
) ELSE (
	ECHO Could not call api using cURL ^(or alternative^) 
)
GOTO :EOF

:: msg user if auth= unset
:auth_msg
SET achk=0
IF NOT DEFINED auth ( SET achk=1 )
IF "%auth%"=="" ( SET achk=1 )
IF %achk% EQU 1 (
	echo:
	ECHO Set "auth=" in "%script_name%" to your API Token. Get it from:
	ECHO   http://pi.hole^/admin ^> Login ^> Settings
)
GOTO :EOF

:help
echo:
ECHO Simple Windows Batch file wrapper for Pi-Hole API
echo:
ECHO Calls Pi-Hole API with cURL ^(or alternative^) using options below.
ECHO It just adds the option to URL so if there are new API options in the
ECHO future which are not listed below they should also work.
echo:
ECHO USAGE:
ECHO   %script_name% enable^|disable [0^|10^|30^|300^|N] ( 0=perm, default=%sec% seconds ^)
echo:
ECHO EXAMPLE:
ECHO   %~dpnx0% disable 60
echo:
ECHO MORE OPTIONS: 
ECHO   status type version summary summaryRaw recentBlocked overTimeData10mins
ECHO   topItems getQuerySources getForwardDestinations getQueryTypes getAllQueries
ECHO   ^( ^^ options on the first row do not require api token ^)
CALL :auth_msg
GOTO :EOF

:test
:: test options listed in help
FOR /F %%t IN ('pihole.bat -h ^| findstr "status topItems" ^| tr " " "\n"') DO (
	ECHO * %%t : & pihole.bat %%t | tail -10 & echo:
	ECHO * %%t ^(PS^) : & pihole.bat -p %%t | tail -10 & echo:
)
GOTO :EOF
