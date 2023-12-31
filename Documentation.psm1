<#
    .SYNOPSIS
        Documentation-related functions.

    .DESCRIPTION
        This script imports the following documentation-related functions, as well as any required assemblies:
            - Get-LoremIpsum
            - Get-YAMLHelp
            - New-Documentation

    .Notes
        Version: 0.0
#>
Get-ChildItem (Split-Path $script:MyInvocation.MyCommand.Path) -Filter '*.ps1' -Recurse | ForEach-Object { 
    . $_.FullName 
} 
Get-ChildItem "$(Split-Path $script:MyInvocation.MyCommand.Path)\public\*" -Filter '*.ps1' -Recurse | ForEach-Object { 
    Export-ModuleMember -Function $_.BaseName
}