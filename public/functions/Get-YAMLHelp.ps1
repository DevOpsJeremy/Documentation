function Get-YAMLHelp
{
    <#
        .SYNOPSIS
            Programmatically gets the "comment-based help" information from a YAML file.

        .DESCRIPTION
            This function takes a YAML file and captures the "comment-based help" information from the file, then returns it as an object with those keywords.

            The function accepts the following comment-based help keywords:
                - SYNOPSIS
                - DESCRIPTION
                - EXAMPLE
                - INPUTS
                - OUTPUTS
                - NOTES
                - LINK
                - COMPONENT
                - FUNCTIONALITY
                - ROLE

        .OUTPUTS
            YAMLHelpInfo

        .PARAMETER Path
            Path of the YAML file.

        .EXAMPLE
            PS > Get-YAMLHelp -Path file.yml `
            Synopsis    : Creates a new EC2 instance `
            Description : {This playbook creates a new EC2 instance.} `
            Examples    : {Get-YAMLHelp.YAMLExample} `
            Inputs      : {region, instance_name} `
            Outputs     : `
            Notes       : `
            Link        : `
            Role        :

        .Notes
            Version: 0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.IO.FileInfo] $Path
    )
    #region Functions
    function Get-HelpProperties {
        function Get-KeywordInfo {
            [string] $keywordPattern = '(?<=\s*#\s*\.)\w+'
            [System.Text.RegularExpressions.Match] $regex = [regex]::Match($line, $keywordPattern)
            $keywordEnum = [CommentBasedHelpKeyword]::$($regex.Value)
            if (![string]::IsNullOrEmpty($keywordEnum)){
                return [YAMLKeywordInfo] @{
                    Keyword = [CommentBasedHelpKeyword]::$($regex.Value)
                    StartIndex = $regex.Index
                }
            }
        }
        function Get-Keyword {
            return (Get-KeywordInfo).Keyword
        }
        function Get-KeywordCheck {
            return ![string]::IsNullOrEmpty((Get-Keyword))
        }
        [string[]] $lines = Get-Content -Path (Resolve-Path $Path)
        [int] $lineCount = [int]::new()
        [string[]] $values = @()
        [YAMLHelpProperty[]] $helpProperties = @()
        while (($line = $lines[$lineCount]) -match '^\s*(|#.*)$') {
            if ($line.Trim()){
                $keywordCheck = Get-KeywordCheck
                if ($keywordCheck){
                    if ($keywordInfo){
                        $helpProperties += [YAMLHelpProperty] @{
                            Keyword = $keywordInfo.Keyword
                            Value = $values
                        }
                    }
                    [string[]] $values = @()
                    [YAMLKeywordInfo] $keywordInfo = Get-KeywordInfo
                } else {
                    $values += switch ($keywordInfo.Keyword){
                        Example {
                            $line.Substring($keywordInfo.StartIndex - 1).TrimEnd()
                        }
                        Default {
                            $line.Trim().TrimStart('#').Trim()
                        }
                    }
                    
                }
            }
            $lineCount++
        }
        if (![string]::IsNullOrEmpty($keywordInfo.Keyword) -and ![string]::IsNullOrEmpty($values)){
            $helpProperties += [YAMLHelpProperty] @{
                Keyword = $keywordInfo.Keyword
                Value = $values
            }
        }
        return $helpProperties
    }
    function Get-YAMLHelpObject {
        $helpProperties = [System.Collections.Hashtable]::new()
        $examples = @()
        $links = @()
        foreach ($prop in Get-HelpProperties){
            switch ($prop){
                { $_.Keyword -eq [CommentBasedHelpKeyword]::DESCRIPTION } {
                    $var = $_
                    try {
                        $helpProperties.Add(
                            (Get-Culture).TextInfo.ToTitleCase($var.Keyword.ToString().ToLower()),
                            [YAMLDescription]@{
                                Text = $var.Value
                            }
                        )
                    } catch {
                        throw "Duplicate property: $($var.Keyword)."
                        exit 1
                    }
                }
                { $_.Keyword -eq [CommentBasedHelpKeyword]::EXAMPLE } {
                    $examples += [YAMLExample] @{
                        example = [YAMLCode] @{
                            code = $_.Value -join "`n"
                        }
                    }
                }
                { $_.Keyword -eq [CommentBasedHelpKeyword]::NOTES } {
                    $var = $_
                    try {
                        $helpProperties.Add(
                            'alertSet',
                            [YAMLAlertSet]@{
                                alert = [YAMLAlert] @{
                                        text = $var.Value
                                    }
                            }
                        )
                    } catch {
                        throw "Duplicate property: alertSet."
                        exit 1
                    }
                }
                { $_.Keyword -eq [CommentBasedHelpKeyword]::LINK } {
                    $linkType = if ($_.Value -match 'https?:\/\/(.+\.)+\w+\/?[^\s\t\n\r]*'){
                        'uri'
                    } else {
                        'linkText'
                    }
                    $links += [YAMLRelatedLink] @{
                        navigationLink = [YAMLNavigationLink] @{
                            $linkType = $_.Value[0]
                        }
                    }
                }
                Default {
                    $var = $_
                    try {
                        $helpProperties.Add((Get-Culture).TextInfo.ToTitleCase($var.Keyword.ToString().ToLower()), $var.Value)
                    } catch {
                        throw "Duplicate property: $($var.Keyword)."
                        exit 1
                    }
                }
            }
        }
        $helpProperties["Examples"] = $examples
        $helpProperties["RelatedLinks"] = $links
        $helpProperties["Name"] = $Path.FullName
        return [YAMLHelpInfo] $helpProperties
    }
    #endregion Functions
    return Get-YAMLHelpObject
}
