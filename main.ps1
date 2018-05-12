New-Variable -Name LogFilePath -Value "c:\windows\temp\LogFileM.txt" -Scope "Global"
New-Variable -Name ProcessTimeout -Value 1200000
### TESTED ON WINDOWS 10 AND 7 ONLY ###
#TODO: if already installed.
#Remove ExtLoader.

function Main () {
    <#
    .SYNOPSIS

    Runs program features. 

    .DESCRIPTION

    * the program runs automation program installation with the configuration file.
    * configure external features (no sleep on computer, no windows update, change background screen)

    .NOTES
    none
    #>
    # backup folder, and install programs.
    #CopyFolder -SourceFolder source  -DestinationFolder dest;
    InstallPorgramUnattended("C:\ExtLoader\Config.template.xml");

    # additional wanted computer settings.
    ChangeBackgroundRandomized("c:\ExtLoader\Backgrounds");
    StopWindowsAutomaticUpdates;
    SetWindowsPowerSettingsTimeout(0);
    Invoke-Item -Path $LogFilePath;

}

function RunProgram () {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $ProgramPath,

        [Parameter(Mandatory = $True)]
        [string]
        $ProgramArgs,

        [Parameter(Mandatory = $True)]
        [string]
        $ProgramName,
        
        [Parameter(Mandatory = $True)]
        [string]
        $ShouldUseShellExecute
    )

    Write-Log -Level "DEBUG" -Message "installing $($ProgramName) : $($ProgramPath) with: $($ProgramArgs)" -LogFile $LogFilePath
            if ([System.IO.File]::Exists($ProgramPath) -eq $false) {
                Write-Log -Level "ERROR" -Message "FILE NOT FOUND $($ProgramPath)"
            }
            else {
                $processInfo = New-Object System.Diagnostics.processStartInfo
                $processInfo.FileName = $ProgramPath
                $processInfo.Arguments = $ProgramArgs
                if ($ShouldUseShellExecute -eq "0")
                {
                    $processInfo.RedirectStandardOutput = $True
                    $processInfo.RedirectStandardError = $True
                    $processInfo.UseShellExecute = $false
                }
                $process = New-Object System.Diagnostics.Process
                $process.StartInfo = $processInfo
                $process.start() | Out-Null
                $HasExited = $process.WaitForExit($ProcessTimeout)
                if ($ShouldUseShellExecute -eq "0") {
                    $stdout = $process.StandardOutput.ReadToEnd()
                    $stderror = $process.StandardError.ReadToEnd()
                }
                $exitCode = $process.ExitCode

                Write-Log -Level "DEBUG" -Message "STDOUT: $($stdout)" -LogFile $LogFilePath
                Write-Log -Level "DEBUG" -Message "STDERR: $($stderror)" -LogFile $LogFilePath
                if ($HasExited -eq $false){
                    Write-Log -Level "ERROR" -Message "program $($ProgramName) didn't complete the run after $($ProcessTimeout) miliseconds.."
                }
                elseif ($exitCode -ne 0){
                    Write-Log -Level "ERROR" -Message "program $($ProgramName) exited with error code $($exitCode)" -LogFile $LogFilePath
                }
            }
    return $exitCode -eq 0
}

function CopyFolder() {
    <#
    .SYNOPSIS
    copies folder from source to destination recursively.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $SourceFolder,

        [Parameter(Mandatory = $True)]
        [string]
        $DestinationFolder
    )

    Copy-Item -Force -Recurse -Path $SourceFolder -Destination $DestinationFolder
}

function InstallPorgramUnattended () {
    <#
    .SYNOPSIS
    install programs unattendedly from the configuration file given
    
    .DESCRIPTION
    from the configuraiton, get the program name, file path and argumnets,
    execute the file with the arguments, and then write indicative log to log file, otherwise the standard input.
    
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $ConfigFilePath
    )
    
    Write-Log -Level "INFO" -Message "programs installation begins." -LogFile $LogFilePath
    $InstallationConfig = ([xml](Get-Content $ConfigFilePath)).configuration.programsInstall
        
        foreach ($node in $InstallationConfig.program) {
            # create a process, which redirects stdout and stderr.
            Write-Log -Level "DEBUG" -Message "$($node.executablePath), $($node.args), $($node.name)" -LogFile $LogFilePath
            RunProgram -ProgramArgs $node.args -ProgramName $node.name -ProgramPath $node.executablePath -ShouldUseShellExecute $node.shell
            
        }
    
    Write-Log -Level "INFO" -Message "programs installation ended." -LogFile $LogFilePath
}

