# Global variables
$GameFolder = "C:\SteamCMD\steamapps\common\The Isle Dedicated Server\TheIsle\Saved\"
$GameINI = $GameFolder+"Config\WindowsServer\Game.ini"
$GameLOG = $GameFolder+"Logs\TheIsle.log"
$ServerJsonFile = "server.json"
$PlayersJsonFile = "players.json"
$ServerSecretFile = "ServerSecret.txt"

function Display-Dino
{
    Param(
        $_Dino,
        $_DinoParams,
        $_PlayerName,
        $_SteamID
    )
    write-host "---------- $_SteamID | $_PlayerName --------------"
    write-host "# $_Dino #"
    ForEach ($_Param in $_DinoParams.keys)
    {
        write-host "|"$_Param": $($_DinoParams[$_Param])"
    }
    write-host "#############################################################################"
}

function Display-Player
{
    Param(
        $_Player,
        $_SteamID
    )
    write-host "---------- $_SteamID | $($_Player["Name"]) --------------"
    ForEach ($_Dino in $_Player.keys)
    {
        if ($_Dino -ne "Name")
        {
            write-host "| $_Dino ----"
            $_Player[$_Dino]
        }
    }
    write-host "#############################################################################"
}

function Display-PlayerTable
{
    Param(
        $_PlayerTable
    )
    $_PlayerTable.keys
    ForEach ($_Player in $_PlayerTable.keys)
    {
        write-host "---------- $_Player | $($_PlayerTable[$_Player]["Name"]) --------------"
        ForEach ($_Dino in $_PlayerTable[$_Player].keys)
        {
            if ($_Dino -ne "Name")
            {
                write-host "| $_Dino ----"
                $_PlayerTable[$_Player][$_Dino]
            }
        }
    }
    write-host "#############################################################################"
}

function Get-AdminsJSON
{
    $_AdminsJSON = @()
    Select-String -Path $GameINI -Pattern "AdminsSteamIDs" | % {
        $_AdminsJSON += @{SteamID = $_.Line.Split('=')[1]}
    }
    return $_AdminsJSON
}

function Get-PlayersJSON
{
    $_PlayersJSON = @()
    #$_PhillipJSON = @()
    ForEach ($_Player in $PlayerTable.keys)
    {
        # no more array for each dino
        <#
        [int64]$_lastEpoch = 0
        [string]$_latestDino = ""
        ForEach ($_Dino in $PlayerTable[$_Player].keys)
        {
            #if ($_Player -eq "76561197960267552")
            #{
            #    $_PhillipJSON += @{
            #        SteamID=$_Player
            #        UpdateEpoch=$PlayerTable[$_Player][$_Dino]["UpdateEpoch"]
            #        DinoSpecies=$_Dino
            #        Coordinates="-1,-1"
            #        Yaw="1"
            #        HerdID="0123456789"
            #        Growth=$PlayerTable[$_Player][$_Dino]["Growth"]
            #        Health="100.0"
            #        Stamina="100.0"
            #        Hunger="100.0"
            #        Thirst="100.0"
            #    }
            #       
            #}
            # iterate through all dinos that the player has a savegame for, choose the latest one
            if ($_Dino -ne "Name")
            {
                if ($_lastEpoch -lt $PlayerTable[$_Player][$_Dino]["UpdateEpoch"])
                {
                    $_lastEpoch = $PlayerTable[$_Player][$_Dino]["UpdateEpoch"]
                    $_latestDino = $_Dino
                }
            }
        }
        #>
        # known bug: if there is only one player: powershell will not properly follow what we want here (add a hash table to an array) but just create a hashtable - or this is messed up by the ConvertTo-Json which will later try to transform this into proper JSON...
        $_PlayersJSON += @{
            SteamID=$_Player
            #UpdateEpoch=$PlayerTable[$_Player][$_latestDino]["UpdateEpoch"]
            UpdateEpoch=$PlayerTable[$_Player]["UpdateEpoch"]
            #DinoSpecies=$_latestDino
            DinoSpecies=$PlayerTable[$_Player]["DinoSpecies"]
            Coordinates="-1,-1"
            Yaw="1"
            HerdID="0123456789"
            #Growth=$PlayerTable[$_Player][$_latestDino]["Growth"]
            Growth=$PlayerTable[$_Player]["Growth"]
            Health="100.0"
            Stamina="100.0"
            Hunger="100.0"
            Thirst="100.0"
        }
        #$_PhillipJSON | ConvertTo-Json -Depth 2 | Out-File "phillip.json"
    }
    return $_PlayersJSON
}

