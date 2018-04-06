New-Variable -Name LogFilePath -Value "c:\windows\temp\LogFileM.txt" -Scope "Global"

### TESTED ON WINDOWS 10 AND 7 ONLY ###

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
    CopyFolder source dest
    InstallPrograms(ConfigFilePath)

    # additional wanted computer settings.
    ChnageBackgroundRandomized(FolderPath)
    StopWindowsAutomaticUpdates



}

function CopyFolder() {
    <#
    .SYNOPSIS
    copies folder from source to destination
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

    Copy-Item -Force -Path $SourceFolder -Destination $DestinationFolder

}

function InstallPrograms () {
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

    function GetInstallationDictionary () {
        <#
        .SYNOPSIS
        create from the config file the installation dictionary (that is combined of file-path and command-arugments)
        #>
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $True)]
            [string]
            $ConfigFilePath
        )

        $InstallationConfig = [xml](Get-Content $ConfigFilePath).programsInstall
        
        ForEach-Object -InputObject ($InstallationConfig.ChildNodes) {
            [System.Diagnostics.Process]::Start($_.executablePath, $_.args)
        }

    }

    $InstllationDictionary = GetInstallationDictionary(ConfigFilePath)


}

function ChangeBackgroundRandomized () {
    <#
    .SYNOPSIS
    get a folder's path that has pictures in it, choose one randomly, and then sets its as the background.
    # TODO: MD5 of SetWallpaper.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $FolderPath
    )

    $BackgroundFilePath = Get-Random -InputObject (Get-ChildItem -File $FolderPath | ForEach-Object {$_.FullName})
    [System.Diagnostics.Process]::Start("SetWallpaper.exe", $BackgroundFilePath)

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
                Write-Log -Level "ERROR" -Message "Failed to disable the 'wuauserv' service. The return value was $result." -LogFile $LogFilePath
            }
            else {Write-Log -Level "INFO" -Message "Success to disable the 'wuauserv' service" -LogFile $LogFilePath}
			
            if ($service.State -eq "Running") {
                # stops the service.
                $result = $service.StopService().ReturnValue
                if ($result) {
                    Write-Log -Level "ERROR" -Message "Failed to stop the 'wuauserv' service. The return value was $result." -LogFile $LogFilePath
                }
                else {Write-Log -Level "INFO" -Message "Success to stop the 'wuauserv' service" -LogFile $LogFilePath}
            }
        }
        else {Write-Log -Level "WARN" -Message "The 'wuauserv' service is already disabled." -LogFile $LogFilePath}
    }
    else {Write-Log -Level "ERROR" -Message "Failed to retrieve the service 'wuauserv'" -LogFile $LogFilePath }
    
}

function SetWindowsScreenTime () {
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
    [System.Diagnostics.Process]::Start($PowerCfg, "-change -monitor-timeout-ac $ScreenTime")
    [System.Diagnostics.Process]::Start($PowerCfg, "-change -monitor-timeout-dc $ScreenTime")
    [System.Diagnostics.Process]::Start($PowerCfg, "-change -standby-timeout-ac $ScreenTime") # TODO: check
    [System.Diagnostics.Process]::Start($PowerCfg, "-change -standby-timeout-dc $ScreenTime") # TODO: check.

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
    Else {
        Write-Output $Line
    }
}


