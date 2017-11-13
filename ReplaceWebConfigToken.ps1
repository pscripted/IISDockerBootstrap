<#
.Synopsis
   Replace tokenized web.config with environment specific web.config
.DESCRIPTION
   Use tokens in the format of '@@tokenname@@' in a web.config file and match them to environment variables and docker secrets that match the token name. 
   Point to a secret in an environment variable with '@@secret:secretname@@'
.EXAMPLE
   Convert-TokenizedWebConfig -WebConfig C:\path\web.docker.config -outputWebConfig=C:\path\Web.config
#>

function Convert-TokenizedWebConfig
{
    [CmdletBinding()]
    Param
    (
        #Input Web Config. Default to file in PWD 
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $WebConfig=".\Web.Docker.config",
        #Output Config
        $outputWebConfig=".\Web.config",
        # Choose Environment Variables Over secrets, by default we use secrets first if both exist
        [switch]
        $EnvPriority
    )

    Process
    {
        if (!(Test-Path $webconfig)) {            
           if (Test-Path ".\Web.config") {
               Write-Verbose "Could not locate input web config path, but found web.config in local folder"
               $WebConfig=".\Web.config"
            }
            else {
                Write-Error "Incorrect Input Web.Config"
                exit
            }
        }
        $WebConfigContent = get-content $WebConfig
        $tokens = @()
        $configmatches = $WebConfigContent -match "@@(.+)@@"
        $matchedTokens = @{}
        foreach ($match in $configmatches) {
            $match | Select-String "@@(.+?)@@" -AllMatches | ForEach-Object{$_.Matches} | ForEach-Object{ $tokens += $_.Value -replace '@@',''}
        }

        foreach ($token in $tokens | Select-Object -Unique) {
            $matchedTokens[$token] = @{}
            Write-Verbose "Searching for token $token"    
            
            #Test for Secret
            if (Test-Path $env:ProgramData\docker\secrets\$token) {
                Write-Verbose "Found secret for $token"
                $matchdata = Get-Content $env:ProgramData\docker\secrets\$token
                $matchedTokens[$token]['secret'] = $matchdata        
            }
            #Test for Variable
            if (Test-Path env:$($token)) {
                $matchedTokens[$token]['envvar'] = (get-item env:${token}).Value
                write-Verbose "Found environment variable for $token"
            }    
        }

        foreach ($token  in $matchedTokens.GetEnumerator()) {
            Write-Output "Replacing $($token.key)"
            #If both exist check which one we use
            if ($token.value.secret -and $token.value.envvar ) {
                if ($EnvPriority) {
                    " With $($token.value.envvar)"
                    #Check if token is using sytax to point to a secret
                    if ($token.value.envvar -match 'secret:(.+)') {
                        if (Test-Path $env:ProgramData\docker\secrets\$($matches[1]) ) {
                            Write-Output "  Matched token to secret: $($matches[1])"
                            $token.value.envvar = Get-Content $env:ProgramData\docker\secrets\$($matches[1])
                        } 
                    }
                    else {
                        Write-Output "Secret pointer does not match secret. Check if Service has rights to secret"
                    }
                    $WebConfigContent = $WebConfigContent -replace "@@$($token.key)@@",$token.value.envvar
                }
                else {
                    $WebConfigContent = $WebConfigContent -replace "@@$($token.key)@@",$token.value.secret
                }
            }
            #If there is just a secret, use it
            elseif ($token.value.secret) {
                $WebConfigContent =  $WebConfigContent -replace "@@$($token.key)@@",$token.value.secret    
            }
            #if there is an environment variable, use it, and check if it points to a secret.
            elseif ($token.value.envvar) {
                Write-Output  " With $($token.value.envvar)"
                #Check if token is using sytax to point to a secret
                if ($token.value.envvar -match 'secret:(.+)') {
                    if (Test-Path $env:ProgramData\docker\secrets\$($matches[1]) ) {
                        Write-Output "  Matched token to secret: $($matches[1])"
                        $token.value.envvar = Get-Content $env:ProgramData\docker\secrets\$($matches[1])
                    } 
                }
                else {
                    Write-Output "Secret pointer does not match secret. Check if Service has rights to secret"
                }
                $WebConfigContent = $WebConfigContent -replace "@@$($token.key)@@",$token.value.envvar
            }
        }
        $WebConfigContent | Out-File $outputWebConfig -Force -Confirm:$false -Encoding utf8
    }
}