function Store-PlayerJSON
{
    Param(
        $_PlayerJsonFile
    )
    $_PlayerJSON = @{Admins=Get-AdminsJSON; Players=Get-PlayersJSON}
    # test output of JSON - the ConvertTo-Json needs a depth parameter to cover all subelements of the hashtable - we could just set this to 9999 to catch everything ever.
    $_PlayerJSON | ConvertTo-Json -Depth 2 | Out-File $_PlayerJsonFile
}

function Get-ServerIdentity
{
    Param(
        $_ServerJsonFile
    )
    Select-String -Path $_ServerJsonFile -Pattern "ServerID" | % {
        $_ServerID = $_.Line.Split('"')[3]
    }
    Select-String -Path $_ServerJsonFile -Pattern "ServerName" | % {
        $_ServerName = $_.Line.Split('"')[3]
    }
    $_ServerIdentity = @{ServerID=$_ServerID; ServerName=$_ServerName}
    return $_ServerIdentity
}

function Store-ServerJSON
{
    Param(
        $_GameINI,
        $_ServerJsonFile
    )
    Select-String -Path $_GameINI -Pattern "ServerName" | % {
        $_ServerName = $_.Line.Split('=')[1]
    }
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash?view=powershell-7.1#example-4--compute-the-hash-of-a-string
    # >>
    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write("$_ServerName")
    $writer.Flush()
    $stringAsStream.Position = 0
    $_ServerID = Get-FileHash -Algorithm MD5 -InputStream $stringAsStream | %{$_.Hash.SubString(0,6)}
    # <<
    $_ServerJSON = @{ServerID=$_ServerID; ServerName=$_ServerName; ServerMap="Isla_Spiro"}
    $_ServerJSON | ConvertTo-Json -Depth 2 | Out-File $_ServerJsonFile
}

function CheckAPIAccess
{
    Param(
        $_ServerJsonFile,
        $_ServerSecretFile
    )
    if (!(Test-Path -Path $_ServerSecretFile -PathType leaf))
    {
        Write-Host "Start server registration"
        ServerRegistration $_ServerJsonFile $_ServerSecretFile
    }
    else
    {
        [string]$_ServerSecret = Get-Content -Raw $_ServerSecretFile
        if ([string]::IsNullOrEmpty($_ServerSecret))
        {
            echo "ServerSecret missing from $_ServerSecretFile."
            echo "If you have a backup of this file then restore it - if you lost your ServerSecret then reach out to the TI-Nav dev."
            echo "If you never registered this TI server to TI-Nav.net then try to delete $_ServerSecretFile and re-run TI-Nav-Collector"
            exit
        }
        else
        {
            $_ServerIdentity = Get-ServerIdentity $_ServerJsonFile
            $_headers = @{'X-TINav-ServerID' = $_ServerIdentity["ServerID"]}
            $_URL = "https://ti-nav.net/apis/server-registration-api.php"
            try {
                $_ServerRegistrationResponse = Invoke-WebRequest -Method 'HEAD' -Headers $_headers -Uri $_URL
                $_ServerRegistrationResponseBody = $_ServerRegistrationResponse.Content
                $_StatusCode = $_ServerRegistrationResponse.BaseResponse.StatusCode.Value__
            }
            catch [System.Net.WebException] {
                $_ServerRegistrationResponseBody = $_
                [int]$_StatusCode = $_.Exception.Response.StatusCode
            }
            switch ($_StatusCode)
            {
                202 {
                    return $true
                }
                403 {
                    Write-Host
                    Write-Host " This TI server has been registered @ TI-Nav.net but it is not enabled atm!"
                    Write-Host
                    Write-Host " If you see this message for the first time then please firmly introduce yourselve here:"
                    Write-Host " https://github.com/sock3t/TI-Nav-Collector/discussions?discussions_q=category%3A%22Join+ALPHA+Testing%22"
                    Write-Host
                    Write-Host " Please incl. this information with your introduction:"
                    Write-Host "  ----------------------------------------------------------"
                    Write-Host " | ServerID:`t"$_ServerIdentity["ServerID"]
                    Write-Host " | ServerName:`t"$_ServerIdentity["ServerName"]
                    Write-Host "  ----------------------------------------------------------"
                    Write-Host
                    Write-Host " Additionally please describe the average amount of player usually playing on your server."
                    Write-Host
                    Write-Host " This information will greatly help with alpha testing and resource planing!"
                    Write-Host " Thanks a lot for your interest and participation during alpha testing!"
                    return $false
                }
                405 {
                    Write-Host "Bad method. The TI-Nav-Collector script might have been modified or there is a man in the middle tampering going on."
                    exit
                }
                404 {
                    Write-Host "Unknown ServerID: "$_ServerIdentity["ServerID"]
                    Write-Host "This TI server is not registered @ TI-Nav.net."
                    Write-Host "Yet there is a $_ServerSecretFile with a ServerSecretID inside."
                    Write-Host "In case this TI server has been renamed recently: Make a backup copy of the $_ServerSecretFile (you might want to return to the old server name) and re-run TI-Nav-Collector"
                    Write-Host "In case the TI-Nav-Collector worked before and the TI Server was not renamed please reach out to the TI-Nav dev."
                    Write-Host "Exiting."
                    exit
                }
                500 {
                    Write-Host "Server side issue. Please inform the TI-Nav developer. Exiting"
                    exit
                }
                default {
                    Write-Host "Unknown registration HEAD issue. Exiting."
                    exit
                }
            }
        }
    }
}

