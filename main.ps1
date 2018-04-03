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

    # backup and save files.
    BackUpFiles(sorce, dest);
    InstallPrograms(ConfigFilePath);

    # additional wanted computer settings.
    ChnageBackgroundRandomized(FolderPath);
    StopWindowsAutomaticUpdates();



}

function BackUpFiles(SourceFolder, DestinationFolder) {
    <#
    .SYNOPSIS
    copies folder from source to destination
    #>


}

function InstallPrograms (ConfigFilePath) {
    <#
    .SYNOPSIS
    install programs unattendedly from the configuration file given
    
    .DESCRIPTION
    from the configuraiton, get the program name, file path and argumnets,
    execute the file with the arguments, and then write indicative log to log file, otherwise the standard input.
    
    #>

    GetConfiguration(ConfigFilePath)

}

function ChnageBackgroundRandomized () {
    <#
    .SYNOPSIS
    get a folder's path that has pictures in it, choose one randomly, and then sets its as the background.
    #>
    
}

function StopWindowsAutomaticUpdates () {
    <#
    .SYNOPSIS
    stops windows automatic updates.
    #>
}

function SetWindowsScreenTime (ScreenTime) {
    <#
    .SYNOPSIS
    sets the time of screen for windows until he goes to sleep (-1 for never sleep.)
    #>
}