function ChangeBackgroundRandomized () {
    <#
    .SYNOPSIS
    get a folder's path that has pictures in it, choose one randomly, and then sets its as the background.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $FolderPath
    )

    $BackgroundFilePath = Get-Random -InputObject (Get-ChildItem -File $FolderPath | ForEach-Object {$_.FullName})
    [System.Diagnostics.Process]::Start("C:\ExtLoader\SetWallpaper.exe", $BackgroundFilePath) | Out-Null
    Write-Log -Level "INFO" -Message "Changed wallpaper to $($BackgroundFilePath)" -LogFile $LogFilePath

}

function StopWindowsAutomaticUpdates () {
    <#
    .SYNOPSIS
    stops windows automatic updates. works only on windows 10. (#TODO: test on windows 7)

    .DESCRIPTION
    stops the windows service that is designated to windows update.
    #>


    $service = Get-WmiObject Win32_Service -Filter 'Name="wuauserv"'
    if ($service) {
        if ($service.StartMode -ne "Disabled") {
            # changing service start mode to disabled (so in case of restart he will not try to update again).
            $result = $service.ChangeStartMode("Disabled").ReturnValue
            if ($result) {
                Write-Log -Level "ERROR" -Message "Failed to disable the 'wuauserv' service. The return value was $($result)." -LogFile $LogFilePath
            }
            else {Write-Log -Level "INFO" -Message "Success to disable the 'wuauserv' service" -LogFile $LogFilePath}
			
            if ($service.State -eq "Running") {
                # stops the service.
                $result = $service.StopService().ReturnValue
                if ($result) {
                    Write-Log -Level "ERROR" -Message "Failed to stop the 'wuauserv' service. The return value was $($result)." -LogFile $LogFilePath
                }
                else {Write-Log -Level "INFO" -Message "Success to stop the 'wuauserv' service" -LogFile $LogFilePath}
            }
        }
        else {Write-Log -Level "WARN" -Message "The 'wuauserv' service is already disabled." -LogFile $LogFilePath}
    }
    else {Write-Log -Level "ERROR" -Message "Failed to retrieve the service 'wuauserv'" -LogFile $LogFilePath }
    
}

function SetWindowsPowerSettingsTimeout () {
    <#
    .SYNOPSIS
    sets the time of screen for windows until he goes to sleep (0 for never sleep.), in minutes.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [int]
        $ScreenTime
    )

    $PowerCfg = "C:\Windows\system32\powercfg.exe"
    $ProcessMonitorTimeoutAC = [System.Diagnostics.Process]::Start($PowerCfg, "-change -monitor-timeout-ac $ScreenTime")
    $ProcessMonitorTimeoutDC = [System.Diagnostics.Process]::Start($PowerCfg, "-change -monitor-timeout-dc $ScreenTime")
    $ProcessStandbayTimeoutAC = [System.Diagnostics.Process]::Start($PowerCfg, "-change -standby-timeout-ac $ScreenTime") # TODO: check
    $ProcessStandbayTimeoutDC = [System.Diagnostics.Process]::Start($PowerCfg, "-change -standby-timeout-dc $ScreenTime") # TODO: check.

    #TODO: check all this.
    $ProcessDiskTimeoutAC = [System.Diagnostics.Process]::Start($PowerCfg, "-change -disk-timeout-ac $ScreenTime") 
    $ProcessDiskTimeoutDC = [System.Diagnostics.Process]::Start($PowerCfg, "-change -disk-timeout-dc $ScreenTime")
    $ProcessHibernateTimeoutAC = [System.Diagnostics.Process]::Start($PowerCfg, "-change -hibernate-timeout-ac $ScreenTime")
    $ProcessHibernateTimeoutDC = [System.Diagnostics.Process]::Start($PowerCfg, "-change -hibernate-timeout-dc $ScreenTime")


    $Processes = @($ProcessMonitorTimeoutAC, $ProcessMonitorTimeoutDC, $ProcessStandbayTimeoutAC, $ProcessStandbayTimeoutDC, $ProcessDiskTimeoutAC, $ProcessDiskTimeoutDC, $ProcessHibernateTimeoutAC, $ProcessHibernateTimeoutDC)
    $ProcessCounter = 0
    foreach ($Process in $Processes) {
        $Process.WaitForExit()
        if ($Process.ExitCode -ne 0) {
            Write-Log -Level "ERROR" -Message "process $($ProcessCounter) didn't work exactly as planned, $($Process.ExitCode) exit code."
        }
        $ProcessCounter++
    }
    
    Write-Log -Level "INFO" -Message "FINISHED LOADING "

}

Function Write-Log {
    <#
    .SYNOPSIS
    writes log to file, if file is not given, logs to stdout.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory = $True)]
        [AllowEmptyString()]
        [string]
        $Message,

        [Parameter(Mandatory = $False)]
        [string]
        $LogFile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If ($LogFile) {
        Add-Content $LogFile -Value $Line
    }
    # Else { #TODO: return
        Write-Output $Line
    # }
}