function ServerRegistration
{
    Param(
        $_ServerJsonFile,
        $_ServerSecretFile
    )
    $_URL = "https://ti-nav.net/apis/server-registration-api.php"
    $_content = Get-Content -Raw $_ServerJsonFile
    #$_content -replace "`n","" -replace "`r",""
    try {
        $_ServerRegistrationResponse = Invoke-WebRequest -Method 'POST' -ContentType 'application/json' -body $_content -Uri $_URL
        $_ServerRegistrationResponseBody = $_ServerRegistrationResponse.Content
        $_StatusCode = $_ServerRegistrationResponse.BaseResponse.StatusCode.Value__

    }
    catch [System.Net.WebException] {
        $_ServerRegistrationResponseBody = $_
        [int]$_StatusCode = $_.Exception.Response.StatusCode
    }
    switch ($_StatusCode)
    {
        200 {
            $_ServerRegistrationResponseBody | Out-File $_ServerSecretFile
            Write-Host "Server registration successful."
            break
        }
        400 {
            Write-Host -NoNewline "Server registration failed, we did not send proper json formatted data ($_StatusCode): "
            write-host $_ServerRegistrationResponseBody
            exit
        }
        409 {
            Write-Host -NoNewline "Server registration failed, conflict ($_StatusCode): "
            write-host $_ServerRegistrationResponseBody
            exit
        }
        415 {
            Write-Hos -NoNewlinet "Server registration failed, we did not use the proper conten type ($_StatusCode): "
            write-host $_ServerRegistrationResponseBody
            exit
        }
        default {
            Write-Host -NoNewline "Server registration failed, unknown status code ($_StatusCode): "
            write-host $_ServerRegistrationResponseBody
            exit
        }
    }
}

function SendPlayerJSON
{
    Param(
        $_ServerJsonFile,
        $_PlayerJsonFile,
        $_ServerSecretFile
    )
    # no more stopwatch checking - we can afford to send player data for every one of the captured events.
    #if ($stopWatch.Elapsed -ge $timeSpan)
    #{
        Write-Host "Sending latest JSON to TI-Nav"
        [string]$_ServerSecret = Get-Content -Raw $_ServerSecretFile
        $_ServerIdentity = Get-ServerIdentity $_ServerJsonFile
        [string]$_ServerID = $_ServerIdentity["ServerID"]
        $_headers = @{'X-TINav-ServerID' = $_ServerID; 'X-TINav-ServerSecretID' = $_ServerSecret}
        $_URL="https://ti-nav.net/apis/server-push-api.php"

        $_content = Get-Content -Raw $_PlayerJsonFile
        #$_content -replace "`n","" -replace "`r",""
        try {
            $_ServerRegistrationResponse = Invoke-WebRequest -Method 'POST' -ContentType 'application/json' -Headers $_headers -body $_content -Uri $_URL
            $_ServerRegistrationResponseBody = $_ServerRegistrationResponse.Content
            $_StatusCode = $_ServerRegistrationResponse.BaseResponse.StatusCode.Value__

        }
        catch [System.Net.WebException] {
            $_ServerRegistrationResponseBody = $_
            [int]$_StatusCode = $_.Exception.Response.StatusCode
        }
        # we do nothing for now - maybe some more exception handling would be good :)
        Write-Host -NoNewline "HTTP Response ($_StatusCode): "
        write-host $_ServerRegistrationResponseBody
        #$stopWatch.Reset()
        #$stopWatch.Start()
    #}
}

######################
#       Main         #
######################

Store-ServerJSON $GameINI $ServerJsonFile
While (!(CheckAPIAccess $ServerJsonFile $ServerSecretFile))
{
    Write-Host
    Write-Host " -- Retrying whether server is enabled every 5 minutes:"
    Start-Sleep -s 3
    Clear-Host
}

# setup global stop watch - it will be accessed from the SendPlayerJSON function:
#$stopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
#$timeSpan = New-TimeSpan -Seconds 10
#$stopWatch.Start()

$PlayerTable = @{}
# just 100 lines for testing & debugging
# we don't have to parse the entire log file, yet this can help to bulk load from older log files etc. So we keep it this way.
#get-content $GameLOG -wait -tail 100 | % {
get-content $GameLOG -wait | % {
    switch -regex ($_)
    {
        'LogTheIsleKillData' {
            $_logline = $_ -replace "[-,:\[\]]",'|'
            $_array = $_logline.split('|')
            switch ($_array[17].Trim())
            {
                'Died from Natural cause' {
                    # Do we have a table entry for this SteamID already - if not create one and set Playername.
                    $_SteamID = $_array[12]
                    if (!$PlayerTable[$_SteamID])
                    {
                        $PlayerTable[$_SteamID] = @{}
                        $PlayerTable[$_SteamID]["Name"] = $_array[11].Trim()
                    }
                    # Do we have a Dino of this spezies for this player already - if not create one.
                    # This becomes obsolete now - we do this on the server side again. So no more growth comparison, no need to store an array of all Dinos a player played so far. Just send the latest state.
                    $_Dino = "BP_"+$_array[14].Trim()+"_C"
                    <#
                    if (!$PlayerTable[$_SteamID][$_Dino])
                    {
                        $PlayerTable[$_SteamID][$_Dino] = @{}
                    }
                    #>
                    # Does the player have already the same dino with larger growth - then prevent overwriting the progress/state for this one
                    # This becomes obsolete now - we do this on the server side again. So no more growth comparison, no need to store an array of all Dinos a player played so far. Just send the latest state.
                    # Growth in %
                    #$_Growth = [int]([decimal]$_array[16].Trim() * 100)
                    # growth in decimal notation - likely more convenient for copy&paste into the in-game UI
                    $_Growth = [decimal]$_array[16].Trim()
                    <#
                    if ($PlayerTable[$_SteamID][$_Dino]["Growth"] -le $_Growth)
                    {
                    #>
                        #$PlayerTable[$_SteamID][$_Dino]["Date"] = $_array[1].Trim()
                        #$PlayerTable[$_SteamID][$_Dino]["Time"] = $_array[2].Trim()
                        #$PlayerTable[$_SteamID][$_Dino]["msec"] = $_array[3].Trim()
                        $_date = $_array[1].Trim().Replace(".","/")
                        $_time = $_array[2].Trim().Replace(".",":")
                        $_msec = $_array[3].Trim()
                        $_DateTimeString = "$_date $_time.$_msec"
                        
                        <#
                        $PlayerTable[$_SteamID][$_Dino]["UpdateEpoch"] = [int64](New-TimeSpan -Start $(Get-Date -Date "01/01/1970") -End $_DateTimeString).TotalMilliseconds
                        $PlayerTable[$_SteamID][$_Dino]["Gender"] = $_array[15].Trim()
                        $PlayerTable[$_SteamID][$_Dino]["Growth"] = $_Growth
                        $PlayerTable[$_SteamID][$_Dino]["State"] = $_array[17].Trim()
                        #>
                        # no more array for each Dino, just the current
                        $PlayerTable[$_SteamID]["UpdateEpoch"] = [int64](New-TimeSpan -Start $(Get-Date -Date "01/01/1970") -End $_DateTimeString).TotalMilliseconds
                        $PlayerTable[$_SteamID]["Gender"] = $_array[15].Trim()
                        $PlayerTable[$_SteamID]["Growth"] = $_Growth
                        $PlayerTable[$_SteamID]["State"] = $_array[17].Trim()
                        $PlayerTable[$_SteamID]["DinoSpecies"] = $_Dino
                        #Display-PlayerTable $PlayerTable
                        #Display-Player $PlayerTable[$_SteamID]
                        #Display-Dino $_Dino $PlayerTable[$_SteamID][$_Dino] $PlayerTable[$_SteamID]["Name"] $_SteamID
                        Store-PlayerJSON $PlayersJsonFile
                        # only send if the current log entries' timestamp is close to current time (otherwise this is crawling old logs which don't have to be send)
                        $__currdate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,"UTC")
                        $__timediff = [int64](New-TimeSpan -Start $_DateTimeString -End $__currdate).TotalMinutes
                        write-host -NoNewline ";"
                        if ($__timediff -eq 0)
                        {
                            SendPlayerJSON $ServerJsonFile $PlayersJsonFile $ServerSecretFile
                        }
                    <#
                    }
                    #>
                }
                'Killed the following player' {
                    # Do we have a table entry for this SteamID already - if not create one and set Playername.
                    $_SteamID = $_array[21]
                    if (!$PlayerTable[$_SteamID])
                    {
                        $PlayerTable[$_SteamID] = @{}
                        $PlayerTable[$_SteamID]["Name"] = $_array[19].Trim()
                    }
                    # Do we have a Dino of this spezies for this player already - if not create one.
                    # This becomes obsolete now - we do this on the server side again. So no more growth comparison, no need to store an array of all Dinos a player played so far. Just send the latest state.
                    $_Dino = "BP_"+$_array[24].Trim()+"_C"

                    <#
                    if (!$PlayerTable[$_SteamID][$_Dino])
                    {
                        $PlayerTable[$_SteamID][$_Dino] = @{}
                    }
                    #>

                    # Does the player have already the same dino with larger growth - then prevent overwriting the progress/state for this one
                    # This becomes obsolete now - we do this on the server side again. So no more growth comparison, no need to store an array of all Dinos a player played so far. Just send the latest state.
                    # Growth in %
                    #$_Growth = [int]([decimal]$_array[28].Trim() * 100)
                    # growth in decimal notation - likely more convenient for copy&paste into the in-game UI
                    $_Growth = [decimal]$_array[28].Trim()

                    <#
                    if ($PlayerTable[$_SteamID][$_Dino]["Growth"] -le $_Growth)
                    {
                    #>

                        #$PlayerTable[$_SteamID][$_Dino]["Date"] = $_array[1].Trim()
                        #$PlayerTable[$_SteamID][$_Dino]["Time"] = $_array[2].Trim()
                        #$PlayerTable[$_SteamID][$_Dino]["msec"] = $_array[3].Trim()
                        $_date = $_array[1].Trim().Replace(".","/")
                        $_time = $_array[2].Trim().Replace(".",":")
                        $_msec = $_array[3].Trim()
                        $_DateTimeString = "$_date $_time.$_msec"

                        <#
                        $PlayerTable[$_SteamID][$_Dino]["UpdateEpoch"] = [int64](New-TimeSpan -Start $(Get-Date -Date "01/01/1970") -End $_DateTimeString).TotalMilliseconds
                        $PlayerTable[$_SteamID][$_Dino]["Gender"] = $_array[26].Trim()
                        $PlayerTable[$_SteamID][$_Dino]["Growth"] = $_Growth
                        $PlayerTable[$_SteamID][$_Dino]["State"] = "Killed by " + $_SteamID.Trim()
                        #>
                        # no more array for each Dino, just the current
                        $PlayerTable[$_SteamID]["UpdateEpoch"] = [int64](New-TimeSpan -Start $(Get-Date -Date "01/01/1970") -End $_DateTimeString).TotalMilliseconds
                        $PlayerTable[$_SteamID]["Gender"] = $_array[26].Trim()
                        $PlayerTable[$_SteamID]["Growth"] = $_Growth
                        $PlayerTable[$_SteamID]["State"] = "Killed by " + $_SteamID.Trim()
                        $PlayerTable[$_SteamID]["DinoSpecies"] = $_Dino
                        #Display-PlayerTable $PlayerTable
                        #Display-Player $PlayerTable[$_SteamID]
                        #Display-Dino $_Dino $PlayerTable[$_SteamID][$_Dino] $PlayerTable[$_SteamID]["Name"] $_SteamID
                        Store-PlayerJSON $PlayersJsonFile
                        $__currdate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,"UTC")
                        $__timediff = [int64](New-TimeSpan -Start $_DateTimeString -End $__currdate).TotalMinutes
                        write-host -NoNewline ":"
                        if ($__timediff -eq 0)
                        {
                            SendPlayerJSON $ServerJsonFile $PlayersJsonFile $ServerSecretFile
                        }
                    <#
                    }
                    #>
                }
            }
        }
        'LogTheIsleJoinData' {
            $_logline = $_ -replace "[-,:\[\]]",'|'
            $_array = $_logline.split('|')
            $_event = $_array[13].Trim()
            switch ($_event)
            {
                'Left The Server' {
                    # Do we have a table entry for this SteamID already - if not create one and set Playername.
                    $_SteamID = $_array[12]
                    if (!$PlayerTable[$_SteamID])
                    {
                        $PlayerTable[$_SteamID] = @{}
                        $PlayerTable[$_SteamID]["Name"] = $_array[11].Trim()
                    }
                    # Do we have a Dino of this spezies for this player already - if not create one.
                    # This becomes obsolete now - we do this on the server side again. So no more growth comparison, no need to store an array of all Dinos a player played so far. Just send the latest state.
                    $_Dino = "BP_"+$_array[15].Trim()+"_C"

                    <#
                    if (!$PlayerTable[$_SteamID][$_Dino])
                    {
                        $PlayerTable[$_SteamID][$_Dino] = @{}
                    }
                    #>

                    # Does the player have already the same dino with larger growth - then prevent overwriting the progress/state for this one
                    # This becomes obsolete now - we do this on the server side again. So no more growth comparison, no need to store an array of all Dinos a player played so far. Just send the latest state.
                    # Growth in %
                    #$_Growth = [int]([decimal]$_array[19].Trim() * 100)
                    # growth in decimal notation - likely more convenient for copy&paste into the in-game UI
                    $_Growth = [decimal]$_array[19].Trim()

                    <#
                    if ($PlayerTable[$_SteamID][$_Dino]["Growth"] -le $_Growth)
                    {
                    #>
                        #$PlayerTable[$_SteamID][$_Dino]["Date"] = $_array[1].Trim()
                        #$PlayerTable[$_SteamID][$_Dino]["Time"] = $_array[2].Trim()
                        #$PlayerTable[$_SteamID][$_Dino]["msec"] = $_array[3].Trim()
                        $_date = $_array[1].Trim().Replace(".","/")
                        $_time = $_array[2].Trim().Replace(".",":")
                        $_msec = $_array[3].Trim()
                        $_DateTimeString = "$_date $_time.$_msec"

                        <#
                        $PlayerTable[$_SteamID][$_Dino]["UpdateEpoch"] = [int64](New-TimeSpan -Start $(Get-Date -Date "01/01/1970") -End $_DateTimeString).TotalMilliseconds
                        $PlayerTable[$_SteamID][$_Dino]["Gender"] = $_array[17].Trim()
                        $PlayerTable[$_SteamID][$_Dino]["Growth"] = $_Growth
                        $PlayerTable[$_SteamID][$_Dino]["State"] = $_event
                        #>
                        # no more array for each Dino, just the current
                        $PlayerTable[$_SteamID]["UpdateEpoch"] = [int64](New-TimeSpan -Start $(Get-Date -Date "01/01/1970") -End $_DateTimeString).TotalMilliseconds
                        $PlayerTable[$_SteamID]["Gender"] = $_array[17].Trim()
                        $PlayerTable[$_SteamID]["Growth"] = $_Growth
                        $PlayerTable[$_SteamID]["State"] = $_event
                        $PlayerTable[$_SteamID]["DinoSpecies"] = $_Dino
                        #Display-PlayerTable $PlayerTable
                        #Display-Player $PlayerTable[$_SteamID]
                        #Display-Dino $_Dino $PlayerTable[$_SteamID][$_Dino] $PlayerTable[$_SteamID]["Name"] $_SteamID
                        Store-PlayerJSON $PlayersJsonFile
                        $__currdate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,"UTC")
                        $__timediff = [int64](New-TimeSpan -Start $_DateTimeString -End $__currdate).TotalMinutes
                        write-host -NoNewline "-"
                        if ($__timediff -eq 0)
                        {
                            SendPlayerJSON $ServerJsonFile $PlayersJsonFile $ServerSecretFile
                        }
                    <#
                    }
                    #>
                }
                'Joined The Server. Save file found Dino' {
            # output the arry with index numbers - so we can choose the correct items
            #for($i=0;$i -le $_array.length-1;$i++)
            #{
            #    write-host $i ":" $_array[$i]
            #}
            #exit
                    # Do we have a table entry for this SteamID already - if not create one and set Playername.
                    $_SteamID = $_array[12]
                    if (!$PlayerTable[$_SteamID])
                    {
                        $PlayerTable[$_SteamID] = @{}
                        $PlayerTable[$_SteamID]["Name"] = $_array[11].Trim()
                    }
                    # Do we have a Dino of this spezies for this player already - if not create one.
                    # This becomes obsolete now - we do this on the server side again. So no more growth comparison, no need to store an array of all Dinos a player played so far. Just send the latest state.
                    $_Dino = "BP_"+$_array[14].Trim()+"_C"

                    <#
                    if (!$PlayerTable[$_SteamID][$_Dino])
                    {
                        $PlayerTable[$_SteamID][$_Dino] = @{}
                    }
                    #>

                    # Does the player have already the same dino with larger growth - then prevent overwriting the progress/state for this one
                    # This becomes obsolete now - we do this on the server side again. So no more growth comparison, no need to store an array of all Dinos a player played so far. Just send the latest state.
                    # Growth in %
                    #$_Growth = [int]([decimal]$_array[20].Trim() * 100)
                    # growth in decimal notation - likely more convenient for copy&paste into the in-game UI
                    $_Growth = [decimal]$_array[18].Trim()

                    <#
                    if ($PlayerTable[$_SteamID][$_Dino]["Growth"] -le $_Growth)
                    {
                    #>

                        #$PlayerTable[$_SteamID][$_Dino]["Date"] = $_array[1].Trim()
                        #$PlayerTable[$_SteamID][$_Dino]["Time"] = $_array[2].Trim()
                        #$PlayerTable[$_SteamID][$_Dino]["msec"] = $_array[3].Trim()
                        $_date = $_array[1].Trim().Replace(".","/")
                        $_time = $_array[2].Trim().Replace(".",":")
                        $_msec = $_array[3].Trim()
                        $_DateTimeString = "$_date $_time.$_msec"

                        <#
                        $PlayerTable[$_SteamID][$_Dino]["UpdateEpoch"] = [int64](New-TimeSpan -Start $(Get-Date -Date "01/01/1970") -End $_DateTimeString).TotalMilliseconds
                        $PlayerTable[$_SteamID][$_Dino]["Gender"] = $_array[16].Trim()
                        $PlayerTable[$_SteamID][$_Dino]["Growth"] = $_Growth
                        $PlayerTable[$_SteamID][$_Dino]["State"] = $_event
                        #>
                        # no more array for each Dino, just the current
                        $PlayerTable[$_SteamID]["UpdateEpoch"] = [int64](New-TimeSpan -Start $(Get-Date -Date "01/01/1970") -End $_DateTimeString).TotalMilliseconds
                        $PlayerTable[$_SteamID]["Gender"] = $_array[16].Trim()
                        $PlayerTable[$_SteamID]["Growth"] = $_Growth
                        $PlayerTable[$_SteamID]["State"] = $_event
                        $PlayerTable[$_SteamID]["DinoSpecies"] = $_Dino
                        #Display-PlayerTable $PlayerTable
                        #Display-Player $PlayerTable[$_SteamID]
                        #Display-Dino $_Dino $PlayerTable[$_SteamID][$_Dino] $PlayerTable[$_SteamID]["Name"] $_SteamID
                        Store-PlayerJSON $PlayersJsonFile
                        $__currdate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,"UTC")
                        $__timediff = [int64](New-TimeSpan -Start $_DateTimeString -End $__currdate).TotalMinutes
                        write-host -NoNewline ","
                        if ($__timediff -eq 0)
                        {
                            SendPlayerJSON $ServerJsonFile $PlayersJsonFile $ServerSecretFile
                        }
                    <#
                    }
                    #>
                }
            }
        }
        'LogTheIsleCharacter' {
            $_logline = $_ -replace "[-,:\[\]]",'|'
            $_array = $_logline.split('|')
            # output the arry with index numbers - so we can choose the correct items
            #for($i=0;$i -le $_array.length-1;$i++)
            #{
            #    write-host $i ":" $_array[$i]
            #}
            #exit
            $_event = $_array[22].Trim()
            switch ($_event)
            {
                'Rest' {
                    # Do we have a table entry for this SteamID already - if not create one and set Playername.
                    $_SteamID = $_array[12]
                    if (!$PlayerTable[$_SteamID])
                    {
                        $PlayerTable[$_SteamID] = @{}
                        $PlayerTable[$_SteamID]["Name"] = $_array[11].Trim()
                    }
                    # Do we have a Dino of this spezies for this player already - if not create one.
                    # This becomes obsolete now - we do this on the server side again. So no more growth comparison, no need to store an array of all Dinos a player played so far. Just send the latest state.
                    $_Dino = "BP_"+$_array[15].Trim()+"_C"

                    <#
                    if (!$PlayerTable[$_SteamID][$_Dino])
                    {
                        $PlayerTable[$_SteamID][$_Dino] = @{}
                    }
                    #>

                    # Does the player have already the same dino with larger growth - then prevent overwriting the progress/state for this one
                    # This becomes obsolete now - we do this on the server side again. So no more growth comparison, no need to store an array of all Dinos a player played so far. Just send the latest state.
                    # Growth in %
                    #$_Growth = [int]([decimal]$_array[19].Trim() * 100)
                    # growth in decimal notation - likely more convenient for copy&paste into the in-game UI
                    $_Growth = [decimal]$_array[19].Trim()

                    <#
                    if ($PlayerTable[$_SteamID][$_Dino]["Growth"] -le $_Growth)
                    {
                    #>

                        #$PlayerTable[$_SteamID][$_Dino]["Date"] = $_array[1].Trim()
                        #$PlayerTable[$_SteamID][$_Dino]["Time"] = $_array[2].Trim()
                        #$PlayerTable[$_SteamID][$_Dino]["msec"] = $_array[3].Trim()
                        $_date = $_array[1].Trim().Replace(".","/")
                        $_time = $_array[2].Trim().Replace(".",":")
                        $_msec = $_array[3].Trim()
                        $_DateTimeString = "$_date $_time.$_msec"

                        <#
                        $PlayerTable[$_SteamID][$_Dino]["UpdateEpoch"] = [int64](New-TimeSpan -Start $(Get-Date -Date "01/01/1970") -End $_DateTimeString).TotalMilliseconds
                        $PlayerTable[$_SteamID][$_Dino]["Gender"] = $_array[17].Trim()
                        $PlayerTable[$_SteamID][$_Dino]["Growth"] = $_Growth
                        $PlayerTable[$_SteamID][$_Dino]["State"] = $_event
                        #>
                        # no more array for each Dino, just the current
                        $PlayerTable[$_SteamID]["UpdateEpoch"] = [int64](New-TimeSpan -Start $(Get-Date -Date "01/01/1970") -End $_DateTimeString).TotalMilliseconds
                        $PlayerTable[$_SteamID]["Gender"] = $_array[17].Trim()
                        $PlayerTable[$_SteamID]["Growth"] = $_Growth
                        $PlayerTable[$_SteamID]["State"] = $_event
                        $PlayerTable[$_SteamID]["DinoSpecies"] = $_Dino
                        #Display-PlayerTable $PlayerTable
                        #Display-Player $PlayerTable[$_SteamID]
                        #Display-Dino $_Dino $PlayerTable[$_SteamID][$_Dino] $PlayerTable[$_SteamID]["Name"] $_SteamID
                        Store-PlayerJSON $PlayersJsonFile
                        $__currdate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,"UTC")
                        $__timediff = [int64](New-TimeSpan -Start $_DateTimeString -End $__currdate).TotalMinutes
                        write-host -NoNewline "_"
                        if ($__timediff -eq 0)
                        {
                            SendPlayerJSON $ServerJsonFile $PlayersJsonFile $ServerSecretFile
                        }
                    <#
                    }
                    #>
                }
            }
        }
    }
}