#http://www.techotopia.com/index.php/Drawing_Graphics_using_PowerShell_1.0_and_GDI%2B
# $arrImage = New-Object 'object[,]' sizeX,sizeY
# [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
# Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Unrestricted

param(
    [bool]$QuickStart = $False,
    [bool]$Debug = $False
)

#$objForm.size = New-Object System.Drawing.Size(($factor * $DrawingSizeX + 16), ($factor * $DrawingSizeY + 38))
#$objForm.size = New-Object System.Drawing.Size(($factor * $DrawingSizeX + 16 + 6), ($factor * $DrawingSizeY + 38 + 18))

#$osVersion = [string](Get-CimInstance Win32_OperatingSystem -Property *)

$wndOffsetX = 16
$wndOffsetY = 38

#Write-Host "OS: $osVersion"

#if($osVersion -like "*Windows 10*")
#{
#    $wndOffsetX = 22
#    $wndOffsetY = 56
#}

# load forms (GUI)
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing.Icon")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing.Graphics")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Net.Sockets") 
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Globalization")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Input")

# Mediaplayer
Add-Type -AssemblyName PresentationCore
# Visual Styles
[void] [System.Windows.Forms.Application]::EnableVisualStyles() 

# STA Modus (Single Threading Apartment) - benötigt für OpenFileDialog
try {[threading.thread]::CurrentThread.SetApartmentState(0)}
catch { 
$ErrorMessage = $_.Exception.Message
Write-Host "ERROR: $ErrorMessage"
Write-Host "ERROR: [threading.thread]::CurrentThread.SetApartmentState(0)"}

# TEMP
$global:EnableFoW = $False

$global:VersionInfo = @{}
# major
$global:VersionInfo[0] = "0"
# minor
$global:VersionInfo[1] = "7"
# patch
$global:VersionInfo[2] = "2"
# build
$global:VersionInfo[3] = "20210622"

$global:arrWindows = @{}
$global:arrWindows.WindowOpen = $False
$global:arrWindows.InputCurrent = ""
$global:arrWindows.WindowCurrent = ""

$global:arrWindows.lastClickButton = ""
$global:arrWindows.lastClickWindow = ""

$global:arrWindows.lastInput = ""
$global:arrWindows.lastInputWindow = ""

$global:arrWindows.editorWindow = ""
$global:arrWindows.editorButton = ""

$global:arrWindows.isInitializing = $False

$global:arrSettings = @{}
$global:arrSettings["TOPMOST"] = $False;
$global:arrSettings["SCROLLSPEED"] = 1;
$global:arrSettings["SIZE"] = 2;
$global:arrSettings["VOLUMEMUSIC"] = 1;
$global:arrSettings["VOLUMEEFFECTS"] = 1;
$global:arrSettings["PLAYER_NAME"] = "Unknown";
$global:arrSettings["LAST_X"] = 0;
$global:arrSettings["LAST_Y"] = 0;

$global:arrSettings["MP_LASTIP"] = "127.0.0.1";
$global:arrSettings["MP_LASTPORT"] = "3665";
$global:arrSettings["MP_FRAMES"] = 60;

$global:arrMultiplayer = @{}

function MP_resetVariables()
{
    Write-Host "MP_resetVariables()"

    $global:arrMultiplayer = @{}
    $global:arrMultiplayer.iFrames = $global:arrSettings["MP_FRAMES"]
    $global:arrMultiplayer.State = "NONE"

    # this is quite bad here...
    # the server stop server function still has it's variables
    # but the client does not
    $global:arrMultiplayer.isServer = $False
    $global:arrMultiplayer.Server = @{}
    $global:arrMultiplayer.Server.isServerRunning = $False
    $global:arrMultiplayer.Server.datLastUpdate = Get-Date
    $global:arrMultiplayer.Server.udpClient = $Null
    $global:arrMultiplayer.Server.udpEndpoint = $Null
    $global:arrMultiplayer.Server.Clients = @{}
    $global:arrMultiplayer.Server.MapInfo = @{}
    $global:arrMultiplayer.Server.MapInfo.Loaded = $False
    $global:arrMultiplayer.Server.MapInfo.MaxPlayers = 0
    $global:arrMultiplayer.Server.MapInfo.Name = ""
    $global:arrMultiplayer.Server.MapInfo.Hash = ""

    $global:arrMultiplayer.isClient = $False
    $global:arrMultiplayer.Client = @{}
    $global:arrMultiplayer.Client.isClientRunning = $False
    $global:arrMultiplayer.Client.datLastUpdate = Get-Date
    $global:arrMultiplayer.Client.udpClient = $Null
    $global:arrMultiplayer.Client.udpEndpoint = $Null
    $global:arrMultiplayer.Client.ID = -1
    $global:arrMultiplayer.Client.MapName = ""
    $global:arrMultiplayer.Client.MapHash = ""
    $global:arrMultiplayer.Client.lastServerPingDiff = 0;

    $global:strMapFile = ""

    if($global:arrPlayerInfo)
    {
        for($p = 1; $p -le 4; $p++)
        {
            $global:arrPlayerInfo[$p] = @{}
        }
    }

    $global:EnableFoW = $False
}

MP_resetVariables

function MP_getLocalPlayerID()
{
    if(!(MP_isMultiplayer)) {return $global:arrPlayerInfo.currentPlayer}
    if($global:arrMultiplayer.isServer) { return 1 }
    return $global:arrMultiplayer.Client.ID
}

function MP_isMultiplayer()
{
    return ($global:arrMultiplayer.isClient -or $global:arrMultiplayer.isServer)
}

function MP_isCurrentMPPlayer($plrID)
{
    Write-Host "MP_isCurrentMPPlayer($plrID)"
    $plrID = [int]$plrID

    return (($global:arrMultiplayer.isClient -and ($plrID -eq $global:arrMultiplayer.Client.ID)) -or ($global:arrMultiplayer.isServer -and ($plrID -eq 1)))
}

function SERVER_setupServer()
{
    Write-Host "SERVER_setupServer"

    MP_resetVariables

    try
    {
        $global:arrMultiplayer.Server.udpEndpoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, ([int]$global:arrSettings["MP_LASTPORT"]))
        $global:arrMultiplayer.Server.udpClient = New-Object System.Net.Sockets.UdpClient ([int]$global:arrSettings["MP_LASTPORT"])
    }
    catch
    {
        $global:arrMultiplayer.Server.isServerRunning = $False
        throw $_
        return;
    }

    $global:arrMultiplayer.Server.Clients = @{}
    $global:arrMultiplayer.isServer = $True
    $global:arrMultiplayer.Server.isServerRunning = $True
    $global:arrMultiplayer.State = "SERVER_IN_LOBBY"
    SERVER_runServer
}

function SERVER_runServer()
{
    Write-Host "SERVER_runServer"

    $endpoint = $global:arrMultiplayer.Server.udpEndpoint

    $pingTimer = 1000

    while($global:arrMultiplayer.Server.isServerRunning)
    {
        # run any events (e.g. clicks)
        [System.Windows.Forms.Application]::DoEvents()

        $diff = (Get-Date) - $global:arrMultiplayer.Server.datLastUpdate
        $global:arrMultiplayer.Server.datLastUpdate = Get-Date
        # $diffms = $diff.TotalMilliseconds

        if(($pingTimer - $diff.TotalMilliseconds) -le 0)
        {
            $pingTimer = 1000
            SERVER_sendDataAll "0x05/1"
        }
        else
        {
            $pingTimer = $pingTimer - $diff.TotalMilliseconds
        }

        if($global:arrMultiplayer.Server.udpClient.Available)
        {
            $error = $False
            try
            {
                $content = $global:arrMultiplayer.Server.udpClient.Receive([ref]$endpoint)
            }
            catch
            {
                $error = $True
            }
            
            if(!$error)
            {
                SERVER_handleMessages $($endpoint.Address.IPAddressToString) $($endpoint.Port) ($([Text.Encoding]::ASCII.GetString($content)))
            }
            else
            {
                SERVER_removeEndpoint ($endpoint.Address.IPAddressToString + ":" + $endpoint.Port)
            }
        }

        Start-Sleep -m ((1 / $global:arrMultiplayer.iFrames) * 1000)
    }
}

function SERVER_removeEndpoint($strEndpoint)
{
    Write-Host "SERVER_removeEndpoint($strEndpoint)"

    if($global:arrMultiplayer.Server.Clients[$strEndpoint])
    {
        $global:arrMultiplayer.Server.Clients.Remove($strEndpoint)
    }

    $plrID = -1
    for($p = 1; $p -le 4; $p++)
    {
        if($global:arrPlayerInfo[$p][10] -eq $strEndpoint)
        {
            $plrID = $p
        }
    }

    # check if it was an active player
    if($global:arrWindows.WindowCurrent -eq "WND_MULTIPLAYER_SERVER" -and $global:arrMultiplayer.Server.MapInfo.Loaded)
    {
        if($plrID -ne -1)
        {
            $global:arrPlayerInfo[$plrID][0] = ("Player " + $p)
            $global:arrPlayerInfo[$plrID][5] = 1
            $global:arrPlayerInfo[$plrID][10] = ""
        }

        SERVER_setupPlayerButtons
    }
    elseif($global:arrMultiplayer.State -eq "SERVER_WAIT_FOR_PLAYERS")
    {
        if($plrID -ne -1)
        {
            $global:arrPlayerInfo[$plrID][5] = 0
            LBL_setTextColor "WND_SERVER_WAITING" ("LBL_PLR0" + $plrID) "GRAY" 

            SERVER_MapReady
        }
    }
    elseif($global:arrMultiplayer.State -eq "SERVER_TURN_SELF" -or $global:arrMultiplayer.State -eq "SERVER_TURN_OTHER")
    {
        # we are ingame
        if($plrID -ne -1)
        {
            $global:arrPlayerInfo[$plrID][5] = 0
            # fake client next day
            if($global:arrPlayerInfo.currentPlayer -eq $plrID)
            {
                SERVER_handleMessages "any" "any" "0x103"
            }
        }
    }
}

function SERVER_MapReady()
{
    # if last one missing, add "start" button for host
    $keys       = $global:arrMultiplayer.Server.Clients.Keys
    $allLoaded  = $True
    foreach($key in $keys)
    {
        if($global:arrMultiplayer.Server.Clients[$key].clientState -ne "CLIENT_MAP_READY")
        {
            $allLoaded = $False
        }
    }

    if($allLoaded)
    {
        BTN_setDisabledState "WND_SERVER_WAITING" "BTN_CONTINUE" $False
    }
}

function SERVER_handleMessages($ip, $port, $strMsg)
{
    Write-Host "SERVER_handleMessages($ip, $port, $strMsg)"

    $splittedData = $strMsg.Split('/')
    $clientID = ($ip + ":" + $port)

    switch($splittedData[0])
    {
        # Login Request
        "0x01"
        {
            $loginResult = 0
            $plrID = -1

            if($global:arrMultiplayer.Server.Clients[$clientID])
            {
                Write-Host "Known Endpoint"
            }
            else
            {
                Write-Host "New Endpoint"
                $global:arrMultiplayer.Server.Clients[$clientID] = @{}
                $global:arrMultiplayer.Server.Clients[$clientID].Name = $splittedData[1]
                $global:arrMultiplayer.Server.Clients[$clientID].Endpoint = New-Object System.Net.IPEndPoint([IPAddress]::Parse($ip), [int]$port)
                $global:arrMultiplayer.Server.Clients[$clientID].pingTimer = 10000
                $global:arrMultiplayer.Server.Clients[$clientID].clientState = "CLIENT_SERVER_JOINED"
            }

            if(!$global:arrMultiplayer.Server.MapInfo.Loaded)
            {
                # ERROR, Map not loaded
                $loginResult = 1
            }

            if($loginResult -eq 0)
            {
                $plrID = SERVER_setPlayerSlotIfAny $ip $port

                if($plrID -eq -1)
                {
                    # ERROR, Server full
                    $loginResult = 2
                }
            }

            SERVER_sendData ($ip + ":" + $port) ("0x02/" + $loginResult + "/" + $plrID + "/" + ([int]$global:EnableFoW) + "/" + $global:arrMultiplayer.Server.MapInfo.Name + "/" + $global:arrMultiplayer.Server.MapInfo.Hash)
            if($loginResult -eq 0)
            {
                SERVER_sendDataAll ("0x03" + (SERVER_serializePlayers))
            }
        }
        # client disconnects
        "0x07"
        {
            SERVER_removeEndpoint $clientID
        }
        # Map loaded
        "0x101"
        {
            if($splittedData -eq "1")
            {
                # a client loaded the map, update state
                Write-Host "Client $clientID is now 'CLIENT_MAP_READY'"

                $global:arrMultiplayer.Server.Clients[$clientID].clientState = "CLIENT_MAP_READY"

                # make player green (ready)
                $plrID = $global:arrMultiplayer.Server.Clients[$clientID].ingameID
                LBL_setTextColor "WND_SERVER_WAITING" ("LBL_PLR0" + $plrID) "GREEN"

                SERVER_MapReady
            }
        }
        # CLIENT ends turn
        "0x103"
        {
            handleEndTurnPlayer
        }
        # CLIENT adds bld Site
        "0x202"
        {
            #CLIENT_sendData ("0x202/" + ($tile_x - 2) + "/" + ($tile_y - 2) + "/" + ($global:arrSettingsInternal["BUILDINGS_SELECTED"]))
            $plrID      = $global:arrMultiplayer.Server.Clients[$clientID].ingameID
            $posX       = [int]($splittedData[1])
            $posY       = [int]($splittedData[2])
            $building   = [int]($splittedData[3])

            # Building is always at 0% and free
            # wares are updated by 0x200
            # state is updated by ????
            addBuildingAtPositionForPlayer $posX $posY $building $plrID 0.0 $False
        }
        # CLIENT destroys building
        "0x205"
        {
            $bldIndex   = [int]($splittedData[1])

            if(!($global:arrBuildings[$bldIndex]))
            {
                throw ("CLIENT: Building '" + $bldIndex + "' does not exist! Game is ASYNC!")
                return;
            }

            BLD_DestroyBuilding $bldIndex
        }
        # CLIENT adds an army
        "0x302"
        {
            #CLIENT_sendData ("0x302/" + ([int]($tile_x - 2)) + "/" + ([int]($tile_y - 2)))
            $plrID = $global:arrMultiplayer.Server.Clients[$clientID].ingameID
            $posX       = [int]($splittedData[1])
            $posY       = [int]($splittedData[2])

            addArmyAtPositionForPlayer $posX $posY $plrID $False (generateName) 1
        }
        # CLIENT moves an army
        "0x304"
        {
            #CLIENT_sendData ("0x304/" + $armyID + "/" + $targetX + "/" + $targetY)
            #ARMY_DoAction($armyID, $action, $targetX, $targetY)
            $armyID       = [int]($splittedData[1])

            if(!(SERVER_checkArmy $armyID)){return;}

            $targetX = [int]($splittedData[2])
            $targetY = [int]($splittedData[3])

            ARMY_DoAction $armyID 1 $targetX $targetY
        }
        # CLIENT attacks building
        "0x305"
        {
            #CLIENT_sendData ("0x305/" + $armyID + "/" + $targetX + "/" + $targetY)
            $armyID       = [int]($splittedData[1])

            if(!(SERVER_checkArmy $armyID)){return;}

            $targetX = [int]($splittedData[2])
            $targetY = [int]($splittedData[3])

            ARMY_DoAction $armyID 3 $targetX $targetY
        }
        # CLIENT Merge Army
        "0x308"
        {
            # CLIENT_sendData ("0x308/" + $sourceArmy + "/" + $targetArmy)

            $srcArmyID  = [int]($splittedData[1])
            $trgArmyID  = [int]($splittedData[2])

            if(!(SERVER_checkArmy $srcArmyID)){return;}
            if(!(SERVER_checkArmy $trgArmyID)){return;}

            ARMY_MergeArmies $srcArmyID $trgArmyID
        }
        # CLIENT Merge Buy
        "0x310"
        {
            #CLIENT_sendData ("0x310/" + $posX + "/" + $posY)

            $targetX = [int]($splittedData[1])
            $targetY = [int]($splittedData[2])

            ARMY_BuyArmyLevel $targetX $targetY
        }
        # CLIENT attacks unit
        "0x311"
        {
            #CLIENT_sendData ("0x311/" + $armyID + "/" + $targetX + "/" + $targetY)
            $armyID       = [int]($splittedData[1])

            if(!(SERVER_checkArmy $armyID)){return;}

            $targetX = [int]($splittedData[2])
            $targetY = [int]($splittedData[3])

            ARMY_DoAction $armyID 2 $targetX $targetY
        }
    }
}

function SERVER_checkArmy($iArmyID)
{
    Write-Host "SERVER_checkArmy($iArmyID)"

    if(!$global:arrArmies[$iArmyID])
    {
        throw ("SERVER: Army '" + $iArmyID + "' does not exist! Game is ASYNC!")
        return $False;
    }

    return $True;
}

function SERVER_sendData($strEndpoint, $data)
{
    Write-Host "SERVER_sendData($strEndpoint, $data)"
    $bytes = [Text.Encoding]::ASCII.GetBytes($data)
    try {
        $result = $global:arrMultiplayer.Server.udpClient.Send($bytes, $bytes.length, $global:arrMultiplayer.Server.Clients[$strEndpoint].Endpoint)
    } catch {
        SERVER_removeEndpoint $strEndpoint
    }
    
}

function SERVER_sendDataAll($data)
{
    $keys    = $global:arrMultiplayer.Server.Clients.Keys

    foreach($key in $keys)
    {
        SERVER_sendData $key $data
    }
}

function SERVER_stopServer()
{
    Write-Host "SERVER_stopServer"

    for($p = 2; $p -le 4; $p++)
    {
        if($global:arrPlayerInfo[$p] -and $global:arrPlayerInfo[$p][10] -and $global:arrPlayerInfo[$p][5] -eq 2)
        {
            SERVER_sendData ($global:arrPlayerInfo[$p][10]) ("0x04/2")
            SERVER_removeEndpoint ($global:arrPlayerInfo[$p][10])
        }
    }

    if($global:arrMultiplayer.Server.udpClient)
    {
        $global:arrMultiplayer.Server.udpClient.Close()
        $global:arrMultiplayer.Server.udpClient = $Null
    }

    if($global:arrMultiplayer.isServer)
    {
        MP_resetVariables
    }
}

function SERVER_setPlayerSlotIfAny($ip, $port)
{
    Write-Host "SERVER_setPlayerSlotIfAny($ip, $port)"

    for($p = 1; $p -le 4; $p++)
    {
        if($global:arrPlayerInfo[$p][5] -eq 1)
        {
            $global:arrPlayerInfo[$p][10] = ($ip + ":" + $port)
            $global:arrPlayerInfo[$p][0] = $global:arrMultiplayer.Server.Clients[($ip + ":" + $port)].Name
            $global:arrPlayerInfo[$p][5] = 2
            $global:arrMultiplayer.Server.Clients[($ip + ":" + $port)].ingameID = $p
            BTN_setTextAndColor "WND_MULTIPLAYER_SERVER" ("BTN_MP_PLAYER" + ($p - 1)) $global:arrMultiplayer.Server.Clients[($ip + ":" + $port)].Name "GRAY"
            return $p
        }
    }

    return -1
}

function SERVER_serializePlayers()
{
    $strValue = ""

    for($p = 1; $p -le 4; $p++)
    {
        $strValue = $strValue + "/" + $global:arrPlayerInfo[$p][5] + "/" + $global:arrPlayerInfo[$p][0]
    }

    return $strValue
}

function SERVER_SetupEscapeKickButtons()
{
    Write-Host "SERVER_SetupEscapeKickButtons()"

    for($p = 2; $p -le 4; $p++)
    {
        $btnDisable = $True
        $btnText = "Closed"

        if($global:arrPlayerInfo[$p][5] -eq 2)
        {
            $btnDisable = $False
            $btnText = $global:arrPlayerInfo[$p][0]
        }

        BTN_setDisabledState "WND_ESC_MP_SERVER" ("BTN_MP_KICK" + ($p - 2)) $btnDisable
        BTN_setText "WND_ESC_MP_SERVER" ("BTN_MP_KICK" + ($p - 2)) $btnText
    }
}

function SERVER_KickPlayerIngame($plrID)
{
    Write-Host "SERVER_KickPlayerIngame($plrID)"

    SERVER_sendData ($global:arrPlayerInfo[$plrID][10]) ("0x04/1")
    SERVER_removeEndpoint ($global:arrPlayerInfo[$plrID][10])
    $global:arrPlayerInfo[$plrID][5] = 0

    SERVER_SetupEscapeKickButtons
}

function CLIENT_setupConnection()
{
    Write-Host "CLIENT_setupConnection"

    MP_resetVariables

    $serverAdress = $global:arrWindows["WND_MULTIPLAYER_TYPESELECTION"].ninp["INP_MULTIPLAYER_IP"].text
    $serverPort = $global:arrWindows["WND_MULTIPLAYER_TYPESELECTION"].ninp["INP_MULTIPLAYER_PORT"].text

    try
    {
        Write-Host "CLIENT_setupConnection: Connecting to " $serverAdress $serverPort

        $global:arrMultiplayer.Client.udpEndpoint = new-object System.Net.IPEndPoint( [IPAddress]::Parse($serverAdress), [int]$serverPort )
        $global:arrMultiplayer.Client.udpClient = new-object System.Net.Sockets.UdpClient
    }
    catch
    {
        throw $_
        return;
    }

    $global:arrMultiplayer.isClient = $True
    $global:arrMultiplayer.Client.isClientRunning = $True
    $global:arrMultiplayer.State = "CLIENT_WAIT_FOR_RESPONSE"

    CLIENT_sendData ("0x01/" + $global:arrSettings["PLAYER_NAME"])
    $global:arrMultiplayer.Client.datLastUpdate = Get-Date
    CLIENT_runClient
}

function CLIENT_sendData($data)
{
    Write-Host "CLIENT_sendData($data)"

    $bytes = [Text.Encoding]::ASCII.GetBytes($data)
    $result = $global:arrMultiplayer.Client.udpClient.Send($bytes, $bytes.length, $global:arrMultiplayer.Client.udpEndpoint)
}

function CLIENT_stopClient()
{
    Write-Host "CLIENT_stopClient"

    if($global:arrMultiplayer.Client.udpClient)
    {
        # inform server
        CLIENT_sendData "0x07/1"

        $global:arrMultiplayer.Client.udpClient.Close()
        $global:arrMultiplayer.Client.udpClient = $Null
    }

    if($global:arrMultiplayer.isClient)
    {
        MP_resetVariables
    }
}

function CLIENT_runClient()
{
    Write-Host "CLIENT_runClient"

    $endpoint = $global:arrMultiplayer.Client.udpEndpoint

    $hasError = $False

    while($global:arrMultiplayer.Client.isClientRunning)
    {
        # run any events (e.g. clicks)
        [System.Windows.Forms.Application]::DoEvents()

        $diff = (Get-Date) - $global:arrMultiplayer.Client.datLastUpdate
        $global:arrMultiplayer.Client.datLastUpdate = Get-Date

        $global:arrMultiplayer.Client.lastServerPingDiff = $global:arrMultiplayer.Client.lastServerPingDiff + $diff.TotalMilliseconds
        if($global:arrMultiplayer.Client.lastServerPingDiff -ge 5000)
        {
            CLIENT_stopClient
            $global:strGameState = "MAIN_MENU"
            CLIENT_showError "Connection to Server lost!"
        }

        if($global:arrMultiplayer.Client.udpClient.Available)
        {
            try
            {
                $content = $global:arrMultiplayer.Client.udpClient.Receive([ref]$endpoint)
                $hasError = $False
            } 
            catch 
            {
                $hasError = $True
            }

            if($hasError)
            {
                CLIENT_stopClient
                $global:strGameState = "MAIN_MENU"
                CLIENT_showError "Can't reach server!"
            }
            else
            {
                CLIENT_handleMessages $($endpoint.Address.IPAddressToString) $($endpoint.Port) ($([Text.Encoding]::ASCII.GetString($content)))
            }
        }

        Start-Sleep -m ((1 / $global:arrMultiplayer.iFrames) * 1000)
    }
}

function CLIENT_handleMessages($ip, $port, $strMsg)
{
    Write-Host "CLIENT_handleMessages($ip, $port, $strMsg)"

    $splittedData = $strMsg.Split('/')

    switch($splittedData[0])
    {
        # Login Result
        "0x02"
        {
            $loginResult = $splittedData[1]
            if($loginResult -eq 1) # map not selected
            {
                CLIENT_stopClient
                CLIENT_showError "Server has no map selected yet!"
            }
            elseif ($loginResult -eq 2) # server full
            {
                CLIENT_stopClient
                CLIENT_showError "Server is full!"
            }
            else
            {
                $global:arrMultiplayer.Client.ID = [int]$splittedData[2]
                $global:EnableFoW = [bool]([int]$splittedData[3])
                $global:arrMultiplayer.Client.MapName = $splittedData[4]
                $global:arrMultiplayer.Client.MapHash = $splittedData[5]

                showWindow "WND_MULTIPLAYER_CLIENT"

                $global:arrMultiplayer.State = "CLIENT_IN_LOBBY"
            }
        }
        # Player Info
        "0x03"
        {
            $strWindow = "WND_MULTIPLAYER_CLIENT"

            if($global:arrWindows.WindowCurrent -ne $strWindow) {return;}

            for($p = 1; $p -le 4; $p++)
            {
                if([int]$splittedData[($p * 2 - 1)] -eq 2) # player occupied slot
                {
                    BTN_setTextAndColor $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $splittedData[($p * 2)] "GRAY"
                }
                elseif([int]$splittedData[($p * 2 - 1)] -eq 1)
                {
                    BTN_setTextAndColor $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $global:arrMPPlayerTypeIDString[1] "GRAY"
                }
                else
                {
                    BTN_setTextAndColor $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $global:arrMPPlayerTypeIDString[0] "RED"
                }

                $global:arrPlayerInfo[$p] = @{}
                $global:arrPlayerInfo[$p][0] = $splittedData[($p * 2)] # name
                $global:arrPlayerInfo[$p][5] = [int]$splittedData[($p * 2 - 1)] #type
            }
        }
        # kicked by server
        "0x04"
        {
            CLIENT_stopClient

            $kickReason = $splittedData[1]

            $msg = "The host kicked you like a football!"

            switch($kickReason)
            {
                "2"
                {
                    $msg = "Host stopped Server!"
                }
            }

            CLIENT_showError $msg
            $global:strGameState = "MAIN_MENU"
        }
        # server pinged
        "0x05"
        {
            $global:arrMultiplayer.Client.lastServerPingDiff = 0;
        }
        # server change Fow setting
        "0x06"
        {
            $global:EnableFoW = [bool]([int]$splittedData[1])
            WND_setFOWButtonState "WND_MULTIPLAYER_CLIENT" "BTN_FOW_TOGGLE" $global:EnableFoW
        }
        # load map
        "0x100"
        {
            try
            {
                loadMap (".\MAP\" + $global:arrMultiplayer.Client.MapName)
            }
            catch
            {
                CLIENT_stopClient
                CLIENT_showError "Bad Mapfile!"
                return;
            }

            # loading done
            CLIENT_sendData "0x101/1"

            $global:strGameState = "SINGLEPLAYER_INGAME"
            $global:arrMultiplayer.State = "CLIENT_WAIT_FOR_START"
            showWindow "WND_CLIENT_WAITING"
        }
        # current player
        "0x102"
        {
            # update accordingly
            $global:arrPlayerInfo.currentPlayer = [int]($splittedData[1])
            $plrID = $global:arrPlayerInfo.currentPlayer

            $global:arrPlayerInfo[$plrID][6] = [int]($splittedData[2])
            $global:arrPlayerInfo[$plrID][7] = [int]($splittedData[3])
            $global:arrPlayerInfo[$plrID][8] = [int]($splittedData[4])
            $global:arrPlayerInfo[$plrID][9] = [int]($splittedData[5])

            $global:arrPlayerInfo[$plrID][1] = [int]($splittedData[6])
            $global:arrPlayerInfo[$plrID][2] = [int]($splittedData[7])
            $global:arrPlayerInfo[$plrID][3] = [int]($splittedData[8])
            $global:arrPlayerInfo[$plrID][4] = [int]($splittedData[9])

            # if self, activate controls, if not update waiting window
            if($global:arrMultiplayer.Client.ID -eq $plrID)
            {
                $global:arrMultiplayer.State = "CLIENT_TURN_SELF"
                playSFX "SND_TURN_SELF"
                GAME_SP_closeTileinfo
                centerOnPlayer $plrID
                showWindow "WND_SP_MENU_WARES_N"
            }
            else
            {
                $global:arrMultiplayer.State = "CLIENT_TURN_OTHER"
                playSFX "SND_TURN_OTHER"
                showWindow "WND_CLIENT_WAITINGFOR" 
            }
        }
        # playerstat update
        "0x200"
        {
            # SERVER_sendDataAll ("0x200/" + $plrID + "/" + $global:arrPlayerInfo[$plrID][6] + "/" + $global:arrPlayerInfo[$plrID][7] + "/" + $global:arrPlayerInfo[$plrID][8] + "/" + $global:arrPlayerInfo[$plrID][9])
            $global:arrPlayerInfo.currentPlayer = [int]($splittedData[1])
            $plrID = $global:arrPlayerInfo.currentPlayer

            $global:arrPlayerInfo[$plrID][6] = [int]($splittedData[2])
            $global:arrPlayerInfo[$plrID][7] = [int]($splittedData[3])
            $global:arrPlayerInfo[$plrID][8] = [int]($splittedData[4])
            $global:arrPlayerInfo[$plrID][9] = [int]($splittedData[5])
        }
        # new building site
        "0x201"
        {
            # ignore messages for building sites before map is ready
            if ($global:arrMultiplayer.State -eq "CLIENT_IN_LOBBY") {return}

            #SERVER_sendDataAll ("0x201/" + $player + "/" + $posX + "/" + $posY + "/" + $building
            $plrID      = [int]($splittedData[1])
            $posX       = [int]($splittedData[2])
            $posY       = [int]($splittedData[3])
            $building   = [int]($splittedData[4])

            # Building is always at 0% and free
            # wares are updated by 0x200
            # state is updated by ????
            addBuildingAtPositionForPlayer $posX $posY $building $plrID 0.0 $True
        }
        "0x203"
        # buidling percent Update
        {
            #SERVER_sendDataAll ("0x203/" + $i + "/" + ($global:arrBuildings[$i][5]) + "/" + (global:arrBuildings[$i][4]))

            $bldIndex   = [int]($splittedData[1])
            $percent    = [float]($splittedData[2])
            $state      = [int]($splittedData[3])

            if(!($global:arrBuildings[$bldIndex]))
            {
                throw ("CLIENT: Building '" + $bldIndex + "' does not exist! Game is ASYNC!")
                return;
            }

            updateBuildingState $bldIndex $percent $state
        }
        # building destroyed
        "0x204"
        {
            #BLD_DestroyBuilding($bld, $byServer)
            $bldIndex   = [int]($splittedData[1])

            if(!($global:arrBuildings[$bldIndex]))
            {
                throw ("CLIENT: Building '" + $bldIndex + "' does not exist! Game is ASYNC!")
                return;
            }

            $silent   = [bool]($splittedData[2])

            BLD_DestroyBuilding $bldIndex $True $silent
        }
        # update HP
        "0x206"
        {
            $bldIndex       = [int]($splittedData[1])
            $newHitpoints   = [int]($splittedData[2])

            if(!($global:arrBuildings[$bldIndex]))
            {
                throw ("CLIENT: Building '" + $bldIndex + "' does not exist! Game is ASYNC!")
                return;
            }

            BLD_updateHitpoints $bldIndex $newHitpoints
            MAP_addBuildingBar $bldIndex 
        }
        # a building was destroyed in battle
        "0x207"
        {
            # SERVER_sendDataAll("0x207/" + $ownerID)
            $owner   = [int]($splittedData[1])

            if(($global:arrMultiplayer.Client.ID -eq $global:arrPlayerInfo.currentPlayer) -and ($global:arrMultiplayer.Client.ID -ne $owner))
            {
                playSFX "SND_HUM_ARMY_WIN"
            }
        }
        # new army
        "0x301"
        {
            # SERVER_sendDataAll ("0x301/" + $plrID + "/" + $posX + "/" + $posY + "/" + $name)
            $plrID      = [int]($splittedData[1])
            $posX       = [int]($splittedData[2])
            $posY       = [int]($splittedData[3])
            $name       = ($splittedData[4])

            addArmyAtPositionForPlayer $posX $posY $plrID $True $name 1

            # client needs to update his buttons
            if($plrID -eq $global:arrMultiplayer.Client.ID)
            {
                WND_SetOffsetButton
            }
        }
        # army movement update
        "0x303"
        {
            #SERVER_sendDataAll("0x303/" + $armyID + "/" + $targetX + "/" + $targetY+ "/" + ($global:arrArmies[$armyID][5]) + "/" + ($global:arrArmies[$armyID][10]))

            $armyID = [int]($splittedData[1])

            if(!(CLIENT_checkArmy $armyID)){return;}

            $targetX = [int]($splittedData[2])
            $targetY = [int]($splittedData[3])

            ARMY_changePosition $armyID $targetX $targetY
            ARMY_setMovepoints $armyID ([int]($splittedData[4]))
            ARMY_setSleepState $armyID ([int]($splittedData[5]))

            # own army?
            $plrID = $global:arrArmies[$armyID][2]

            if($plrID -eq $global:arrMultiplayer.Client.ID)
            {
                $global:arrCreateMapOptions["SELECTED_X"] = $targetX + 2;
                $global:arrCreateMapOptions["SELECTED_Y"] = $targetY + 2;

                openTileInfoIfNeeded $targetX $targetY
            }
        }
        # army state update
        "0x306"
        {
            # armyID, armyHP, armyMP, armySleep
            #SERVER_sendDataAll("0x306/" + $i + "/" + ($global:arrArmies[$i][6]) + "/" + ($global:arrArmies[$i][5]) + "/" + ($global:arrArmies[$i][10]))

            $armyID = [int]($splittedData[1])

            if(!(CLIENT_checkArmy $armyID)){return;}

            ARMY_setHitpoints  $armyID ([int]($splittedData[2]))
            ARMY_setMovepoints $armyID ([int]($splittedData[3]))
            ARMY_setSleepState $armyID ([int]($splittedData[4]))

            #if($global:arrPlayerInfo.selectedTile.armyID -eq $armyID -and $global:arrMultiplayer.Client.ID -ne $global:arrArmies[$armyID][2])
            #{
            #    GAME_setArmyTileinfo
            #}
        }
        # SERVER UNUSED
        # new: set level and HP
        "0x307"
        {
            # SERVER_sendDataAll ("0x307/" + $targetArmy + "/" + ($global:arrArmies[$attackerID][4]) + "/" + ($global:arrArmies[$attackerID][7]))

            $armyID = [int]($splittedData[1])

            if(!(CLIENT_checkArmy $armyID)){return;}

            ARMY_setHitpoints  $armyID ([int]($splittedData[2]))
            ARMY_setLevel $armyID ([int]($splittedData[3]))
            ARMY_setMovepoints $armyID ([int]($splittedData[4]))

            if(([int]($splittedData[4])) -eq 0) {
                ARMY_setSleepState $armyID 1
            }
        }
        # army destroyed
        "0x309"
        {
            #SERVER_sendDataAll ("0x309/" + $armyID)
            $armyID = [int]($splittedData[1])

            if(!(CLIENT_checkArmy $armyID)){return;}

            ARMY_DestroyArmy $armyID

            #$strWindow = "WND_MULTIPLAYER_CLIENT"

            if($global:arrWindows.WindowCurrent -eq "WND_SP_MENU_ARMY_N") 
            {
                changeArmyOffset 0
            }

            # this was the currently selected army
            if($global:arrPlayerInfo.selectedTile.armyID -eq $armyID)
            {
                GAME_SP_closeTileinfo
            }
        }
        # battle win/lose
        "0x312"
        {
            $result = [int]($splittedData[1])

            if($result -eq 1)   { playSFX "SND_HUM_ARMY_WIN" }
            else                { playSFX "SND_HUM_ARMY_LOSE" }
        }
    }
}

function CLIENT_checkArmy($iArmyID)
{
    Write-Host "CLIENT_checkArmy($iArmyID)"

    if(!$global:arrArmies[$armyID])
    {
        throw ("CLIENT: Army '" + $armyID + "' does not exist! Game is ASYNC!")
        return $False;
    }

    return $True;
}

function CLIENT_openHostScreen()
{
    loadMapHeader (".\MAP\" + $global:arrMultiplayer.Client.MapName)

    MAP_loadMD5Sum (".\MAP\" + $global:arrMultiplayer.Client.MapName)

    if($global:arrMap["HASH"] -ne $global:arrMultiplayer.Client.MapHash)
    {
        CLIENT_stopClient
        CLIENT_showError "Server has different map version (" + $global:arrMultiplayer.Client.MapName + ")!"
        return;
    }

    $strWindow = "WND_MULTIPLAYER_CLIENT"

    BTN_setText $strWindow "BTN_MP_OPENMAP" $global:arrMultiplayer.Client.MapName
    LBL_setText $strWindow "LBL_MP_PLAYERS" ([string](getPlayerCount))
    LBL_setText $strWindow "LBL_MP_AUTHOR" ($global:arrMap["AUTHOR"])
    LBL_setText $strWindow "LBL_MP_SIZE" ("" + $global:arrMap["WIDTH"] + " x " + $global:arrMap["HEIGHT"])
}

function CLIENT_showError($strMessage)
{
    Write-Host "CLIENT_showError($strMessage)"
    
    showWindow "WND_MP_ERRORS"
    LBL_setText "WND_MP_ERRORS" "LBL_MESSAGE" $strMessage
}

function SERVER_showError($strMessage)
{
    showWindow "WND_SERVER_ERRORS"
    LBL_setText "WND_SERVER_ERRORS" "LBL_MESSAGE" $strMessage
}

$global:arrSettingsInternal = @{}
$global:arrSettingsInternal["SONG_CURRENT"] = 0;
$global:arrSettingsInternal["SONGS"] = 0;
$global:arrSettingsInternal["HOOVER_X"] = -1;
$global:arrSettingsInternal["HOOVER_Y"] = -1;
$global:arrSettingsInternal["HOOVER_CANBUILD"] = $False;
$global:arrSettingsInternal["PLAYER_MAX"] = 4;
$global:arrSettingsInternal["PLAYERTYPE_MAX"] = 5;
$global:arrSettingsInternal["TILESIZE"] = 16;
$global:arrSettingsInternal["BUILDINGS_MIN"] = 1
$global:arrSettingsInternal["BUILDINGS_CIVILS"] = 8;
$global:arrSettingsInternal["BUILDINGS_MILITARY"] = 4;
$global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1;
$global:arrSettingsInternal["CULTURE"] = (New-Object System.Globalization.CultureInfo("en-US", $False))
$global:arrSettingsInternal["TILERECT"] = (New-Object System.Drawing.Rectangle(0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"]));
$global:arrSettingsInternal["RECRUIT_ARMY"] = $False
$global:arrSettingsInternal["HOOVER_CANRECRUIT"] = 0
$global:arrSettingsInternal["ARMY_DEFAULT_MP"] = 2
$global:arrSettingsInternal["ARMY_DEFAULT_HP"] = 3
$global:arrSettingsInternal["ARMY_DEFAULT_DMG"] = 2
$global:arrSettingsInternal["ARMY_UNIT_COSTS"] = @{}
# initial buy
$global:arrSettingsInternal["ARMY_UNIT_COSTS"][0] = 35  # gold
$global:arrSettingsInternal["ARMY_UNIT_COSTS"][1] = 60  # food
$global:arrSettingsInternal["ARMY_UNIT_COSTS"][2] = 5   # people


$global:Campaigns = @{}
$global:Campaigns.selected = -1
$global:Campaigns.selectedMap = -1
$global:Campaigns.data = @{}
$global:Campaigns.script = @{}

$global:arrMap = @{}
function initMapArray()
{
    $global:arrMap = @{}
    $global:arrMap["HASH"] = ""
    $global:arrMap["AUTHOR"] = "The Author"
    $global:arrMap["MAPNAME"] = "The Name"
    $global:arrMap["WIDTH"] = 0
    $global:arrMap["HEIGHT"] = 0
    $global:arrMap["BUILDING_INDEX"] = 0
    $global:arrMap["ARMY_INDEX"] = 0
    $global:arrMap["PLAYER_01X"] = -1
    $global:arrMap["PLAYER_01Y"] = -1
    $global:arrMap["PLAYER_02X"] = -1
    $global:arrMap["PLAYER_02Y"] = -1
    $global:arrMap["PLAYER_03X"] = -1
    $global:arrMap["PLAYER_03Y"] = -1
    $global:arrMap["PLAYER_04X"] = -1
    $global:arrMap["PLAYER_04Y"] = -1
    # L stands for layer
    $global:arrMap["WORLD_L1"] = @{}
    $global:arrMap["WORLD_L2"] = @{}
    $global:arrMap["WORLD_L3"] = @{}
    $global:arrMap["WORLD_LBLD"] = @{} # Buildings are referenced by ID, ID = -1 => no building, everything else = building in a building array. At first the building array should include player start positions.
    $global:arrMap["WORLD_LARMY"] = @{} # same as buildings but for army
    $global:arrMap["WORLD_CONTINENT"] = @{} # 0 = no movement, 1 = main continent, n = other continent
    $global:arrMap["WORLD_MMAP"] = @{} # movementmap, bit 1 = up, bit 2 = right, bit 3 = down, bit 4 = left

    # generated at runtime
    $global:arrMap["WORLD_OVERLAY"] = @{}
    $global:arrMap["WORLD_VIEWMAP"] = @{} # visibility for each player
}

initMapArray

#region PLAYER_INFO

$global:arrPlayerInfo = @{}
$global:arrPlayerInfo.currentPlayer = -1
$global:arrPlayerInfo.roundNo = -1
$global:arrPlayerInfo.currentSelection = -1
$global:arrPlayerInfo.selectedTile = @{}
$global:arrPlayerInfo.combatEvent = @{}
$global:arrPlayerInfo.offsetArmies = 0
$global:arrPlayerInfo.scrollX = -1
$global:arrPlayerInfo.scrollY = -1


function resetPlayerTileSelection()
{
    $global:arrPlayerInfo.selectedTile.x = -1
    $global:arrPlayerInfo.selectedTile.y = -1
    $global:arrPlayerInfo.selectedTile.objectID = -1
    $global:arrPlayerInfo.selectedTile.buildingID = -1
    $global:arrPlayerInfo.selectedTile.armyID = -1
    $global:arrPlayerInfo.selectedTileArmyActions = @{}
}

resetPlayerTileSelection
# playername (0)
# gold_income (1)
# wood_income (2)
# food_income (3)
# production (4)
# playertype (index) (5)
# gold_amount (6)
# wood_amount (7)
# food_amount (8)
# people_amount (9)

#endregion

#region PLAYERTYPES
$global:arrPlayertypeIndexString = @{}
$global:arrPlayertypeIndexString[0] = "Closed"
$global:arrPlayertypeIndexString[1] = "Dummy"
$global:arrPlayertypeIndexString[2] = "AI"
$global:arrPlayertypeIndexString[3] = "Local"
$global:arrPlayertypeIndexString[4] = "Network"

$global:arrMPPlayerTypeIDString = @{}
$global:arrMPPlayerTypeIDString[0] = "Closed"
$global:arrMPPlayerTypeIDString[1] = "Open"
$global:arrMPPlayerTypeIDString[2] = "Taken"
#endregion

#region NAMES
$global:arrNames = @{}
$global:arrNames[0] = @{}
$global:arrNames[1] = @{}
function loadNames($objTargetArray, $strFileName)
{
    if (Test-Path $strFileName) { $arrFileTemp = Get-Content $strFileName }
    else { Write-Host "$strFileName is missing!"; return; }

    for($i = 0; $i -lt $arrFileTemp.Length; $i++)
    {
        $objTargetArray[$i] = $arrFileTemp[$i]
    }
}

loadNames ($global:arrNames[0]) ".\DAT\NAMES_1.dat"
loadNames ($global:arrNames[1]) ".\DAT\NAMES_2.dat"

function generateName()
{
    $index1 = (urand 0 ($global:arrNames[0].Count - 1))
    $index2 = (urand 0 ($global:arrNames[1].Count - 1))

    return ($global:arrNames[0][$index1] + $global:arrNames[1][$index2])
}
#endregion

#region COLORS
$global:arrColors = @{}
$global:arrColors.TransparentBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Transparent)

function addcolor($type, $r, $g, $b, $a = 255)
{
    Write-Host "addcolor($type, $r, $g, $b, $a)"

    $global:arrColors[$type] = @{}; 
    $global:arrColors[$type].color = [System.Drawing.Color]::FromArgb($a, $r, $g, $b); 
    $global:arrColors[$type].pen = New-Object System.Drawing.Pen($global:arrColors[$type].color, 3); 
    $global:arrColors[$type].brush = New-Object System.Drawing.SolidBrush($global:arrColors[$type].color)
}

$global:arrTexts = @{}

function loadTexts()
{
    Write-Host "loadTexts()"

    $strFileName = ".\DAT\TEXTS.dat"
    if (Test-Path $strFileName) { $arrTextsTMP = Get-Content $strFileName }
    else { Write-Host "$strFileName is missing!"; return; }

    $strCurrentText = ""

    for($i = 0; $i -lt $arrTextsTMP.Length; $i++)
    {
        $strLine = $arrTextsTMP[$i].Trim()

        $isCommand = $strLine -match "^\[.*\]"

        if($isCommand)
        {
            #Write-Host "Command: $strLine"

            $strLine = $strLine.Replace("[", "")
            $strLine = $strLine.Replace("]", "")

            $isValid = !$strLine.Contains(" ")

            if($isValid)
            {
                if($strLine -eq "END")
                {
                    $strCurrentText = ""
                }
                else
                {
                    $strCurrentText = $strLine
                }
            }
            else
            {
                $strCurrentText = ""
            }
        }
        else
        {
            if($strCurrentText -ne "")
            {
                if(!$global:arrTexts[$strCurrentText])
                {
                    $global:arrTexts[$strCurrentText] = @{}
                }

                $global:arrTexts[$strCurrentText][($global:arrTexts[$strCurrentText].Count)] = $strLine
            }
        }
    }

    #Write-Host "A:" ($global:arrTexts["LICENSE"])
}

function getText($strText)
{
    if(!$global:arrTexts[$strText])
    {
        return "TEXT DOES NOT EXIST"
    }
    else
    {
        return $global:arrTexts[$strText]
    }
}

loadTexts

function loadDat($objTargetArray, $strFileName, $mode)
{
    if (Test-Path $strFileName) { $arrConfigTMP = Get-Content $strFileName }
    else { Write-Host "$strFileName is missing!"; return; }
    
    for($i = 0; $i -lt $arrConfigTMP.Length; $i++)
    {
        $arrConfigLine = $arrConfigTMP[$i].split("=")
        
        $strKey = $arrConfigLine[0].Trim()
        $strValues = $arrConfigLine[1].Trim()
        $arrConfigValues = $strValues.split(",")
        
        if($mode -eq "TERRAIN")
        {
            if($global:arrTextures[$strKey])
            {
                for($j = 0; $j -lt 4; $j++)
                {
                    $objTargetArray[$strKey][$j] = ([int]($arrConfigValues[$j]))
                }
            }
            else
            {
                Write-Host "$strKey existiert nicht"
            }
        }
        elseif($mode -eq "COLOR")
        {
            addcolor $strKey $arrConfigValues[0] $arrConfigValues[1] $arrConfigValues[2] $arrConfigValues[3]
        }
        else
        {
            $objTargetArray[$strKey] = $strValues
        }
    }
}

loadDat $null ".\DAT\COLOR.dat" "COLOR"
#endregion

$global:strGameState = "WAIT_INIT_CLICK"
$global:strMapFile = "";

$global:arrCreateMapOptions = @{}

function MAP_resetCreateOptions()
{
    $global:arrCreateMapOptions["WIDTH"] = 32;
    $global:arrCreateMapOptions["HEIGHT"] = 32;
    $global:arrCreateMapOptions["BASTEXTUREID"] = 0;
    $global:arrCreateMapOptions["EDITOR_CHUNK_X"] = 0;
    $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] = 0;
    $global:arrCreateMapOptions["EDIT_MODE"] = 0;
    $global:arrCreateMapOptions["CLICK_MODE"] = 0;
    $global:arrCreateMapOptions["IDX_LAYER01"] = 0;
    $global:arrCreateMapOptions["IDX_LAYER02"] = 0;
    $global:arrCreateMapOptions["IDX_LAYER03"] = 0;
    $global:arrCreateMapOptions["SELECT_LAYER01"] = -1;
    $global:arrCreateMapOptions["SELECT_LAYER02"] = -1;
    $global:arrCreateMapOptions["SELECT_LAYER03"] = -1;
    $global:arrCreateMapOptions["SELECT_PLAYER"] = -1;
    $global:arrCreateMapOptions["LAST_CHANGED_TEX"] = 0;
    $global:arrCreateMapOptions["LAST_MODE"] = 0;
    $global:arrCreateMapOptions["LAST_CHANGED_X"] = 0;
    $global:arrCreateMapOptions["LAST_CHANGED_Y"] = 0;
    $global:arrCreateMapOptions["SELECTED_X"] = 0;
    $global:arrCreateMapOptions["SELECTED_Y"] = 0;
    $global:arrCreateMapOptions["SHOW_PREVIEW"] = $False;
}
MAP_resetCreateOptions


#region FUNCTIONS_LOAD_GRAPHICS
function loadGraphicsByName($objTargetArray, $strPath, $strFilter, $makeTransparent)
{
    foreach($file in (Get-ChildItem -Path $strPath $strFilter))
    {
        $arrSplit = $file.Name.split(".")
        $objTargetArray[$arrSplit[0]] = @{}
        $objTargetArray[$arrSplit[0]].bitmap = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPath + $file.Name))));

        if($makeTransparent)
        {
            $objTargetArray[$arrSplit[0]].bitmap.MakeTransparent($global:arrColors["CLR_MAGENTA"].color);
        }
    }
}
#endregion

#region \GFX\ICON
$global:arrIcons = @{}

loadGraphicsByName $global:arrIcons ".\GFX\ICON\" "ICON_*" $True
loadGraphicsByName $global:arrIcons ".\GFX\WORLD\" "GROUND_*" $True
loadGraphicsByName $global:arrIcons ".\GFX\WORLD\" "PLAYER_*" $True
loadGraphicsByName $global:arrIcons ".\GFX\WORLD\" "LAYER_*" $True
loadGraphicsByName $global:arrIcons ".\GFX\WORLD\" "OBJ_*" $True
loadGraphicsByName $global:arrIcons ".\GFX\BUILDING\" "HUM_*" $True

loadGraphicsByName $global:arrIcons ".\GFX\FOW\" "FOW_*" $True

#endregion

#region \GFX\WORLD\
# All textures shown in the editor at the first tab
$arrBaseTextureIDToKey = "GROUND_GREEN_01", "GROUND_GREEN_02", "GROUND_GREEN_03", "GROUND_GREEN_04", "GROUND_WATER_01", "GROUND_EMPTY_01"

# All textures shown in the editor at the 2nd tab
# 0 - 11 invalid
# 12 - 22 valid
# 23 - x invalid
$arrOverlayTextureIDToKey = "LAYER_EDGE_01", "LAYER_EDGE_02", "LAYER_EDGE_03", "LAYER_EDGE_04", "LAYER_EDGE_05", "LAYER_EDGE_06", "LAYER_EDGE_07", "LAYER_EDGE_08", "LAYER_EDGE_09", "LAYER_EDGE_10", "LAYER_EDGE_11", "LAYER_EDGE_12", `
"LAYER_PATH_01", "LAYER_PATH_02", "LAYER_PATH_03", "LAYER_PATH_04", "LAYER_PATH_05", "LAYER_PATH_06", "LAYER_PATH_07", "LAYER_PATH_08", "LAYER_PATH_09", "LAYER_PATH_10", "LAYER_PATH_11", `
"LAYER_RIVER_01", "LAYER_RIVER_02", "LAYER_RIVER_03", "LAYER_RIVER_04", "LAYER_RIVER_05", "LAYER_RIVER_06", "LAYER_RIVER_07", "LAYER_RIVER_08", "LAYER_RIVER_09", "LAYER_RIVER_10", "LAYER_RIVER_11", "LAYER_RIVER_12", "LAYER_RIVER_13", "LAYER_RIVER_14", "LAYER_RIVER_15", "LAYER_RIVER_16", "LAYER_RIVER_17", "LAYER_RIVER_18", "LAYER_RIVER_19"

# All textures shown in the editor at the 3rd tab
$arrObjectTextureIDToKey = "OBJ_BUSH_01", "OBJ_BUSH_02", "OBJ_BUSH_03", "OBJ_CHEST_01", "OBJ_MOUNTAIN_01", "OBJ_MOUNTAIN_02", "OBJ_MOUNTAIN_03", "OBJ_MOUNTAIN_04", "OBJ_STONES_01", "OBJ_STONES_02", "OBJ_STONES_03", "OBJ_STONES_04", "OBJ_STONES_05", "OBJ_TREE_01", "OBJ_TREE_02", "OBJ_TREE_03", "OBJ_TREE_04",`
 "OBJ_WHIRL_01", "OBJ_GOLD_01", "OBJ_HARBOR_01", "OBJ_POND_01", "OBJ_RUINS_01", "OBJ_RUINS_02", "OBJ_SHIP_01", "OBJ_SIGNPOST_01"

# All player icons
$arrPlayerIconsIDToKey = "PLAYER_00", "PLAYER_01", "PLAYER_02", "PLAYER_03", "PLAYER_04"

$strPathTextureGFX = ".\GFX\WORLD\"
$global:arrTextures = @{}

loadGraphicsByName $global:arrTextures $strPathTextureGFX "GROUND_*" $False

loadGraphicsByName $global:arrTextures $strPathTextureGFX "LAYER_EDGE_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "LAYER_PATH_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "LAYER_RIVER_*" $True

loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_BUSH_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_MOUNTAIN_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_STONES_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_TREE_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_WHIRL_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_CHEST_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_GOLD_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_HARBOR_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_POND_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_RUINS_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_SHIP_*" $True
loadGraphicsByName $global:arrTextures $strPathTextureGFX "OBJ_SIGNPOST_*" $True

loadGraphicsByName $global:arrTextures $strPathTextureGFX "PLAYER_*" $True

loadDat $global:arrTextures ".\DAT\TERRAIN.dat" "TERRAIN"

$global:arrPath = @{}

#region KEYS
$global:arrKeyTranslation = @{}
$global:arrKeyTranslation["Space"] = ' '
loadDat $global:arrKeyTranslation ".\DAT\KEY_MAP.dat" $null

$global:arrKeyFunction = @{}
loadDat $global:arrKeyFunction ".\DAT\KEY_FUNCTION.dat" $null

function translateKey($keyIn)
{
    if($global:arrKeyTranslation[$keyIn])
    {
        return $global:arrKeyTranslation[$keyIn];
    }

    return $keyIn;
}

function getKeyFunction($keyIn)
{
    if($global:arrKeyFunction[$keyIn])
    {
        return $global:arrKeyFunction[$keyIn];
    }

    return ''
}
#endregion

function calculateDistance($sourceX, $sourceY, $targetX, $targetY)
{
    return ([math]::Abs($targetX - $sourceX) + [math]::Abs($targetY - $sourceY))
}

function markPath()
{
    Write-Host "markPath()"

    $keysX = $global:arrPath.path.Keys

    foreach($keyX in $keysX)
    {
        $keysY = $global:arrPath.path[($keyX)].Keys

        foreach($keyY in $keysY)
        {
            if($global:arrPath.path[$keyX][$keyY].isPath)
            {
                $global:arrMap["WORLD_OVERLAY"][$keyX][$keyY] = $global:arrInterface["SELECTION_TILE_INVALID"].bitmap
                MAP_drawTile $keyX $keyY $True
            }
        }
    }
}

function findPath()
{
    Write-Host "findPath()"

    if(!$global:arrPath.validPath)
    {
        Write-Host "No valid Path!"
        return;
    }

    # this is reverse, from target to source
    $workX = $global:arrPath.targetX
    $workY = $global:arrPath.targetY

    $nextX = -1
    $nextY = -1
    $curG = 10000
    $curD = 10000

    while($workX -ne $global:arrPath.sourceX -or $workY -ne $global:arrPath.sourceY)
    {
        for($i = 0; $i -lt 4; $i++)
        {
            $locX = $workX + ($i % 2 * (2 - $i))
            $locY = $workY + (($i + 1) % 2 * (-1 + $i))
            #Write-Host "X: $locX"
            #Write-Host "Y: $locY"

            if($global:arrPath.path[$locX])
            {
                if($global:arrPath.path[$locX][$locY])
                {
                    #Write-Host "G: " ($global:arrPath.path[$locX][$locY].G)

                    # G always wins
                    if($global:arrPath.path[$locX][$locY].G -lt $curG)
                    {
                        #Write-Host "Setting next"
                        $curG = $global:arrPath.path[$locX][$locY].G
                        $curD = $global:arrPath.path[$locX][$locY].D
                        $nextX = $locX
                        $nextY = $locY
                    }
                    elseif($global:arrPath.path[$locX][$locY].G -eq $curG)
                    {
                        if($global:arrPath.path[$locX][$locY].D -lt $curD)
                        {
                            $curG = $global:arrPath.path[$locX][$locY].G
                            $curD = $global:arrPath.path[$locX][$locY].D
                            $nextX = $locX
                            $nextY = $locY
                        }
                    }
                }
            }
        }

        #Write-Host "Nexts: $nextX $nextY"
        $global:arrPath.path[$nextX][$nextY].isPath = $True
        $workX = $nextX
        $workY = $nextY
        $nextX = -1
        $nextY = -1
        $curG = 10000
        $curD = 10000

        $global:arrPath.pathLength = $global:arrPath.pathLength + 1

        #Write-Host "Press any key to continue..."
        #$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

    Write-Host "findPath():Done"
    Write-Host "findPath():Length:"($global:arrPath.pathLength)
}

function markCheckedPath()
{
    Write-Host "markCheckedPath()"

    $keysX = $global:arrPath.path.Keys

    foreach($keyX in $keysX)
    {
        $keysY = $global:arrPath.path[($keyX)].Keys

        foreach($keyY in $keysY)
        {
            $display = "SELECTION_TILE_GREEN"

            if($global:arrPath.path[$keyX][$keyY].final)
            {
                $display = "SELECTION_TILE_MOVE"
            }

            $global:arrMap["WORLD_OVERLAY"][$keyX][$keyY] = $global:arrInterface[$display].bitmap
            MAP_drawTile $keyX $keyY $True
        }
    }
}

function getNextPosition()
{
    #Write-Host "getNextPosition()"
    $found = $False;

    $keysX = $global:arrPath.path.Keys
    
    # find the position with the lowest F
    # save X and Y
    # not final

    $global:arrPath.nextX = -1
    $global:arrPath.nextY = -1
    $curF = 10000;

    foreach($keyX in $keysX)
    {
        #Write-Host "KeyX: $keyX"
        $keysY = $global:arrPath.path[($keyX)].Keys

        foreach($keyY in $keysY)
        {
            #Write-Host "KeyY: $keyY"

            if(!$global:arrPath.path[$keyX][$keyY].final)
            {
                #Write-Host "not final"
                if($global:arrPath.path[$keyX][$keyY].F -lt $curF)
                {
                    #Write-Host "And better F"
                    $curF = $global:arrPath.path[$keyX][$keyY].F;
                    $global:arrPath.nextX = $keyX;
                    $global:arrPath.nextY = $keyY;
                }
            }
        }
    }

    $global:arrPath.isDone = !($global:arrPath.nextX -ne -1 -and $global:arrPath.nextY -ne -1)
    #Write-Host "IsDone: "($global:arrPath.isDone)
}

function generatePath($sourceX, $sourceY, $targetX, $targetY, $plrID, $maxDistance, $displayEndpoints)
{
    Write-Host "generatePath($sourceX, $sourceY, $targetX, $targetY, $plrID, $maxDistance)"
    $startLoop = Get-Date
    $tilesVisited = 0

    $global:arrPath = @{}
    $global:arrPath.validPath = $False
    $global:arrPath.isDone = $False
    $global:arrPath.pathLength = 0
    $global:arrPath.path = @{}
    $global:arrPath.sourceX = $sourceX
    $global:arrPath.sourceY = $sourceY
    $global:arrPath.targetX = $targetX
    $global:arrPath.targetY = $targetY

    ## set overlays
    if($displayEndpoints)
    {
        $global:arrMap["WORLD_OVERLAY"][$sourceX][$sourceY] = $global:arrInterface["SELECTION_TILE_VALID"].bitmap
        MAP_drawTile $sourceX $sourceY $True
        $global:arrMap["WORLD_OVERLAY"][$targetX][$targetY] = $global:arrInterface["SELECTION_TILE_ATTACK"].bitmap
        MAP_drawTile $targetX $targetY $True
    }

    # as far as I remember this is the sourcepoint
    $global:arrPath.path[$sourceX] = @{}
    $global:arrPath.path[$sourceX][$sourceY] = @{}
    $global:arrPath.path[$sourceX][$sourceY].G = 0
    $global:arrPath.path[$sourceX][$sourceY].H = (calculateDistance $sourceX $sourceY $targetX $targetY)
    $global:arrPath.path[$sourceX][$sourceY].F = ($global:arrPath.path[$sourceX][$sourceY].G + $global:arrPath.path[$sourceX][$sourceY].H)
    $global:arrPath.path[$sourceX][$sourceY].D = 0
    $global:arrPath.path[$sourceX][$sourceY].final = $False

    while(!$global:arrPath.isDone)
    {
        # get next source (which is the source in the first iteration)
        getNextPosition

        # bad case, no path found
        if($global:arrPath.isDone) {return;}

        # finalize source
        $workX = $global:arrPath.nextX
        $workY = $global:arrPath.nextY

        $global:arrPath.path[$workX][$workY].final = $True

        $workG = $global:arrPath.path[$workX][$workY].G
        #Write-Host "start work G: " ($global:arrPath.path[$workX][$workY].G)

        # check neighbors
        for($i = 0; $i -lt 4; $i++)
        {
            $locX = $workX + ($i % 2 * (2 - $i))
            $locY = $workY + (($i + 1) % 2 * (-1 + $i))
            #Write-Host "X: $locX"
            #Write-Host "Y: $locY"

            # good case, we found a path
            if($locX -eq $global:arrPath.targetX -and $locY -eq $global:arrPath.targetY)
            {
                Write-Host "Path found!"
                $global:arrPath.isDone = $True
                $global:arrPath.validPath = $True
                Write-Host "generatePath Time: " (New-TimeSpan -Start $startLoop -End (Get-Date))
                Write-Host "Visited Tiles: $tilesVisited"
                return;
            }

            $canMove = (canTerrainMoveDirection $locX $locY $i)
            #Write-Host "Can Move: $canMove"

            # if the current target can be reached, ignore it (don't finish)
            if(!$canMove) {continue;}

            if(!$global:arrPath.path[$locX]) 
            {   
                $global:arrPath.path[$locX] = @{}
            }

            if(!$global:arrPath.path[$locX][$locY]) 
            {
                $global:arrPath.path[$locX][$locY] = @{}
                $global:arrPath.path[$locX][$locY].G = 10000
                $global:arrPath.path[$locX][$locY].final = $False
            }

            # don't check tiles with better Gs
            if($global:arrPath.path[$locX][$locY].final) {continue;}

            if($global:arrPath.path[$locX][$locY].G -lt ($workG + 1)) {continue;}

            $tilesVisited = $tilesVisited + 1

            $global:arrPath.path[$locX][$locY].G = $workG + 1
            $global:arrPath.path[$locX][$locY].H = (calculateDistance $locX $locY $targetX $targetY)
            $global:arrPath.path[$locX][$locY].F = ($global:arrPath.path[$locX][$locY].G + $global:arrPath.path[$locX][$locY].H)
            $global:arrPath.path[$locX][$locY].final = $False

            $d1 = [math]::Abs($locX - $sourceX)
            $d2 = [math]::Abs($locY - $sourceY)

            $global:arrPath.path[$locX][$locY].D = if($d1 -gt $d2) { $d1} else {$d2}

            #Write-Host "DistX: " ($i - $global:arrPath.sourceX)
            #Write-Host "DistY: " ($j - $global:arrPath.sourceY)

            #Write-Host "G: "($global:arrPath.path[$locX][$locY].G)
            #Write-Host "H: "($global:arrPath.path[$locX][$locY].H)
            #Write-Host "F: "($global:arrPath.path[$locX][$locY].F)
            #Write-Host "---------------"
        }
    }

    Write-Host "generatePath Time: " (New-TimeSpan -Start $startLoop -End (Get-Date))
    Write-Host "Visited Tiles: $tilesVisited"
}

function getTerrainDat($strKey, $iIndex)
{
    #Write-Host "getTerrainDat($strKey, $iIndex) (->" ($global:arrTextures[$strKey][$iIndex]) ")"
    return $global:arrTextures[$strKey][$iIndex]
}

function canTerrainMove($strKey)
{
    for($i = 0; $i -lt 4; $i++)
    {
        #Write-Host "Terrain: " (getTerrainDat $strKey $i)
        if((getTerrainDat $strKey $i) -gt 0) {return $True}
    }
    return $False;
}

function canTerrainMoveDirection($x, $y, $dir)
{
    #Write-Host "canTerrainMoveDirection($x, $y, $dir)"

    if($x -lt 0 -or $y -lt 0) {return $False}
    if($x -ge $global:arrMap["WIDTH"]) {return $False}
    if($y -ge $global:arrMap["HEIGHT"]) {return $False}

    $texL1 = ($arrBaseTextureIDToKey[$global:arrMap["WORLD_L1"][$x][$y]])
    $texL2 = ($arrOverlayTextureIDToKey[$global:arrMap["WORLD_L2"][$x][$y]])
    $texL3 = ($arrObjectTextureIDToKey[$global:arrMap["WORLD_L3"][$x][$y]])

    $moveL1 = $True
    if($global:arrMap["WORLD_L1"][$x][$y] -ne -1)
    {
        $moveL1 = ((getTerrainDat $texL1 $dir) -gt 0)
    }

    $moveL2 = $True
    if($global:arrMap["WORLD_L2"][$x][$y] -ne -1)
    {
        $moveL2 = ((getTerrainDat $texL2 $dir) -gt 0)
    }
    $moveL3 = $True
    if($global:arrMap["WORLD_L3"][$x][$y] -ne -1)
    {
        $moveL3 = ((getTerrainDat $texL3 $dir) -gt 0)
    }

    #Write-Host "canTerrainMoveDirection($x,$y): $moveL1 $moveL2 $moveL3"

    return($moveL1 -and $moveL2 -and $moveL3)
}

function hasMoveFlag($x, $y, $flag)
{
    Write-Host "hasMoveFlag($x, $y, $flag)"
    if($x -lt 0 -or $y -lt 0) {return $False}
    if($x -ge $global:arrMap["WIDTH"]) {return $False}
    if($y -ge $global:arrMap["HEIGHT"]) {return $False}

    return (($global:arrMap["WORLD_MMAP"][$x][$y] -band $flag) -eq $flag)
}

function floodfillContinent($old, $new)
{
    If($old -eq $new) {return;}

    Write-Host "floodfillContinent($old, $new)"

    for($i = 0; $i -lt $global:arrMap["WIDTH"]; $i++)
    {
        for($j = 0; $j -lt $global:arrMap["HEIGHT"]; $j++)
        {
            if($global:arrMap["WORLD_CONTINENT"][$i][$j] -eq $old)
            {
                $global:arrMap["WORLD_CONTINENT"][$i][$j] = $new
            }
        }
    }
}

function buildMMAP()
{
    $runs5 = [math]::floor($global:arrMap["WIDTH"] * $global:arrMap["HEIGHT"] * 0.05);
    $runs = 0;

    # step 1: fill temporary data
    # as 0 = can't move and 1 = main continent (not know yet) we start at 2
    $maxIndex = 2

    # loop through all tiles
    for($i = 0; $i -lt $global:arrMap["WIDTH"]; $i++)
    {
        Write-Host "$i of "$global:arrMap["WIDTH"]

        $startLoop = Get-Date
        for($j = 0; $j -lt $global:arrMap["HEIGHT"]; $j++)
        {
            $global:arrMap["WORLD_MMAP"][$i][$j] = 0

            # as i = x
            # is j = y
            # but as we iterate over x, this is column wise, not row wise!
            #

            $canMoveU = ((canTerrainMoveDirection $i $j 0) -and (canTerrainMoveDirection $i ($j - 1) 2))
            $canMoveR = ((canTerrainMoveDirection $i $j 1) -and (canTerrainMoveDirection ($i + 1)  $j 3))
            $canMoveD = ((canTerrainMoveDirection $i $j 2) -and (canTerrainMoveDirection $i  ($j + 1)  0))
            $canMoveL = ((canTerrainMoveDirection $i $j 3) -and (canTerrainMoveDirection ($i - 1)  $j 1))

            #Write-Host "Pos: $i $j"
            #$selfU = (canTerrainMoveDirection $i $j 0)
            #$targetU = (canTerrainMoveDirection $i ($j - 1) 2)
            #$selfR = (canTerrainMoveDirection $i $j 1)
            #$targetR = (canTerrainMoveDirection ($i + 1)  $j 3)
            #$selfD = (canTerrainMoveDirection $i $j 2)
            #$targetD = (canTerrainMoveDirection $i  ($j + 1)  0)
            #$selfL = (canTerrainMoveDirection $i $j 3)
            #$targetL = (canTerrainMoveDirection ($i - 1)  $j 1)
            #
            #Write-Host "U: $selfU $targetU"
            #Write-Host "R: $selfR $targetR"
            #Write-Host "D: $selfD $targetD"
            #Write-Host "L: $selfL $targetL"

            #$canMoveU = ((canTerrainMoveDirection $i $j 0) -and (canTerrainMoveDirection $i ($j - 1) 0))
            #$canMoveR = ((canTerrainMoveDirection $i $j 1) -and (canTerrainMoveDirection ($i + 1)  $j 1))
            #$canMoveD = ((canTerrainMoveDirection $i $j 2) -and (canTerrainMoveDirection $i  ($j + 1)  2))
            #$canMoveL = ((canTerrainMoveDirection $i $j 3) -and (canTerrainMoveDirection ($i - 1)  $j 3))

            #Write-Host "Pos: $i $j"
            #Write-Host "U: $canMoveU"
            #Write-Host "R: $canMoveR"
            #Write-Host "D: $canMoveD"
            #Write-Host "L: $canMoveL"

            #Write-Host "OldResultFlag: " ($global:arrMap["WORLD_MMAP"][$i][$j])

            if($canMoveU) {$global:arrMap["WORLD_MMAP"][$i][$j] = ($global:arrMap["WORLD_MMAP"][$i][$j] -bxor 1)}
            if($canMoveR) {$global:arrMap["WORLD_MMAP"][$i][$j] = ($global:arrMap["WORLD_MMAP"][$i][$j] -bxor 2)}
            if($canMoveD) {$global:arrMap["WORLD_MMAP"][$i][$j] = ($global:arrMap["WORLD_MMAP"][$i][$j] -bxor 4)}
            if($canMoveL) {$global:arrMap["WORLD_MMAP"][$i][$j] = ($global:arrMap["WORLD_MMAP"][$i][$j] -bxor 8)}

            #Write-Host "ResultFlag: " ($global:arrMap["WORLD_MMAP"][$i][$j])

            # step 1, check if this is a possible continent tile or not
            $canMoveL1 = $True
            if($global:arrMap["WORLD_L1"][$i][$j] -ne -1)
            {
                $canMoveL1 = (canTerrainMove ($arrBaseTextureIDToKey[$global:arrMap["WORLD_L1"][$i][$j]]))
            }

            $canMoveL2 = $True
            if($global:arrMap["WORLD_L2"][$i][$j] -ne -1)
            {
                $canMoveL2 = (canTerrainMove ($arrOverlayTextureIDToKey[$global:arrMap["WORLD_L2"][$i][$j]]))
            }

            $canMoveL3 = $True
            if($global:arrMap["WORLD_L3"][$i][$j] -ne -1)
            {
                $canMoveL3 = (canTerrainMove ($arrObjectTextureIDToKey[$global:arrMap["WORLD_L3"][$i][$j]]))
            }

            $canMove = ($canMoveL1 -and $canMoveL2 -and $canMoveL3)
            # TODO: generate move index
            if($canMove)
            {
                if(hasMoveFlag $i $j 8)
                {
                    # race condition, $i needs to be > 0, otherwise the array check fill crash
                    if($i -gt 0 -and $global:arrMap["WORLD_CONTINENT"][($i - 1)][$j] -eq 0)
                    {
                        $global:arrMap["WORLD_CONTINENT"][$i][$j] = $maxIndex
                        $global:arrMap["WORLD_CONTINENT"][($i - 1)][$j] = $maxIndex
                        $maxIndex = $maxIndex + 1
                    }
                    elseif($i -gt 0)
                    {
                        $global:arrMap["WORLD_CONTINENT"][$i][$j] = $global:arrMap["WORLD_CONTINENT"][($i - 1)][$j]
                    }
                    else
                    {
                        $global:arrMap["WORLD_CONTINENT"][$i][$j] = $maxIndex
                        $maxIndex = $maxIndex + 1
                    }
                }

                if(hasMoveFlag $i $j 1)
                {
                    # we possibly already have a flag
                    $selfContinent = ($global:arrMap["WORLD_CONTINENT"][$i][$j] -gt 0)

                    if($j -gt 0 -and $global:arrMap["WORLD_CONTINENT"][$i][($j - 1)] -eq 0)
                    {
                        if($selfContinent)
                        {
                            $global:arrMap["WORLD_CONTINENT"][$i][($j - 1)] = $global:arrMap["WORLD_CONTINENT"][$i][$j]
                        }
                        else
                        {
                            $global:arrMap["WORLD_CONTINENT"][$i][$j] = $maxIndex
                            $global:arrMap["WORLD_CONTINENT"][$i][($j - 1)] = $maxIndex
                            $maxIndex = $maxIndex + 1
                        }
                    }
                    elseif($j -gt 0)
                    {
                        if($selfContinent)
                        {
                            if($global:arrMap["WORLD_CONTINENT"][$i][($j -1)] -ne $global:arrMap["WORLD_CONTINENT"][$i][$j])
                            {
                                floodfillContinent $global:arrMap["WORLD_CONTINENT"][$i][($j -1)] $global:arrMap["WORLD_CONTINENT"][$i][$j]
                            }
                        }
                        else
                        {
                            $global:arrMap["WORLD_CONTINENT"][$i][$j] = $global:arrMap["WORLD_CONTINENT"][$i][($j -1)]
                        }
                    }
                    else
                    {
                        $global:arrMap["WORLD_CONTINENT"][$i][$j] = $maxIndex
                        $maxIndex = $maxIndex + 1
                    }
                }

                if($global:arrMap["WORLD_CONTINENT"][$i][$j] -eq 0)
                {
                    $global:arrMap["WORLD_CONTINENT"][$i][$j] = $maxIndex
                    $maxIndex = $maxIndex + 1
                }
            }
            else
            {
                $global:arrMap["WORLD_CONTINENT"][$i][$j] = 0
            }

            if(($i * $j) -ge $runs)
            {
                $percent = [math]::floor(($i * $j) / ($global:arrMap["WIDTH"] * $global:arrMap["HEIGHT"]) * 100)

                $runs += $runs5;

                if($global:strGameState -eq "EDIT_MAP_ESCAPE")
                {
                    BAR_SetTextValue "WND_EDITOR_WAIT_N" "BAR_SAVE_PROGRESS" ("MMAP (" + $percent +"%)") ($percent / 100)
                }

                [System.Windows.Forms.Application]::DoEvents() 
            }
        }

        $endLoop = Get-Date
        Write-Host "generateMMAP: " (New-TimeSpan -Start $startLoop -End $endLoop)
    }

    # Set continent of p1 to 1
    if($global:arrMap["PLAYER_01X"] -ne -1 -and $global:arrMap["PLAYER_01Y"] -ne -1)
    {
        floodfillContinent ($global:arrMap["WORLD_CONTINENT"][([int]($global:arrMap["PLAYER_01X"]))][([int]($global:arrMap["PLAYER_01Y"]))]) 1
    }
}
#endregion

#region \GFX\INTERFACE\
$strPathInterfaceGFX = ".\GFX\INTERFACE\"
$global:arrInterface = @{}

loadGraphicsByName $global:arrInterface $strPathInterfaceGFX "SELECTION_TILE_*" $True
#endregion

#region FUNCTIONS_LOAD_SOUNDS
function playSFX($strName)
{
    Write-Host "playSFX($strName)"

    if ($global:arrSFX[$strName]) 
    {
        $global:arrSFX[$strName].Position = New-TimeSpan -Hour 0 -Minute 0 -Seconds 0;
        $global:arrSFX[$strName].Volume = [int]$global:arrSettings["VOLUMEEFFECTS"] * 0.1;
        $global:arrSFX[$strName].Play();
    }
    else
    {
        Write-Host "Cant play $strName"
    }
}

function playSongs()
{
    if([int]$global:arrSettingsInternal["SONGS"] -le 0) {return;}

    $global:arrMusic[([int]$global:arrSettingsInternal["SONG_CURRENT"])].player.Stop();

    if($global:arrSettings["VOLUMEMUSIC"] -le 0) {return;}

    if($global:arrMusic.loopCounter -le 0)
    {
        if($global:arrMusic.loopCounter -ne -1)
        {
            [int]($global:arrSettingsInternal["SONG_CURRENT"]) += 1
        }

        if([int]$global:arrSettingsInternal["SONG_CURRENT"] -ge [int]$global:arrSettingsInternal["SONGS"])
        {
            [int]$global:arrSettingsInternal["SONG_CURRENT"] = 0
        }

        $global:arrMusic.loopCounter = $global:arrMusic[([int]$global:arrSettingsInternal["SONG_CURRENT"])].repeats - 1
    }
    else
    {
        $global:arrMusic.loopCounter -= 1
    }

    $global:arrMusic[([int]$global:arrSettingsInternal["SONG_CURRENT"])].player.Position = New-TimeSpan -Hour 0 -Minute 0 -Seconds 0;
    $global:arrMusic[([int]$global:arrSettingsInternal["SONG_CURRENT"])].player.Volume = [int]$global:arrSettings["VOLUMEMUSIC"] * 0.1;
    $global:arrMusic[([int]$global:arrSettingsInternal["SONG_CURRENT"])].player.Play();
}

function loadSoundByName($objTargetArray, $strPath, $strFilter)
{
    foreach($file in (Get-ChildItem -Path $strPath $strFilter))
    {
        $arrSplit = $file.Name.split(".")
    
        $objTargetArray[$arrSplit[0]] = New-Object System.Windows.Media.Mediaplayer
        $objTargetArray[$arrSplit[0]].Open([uri]($file.FullName))
        # "mute" the sound, otherwise it's played on load?
        $objTargetArray[$arrSplit[0]].Volume = 0;
    }
}

$global:arrMusic = @{}
$global:arrMusic.loopCounter = -1

function loadSongs($strPath, $strFilter)
{
    $iID = 0

    foreach($file in (Get-ChildItem -Path $strPath $strFilter))
    {
        # 0 = SNG
        # 1 = ID
        # 2 = repeats
        $arrSplit = ($file.Name.split("."))[0].split("_")

        $global:arrMusic[$iID] = @{}
        $global:arrMusic[$iID].player = New-Object System.Windows.Media.Mediaplayer
        $global:arrMusic[$iID].player.Open([uri]($file.FullName))
        $global:arrMusic[$iID].player.Volume = [int]$global:arrSettings["VOLUMEMUSIC"] * 0.1;
        $global:arrMusic[$iID].repeats = [int]($arrSplit[2])
        $global:arrMusic[$iID].player.Add_MediaEnded({playSongs})

        $iID += 1
    }

    $global:arrSettingsInternal["SONGS"] = $iID
}

#endregion

#region \SND\
$strPathMusic = ".\SND\"
$global:arrSFX = @{}

loadSoundByName $global:arrSFX $strPathMusic "SND_*"
loadSoundByName $global:arrSFX $strPathMusic "SFX_*"

loadSongs $strPathMusic "SNG_*"
#endregion

#region \GFX\IMG\
$strPathImageGFX = ".\GFX\IMAGE\"
$global:objWorld = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathImageGFX + 'SCREEN_SPLASH.png'))));
$global:objWorldFoW = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathImageGFX + 'SCREEN_SPLASH.png'))));

#endregion

#region \GFX\FONT\
$strPathToFontGFX = ".\GFX\FONT\"
$arrFont = @{}
$fontString = "! # %&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ\^_©ÄÖÜß []|"

function setCharColor($strChar, $strColor, $doOutline)
{
    if ($strChar -eq "") {return}

    if (!$arrFont[$strChar]) {return}

    for($i = 0; $i -lt $arrFont[$strChar].Width; $i++)
    {
        for($j = 0; $j -lt $arrFont[$strChar].Height; $j++)
        {
            if($arrFont[$strChar].GetPixel($i, $j).A -gt 0 -and $arrFont[$strChar].GetPixel($i, $j) -ne $global:arrColors["CLR_MAGENTA"].color -and $arrFont[$strChar].GetPixel($i, $j) -ne $global:arrColors["CLR_BLACK"].color)
            {
                $tmpClr = $arrFont[$strChar].GetPixel($i, $j)

                switch($strColor)
                {
                    "GOLD" {$tmpClr = $global:arrColors["CLR_GOLD_1"].color}
                    "RED" {$tmpClr = $global:arrColors["CLR_RED"].color}
                    "GRAY" {$tmpClr = $global:arrColors["CLR_GRAY"].color}
                    "GREEN" {$tmpClr = $global:arrColors["CLR_GREEN"].color}
                    default {return}
                }

                $arrFont[$strChar].SetPixel($i, $j, $tmpClr)
            }
        }
    }
}

for($i = 1; $i -le $fontString.Length; $i++)
{
    if($i -eq 2)
    {
        $arrFont[""""] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + $i + '.png'  ))));
        $arrFont[""""].MakeTransparent($global:arrColors["CLR_MAGENTA"].color);
        setCharColor ("""") "GOLD" $False
    }
    elseif($i -eq 4)
    {
        $arrFont["`$"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + $i + '.png'  ))));
        $arrFont["`$"].MakeTransparent($global:arrColors["CLR_MAGENTA"].color);
        setCharColor ("`$") "GOLD" $False
    }
    else
    {
        $arrFont[$fontString.Substring(($i - 1), 1)] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + $i + '.png'  ))));
        $arrFont[$fontString.Substring(($i - 1), 1)].MakeTransparent($global:arrColors["CLR_MAGENTA"].color);
        setCharColor ($fontString.Substring(($i - 1), 1)) "GOLD" $False
    }
    
}

function replaceColor($objImage, $colorSource, $colorTarget)
{
    for($i = 0; $i -lt $objImage.Width; $i++)
    {
        for($j = 0; $j -lt $objImage.Height; $j++)
        {
            if($objImage.GetPixel($i, $j) -eq $colorSource)
            {

                $objImage.SetPixel($i, $j, $colorTarget)
            }
        }
    }
}
#endregion

#region \GFX\BUILDING\
# ideas for bld table
# ID, ID = index
# PosX
# PosY
# Owner
# HP
# Type
#####
$global:arrBuildings = @{}

$global:arrBuildingIDToKey = "HUM_HQ", "HUM_HOUSE_SMALL", "HUM_HOUSE_MEDIUM", "HUM_HOUSE_LARGE", "HUM_FARM", "HUM_FIELD", "HUM_MINE", "HUM_SAWMILL", "HUM_BARRACKS", "HUM_TOWER"

$rect_tile    = New-Object System.Drawing.Rectangle(0, 0, 16, 16)
$strPathToBuildingGFX = ".\GFX\BUILDING\"
$global:arrBuilding = @{}

for($i = 0; $i -lt $global:arrBuildingIDToKey.Length; $i++)
{
    $bldKey = $global:arrBuildingIDToKey[$i]

    $arrBuilding[$global:arrBuildingIDToKey[$i]] = @{}

    # player 0
    $global:arrIcons[($bldKey + "_0_0")] = @{}
    $global:arrIcons[($bldKey + "_0_0")].bitmap = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToBuildingGFX + ($global:arrBuildingIDToKey[$i] + '_00.png')  ))));
    $global:arrIcons[($bldKey + "_0_1")] = @{}
    $global:arrIcons[($bldKey + "_0_1")].bitmap = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToBuildingGFX + ($global:arrBuildingIDToKey[$i] + '_01.png')  ))));

    for($j = 1; $j -le $global:arrSettingsInternal["PLAYER_MAX"]; $j++)
    {
        $global:arrIcons[($bldKey + "_" + $j + "_0")] = @{}
        $global:arrIcons[($bldKey + "_" + $j + "_0")].bitmap = $global:arrIcons[($bldKey + "_0_0")].bitmap.Clone($rect_tile, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        replaceColor ($global:arrIcons[($bldKey + "_" + $j + "_0")].bitmap) $global:arrColors["CLR_PLAYER_DEF00"].color $global:arrColors[("CLR_PLAYER_" + $j + "0")].color
        replaceColor ($global:arrIcons[($bldKey + "_" + $j + "_0")].bitmap) $global:arrColors["CLR_PLAYER_DEF01"].color $global:arrColors[("CLR_PLAYER_" + $j + "1")].color

        $global:arrIcons[($bldKey + "_" + $j + "_1")] = @{}
        $global:arrIcons[($bldKey + "_" + $j + "_1")].bitmap = $global:arrIcons[($bldKey + "_0_1")].bitmap.Clone($rect_tile, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        replaceColor ($global:arrIcons[($bldKey + "_" + $j + "_1")].bitmap) $global:arrColors["CLR_PLAYER_DEF00"].color $global:arrColors[("CLR_PLAYER_" + $j + "0")].color
        replaceColor ($global:arrIcons[($bldKey + "_" + $j + "_1")].bitmap) $global:arrColors["CLR_PLAYER_DEF01"].color $global:arrColors[("CLR_PLAYER_" + $j + "1")].color
    }
}

#endregion

#region UNITS
$strPathToUnitGFX = ".\GFX\UNIT\"
$global:arrArmies = @{}

# load player 0
$arrIcons[('HUM_UNIT_0')] = @{}
$arrIcons[('HUM_UNIT_0')].bitmap = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToUnitGFX + ('HUM_UNIT.png')  ))));

for($j = 1; $j -le $global:arrSettingsInternal["PLAYER_MAX"]; $j++)
{
    $arrIcons[('HUM_UNIT_' + $j)] = @{}
    $arrIcons[('HUM_UNIT_' + $j)].bitmap = $arrIcons[('HUM_UNIT_0')].bitmap.Clone($rect_tile, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    replaceColor ($arrIcons[('HUM_UNIT_' + $j)].bitmap) $global:arrColors["CLR_PLAYER_DEF00"].color $global:arrColors[("CLR_PLAYER_" + $j + "0")].color
    replaceColor ($arrIcons[('HUM_UNIT_' + $j)].bitmap) $global:arrColors["CLR_PLAYER_DEF01"].color $global:arrColors[("CLR_PLAYER_" + $j + "1")].color
}
#endregion

#region BUILDING_INFO
$arrBuilding["HUM_HQ"].name = "Headquarter"
$arrBuilding["HUM_HOUSE_SMALL"].name = "House small"
$arrBuilding["HUM_HOUSE_MEDIUM"].name = "House medium"
$arrBuilding["HUM_HOUSE_LARGE"].name = "House large"
$arrBuilding["HUM_FARM"].name = "Farm"
$arrBuilding["HUM_FIELD"].name = "Field"
$arrBuilding["HUM_MINE"].name = "Mine"
$arrBuilding["HUM_SAWMILL"].name = "Sawmill"
$arrBuilding["HUM_BARRACKS"].name = "Barracks"
$arrBuilding["HUM_TOWER"].name = "Tower"

$arrBuilding["HUM_HQ"].gold_cost = 100
$arrBuilding["HUM_HOUSE_SMALL"].gold_cost = 5
$arrBuilding["HUM_HOUSE_MEDIUM"].gold_cost = 12
$arrBuilding["HUM_HOUSE_LARGE"].gold_cost = 28
$arrBuilding["HUM_FARM"].gold_cost = 10
$arrBuilding["HUM_FIELD"].gold_cost = 8
$arrBuilding["HUM_MINE"].gold_cost = 10
$arrBuilding["HUM_SAWMILL"].gold_cost = 30
$arrBuilding["HUM_BARRACKS"].gold_cost = 55
$arrBuilding["HUM_TOWER"].gold_cost = 70

$arrBuilding["HUM_HQ"].wood_cost = 100
$arrBuilding["HUM_HOUSE_SMALL"].wood_cost = 10
$arrBuilding["HUM_HOUSE_MEDIUM"].wood_cost = 22
$arrBuilding["HUM_HOUSE_LARGE"].wood_cost = 52
$arrBuilding["HUM_FARM"].wood_cost = 30
$arrBuilding["HUM_FIELD"].wood_cost = 4
$arrBuilding["HUM_MINE"].wood_cost = 30
$arrBuilding["HUM_SAWMILL"].wood_cost = 10
$arrBuilding["HUM_BARRACKS"].wood_cost = 20
$arrBuilding["HUM_TOWER"].wood_cost = 80

$arrBuilding["HUM_HQ"].hitpoints = 120
$arrBuilding["HUM_HOUSE_SMALL"].hitpoints = 12
$arrBuilding["HUM_HOUSE_MEDIUM"].hitpoints = 24
$arrBuilding["HUM_HOUSE_LARGE"].hitpoints = 48
$arrBuilding["HUM_FARM"].hitpoints = 18
$arrBuilding["HUM_FIELD"].hitpoints = 8
$arrBuilding["HUM_MINE"].hitpoints = 30
$arrBuilding["HUM_SAWMILL"].hitpoints = 30
$arrBuilding["HUM_BARRACKS"].hitpoints = 30
$arrBuilding["HUM_TOWER"].hitpoints = 100

$arrBuilding["HUM_HQ"].buildspeed = 0.1
$arrBuilding["HUM_HOUSE_SMALL"].buildspeed = 0.5
$arrBuilding["HUM_HOUSE_MEDIUM"].buildspeed = 0.25
$arrBuilding["HUM_HOUSE_LARGE"].buildspeed = 0.25
$arrBuilding["HUM_FARM"].buildspeed = 0.5
$arrBuilding["HUM_FIELD"].buildspeed = 1
$arrBuilding["HUM_MINE"].buildspeed = 0.25
$arrBuilding["HUM_SAWMILL"].buildspeed = 0.34
$arrBuilding["HUM_BARRACKS"].buildspeed = 0.25
$arrBuilding["HUM_TOWER"].buildspeed = 0.2

# 0 = none
# 1 = gold
# 2 = wood
# 3 = food
# 4 = people
# > 4 = all

# gold_income
# wood_income
# food_income
# production
$arrBuilding["HUM_HQ"].productionType = 5
$arrBuilding["HUM_HOUSE_SMALL"].productionType = 4
$arrBuilding["HUM_HOUSE_MEDIUM"].productionType = 4
$arrBuilding["HUM_HOUSE_LARGE"].productionType = 4
$arrBuilding["HUM_FARM"].productionType = 0
$arrBuilding["HUM_FIELD"].productionType = 3
$arrBuilding["HUM_MINE"].productionType = 1
$arrBuilding["HUM_SAWMILL"].productionType = 2
$arrBuilding["HUM_BARRACKS"].productionType = 0
$arrBuilding["HUM_TOWER"].productionType = 0

$arrBuilding["HUM_HQ"].productionAmount = 5
$arrBuilding["HUM_HOUSE_SMALL"].productionAmount = 2
$arrBuilding["HUM_HOUSE_MEDIUM"].productionAmount = 4
$arrBuilding["HUM_HOUSE_LARGE"].productionAmount = 8
$arrBuilding["HUM_FARM"].productionAmount = 0
$arrBuilding["HUM_FIELD"].productionAmount = 2
$arrBuilding["HUM_MINE"].productionAmount = 8
$arrBuilding["HUM_SAWMILL"].productionAmount = 6
$arrBuilding["HUM_BARRACKS"].productionAmount = 0
$arrBuilding["HUM_TOWER"].productionAmount = 0

#endregion

# region AI
$global:arrAIPlayer = @{}

for($i = 1; $i -le 4; $i++)
{
    $global:arrAIPlayer[$i] = @{}
    $global:arrAIPlayer[$i].bldCount = @{}
    $global:arrAIPlayer[$i].bldPrio = @{}

    # this is the next build if AI has enough wares
    $global:arrAIPlayer[$i].bldHold = -1

    for($j = 0; $j -lt $global:arrBuildingIDToKey.Count; $j++)
    {
        $global:arrAIPlayer[$i].bldCount[$j] = 0
        $global:arrAIPlayer[$i].bldPrio[$j] = 0
    }

    # as there currently is no update, fake some values
    $global:arrAIPlayer[$i].bldCount[0] = 1
    $global:arrAIPlayer[$i].bldPrio[6] = 50
    $global:arrAIPlayer[$i].bldPrio[7] = 50
}

# the AI needs to be aware of resources
# for that reason the map is scanned for gold and stuff
# also the quality needs to be calculated (free spots around)

$global:AI_InformationArray = @{}
$global:AI_InformationArray.isInitialized = $False
# 0 = gold
$global:AI_InformationArray[0] = @{}
# 1 = wood
$global:AI_InformationArray[1] = @{}
# internal data:
# 0 = quality
# 1 = dist HQ1
# 2 = dist HQ2
# 3 = dist HQ3
# 4 = dist HQ4
# 5 = locX
# 6 = locY

function AI_calculateQuality($iPosX, $iPosY)
{
    $quality = 0

    # check if correct continent
    if(!($global:arrMap["WORLD_CONTINENT"][$iPosX][$iPosY] -eq 1)) {return $quality}

     ## new mode
     for($i = 0; $i -lt 4; $i++)
     {
         $locX = $iPosX + ($i % 2 * (2 - $i))
         $locY = $iPosY + (($i + 1) % 2 * (-1 + $i))

        if((checkBuildingQuality -1 $locX $locY -1))
        {
            $quality = $quality + 1
        }
     }

    return $quality
}

function AI_initializeInformationArray()
{
    Write-Host "AI_initializeInformationArray()"

    for($i = 0; $i -lt $global:arrMap["WIDTH"]; $i++)
    {
        for($j = 0; $j -lt $global:arrMap["HEIGHT"]; $j++)
        {
            $objID = $global:arrMap["WORLD_L3"][$i][$j]

            if($objID -eq -1) { continue; }
            # 18 == gold
            # 13, 14, 15, 16 == wood 

            $type = 0

            if($objID -eq 18 -or ($objID -ge 13 -and $objID -le 16))
            {
                # if it's not gold it's wood
                if($objID -ne 18) {$type = 1}

                $qual = (AI_calculateQuality $i $j)
                $id = $global:AI_InformationArray[$type].Count

                $global:AI_InformationArray[$type][$id] = @{}
                $global:AI_InformationArray[$type][$id][0] = $qual
                $global:AI_InformationArray[$type][$id][5] = $i
                $global:AI_InformationArray[$type][$id][6] = $j

                for($p = 1; $p -le 4; $p++)
                {
                    $plrX = $global:arrMap[("PLAYER_0" + $p + "X")]
                    $plrY = $global:arrMap[("PLAYER_0" + $p + "Y")]

                    $dist = -1

                    # no need for distance checks if qual is 0 anyway
                    if($plrX -ne -1 -and $plrY -ne -1 -and $qual -gt 0)
                    {
                        generatePath $plrX $plrY $i $j -1 -1 $False
                        findPath

                        $dist = $global:arrPath.pathLength
                    }

                    $global:AI_InformationArray[$type][$id][$p] = $dist
                }
            }
        }
    }

    #Write-Host "Goldspots: " ($global:AI_InformationArray[0].Count)
    #for($g = 0; $g -lt $global:AI_InformationArray[0].Count; $g++)
    #{
    #    Write-Host "Pos: " ($global:AI_InformationArray[0][$g][5]) ($global:AI_InformationArray[0][$g][6])
    #    Write-Host "qual: " ($global:AI_InformationArray[0][$g][0])
    #    Write-Host "D1: " ($global:AI_InformationArray[0][$g][1])
    #    Write-Host "D2: " ($global:AI_InformationArray[0][$g][2])
    #    Write-Host "D3: " ($global:AI_InformationArray[0][$g][3])
    #    Write-Host "D4: " ($global:AI_InformationArray[0][$g][4])
    #}
    #Write-Host "-----"
    #Write-Host "Woodspots: " ($global:AI_InformationArray[1].Count)
    #for($g = 0; $g -lt $global:AI_InformationArray[1].Count; $g++)
    #{
    #    Write-Host "Pos: " ($global:AI_InformationArray[1][$g][5]) ($global:AI_InformationArray[1][$g][6])
    #    Write-Host "qual: " ($global:AI_InformationArray[1][$g][0])
    #    Write-Host "D1: " ($global:AI_InformationArray[1][$g][1])
    #    Write-Host "D2: " ($global:AI_InformationArray[1][$g][2])
    #    Write-Host "D3: " ($global:AI_InformationArray[1][$g][3])
    #    Write-Host "D4: " ($global:AI_InformationArray[1][$g][4])
    #}

    $global:AI_InformationArray.isInitialized = $True
}

function AI_getPriorityBuilding($iAIID)
{
    Write-Host "AI_getPriorityBuilding($iAIID)"

    $bldID = -1
    $bldPrio = -1

    for($i = 0; $i -lt $global:arrBuildingIDToKey.Count; $i++)
    {
        Write-Host "Prio: " ($global:arrAIPlayer[$iAIID].bldPrio[$i])

        if($global:arrAIPlayer[$iAIID].bldPrio[$i] -gt $bldPrio)
        {
            $bldID = $i
            $bldPrio = $global:arrAIPlayer[$iAIID].bldPrio[$i]
        }
    }

    Write-Host "Returns $bldID"
    return $bldID
}

function AI_findSpotForBuilding($iAIID, $bldID)
{
    Write-Host "AI_findSpotForBuilding($iAIID, $bldID)"
    $spot = @{}
    $spot.x = -1
    $spot.y = -1
    $spot.isValid = $False

    # iterate over all buildings, find HQ/Tower

    # iterate over all surrounding spots and check if BQ fits

    # if BQ fits, set spot values and return

    for($i = 0; $i -lt $global:arrMap["BUILDING_INDEX"]; $i++)
    {
        # no longer valid (destroyed)
        if(!($global:arrBuildings[$i])){continue}

        # must be given AI
        if($global:arrBuildings[$i][2] -ne $iAIID) {continue;}

        # must be HQ or Tower
        if($global:arrBuildings[$i][3] -ne 0 -and $global:arrBuildings[$i][3] -ne 11) {continue;}

        # and finised
        if(([int]($global:arrBuildings[$i][4]) -ne 1)) {continue;}

        # thats the center for our search
        $bldX = $global:arrBuildings[$i][0]
        $bldY = $global:arrBuildings[$i][1]

        $range = 3
        if($bldID -eq 11){range = 4}

        # each column
        for($locX = ($bldX - $range); $locX -le ($bldX + $range); $locX++)
        {
            for($locY = ($bldY - $range); $locY -le ($bldY + $range); $locY++)
            {
                # invalid spot
                if(!(WORLD_isInWorld $locX $locY)){continue;}

                $isSpot = checkIfBuildingPossible $bldID $locX $locY $iAIID #($iBuildingID, $posX, $posY, $iPlayerID)

                if($isSpot)
                {
                    Write-Host "Found valid spot at $locX $locY"
                    $spot.x = $locX
                    $spot.y = $locY
                    $spot.isValid = $True
                    return $spot
                }
            }
        }
    }

    Write-Host "Spot: $spot"
    return $spot
}

function AI_buildBuilding($iAIID)
{
    Write-Host "AI_buildBuilding($iAIID)"
    # 0 = ERROR
    # 1 = not Possible (Wares)
    # 2 = not Possible (Spots)
    # 3 = Success

    $bldID = (AI_getPriorityBuilding $iAIID)
    if($bldID -eq -1) {return 0;}

    Write-Host "Got BLD ID"

    $hasWares = (checkIfPlayerHasWaresForBuilding $iAIID $bldID)
    if(!$hasWares) 
    {
        $global:arrAIPlayer[$iAIID].bldHold = $bldID;
        return 1;
    }

    Write-Host "Got BLD Wares"

    $buildSpot = (AI_findSpotForBuilding $iAIID $bldID)
    if(!$buildSpot.isValid) {return 2;}

    Write-Host "Got buildSpot" ($buildSpot.x) ($buildSpot.y)

    addBuildingAtPositionForPlayer $buildSpot.x $buildSpot.y $bldID $iAIID 0.0
    return 3;
}

# endregion

$DrawingSizeX    = 480
$DrawingSizeY    = 270

$global:objWorldBackground = New-Object System.Drawing.Bitmap($DrawingSizeX, $DrawingSizeY);
$global:bitmap  = New-Object System.Drawing.Bitmap($DrawingSizeX, $DrawingSizeY);

# Create the form
$objForm = New-Object System.Windows.Forms.Form
$objForm.MaximizeBox = $False;
$objForm.MinimizeBox = $False;
$objForm.size = New-Object System.Drawing.Size(($DrawingSizeX + $wndOffsetX), ($DrawingSizeY + $wndOffsetY))
$objForm.Topmost = $global:arrSettings["TOPMOST"]; 
#https://i-msdn.sec.s-msft.com/dynimg/IC24340.jpeg

$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.SizeMode = 4
$pictureBox.Size = New-Object System.Drawing.Size($DrawingSizeX, $DrawingSizeY)
$objForm.controls.add($pictureBox)
$objForm.AutoSize = $False
$pictureBox.Add_Click({onMouseClick "Picturebox" $_})
$pictureBox.Add_MouseDown({onMouseDown "Picturebox" $_})
$pictureBox.Add_MouseUp({onMouseUp "Picturebox" $_})
$objForm.Add_Shown({$objForm.Activate()})
$pictureBox.Add_Paint({onRedraw $this $_})
$objForm.Add_KeyDown({onKeyPress $this $_})
#$objForm.Add_MouseMove({onMouseMove $this $_})
$pictureBox.Add_MouseMove({onMouseMove $this $_})
$objForm.Add_Click({onMouseClick "Form" $_})
$objForm.Text = ("PowerHeroes v" + $global:VersionInfo[0] + "." + $global:VersionInfo[1] + "." + $global:VersionInfo[2] + " - " + $global:VersionInfo[3])
If(!$QuickStart) {If (Test-Path ".\PowerHeroes.exe") { $objForm.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon(".\PowerHeroes.exe")}}
$objForm.Add_Closing({ SERVER_stopServer; CLIENT_stopClient})

#$objForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$objForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
#$objForm.Location = New-Object System.Drawing.Point(2, 500)

# used for changing the cursor
if(!$QuickStart)
{
try {
Add-Type -MemberDefinition @"
[DllImport("user32.dll")]
public static extern IntPtr LoadCursorFromFile(String lpFileName);
"@ -Namespace "MyWin32" -Name "LoadCursor"

$objForm.Cursor = [MyWin32.LoadCursor]::LoadCursorFromFile(".\GFX\INTERFACE\CURSOR_SHINY.cur")
} catch { Write-Host "Can't change cursor!"}
}

function keepFormRatio()
{
    $fac_x = ($objForm.Size.Width - $wndOffsetX)  / ($DrawingSizeX)
    $fac_y = ($objForm.Size.Height - $wndOffsetY) / ($DrawingSizeY)
    
    if($fac_x -gt $fac_y)
    {
        $objForm.size = New-Object System.Drawing.Size($objForm.Size.Width, ($fac_x * $DrawingSizeY + $wndOffsetY))
        $global:arrSettings["SIZE"] = $fac_x
    }
    else
    {
        $objForm.size = New-Object System.Drawing.Size(($fac_y * $DrawingSizeX + $wndOffsetX), $objForm.Size.Height)
        $global:arrSettings["SIZE"] = $fac_y
    }
}

$objForm.Add_ResizeEnd({

    keepFormRatio
    
    $val_x = $objForm.Size.Width
    $val_y = $objForm.Size.Height
    
    $pictureBox.Size = New-Object System.Drawing.Size(($val_x - $wndOffsetX), ($val_y - $wndOffsetY))

    $global:arrSettings["LAST_X"] = $objForm.Location.X;
    $global:arrSettings["LAST_Y"] = $objForm.Location.Y;

    saveConfig
})

function handleScrolling($posX, $posY)
{
    if($global:arrPlayerInfo.scrollX -eq -1 -or $global:arrPlayerInfo.scrollY -eq -1)
    {
        $global:arrPlayerInfo.scrollX = $posX
        $global:arrPlayerInfo.scrollY = $posY
    }
    else
    {
        # calc distances
        $distX = $global:arrPlayerInfo.scrollX - $posX
        $distY = $global:arrPlayerInfo.scrollY - $posY

        if([math]::Abs($distX) -ge ($global:arrSettingsInternal["TILESIZE"] / 2))
        {
            if($distX -lt 0)
            {
                scrollGameWorld "Right" 1
                $global:arrPlayerInfo.scrollX = $posX
            }
            else
            {
                scrollGameWorld "Left" 1
                $global:arrPlayerInfo.scrollX = $posX
            }
        }

        if([math]::Abs($distY) -ge ($global:arrSettingsInternal["TILESIZE"] / 2))
        {
            if($distY -lt 0)
            {
                scrollGameWorld "Down" 1
                $global:arrPlayerInfo.scrollY = $posY
            }
            else
            {
                scrollGameWorld "Up" 1
                $global:arrPlayerInfo.scrollY = $posY
            }
        }
    }
}

function onMouseMove($sender, $EventArgs)
{
    if($global:strGameState -ne "EDIT_MAP" -and $global:strGameState -ne "SINGLEPLAYER_INGAME")
    {
        return;
    }
    
    $relX = [System.Windows.Forms.Cursor]::Position.X - $objForm.Location.X - 8 # 8 = left border
    $relY = [System.Windows.Forms.Cursor]::Position.Y - $objForm.Location.Y - 30 # 30 = upper border
    
    $fac_x = ($objForm.Size.Width - $wndOffsetX)  / ($DrawingSizeX)
    $fac_y = ($objForm.Size.Height - $wndOffsetY) / ($DrawingSizeY)

    $relX = ($relX / $fac_x)
    $relY = ($relY / $fac_y)
    
    if($EventArgs.Button -eq "Right" -and $relX -lt ($DrawingSizeX - 160))
    {
        handleScrolling $relX $relY
        return;
    }

    if($EventArgs.Button -eq "Left" -and $relX -lt ($DrawingSizeX - 160))
    {
        handleClickEditor $relX $relY
    }
    $tile_x = [math]::floor($relX / $global:arrSettingsInternal["TILESIZE"]) + $global:arrCreateMapOptions["EDITOR_CHUNK_X"]
    $tile_y = [math]::floor($relY / $global:arrSettingsInternal["TILESIZE"]) + $global:arrCreateMapOptions["EDITOR_CHUNK_Y"]
    
    $global:arrCreateMapOptions["SELECTED_X"] = $tile_x;
    $global:arrCreateMapOptions["SELECTED_Y"] = $tile_y;
    
    $pictureBox.Refresh();
}

function MAP_changeTile($objImage, $iTileX, $iTileY)
{
    $rect_dst = New-Object System.Drawing.Rectangle(($iTileX * $global:arrSettingsInternal["TILESIZE"]), ($iTileY * $global:arrSettingsInternal["TILESIZE"]), $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"])

    $objImage.MakeTransparent($global:arrColors["CLR_MAGENTA"].color);

    $tmp_grd = [System.Drawing.Graphics]::FromImage($global:objWorld);

    $tmp_grd.DrawImage($objImage, $rect_dst, ($global:arrSettingsInternal["TILERECT"]), [System.Drawing.GraphicsUnit]::Pixel);
}

function MAP_addBuildingBar($bldIndex)
{
    Write-Host "MAP_addBuildingBar($bldIndex)"

    $offset_x = ($global:arrBuildings[$bldIndex][0] + 2) * $global:arrSettingsInternal["TILESIZE"]
    $offset_y = ($global:arrBuildings[$bldIndex][1] + 2) * $global:arrSettingsInternal["TILESIZE"]

    #calc percent
    $percent = ($global:arrBuildings[$bldIndex][6] / $arrBuilding[$global:arrBuildingIDToKey[$global:arrBuildings[$bldIndex][3]]].hitpoints)

    if(([int]($global:arrBuildings[$bldIndex][4])) -eq 0)
    {
        $percent = $global:arrBuildings[$bldIndex][5]
    }

    if($percent -lt 0.0) { return; }
    elseif($percent -gt 1.0) { $percent = ($percent / 100)}

    $lengthBar = [math]::floor($percent * 10)
    
    # Make sure, that at least one pixel is colored
    if($lengthBar -eq 0)
    {
        $lengthBar = 1;
    }

    $clrBar = getColorNameForPercent $percent

    $tmp_grd = [System.Drawing.Graphics]::FromImage($global:objWorld);
    $tmp_grd.FillRectangle($global:arrColors["CLR_BLACK"].brush, ($offset_x + 2), ($offset_y + 2), 12, 3)
    $tmp_grd.FillRectangle($global:arrColors[$clrBar].brush, ($offset_x + 3), ($offset_y + 3), $lengthBar, 1)

    $objForm.Refresh();
}

function getColorNameForPercent($fPercent)
{
    if($fPercent -gt 1)
    {
        $fPercent = $fPercent / 100
    }

    if($fPercent -gt 1)
    {
        $fPercent = 1
    }

    if($fPercent -gt 0.66)
    {
        return "CLR_GOOD"
    }
    elseif($fPercent -gt 0.33)
    {
        return "CLR_OKAY"
    }
    
    return "CLR_BAD"
}

function MAP_NcreateMapImage()
{
    $global:arrMap["WIDTH"] = $global:arrCreateMapOptions["WIDTH"]
    $global:arrMap["HEIGHT"] = $global:arrCreateMapOptions["HEIGHT"]

    $size_x = $global:arrMap["WIDTH"] + 4;
    $size_y = $global:arrMap["HEIGHT"] + 4;

    $global:objWorld = New-Object System.Drawing.Bitmap(($size_x * $global:arrSettingsInternal["TILESIZE"]), ($size_y * $global:arrSettingsInternal["TILESIZE"]));

    for($i = 0; $i -lt $size_x; $i++)
    {
        # $i - 2 because thats the left border
        if($i -ge 2 -and $i -lt ($size_x - 2))
        {
            $global:arrMap["WORLD_L1"][($i - 2)] = @{}
            $global:arrMap["WORLD_L2"][($i - 2)] = @{}
            $global:arrMap["WORLD_L3"][($i - 2)] = @{}
        }

        for($j = 0; $j -lt $size_y; $j++)
        {
            # $i - 2 because thats the left border
            # same for y
            if($i -ge 2 -and $i -lt ($size_x - 2) -and $j -ge 2 -and $j -lt ($size_y - 2))
            {
                $global:arrMap["WORLD_L1"][($i - 2)][($j - 2)] = $global:arrCreateMapOptions["BASTEXTUREID"]
                $global:arrMap["WORLD_L2"][($i - 2)][($j - 2)] = -1
                $global:arrMap["WORLD_L3"][($i - 2)][($j - 2)] = -1
                MAP_changeTile ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrCreateMapOptions["BASTEXTUREID"]]].bitmap) $i $j
            }
            else
            {
                MAP_changeTile ($global:arrTextures["GROUND_EMPTY_01"].bitmap) $i $j
            }
        }
    }

    for($i = 0; $i -lt $global:arrMap["WIDTH"]; $i++)
    {
        $global:arrMap["WORLD_LBLD"][$i] = @{}
        $global:arrMap["WORLD_LARMY"][$i] = @{}
        $global:arrMap["WORLD_CONTINENT"][$i] = @{}
        $global:arrMap["WORLD_MMAP"][$i] = @{}

        $global:arrMap["WORLD_OVERLAY"][$i] = @{}

        for($j = 0; $j -lt $global:arrMap["HEIGHT"]; $j++)
        {
            $global:arrMap["WORLD_LBLD"][$i][$j] = -1
            $global:arrMap["WORLD_LARMY"][$i][$j] = -1
            $global:arrMap["WORLD_CONTINENT"][$i][$j] = 0
            $global:arrMap["WORLD_MMAP"][$i][$j] = 0

            $global:arrMap["WORLD_OVERLAY"][$i][$j] = $null
        }
    }
}

function isLastPlayer($iPlayerID)
{
    if($iPlayerID -eq $global:arrSettingsInternal["PLAYER_MAX"]) {return $True}

    for($i = ($iPlayerID + 1); $i -le $global:arrSettingsInternal["PLAYER_MAX"]; $i++)
    {
        if((isActivePlayer $i)) {return $False}
    }
    return $True
}

function getNextActivePlayer($iCurrentPlayerID)
{
    for($i = ($iCurrentPlayerID + 1); $i -le $global:arrSettingsInternal["PLAYER_MAX"]; $i++)
    {
        if((isActivePlayer $i)) {return $i}
    }

    return $iCurrentPlayerID
}

function isActivePlayer($iPlayerID)
{
    if(-not $global:arrPlayerInfo[$iPlayerID][5]) {return $False}
    return ($global:arrPlayerInfo[$iPlayerID][5] -gt 0 -and $global:arrPlayerInfo[$iPlayerID][5] -lt 5)
}

function getFirstActivePlayer()
{
    for($i = 1; $i -le $global:arrSettingsInternal["PLAYER_MAX"]; $i++)
    {
        if($global:arrPlayerInfo[$i][5] -ge 1 -and $global:arrPlayerInfo[$i][5] -le 4)
        {
            return $i
        }
    }
    return -1;
}

function getFirstHumanPlayer()
{
    for($i = 1; $i -le $global:arrSettingsInternal["PLAYER_MAX"]; $i++)
    {
        if($global:arrPlayerInfo[$i][5] -eq 3 -or $global:arrPlayerInfo[$i][5] -eq 4)
        {
            return $i
        }
    }
    return -1;
}

function gameGetPlayerCountType($type)
{
    $plrCount = 0;

    for($i = 1; $i -le 4; $i++)
    {
        if($global:arrPlayerInfo[$i][5] -eq $type)
        {
            $plrCount = $plrCount + 1
        }
    }

    return $plrCount;
}

function gameHasPlayerType($type)
{
    return (gameGetPlayerCountType($type) -gt 0)
}

function getPlayerAtPosition($posX, $posY)
{
    if($posX -eq $global:arrMap["PLAYER_01X"] -and $posY -eq $global:arrMap["PLAYER_01Y"]) {return 1}
    if($posX -eq $global:arrMap["PLAYER_02X"] -and $posY -eq $global:arrMap["PLAYER_02Y"]) {return 2}
    if($posX -eq $global:arrMap["PLAYER_03X"] -and $posY -eq $global:arrMap["PLAYER_03Y"]) {return 3}
    if($posX -eq $global:arrMap["PLAYER_04X"] -and $posY -eq $global:arrMap["PLAYER_04Y"]) {return 4}
    return 0
}

function getPlayerCount()
{
    $playerCount = 0
    if($global:arrMap["PLAYER_01X"] -ne -1) {$playerCount += 1}
    if($global:arrMap["PLAYER_02X"] -ne -1) {$playerCount += 1}
    if($global:arrMap["PLAYER_03X"] -ne -1) {$playerCount += 1}
    if($global:arrMap["PLAYER_04X"] -ne -1) {$playerCount += 1}
    return $playerCount
}

function setPlayerPosition($posX, $posY, $playerID)
{
    $global:arrMap[("PLAYER_0" + $playerID + "X")] = $posX
    $global:arrMap[("PLAYER_0" + $playerID + "Y")] = $posY

    drawPlayerIndicatorAtPosition $posX $posY $playerID
}

function drawPlayerIndicatorAtPosition($posX, $posY, $playerID)
{
    Write-Host "drawPlayerIndicatorAtPosition($posX, $posY, $playerID)"

    MAP_changeTile ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrMap["WORLD_L1"][$posX][$posY]]].bitmap) ($posX + 2) ($posY + 2)
    
    if([int]$global:arrMap["WORLD_L2"][([int]$posX)][([int]$posY)] -ne -1)
    {
        MAP_changeTile ($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrMap["WORLD_L2"][$posX][$posY]]].bitmap) ($posX + 2) ($posY + 2)
    }
    # don't need layer 3, if there is something on layer 3 the player couldn't be added in the first place
    #MAP_changeTile ($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrMap["WORLD_L3"][$posX][$posY]]]) $posX $posY

    MAP_changeTile ($global:arrTextures[$arrPlayerIconsIDToKey[$playerID]].bitmap) ($posX + 2) ($posY + 2)
}

function removePlayerFromPosition($playerID)
{
    $strPlayerKey = "PLAYER_0" + $playerID


    $posX = [int]$global:arrMap[($strPlayerKey + "X")]
    $posY = [int]$global:arrMap[($strPlayerKey + "Y")]
    
    if([int]$global:arrMap[($strPlayerKey + "X")] -ne -1)
    {
        removePlayerIndicatorAtPosition $posX $posY $playerID
    }

    # reset position
    $global:arrMap[($strPlayerKey + "X")] = -1
    $global:arrMap[($strPlayerKey + "Y")] = -1
    
}

function removePlayerIndicatorAtPosition($posX, $posY, $playerID)
{
    MAP_changeTile ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrMap["WORLD_L1"][($posX)][($posY)]]].bitmap) ($posX + 2) ($posY + 2)
    
    if($global:arrMap["WORLD_L2"][([int]$posX)][([int]$posY)] -ne -1)
    {
        MAP_changeTile ($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrMap["WORLD_L2"][($posX)][($posY)]]].bitmap) ($posX + 2) ($posY + 2)
    }
}

function loadMapScript($strPath)
{
    Write-Host "loadMapScript($strPath)"

    if($strPath -eq "") { return;}

    if(!(Test-Path $strPath))
    {
        Write-Host "Script '$strPath' does not exist!"
        return;
    }

    $global:Campaigns.script.events = @{}
    $global:Campaigns.script.actions = @{}

    $arrScript_TMP = Get-Content $strPath

    for($i = 0; $i -lt $arrScript_TMP.Length; $i++)
    {
        $strLine = ($arrScript_TMP[$i]).Trim()

        if($strLine -eq "") {continue}

        $strCommand = $strLine.Substring(0,1)
        if($strCommand -eq "@" -or $strCommand -eq "!")
        {
            $arrTmpCommand = $strLine.Substring(1).Split("|")

            if($strCommand -eq "!")
            {
                $global:Campaigns.script.events[$global:Campaigns.script.events.Count] = @{}
                $global:Campaigns.script.events[($global:Campaigns.script.events.Count - 1)][0] = 1

                for($d = 0; $d -lt $arrTmpCommand.Count; $d++)
                {
                    $global:Campaigns.script.events[($global:Campaigns.script.events.Count - 1)][($d + 1)] = $arrTmpCommand[$d].Trim()
                }
            }
            else
            {
                $global:Campaigns.script.actions[$global:Campaigns.script.actions.Count] = @{}
                for($d = 0; $d -lt $arrTmpCommand.Count; $d++)
                {
                    $global:Campaigns.script.actions[($global:Campaigns.script.actions.Count - 1)][$d] = $arrTmpCommand[$d].Trim()
                }
            }
        }
    }

    Write-Host "EventsLoaded: " ($global:Campaigns.script.events.Count)
    Write-Host "ActionsLoaded: " ($global:Campaigns.script.actions.Count)
}

function loadMapHeader($strPath)
{
    if($strPath -eq "") { return;}

    initMapArray

    $arrMap_TMP = Get-Content $strPath
    $global:arrMap["AUTHOR"] =  ($arrMap_TMP[0].split("="))[1]
    $global:arrMap["MAPNAME"] = ($arrMap_TMP[1].split("="))[1]
    $global:arrMap["WIDTH"] =   [int](($arrMap_TMP[2].split("="))[1])
    $global:arrMap["HEIGHT"] =  [int](($arrMap_TMP[3].split("="))[1])

    $global:arrMap["PLAYER_01X"] = [int](($arrMap_TMP[4].split("="))[1])
    $global:arrMap["PLAYER_01Y"] = [int](($arrMap_TMP[5].split("="))[1])
    $global:arrMap["PLAYER_02X"] = [int](($arrMap_TMP[6].split("="))[1])
    $global:arrMap["PLAYER_02Y"] = [int](($arrMap_TMP[7].split("="))[1])
    $global:arrMap["PLAYER_03X"] = [int](($arrMap_TMP[8].split("="))[1])
    $global:arrMap["PLAYER_03Y"] = [int](($arrMap_TMP[9].split("="))[1])
    $global:arrMap["PLAYER_04X"] = [int](($arrMap_TMP[10].split("="))[1])
    $global:arrMap["PLAYER_04Y"] = [int](($arrMap_TMP[11].split("="))[1])

    for($i = 0; $i -lt [int]$global:arrMap["WIDTH"]; $i++)
    {
        $global:arrMap["WORLD_L1"][$i] = @{}
        $global:arrMap["WORLD_L2"][$i] = @{}
        $global:arrMap["WORLD_L3"][$i] = @{}
        $global:arrMap["WORLD_LBLD"][$i] = @{}
        $global:arrMap["WORLD_LARMY"][$i] = @{}
        $global:arrMap["WORLD_CONTINENT"][$i] = @{}
        $global:arrMap["WORLD_MMAP"][$i] = @{}

        $global:arrMap["WORLD_OVERLAY"][$i] = @{}
        $global:arrMap["WORLD_VIEWMAP"][$i] = @{}
    }

    for($i = 0; $i -lt $global:arrMap["WIDTH"]; $i++)
    {
        for($j = 0; $j -lt $global:arrMap["HEIGHT"]; $j++)
        {
            $global:arrMap["WORLD_LBLD"][$i][$j] = -1
            $global:arrMap["WORLD_LARMY"][$i][$j] = -1
            $global:arrMap["WORLD_CONTINENT"][$i][$j] = 0
            $global:arrMap["WORLD_MMAP"][$i][$j] = 0

            $global:arrMap["WORLD_OVERLAY"][$i][$j] = $null
            $global:arrMap["WORLD_VIEWMAP"][$i][$j] = 0
        }
    }

    # wtf is this?
    for($i = 12; $i -lt $arrMap_TMP.Length; $i++)
    {
        $strLocation = ($arrMap_TMP[$i].split("="))[0]
        $strValues = ($arrMap_TMP[$i].split("="))[1]

        $arrValues = $strValues.split(",")

        $realx = [int]($strLocation.split(":")[0])
        $realy = [int]($strLocation.split(":")[1])

        $global:arrMap["WORLD_L1"][[int]$realx][[int]$realy] = [int]$arrValues[0]
        $global:arrMap["WORLD_L2"][[int]$realx][[int]$realy] = [int]$arrValues[1]
        $global:arrMap["WORLD_L3"][[int]$realx][[int]$realy] = [int]$arrValues[2]
        $global:arrMap["WORLD_CONTINENT"][[int]$realx][[int]$realy] = [int]$arrValues[3]
        $global:arrMap["WORLD_MMAP"][[int]$realx][[int]$realy] = [int]$arrValues[4]
    }

    #generateMapPreview
}

function generateMapPreview()
{
    $stepX = 1 / ([int]$global:arrMap["WIDTH"] / 16)
    $stepY = 1 / ([int]$global:arrMap["HEIGHT"] / 16)

    Write-Host "Step x / y: $stepX / $stepY"

    $currentStepX = 1
    $currentStepY = 1

    # create a rect
    $tmp_rec    = New-Object System.Drawing.Rectangle(0, 0, 16, 16)
    # cloning is faster than creating a new bitmap
    $tmp_wnd    = $global:bitmap.Clone($tmp_rec, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    $tmp_grd = [System.Drawing.Graphics]::FromImage($tmp_wnd);
    $tmp_grd.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $tmp_grd.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

    $pixelIDx = 0
    $pixelIDy = 0
    for($i = 0; $i -lt $global:arrMap["WIDTH"]; $i++)
    {
        $pixelIDy = 0
        if($currentStepX -ge 1)
        {
            $currentStepX = $currentStepX -1

            for($j = 0; $j -lt $global:arrMap["HEIGHT"]; $j++)
            {
                if($currentStepY -ge 1)
                {
                    $currentStepY = $currentStepY -1
                    switch ($global:arrMap["WORLD_L1"][$i][$j])
                    {
                        4 
                        {
                            $tmp_wnd.SetPixel($pixelIDx, $pixelIDy, [System.Drawing.Color]::FromArgb(96, 117, 187))
                        }
                        5
                        {
                            $tmp_wnd.SetPixel($pixelIDx, $pixelIDy, [System.Drawing.Color]::FromArgb(0, 0, 0))
                        }
                        default
                        {
                            $tmp_wnd.SetPixel($pixelIDx, $pixelIDy, [System.Drawing.Color]::FromArgb(121, 215, 72))
                        }
                    }
                    $pixelIDy = $pixelIDy + 1
                }
                $currentStepY = $currentStepY + $stepY
            }
            $pixelIDx = $pixelIDx + 1
        }
        $currentStepX = $currentStepX + $stepX
    }

    for($i = 0; $i -lt 4; $i++)
    {
        if([int]$global:arrMap[("PLAYER_0" + ($i + 1) + "X")] -ne -1 -and [int]$global:arrMap[("PLAYER_0" + ($i + 1) + "Y")] -ne -1)
        {
            $playerX = [math]::floor([int]$global:arrMap[("PLAYER_0" + ($i + 1) + "X")] * (16 / [int]$global:arrMap["WIDTH"]))
            $playerY = [math]::floor([int]$global:arrMap[("PLAYER_0" + ($i + 1) + "Y")] * (16 / [int]$global:arrMap["HEIGHT"]))
            $tmp_wnd.SetPixel($playerX, $playerY, [System.Drawing.Color]::FromArgb(255, 0, 0))
        }
    }
   
    $global:arrMap.preview_graphics = $tmp_grd
    $global:arrMap.preview_wnd = $tmp_wnd
}

function loadMap($strPath)
{
    Write-Host "loadMap($strPath)"

    if($strPath -eq "")
    {
        return;
    }

    loadMapHeader $strPath

    $global:arrCreateMapOptions["WIDTH"] = $global:arrMap["WIDTH"]
    $global:arrCreateMapOptions["HEIGHT"] = $global:arrMap["HEIGHT"]

    # create map image
    $size_x = [int]$global:arrMap["WIDTH"] + 4;
    $size_y = [int]$global:arrMap["HEIGHT"] + 4;

    $global:objWorld = New-Object System.Drawing.Bitmap(($size_x * $global:arrSettingsInternal["TILESIZE"]), ($size_y * $global:arrSettingsInternal["TILESIZE"]));

    FOW_generateDefaultFoW

    for ($i = 0; $i -lt $global:arrMap["WIDTH"]; $i++)
    {
        for($j = 0; $j -lt $global:arrMap["HEIGHT"]; $j++)
        {
            $playerID = getPlayerAtPosition $i $j

            if($playerID -ne 0 -and $global:strGameState -ne "EDIT_MAP" -and (isActivePlayer $playerID))
            {
                addBuildingAtPositionForPlayer $i $j 0 ([int]$playerID) 1.0 $True
            }

            MAP_drawTile $i $j
        }
    }

    # $i = y, $j = x, upper side
    for($i = 0; $i -lt 2; $i ++)
    {
        for($j = 0; $j -lt $size_x; $j++)
        {
            MAP_changeTile ($global:arrTextures["GROUND_EMPTY_01"].bitmap) $j $i
        }
    }
    # $i = y, $j = x, lower side
    for($i = ($size_y - 2) ; $i -lt $size_y; $i ++)
    {
        for($j = 0; $j -lt $size_x; $j++)
        {
            MAP_changeTile ($global:arrTextures["GROUND_EMPTY_01"].bitmap) $j $i
        }
    }

    ## $i = x, $j = y, left
    for($i = 0; $i -lt 2; $i ++)
    {
        for($j = 0; $j -lt $size_y; $j++)
        {
            MAP_changeTile ($global:arrTextures["GROUND_EMPTY_01"].bitmap) $i $j
        }
    }

    ## $i = x, $j = y, lower side
    for($i = ($size_x - 2) ; $i -lt $size_x; $i ++)
    {
        for($j = 0; $j -lt $size_y; $j++)
        {
            MAP_changeTile ($global:arrTextures["GROUND_EMPTY_01"].bitmap) $i $j
        }
    }

}

function FOW_draw($objImage, $objFoWImage, $iTileX, $iTileY, $doClear)
{
    Write-Host "FOW_draw($objImage, $objFoWImage, $iTileX, $iTileY, $doClear)"

    $rect_dst = New-Object System.Drawing.Rectangle(($iTileX * $global:arrSettingsInternal["TILESIZE"]), ($iTileY * $global:arrSettingsInternal["TILESIZE"]), $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"])

    $tmp_grd = [System.Drawing.Graphics]::FromImage($objFoWImage);

    if($doClear)
    {
        $tmp_grd.FillRectangle($global:arrColors["CLR_MAGENTA"].brush, ($iTileX * $global:arrSettingsInternal["TILESIZE"]), ($iTileY * $global:arrSettingsInternal["TILESIZE"]), $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"])
        $objFoWImage.MakeTransparent($global:arrColors["CLR_MAGENTA"].color);
    }
    else
    {
        $tmp_grd.DrawImage($objImage, $rect_dst, ($global:arrSettingsInternal["TILERECT"]), [System.Drawing.GraphicsUnit]::Pixel);
    }
}

function FOW_updateForPlayer($iTileX, $iTileY, $iRadius, $iPlayerID, $doClear)
{
    Write-Host "FOW_updateForPlayer($iTileX, $iTileY, $iRadius, $iPlayerID, $doClear)"

    if(!$global:EnableFoW) {return}

    for($y = $iTileY - $iRadius; $y -le $iTileY + $iRadius; $y++)
    {
        for($x = $iTileX - $iRadius; $x -le $iTileX + $iRadius; $x++)
        {
            FOW_updateVisibilityFlag $x $y $iPlayerID
        }
    }
}

# TODO: maybe we should remove visibility which is not possible right now
function FOW_updateVisibilityFlag($posX, $posY, $playerID)
{
    Write-Host "FOW_updateVisibilityFlag($posX, $posY, $playerID)"

    if(!(WORLD_isInWorld $posX $posY)) { return $False; }

    # 2^0 = 1, 2^1 = 2, 2^2 = 4, 2^3 = 8
    $original = $global:arrMap["WORLD_VIEWMAP"][$posX][$posY]

    $global:arrMap["WORLD_VIEWMAP"][$posX][$posY] = $global:arrMap["WORLD_VIEWMAP"][$posX][$posY] -bor ([math]::pow(2, $playerID - 1))

    if($original -ne $global:arrMap["WORLD_VIEWMAP"][$posX][$posY] -and $global:arrPlayerInfo.FoW[$iPlayerID])
    {
        FOW_draw $Null ($global:arrPlayerInfo.FoW[$iPlayerID]) ($posX + 2) ($posY + 2) $True
    }
}

function FOW_isVisibleForPlayer($posX, $posY, $playerID)
{
    if(!(WORLD_isInWorld $posX $posY)) { return $False; }

    # 2^0 = 1, 2^1 = 2, 2^2 = 4, 2^3 = 8
    $flag = ([math]::pow(2, $playerID - 1))

    return (($global:arrMap["WORLD_VIEWMAP"][$posX][$posY] -band $flag) -eq $flag)
}

# Called after map has been loaded already!
function FOW_generateDefaultFoW()
{
    Write-Host "FOW_generateDefaultFoW"

    if(!$global:EnableFoW) {return}

    $size_x = [int]$global:arrMap["WIDTH"] + 4;
    $size_y = [int]$global:arrMap["HEIGHT"] + 4;

    $global:objWorldFoW = New-Object System.Drawing.Bitmap(($size_x * $global:arrSettingsInternal["TILESIZE"]), ($size_y * $global:arrSettingsInternal["TILESIZE"]));

    for ($i = 0; $i -lt $global:arrMap["WIDTH"]; $i++)
    {
        for($j = 0; $j -lt $global:arrMap["HEIGHT"]; $j++)
        {
            # Layer 1
            $texID = $global:arrMap["WORLD_L1"][$i][$j]
            FOW_draw ($global:arrIcons[("FOW_" + $arrBaseTextureIDToKey[$texID])].bitmap) $global:objWorldFoW ($i + 2) ($j + 2)

            # Layer 2
            $texID = $global:arrMap["WORLD_L2"][$i][$j]
            if($texID -ne -1)
            {
                Write-Host "TexID 2 exists - checking " ("FOW_" + $arrOverlayTextureIDToKey[$texID])
                # does  an overlay texture exist?
                if($global:arrIcons[("FOW_" + $arrOverlayTextureIDToKey[$texID])])
                {
                    FOW_draw ($global:arrIcons[("FOW_" + $arrOverlayTextureIDToKey[$texID])].bitmap) $global:objWorldFoW ($i + 2) ($j + 2)
                }
            }

            # Layer 3
            $texID = $global:arrMap["WORLD_L3"][$i][$j]
            if($texID -ne -1)
            {
                Write-Host "TexID 3 exists - checking " ("FOW_" + $arrObjectTextureIDToKey[$texID])

                if($global:arrIcons[("FOW_" + $arrObjectTextureIDToKey[$texID])])
                {
                    FOW_draw ($global:arrIcons[("FOW_" + $arrObjectTextureIDToKey[$texID])].bitmap) $global:objWorldFoW ($i + 2) ($j + 2)
                }
            }

            $playerID = getPlayerAtPosition $i $j
            if($playerID -ne 0)
            {
                FOW_draw ($global:arrIcons["FOW_HUM_HQ"].bitmap) $global:objWorldFoW ($i + 2) ($j + 2)
            }
        }
    }

    # $i = y, $j = x, upper side
    for($i = 0; $i -lt 2; $i ++)
    {
        for($j = 0; $j -lt $size_x; $j++)
        {
            FOW_draw ($global:arrIcons["FOW_GROUND_EMPTY_01"].bitmap) $global:objWorldFoW $j $i

            if($i -eq 1)
            {
                if($j -eq 1)
                {
                    FOW_draw ($global:arrIcons["FOW_OUTER_EDGE_01"].bitmap) $global:objWorldFoW $j $i
                }
                elseif($j -eq ($size_x - 2))
                {
                    FOW_draw ($global:arrIcons["FOW_OUTER_EDGE_03"].bitmap) $global:objWorldFoW $j $i
                }
                elseif($j -ne 0 -and $j -ne ($size_x - 1))
                {
                    FOW_draw ($global:arrIcons["FOW_OUTER_EDGE_02"].bitmap) $global:objWorldFoW $j $i
                }
            }
        }
    }

    ## $i = y, $j = x, lower side
    for($i = ($size_y - 2) ; $i -lt $size_y; $i ++)
    {
        for($j = 0; $j -lt $size_x; $j++)
        {
            FOW_draw ($global:arrIcons["FOW_GROUND_EMPTY_01"].bitmap) $global:objWorldFoW $j $i

            if($i -eq ($size_y - 2))
            {
                if($j -eq 1)
                {
                    FOW_draw ($global:arrIcons["FOW_OUTER_EDGE_07"].bitmap) $global:objWorldFoW $j $i
                }
                elseif($j -eq ($size_x - 2))
                {
                    FOW_draw ($global:arrIcons["FOW_OUTER_EDGE_05"].bitmap) $global:objWorldFoW $j $i
                }
                elseif($j -ne 0 -and $j -ne ($size_x - 1))
                {
                    FOW_draw ($global:arrIcons["FOW_OUTER_EDGE_06"].bitmap) $global:objWorldFoW $j $i
                }
            }
        }
    }

    #### $i = x, $j = y, left
    for($i = 0; $i -lt 2; $i ++)
    {
        for($j = 2; $j -lt ($size_y - 2); $j++)
        {
            FOW_draw ($global:arrIcons["FOW_GROUND_EMPTY_01"].bitmap) $global:objWorldFoW $i $j

            if($i -eq 1)
            {
                FOW_draw ($global:arrIcons["FOW_OUTER_EDGE_08"].bitmap) $global:objWorldFoW $i $j
            }
        }

        
    }
    #
    #### $i = x, $j = y, lower side
    for($i = ($size_x - 2); $i -lt $size_x; $i++)
    {
        for($j = 2; $j -lt $size_y - 2; $j++)
        {
            FOW_draw ($global:arrIcons["FOW_GROUND_EMPTY_01"].bitmap) $global:objWorldFoW $i $j

            if($i -eq ($size_x - 2))
            {
                FOW_draw ($global:arrIcons["FOW_OUTER_EDGE_04"].bitmap) $global:objWorldFoW $i $j
            }
        }
    }

    $global:arrPlayerInfo.FoW = @{}

    # copy image for all players
    for($i = 1; $i -le 4; $i++)
    {
        if($global:arrMap[("PLAYER_0" + $i + "X")] -ne -1 -and $global:arrMap[("PLAYER_0" + $i + "Y")] -ne -1)
        {
            $global:arrPlayerInfo.FoW[$i] = New-Object System.Drawing.Bitmap($global:objWorldFoW)
        }
    }
}

function saveMap($strName)
{

    # get name from user input
    $global:arrMap["MAPNAME"]   = $global:arrWindows["WND_ESC_EDITOR_N"].ninp["INP_EDITOR_MAPNAME"].text
    $global:arrMap["AUTHOR"]    = $global:arrWindows["WND_ESC_EDITOR_N"].ninp["INP_EDITOR_AUTHOR"].text

    $runs5 = [math]::floor($global:arrMap["WIDTH"] * $global:arrMap["HEIGHT"] * 0.05);
    $step = 0;
    $runs = $runs5;

    # Test Save Map
    if($strName -eq "")
    {
        $strFileName = ".\MAP\" + $global:arrMap["MAPNAME"] + ".smf"
    }
    else
    {
        $strFileName = ".\MAP\$strName" + ".smf"
    }
    
    If (Test-Path $strFileName){
        Remove-Item $strFileName
    }

    "AUTHOR=" + $global:arrMap["AUTHOR"] | Out-File -FilePath $strFileName -Append
    "MAPNAME=" + $global:arrMap["MAPNAME"] | Out-File -FilePath $strFileName -Append
    "WIDTH=" + $global:arrMap["WIDTH"] | Out-File -FilePath $strFileName -Append
    "HEIGHT=" + $global:arrMap["HEIGHT"] | Out-File -FilePath $strFileName -Append


    for($i = 1; $i -le $global:arrSettingsInternal["PLAYER_MAX"]; $i++)
    {
        ("PLAYER_0" + $i + "X=") + $global:arrMap[("PLAYER_0" + $i + "X")] | Out-File -FilePath $strFileName -Append
        ("PLAYER_0" + $i + "Y=") + $global:arrMap[("PLAYER_0" + $i + "Y")] | Out-File -FilePath $strFileName -Append
    }

    $keys_a = $global:arrMap["WORLD_L1"].Keys
    
    foreach($key in $keys_a)
    {
        $keys_b = $global:arrMap["WORLD_L1"][$key].Keys

        #foreach($key_out in $keys_a)
        foreach($key_out in $keys_b)
        {
            $strOutput = "";
            $strOutput = "" + $key + ":" + $key_out + "=" + $global:arrMap["WORLD_L1"][$key][$key_out] + "," + $global:arrMap["WORLD_L2"][$key][$key_out]+ "," + $global:arrMap["WORLD_L3"][$key][$key_out] + "," + $global:arrMap["WORLD_CONTINENT"][$key][$key_out] + "," + $global:arrMap["WORLD_MMAP"][$key][$key_out]
            $strOutput | Out-File -FilePath $strFileName -Append

            $step = $step + 1
            if($step -ge $runs)
            {
                $percent = [math]::floor($step / ($global:arrMap["WIDTH"] * $global:arrMap["HEIGHT"]) * 100)
                $runs += $runs5;
                [System.Windows.Forms.Application]::DoEvents() 
                $objForm.Refresh();

                if($global:strGameState -eq "EDIT_MAP_ESCAPE")
                {
                    BAR_SetTextValue "WND_EDITOR_WAIT_N" "BAR_SAVE_PROGRESS" ("Saving (" + $percent +"%)") ($percent / 100)
                }
            }
        }
    }
}

function handleInputInactive($strWindow, $strInput)
{
    Write-Host "handleInputInactive($strWindow, $strInput)"

    $global:arrWindows.InputCurrent = ""

    # redraw with border
    buildInput $strWindow $strInput $False
}

function INP_handleKeyPress($key)
{
    $strWindow = $global:arrWindows.lastInputWindow;
    $strNameInput = $global:arrWindows.lastInput;

    switch($key)
    {
        "Escape"
        {
            INP_handleUnClicked
        }
        "Return"
        {
            INP_handleUnClicked
        }
        "Back"
        {
            if($global:arrWindows[$strWindow].ninp[$strNameInput].text.Length -gt 0)
            {
                INP_setText $strWindow $strNameInput ($global:arrWindows[$strWindow].ninp[$strNameInput].text).Substring(0, ($global:arrWindows[$strWindow].ninp[$strNameInput].text.Length - 1))
            }
        }
        default
        {
            if($key.Length -gt 1)
            {
                Write-Host "Invalid Character (Input): '$key'"
                return;
            }

            if($global:arrWindows[$strWindow].ninp[$strNameInput].text.Length -ge $global:arrWindows[$strWindow].ninp[$strNameInput].length)
            {
                Write-Host "Maximum Input length reached!"
            }
            else
            {
                INP_setText $strWindow $strNameInput ($global:arrWindows[$strWindow].ninp[$strNameInput].text + $key)
            }
        }
    }
}

function INP_handleUnClicked()
{
    # activate input
    INP_setActive $global:arrWindows.lastInputWindow $global:arrWindows.lastInput $False

    # handle functions
    if($global:arrWindows[$global:arrWindows.lastInputWindow].ninp[$global:arrWindows.lastInput].function -ne "")
    {
        INP_handleLeave $global:arrWindows.lastInputWindow $global:arrWindows.lastInput ($global:arrWindows[$global:arrWindows.lastInputWindow].ninp[$global:arrWindows.lastInput].function)
    }

    $global:arrWindows.lastInputWindow = ""
    $global:arrWindows.lastInput = ""
}

function INP_handleClicked($strWindow, $strInput)
{
    $global:arrWindows.lastInput = $strInput
    $global:arrWindows.lastInputWindow = $strWindow

    # activate input
    INP_setActive $strWindow $strInput $True
}

function scrollGameWorld($direction, $by)
{
    switch($direction)
    {
        "Right"
        {
            if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -lt ($global:arrCreateMapOptions["WIDTH"] - 16) -and ($global:strGameState -eq "SINGLEPLAYER_INGAME" -or $global:strGameState -eq "EDIT_MAP"))
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_X"] += $by;
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -gt ($global:arrCreateMapOptions["WIDTH"] - 16))
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_X"] = ($global:arrCreateMapOptions["WIDTH"] - 16)
            }
        }
        "Left"
        {
            if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -gt 0 -and ($global:strGameState -eq "SINGLEPLAYER_INGAME" -or $global:strGameState -eq "EDIT_MAP"))
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_X"] -= $by;
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -lt 0)
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_X"] = 0
            }
        }
        "Down"
        {
            if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -lt ($global:arrCreateMapOptions["HEIGHT"] - 13) -and ($global:strGameState -eq "SINGLEPLAYER_INGAME" -or $global:strGameState -eq "EDIT_MAP"))
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] += $by;
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -gt ($global:arrCreateMapOptions["HEIGHT"] - 13))
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] = ($global:arrCreateMapOptions["HEIGHT"] - 13)
            }
        }
        "Up"
        {
            if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -gt 0 -and ($global:strGameState -eq "SINGLEPLAYER_INGAME" -or $global:strGameState -eq "EDIT_MAP"))
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -= $by;
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -lt 0)
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] = 0
            }
        }
    }

    $objForm.Refresh();
}

function handleKeyFunctions($strFunction)
{
    Write-Host "handleKeyFunctions($strFunction)"
    # can alway call global functions
    keyFunctionGlobal $strFunction

    if($global:strGameState -eq "SINGLEPLAYER_INGAME")
    {
        keyFunctionGame $strFunction
    }

    if($global:strGameState -eq "EDIT_MAP")
    {
        keyFunctionEditor $strFunction
    }

    if($global:strGameState -eq "SINGLEPLAYER_INGAME" -or $global:strGameState -eq "EDIT_MAP")
    {
        keyFunctionGameEditor $strFunction
    }
}

function keyFunctionGlobal($strFunction)
{
    switch($strFunction)
    {   
        "GLOBAL_SCALE_UP"
        {
            scaleGame $True
        }
        "GLOBAL_SCALE_DOWN"
        {
            scaleGame $False
        }
    }
}

function keyFunctionGame($strFunction)
{
    switch($strFunction)
    {   
        "GAME_CENTER_HQ"
        {
            centerOnPlayer ($global:arrPlayerInfo.currentPlayer)
        }
    }
}

function keyFunctionEditor($strFunction)
{
    switch($strFunction)
    {   
        "EDITOR_TOGGLE_PREVIEW"
        {
            $global:arrCreateMapOptions["SHOW_PREVIEW"] = !$global:arrCreateMapOptions["SHOW_PREVIEW"]
        }
    }
}

function keyFunctionGameEditor($strFunction)
{
    switch($strFunction)
    {   
        "GAMEEDITOR_SCROLL_RIGHT"
        {
            scrollGameWorld "Right" ($global:arrSettings["SCROLLSPEED"])
        }
        "GAMEEDITOR_SCROLL_LEFT"
        {
            scrollGameWorld "Left" ($global:arrSettings["SCROLLSPEED"])
        }
        "GAMEEDITOR_SCROLL_DOWN"
        {
            scrollGameWorld "Down" ($global:arrSettings["SCROLLSPEED"])
        }
        "GAMEEDITOR_SCROLL_UP"
        {
            scrollGameWorld "Up" ($global:arrSettings["SCROLLSPEED"])
        }
    }
}

function onKeyPress($sender, $EventArgs)
{
    $keyCode = ""

    if(([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Control) -eq [System.Windows.Forms.Keys]::Control)
    {
        $keyCode = $keyCode + "CTRL"
    }

    if(([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Alt) -eq [System.Windows.Forms.Keys]::Alt)
    {
        $keyCode = $keyCode + "ALT"
    }

    if(([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Shift) -eq [System.Windows.Forms.Keys]::Shift)
    {
        $keyCode = $keyCode + "SHIFT"
    }

    $keyCode = $keyCode + [string]($EventArgs.KeyCode)

    $keyCode = (translateKey $keyCode)

    if($global:arrWindows.lastInput -ne "")
    {
        INP_handleKeyPress $keyCode
        return;
    }

    $keyFunction = (getKeyFunction $keyCode)

    if($keyFunction -ne '')
    {
        handleKeyFunctions $keyFunction
        return
    }

    switch($keyCode)
    {
        "Escape"
        {
            if(!(MP_isMultiplayer))
            {
                if($global:strGameState -eq "EDIT_MAP")
                {
                    showWindow "WND_ESC_EDITOR_N"
                    $global:strGameState = "EDIT_MAP_ESCAPE"
                }
                elseif($global:strGameState -eq "EDIT_MAP_ESCAPE")
                {
                    $global:strGameState = "EDIT_MAP"
                    showWindow "WND_INTERFACE_EDITOR_LAYER_01"
                }

                if($global:arrWindows.WindowCurrent -ne "WND_LOSE_GAME" -and $global:arrWindows.WindowCurrent -ne "WND_WIN_GAME")
                {
                    if($global:strGameState -eq "SINGLEPLAYER_INGAME")
                    {
                        showWindow "WND_ESC_SINGLEPLAYER_N"
                        GAME_setActiveButton "" "" -1 $True
                        GAME_SP_setRecruit $False
                        $global:strGameState = "SINGLEPLAYER_ESCAPE"
                    }
                    elseif($global:strGameState -eq "SINGLEPLAYER_ESCAPE")
                    {
                        $global:strGameState = "SINGLEPLAYER_INGAME"
                        showWindow "WND_SP_MENU_BUILDING_N"
                    }
                }
            }
            else
            {
                if($global:arrWindows.WindowCurrent -ne "WND_ESC_MP_CLIENT" -and $global:arrMultiplayer.isClient)
                {
                    showWindow "WND_ESC_MP_CLIENT"
                    Write-Host "Show Client Escape"
                }
                elseif($global:arrWindows.WindowCurrent -ne "WND_ESC_MP_SERVER" -and $global:arrMultiplayer.isServer)
                {
                    showWindow "WND_ESC_MP_SERVER"
                    Write-Host "Show Server Escape"
                }
            }
        }
        default     {Write-Host "Unhandled keypress, code '$keyCode'"}
    }

    if(!$Debug){return;}

    switch($keyCode)
    {
        "Z"
        {
            #generatePath 10 10 5 5 1 -1 $True
            generatePath 13 13 0 0 1 -1 $True
        }
        "U"
        {
            markCheckedPath
        }
        "I"
        {
            findPath
        }
        "O"
        {
            markPath
        }
        "T"
        {
            #start 'http://www.gurucore.com'
            for($i = 1; $i -lt 5; $i++)
            {
                Write-Host "Name      : " $global:arrPlayerInfo[$i][0]
                Write-Host "Goldincome: " $global:arrPlayerInfo[$i][1]
                Write-Host "Woodincome: " $global:arrPlayerInfo[$i][2]
                Write-Host "Foodincome: " $global:arrPlayerInfo[$i][3]
                Write-Host "Producion : " $global:arrPlayerInfo[$i][4]
                Write-Host "Gold      : " $global:arrPlayerInfo[$i][6]
                Write-Host "Wood      : " $global:arrPlayerInfo[$i][7]
                Write-Host "Food      : " $global:arrPlayerInfo[$i][8]
            }
        }
        "K"
        {
            # setup server 2
            #SERVER2_setupServer
        }
        "L"
        {
            # setup client 2
            #CLIENT2_setupClient
        }
        "F"
        {
            $global:EnableFoW = !$global:EnableFoW
        }
    }
}

function centerOnPlayer($plrID)
{
    $posX = $global:arrMap[("PLAYER_0" + $plrID + "X")]
    $posY = $global:arrMap[("PLAYER_0" + $plrID + "Y")]

    centerOnPosition $posX $posY
}

function onMouseUp($strNameSender, $EventArgs)
{
    #Write-Host "onMouseUp($strNameSender, $EventArgs)"

    if($global:arrWindows.lastInput -ne "")
    {
        INP_handleUnClicked
        return;
    }

    if($EventArgs.Button -eq "Left")
    {
        $relX = ($EventArgs.X / $global:arrSettings["SIZE"])
        $relY = ($EventArgs.Y / $global:arrSettings["SIZE"])

        handleNClickWindow $relX $relY $global:arrWindows.lastClickButton

        BTN_resetPreClickedButton
    }

    if($EventArgs.Button -eq "Right")
    {
        $global:arrPlayerInfo.scrollX = -1
        $global:arrPlayerInfo.scrollY = -1
    }
}

function BTN_resetPreClickedButton()
{
    if($global:arrWindows.lastClickButton -ne "")
    {
        BTN_setPressedState ($global:arrWindows.lastClickWindow) ($global:arrWindows.lastClickButton) $False

        $global:arrWindows.lastClickButton = ""
        $global:arrWindows.lastClickWindow = ""
    }
}

function BTN_setPreClickedButton($clickX, $clickY)
{
    Write-Host "BTN_setPreClickedButton($clickX, $clickY)"

    $fac_x = ($objForm.Size.Width - $wndOffsetX)  / ($DrawingSizeX)
    $fac_y = ($objForm.Size.Height - $wndOffsetY) / ($DrawingSizeY)

    $relX = ($clickX / $fac_x)
    $relY = ($clickY / $fac_y)

    $strCurrentWindow = $global:arrWindows.WindowCurrent

    if($global:arrWindows.lastInput -ne "")
    {
        Write-Host "BTN_setPreClickedButton: Active Input"
        return;
    }

    if($global:arrWindows.WindowOpen -and !$global:arrWindows[$strCurrentWindow].nbtn)
    {
        Write-Host "BTN_setPreClickedButton: No buttons"
        return;
    }

    if($relX -lt $global:arrWindows[$strCurrentWindow].loc_x -or $relX -gt ($global:arrWindows[$strCurrentWindow].loc_x + $global:arrWindows[$strCurrentWindow].wnd.Width))
    {
        Write-Host "BTN_setPreClickedButton: Click outside window (X)"
        return;
    }
    
    if($relY -lt $global:arrWindows[$strCurrentWindow].loc_y -or $relY -gt ($global:arrWindows[$strCurrentWindow].loc_y + $global:arrWindows[$strCurrentWindow].wnd.Height))
    {
        Write-Host "BTN_setPreClickedButton: Click outside window (Y)"
        return;
    }

    $relX = $relX -  $global:arrWindows[$strCurrentWindow].loc_x
    $relY = $relY -  $global:arrWindows[$strCurrentWindow].loc_y

    $keys    = $global:arrWindows[$strCurrentWindow].nbtn.Keys
    
    foreach($key in $keys)
    {
        if($global:arrWindows[$strCurrentWindow].nbtn[$key].disabled) {continue;}

        if($global:arrWindows[$strCurrentWindow].nbtn[$key].hidden) {continue;}

        #if($global:arrWindows[$strCurrentWindow].nbtn[$key].active) {continue;}

        if(($global:arrWindows[$strCurrentWindow].nbtn[$key].loc_x -lt $relX) -and ($global:arrWindows[$strCurrentWindow].nbtn[$key].loc_x + $global:arrWindows[$strCurrentWindow].nbtn[$key].size_x -gt $relX))
        {
            if(($global:arrWindows[$strCurrentWindow].nbtn[$key].loc_y -lt $relY) -and ($global:arrWindows[$strCurrentWindow].nbtn[$key].loc_y + $global:arrWindows[$strCurrentWindow].nbtn[$key].size_y -gt $relY))
            {
                $global:arrWindows.lastClickButton = $key
                $global:arrWindows.lastClickWindow = $strCurrentWindow

                BTN_setPressedState $strCurrentWindow $key $True
                return;
            }
        }
    }

    Write-Host "BTN_setPreClickedButton($relX, $relY) REL"
}

function onMouseDown($strNameSender, $EventArgs)
{
    if($EventArgs.Button -eq "Left")
    {
        BTN_setPreClickedButton $EventArgs.X $EventArgs.Y
    }
}

function onMouseClick($strNameSender, $EventArgs)
{
    $relX = ($EventArgs.X / $global:arrSettings["SIZE"])
    $relY = ($EventArgs.Y / $global:arrSettings["SIZE"])

    switch($strNameSender)
    {
        "Picturebox"
        {
            handleClickPicturebox $relX $relY ($EventArgs.Button)
        }
        default
        {
            Write-Host "unhandled click at $relX $relY"
        }
    }
}

function handleClickPicturebox($posX, $posY, $Button)
{
    if($Button -eq "Right")
    {
        return;
    }

    if($global:strGameState -eq "WAIT_INIT_CLICK")
    {
        showWindow "WND_ESC_MAIN_N"
        $global:strGameState = "MAIN_MENU"
        if([int]$global:arrSettingsInternal["SONGS"] -gt 0){ playSongs }
    }
    elseif($global:arrWindows.WindowOpen)
    {
        handleClickWindow $posX $posY
    }
    else
    {
        Write-Host "unhandled click at $relX $relY (in handleClickPicturebox)"
    }
}

function openTileInfoIfNeeded($posX, $posY)
{
    Write-Host "openTileInfoIfNeeded($posX, $posY)"

    Write-Host "GameState: " ($global:strGameState)
    Write-Host "CurrentWindow: " ($global:arrWindows.WindowCurrent)

    if($global:arrWindows.WindowCurrent -eq "WND_CLIENT_WAITING" -or $global:arrWindows.WindowCurrent -eq "WND_SERVER_WAITING" -or
        $global:arrWindows.WindowCurrent -eq "WND_ESC_MP_CLIENT" -or $global:arrWindows.WindowCurrent -eq "WND_ESC_MP_SERVER"
    )
    {
        return;
    }

    $i = $posX
    $j = $posY

    Write-Host "Pos: $i $j"
    $selfU = (canTerrainMoveDirection $i $j 0)
    $targetU = (canTerrainMoveDirection $i ($j - 1) 2)
    $selfR = (canTerrainMoveDirection $i $j 1)
    $targetR = (canTerrainMoveDirection ($i + 1)  $j 3)
    $selfD = (canTerrainMoveDirection $i $j 2)
    $targetD = (canTerrainMoveDirection $i  ($j + 1)  0)
    $selfL = (canTerrainMoveDirection $i $j 3)
    $targetL = (canTerrainMoveDirection ($i - 1)  $j 1)
    
    Write-Host "U: $selfU $targetU"
    Write-Host "R: $selfR $targetR"
    Write-Host "D: $selfD $targetD"
    Write-Host "L: $selfL $targetL"

    Write-Host "ResultFlag: " ($global:arrMap["WORLD_MMAP"][$i][$j])

    Write-Host "Conti: " ($global:arrMap["WORLD_CONTINENT"][$i][$j])

    Write-Host "ViewMap: " ($global:arrMap["WORLD_VIEWMAP"][$i][$j])

    AI_displayBlockValues $posX $posY 1

    if($global:arrPath.path)
    {
        if($global:arrPath.path[$i])
        {
            if($global:arrPath.path[$i][$j])
            {
                Write-Host "H: " ($global:arrPath.path[$i][$j].H)
                Write-Host "G: " ($global:arrPath.path[$i][$j].G)
                Write-Host "F: " ($global:arrPath.path[$i][$j].F)
                Write-Host "D: " ($global:arrPath.path[$i][$j].D)
                #Write-Host "DistX: " ($i - $global:arrPath.sourceX)
                #Write-Host "DistY: " ($j - $global:arrPath.sourceY)
            }
        }
    }

    # if not visible for player, don't show anything
    If($global:EnableFoW -and !(FOW_isVisibleForPlayer $posX $posY (MP_getLocalPlayerID))) { Write-Host "Not visible for player"; return; }

    $bldID = ([int]($global:arrMap["WORLD_LBLD"][$posX][$posY]))

    $global:arrPlayerInfo.currentSelection = $bldID

    $armyID = ([int]($global:arrMap["WORLD_LARMY"][$posX][$posY]))

    resetPlayerTileSelection

    if($bldID -eq -1 -and $armyID -eq -1)
    {
        $pictureBox.Refresh();
        return
    }

    $global:arrPlayerInfo.selectedTile.x = $posX
    $global:arrPlayerInfo.selectedTile.y = $posY
    $global:arrPlayerInfo.selectedTile.buildingID = $bldID
    $global:arrPlayerInfo.selectedTile.armyID = $armyID

    # check if add army buttons
    if($global:arrPlayerInfo.selectedTile.armyID -ne -1){
        Write-Host "ARMYID: $armyID"
        $global:arrPlayerInfo.selectedTile.mode = "ARMY"
        showWindow "WND_TILEINFO_ARMY_N"
    } elseif($global:arrPlayerInfo.selectedTile.$bldID -ne -1) {
        Write-Host "BLDID: $bldID"
        $global:arrPlayerInfo.selectedTile.mode = "BUILDING"
        showWindow "WND_TILEINFO_BUILDING_N"
    }

    $global:strGameState = "SINGLEPLAYER_TILEINFO"
}

function WORLD_isInWorld($posX, $posY)
{
    if($posX -lt 0 -or $posX -ge $global:arrMap["WIDTH"])
    {
        Write-Host "ERROR: WORLD_isInWorld($posX, $posY) -> out of bounds (X)"
        return $False;
    }

    if($posY -lt 0 -or $posY -ge $global:arrMap["HEIGHT"])
    {
        Write-Host "ERROR: WORLD_isInWorld($posX, $posY) -> out of bounds (Y)"
        return $False;
    }

    return $True;
}

function ARMY_SetOverlayForAction($action, $posX, $posY)
{
    Write-Host "ARMY_SetOverlayForAction($action, $posX, $posY)"

    if($action -eq 1)
    {
        $global:arrMap["WORLD_OVERLAY"][$posX][$posY] = $global:arrInterface["SELECTION_TILE_MOVE"].bitmap
    }
    elseif($action -eq 2 -or $action -eq 3)
    {
        $global:arrMap["WORLD_OVERLAY"][$posX][$posY] = $global:arrInterface["SELECTION_TILE_ATTACK"].bitmap
    }
    elseif($action -eq 4)
    {
        $global:arrMap["WORLD_OVERLAY"][$posX][$posY] = $global:arrInterface["SELECTION_TILE_MERGE"].bitmap
    }
    elseif(WORLD_isInWorld $posX $posY)
    {
        $global:arrMap["WORLD_OVERLAY"][$posX][$posY] = $global:arrInterface["SELECTION_TILE_INVALID"].bitmap
    }

    MAP_drawTile $posX $posY
}

function ARMY_BuyArmyLevel($posX, $posY)
{
    Write-Host "ARMY_BuyArmyLevel($posX, $posY)"

    # this should possibly check for some more stuff like isInWorld and HasWares

    if($global:arrMultiplayer.isClient)
    {
        CLIENT_sendData ("0x310/" + $posX + "/" + $posY)
        return;
    }

    $armyID = $global:arrMap["WORLD_LARMY"][$posX][$posY];

    # no army?
    if($armyID -eq -1) {return 1}

    $srcOwner = $global:arrArmies[$armyID][2]

    # update wares
    updatePlayerStat $srcOwner 6 (-1 * $global:arrSettingsInternal["ARMY_UNIT_COSTS"][0])
    updatePlayerStat $srcOwner 8 (-1 * $global:arrSettingsInternal["ARMY_UNIT_COSTS"][1])
    updatePlayerStat $srcOwner 9 (-1 * $global:arrSettingsInternal["ARMY_UNIT_COSTS"][2])

    # increase level by 1
    $global:arrArmies[$armyID][7] = $global:arrArmies[$armyID][7] + 1

    # increase current HP
    $global:arrArmies[$armyID][4] = $global:arrArmies[$armyID][4] + $global:arrSettingsInternal["ARMY_DEFAULT_HP"]

    if($global:arrMultiplayer.isServer)
    {
        #update army
        SERVER_sendDataAll ("0x307/" + $armyID + "/" + ($global:arrArmies[$armyID][4]) + "/" + ($global:arrArmies[$armyID][7]) + "/" + ($global:arrArmies[$armyID][5]))
        # update player wares
        SERVER_sendDataAll ("0x200/" + $srcOwner + "/" + $global:arrPlayerInfo[$srcOwner][6] + "/" + $global:arrPlayerInfo[$srcOwner][7] + "/" + $global:arrPlayerInfo[$srcOwner][8] + "/" + $global:arrPlayerInfo[$srcOwner][9])
    }
}

function ARMY_MergeArmies($sourceArmy, $targetArmy)
{
    Write-Host "ARMY_MergeArmies($sourceArmy, $targetArmy)"

    if($global:arrMultiplayer.isClient)
    {
        CLIENT_sendData ("0x308/" + $sourceArmy + "/" + $targetArmy)
        return;
    }

    # 1) get source army HP and level
    $srcHealth = $global:arrArmies[$sourceArmy][4]
    $srcLevel = $global:arrArmies[$sourceArmy][7]
    # army must have had at least 1 MP, so -1 is save
    $srcMP = $global:arrArmies[$sourceArmy][5]

    # 2) add level to target army
    $global:arrArmies[$targetArmy][7] = $global:arrArmies[$targetArmy][7] + $srcLevel

    # 3) add HP to target army
    $global:arrArmies[$targetArmy][4] = $global:arrArmies[$targetArmy][4] + $srcHealth

    $global:arrArmies[$targetArmy][5] = $srcMP - 1

    # 4) destroy source army
    ARMY_DestroyArmy $sourceArmy

    if($global:arrMultiplayer.isServer)
    {
        SERVER_sendDataAll ("0x307/" + $targetArmy + "/" + ($global:arrArmies[$targetArmy][4]) + "/" + ($global:arrArmies[$targetArmy][7]) + "/" + ($global:arrArmies[$targetArmy][5]))
    }
}

function ARMY_GetPossibleAction($posX, $posY, $dir, $posTargetX, $posTargetY)
{
    Write-Host "ARMY_GetPossibleAction($posX, $posY, $dir, $posTargetX, $posTargetY)"

    if(!(WORLD_isInWorld $posTargetX $posTargetY)) {return;}

    # scenarios:
    # 0) no movepoints
    # 1) cant move to direction = 0
    # 2) can move to direction, no building, no army = 1
    # 3) can move to direction, hostile army = 2
    # 4) can move to direction, friendly army = 0
    # 5) can move to direction, hostile building = 2
    # 6) can move to direction, friendly building = 1 # if not hostile, simply dont check it
    # 7) can move to direction, hostile army, hostile building = 2
    # new 8) can move to direction, friendly army = 4

    # 0 = none
    # 1 = move
    # 2 = attack army
    # 3 = attack building

    $sourceArmy = ([int]($global:arrMap["WORLD_LARMY"][$posX][$posY]))

    # 0)
    $canMove = ($global:arrArmies[$sourceArmy][5] -ge 1)

    if(!$canMove) 
    {
        #Write-Host "ARMY_GetPossibleAction: Cant move"
        return 0;
    }

    # 1)
    $canMove = canTerrainMoveDirection $posX $posY $dir

    if(!$canMove) 
    {
        #Write-Host "ARMY_GetPossibleAction: Cant move direction $dir"
        return 0;
    }

    # 2^0 = 1, 2^1 = 2, 2^2 = 4, 2^3 = 8
    $canMove = hasMoveFlag $posX $posY ([math]::pow(2, $dir))
    if(!$canMove) 
    {
        #Write-Host "ARMY_GetPossibleAction: Cant move (moveflag)"
        return 0;
    }

    # moveflags are not honored here!

    # canTerrainMoveDirection checks for out of world
    $targetArmy = ([int]($global:arrMap["WORLD_LARMY"][$posTargetX][$posTargetY]))
    $targetBuilding = ([int]($global:arrMap["WORLD_LBLD"][$posTargetX][$posTargetY]))

    # 2) no army and no building at target
    if($targetArmy -eq -1 -and $targetBuilding -eq -1) 
    {
        #Write-Host "ARMY_GetPossibleAction: Can Move"
        return 1;
    }

    $targetArmyOwner = -1
    if($targetArmy -ne -1) {$targetArmyOwner = $global:arrArmies[$targetArmy][2]}
    $sourceArmyOwner = $global:arrArmies[$sourceArmy][2]

    # 3) target army is not owned by the same player
    if($targetArmyOwner -ne -1 -and $targetArmyOwner -ne $sourceArmyOwner) 
    {
        #Write-Host "ARMY_GetPossibleAction: Can attack target army"
        return 2;
    }

    # 4) target army is owned by the same player
    if($targetArmyOwner -ne -1 -and $targetArmyOwner -eq $sourceArmyOwner) 
    {
        #Write-Host "ARMY_GetPossibleAction: Position occupied"
        # new, 4 => merge army
        return 4;
    }

    $targetBuildingOwner = -1
    if($targetBuilding -ne -1) {$targetBuildingOwner = $global:arrBuildings[$targetBuilding][2]}

    # 5) hostile building
    if($targetBuildingOwner -ne $sourceArmyOwner) {return 3;}
    # 6) friendly building
    elseif($targetBuildingOwner -eq $sourceArmyOwner) {return 1;}

    # 7) is already checked
    #Write-Host "ARMY_GetPossibleAction: Default 0"
    return 0;
}

function handleClickGameworld($posX, $posY)
{
    $tile_x = [math]::floor($posX / $global:arrSettingsInternal["TILESIZE"]) + $global:arrCreateMapOptions["EDITOR_CHUNK_X"]
    $tile_y = [math]::floor($posY / $global:arrSettingsInternal["TILESIZE"]) + $global:arrCreateMapOptions["EDITOR_CHUNK_Y"]

    Write-Host "handleClickGameworld($posX, $posY)"

    if($tile_x -lt 2 -or $tile_y -lt 2 -or $tile_x -gt ([int]($arrCreateMapOptions["WIDTH"]) + 1) -or $tile_y -gt ([int]($arrCreateMapOptions["HEIGHT"]) + 1))
    {
        Write-Host "handleClickGameworld: But border tile"
        return;
    }

    if($global:strGameState -eq "SINGLEPLAYER_TILEINFO")
    {
        Write-Host "Tileinfo gamestate... returning!"
        return;
    }

    $selBldId = ([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"]))

    if($selBldId -eq -1 -and !$global:arrSettingsInternal["RECRUIT_ARMY"] -and $global:arrWindows.WindowCurrent -ne "WND_CAMPAIGN_SHOW_TEXT")
    {
        Write-Host "lets check tile info..."

        openTileinfoIfNeeded ([int]($tile_x - 2)) ([int]($tile_y - 2))

        CMP_checkEvent "ON_TILE_CLICKED" (([int]($tile_x - 2)), ([int]($tile_y - 2)))
    }
    elseif($global:arrSettingsInternal["RECRUIT_ARMY"])
    {
        $recruitOption = getRecruitOption ([int]($tile_x - 2)) ([int]($tile_y - 2)) ($global:arrPlayerInfo.currentPlayer)

        if($recruitOption)
        {
            if($recruitOption -eq 1)
            {
                if($global:arrMultiplayer.isClient)
                {
                    CLIENT_sendData ("0x302/" + ([int]($tile_x - 2)) + "/" + ([int]($tile_y - 2)))
                    playSFX "SND_HUM_ARMY_NEW"
                }
                else
                {
                    addArmyAtPositionForPlayer ([int]($tile_x - 2)) ([int]($tile_y - 2)) ($global:arrPlayerInfo.currentPlayer) $False (generateName) 1
                }
                GAME_SP_setRecruit $False
                WND_SetOffsetButton

                CMP_checkEvent "ON_ARMY_RAISED" ($global:arrPlayerInfo.currentPlayer)
            }
            elseif($recruitOption -eq 2)
            {
                ARMY_BuyArmyLevel ([int]($tile_x - 2)) ([int]($tile_y - 2))

                GAME_SP_setRecruit $False
                WND_SetOffsetButton

                # maybe someone needs a MERGE event?
                # CMP_checkEvent "ON_ARMY_MERGED" ($global:arrPlayerInfo.currentPlayer)
            }
        }
    }
    else
    {
        $canBuild = checkIfBuildingPossible $selBldId ([int]($tile_x - 2)) ([int]($tile_y - 2)) ($global:arrPlayerInfo.currentPlayer)

        if($canBuild -and $selBldId -ge 0)
        {
            if($global:arrMultiplayer.isClient)
            {
                # Client says he wants to add a building
                # 200: X    y   bldID
                CLIENT_sendData ("0x202/" + ($tile_x - 2) + "/" + ($tile_y - 2) + "/" + ($global:arrSettingsInternal["BUILDINGS_SELECTED"]))
                playSFX "SND_HUM_BUILDING"
            }
            else
            {
                # Server can add Buildings
                addBuildingAtPositionForPlayer ([int]($tile_x - 2)) ([int]($tile_y - 2)) $global:arrSettingsInternal["BUILDINGS_SELECTED"] ($global:arrPlayerInfo.currentPlayer) 0.0
            }

            GAME_setActiveButton "" "" 0 $True
            GAME_setBuildingValues

            CMP_checkEvent "ON_BUILDING_PLACED" (($global:arrPlayerInfo.currentPlayer), $selBldId)
        }
    }

}

function isValidClickPosition($posX, $posY)
{
    if($posX -lt 0 -or $posX -gt $global:arrMap["WIDTH"])
    {
        Write-Host "isValidClickPosition - ERROR out of world ($posX)"
        return $False;
    }
    
    if($posY -lt 0 -or $posY -gt $global:arrMap["HEIGHT"])
    {
        Write-Host "isValidClickPosition - ERROR out of world ($posY)"
        return $False;
    }

    return $True;
}

function urand($min, $max)
{
    if($min -eq $max) {return $min}
    return (Get-Random -Minimum $min -Maximum ($max + 1))
}

function addArmyAtPositionForPlayer($posX, $posY, $plrID, $isFree, $name, $level)
{
    Write-Host "addArmyAtPositionForPlayer($posX, $posY, $plrID, $isFree, $name, $level)"

    $isValidPosition = isValidClickPosition $posX $posY

    if(!$isValidPosition) {return;}

    # 0 play sfx
    if(!$isFree -and (!(MP_isMultiplayer) -or (MP_isCurrentMPPlayer $plrID)))
    {
        playSFX "SND_HUM_ARMY_NEW"
    }

    # 1 = create new army at current army index
    $armyID = $global:arrMap["ARMY_INDEX"]
    $global:arrArmies[$armyID] = @{}

    # 2 = set values
    $global:arrArmies[$armyID][0] = $posX
    $global:arrArmies[$armyID][1] = $posY
    $global:arrArmies[$armyID][2] = $plrID
    $global:arrArmies[$armyID][3] = $name # generateName
    $global:arrArmies[$armyID][4] = $global:arrSettingsInternal["ARMY_DEFAULT_HP"] * $level# HP
    $global:arrArmies[$armyID][5] = 0 # MP
    $global:arrArmies[$armyID][6] = 1 # sleeping? 0 = no, 1 = yes
    $global:arrArmies[$armyID][7] = $level # army level

    # 3 = set layer
    $global:arrMap["WORLD_LARMY"][$posX][$posY] = $armyID

    # 4 = draw at
    MAP_drawTile $posX $posY $True

    # 5 = pay? Clients do not add armies by command and get their wares updated by server (0x200)
    if(!$isFree -and !$global:arrMultiplayer.isClient)
    {
        updatePlayerStat $plrID 6 (-1 * $global:arrSettingsInternal["ARMY_UNIT_COSTS"][0])
        updatePlayerStat $plrID 8 (-1 * $global:arrSettingsInternal["ARMY_UNIT_COSTS"][1])
        updatePlayerStat $plrID 9 (-1 * $global:arrSettingsInternal["ARMY_UNIT_COSTS"][2])
    }

    # 6 = Server logic
    if($global:arrMultiplayer.isServer)
    {
        # send updated wares
        SERVER_sendDataAll ("0x200/" + $plrID + "/" + $global:arrPlayerInfo[$plrID][6] + "/" + $global:arrPlayerInfo[$plrID][7] + "/" + $global:arrPlayerInfo[$plrID][8] + "/" + $global:arrPlayerInfo[$plrID][9])
        # send new army $armyID
        SERVER_sendDataAll ("0x301/" + $plrID + "/" + $posX + "/" + $posY + "/" + $name)
    }

    # 7 = FOW logic
    FOW_updateForPlayer $posX $posY 1 $plrID $True

    # last
    $global:arrMap["ARMY_INDEX"] = $global:arrMap["ARMY_INDEX"] + 1
}

function updateBuildingState($bldIndex, $newPercent, $newState)
{
    Write-Host "| updateBuildingState($bldIndex, $newPercent, $newState)"

    if(!($global:arrBuildings[$bldIndex]))
    {
        Write-Host "updateBuildingState: Building does not exist"
        return;
    }

    $global:arrBuildings[$bldIndex][5] = $newPercent # percent
    $global:arrBuildings[$bldIndex][4] = $newState # state

    $posX = $global:arrBuildings[$bldIndex][0]
    $posY = $global:arrBuildings[$bldIndex][1]

    MAP_drawTile $posX $posY 

    $owner = $global:arrBuildings[$bldIndex][2]
    $bldID = $global:arrBuildings[$bldIndex][3]

    if(($bldID -eq 0 -or $bldID -eq 9) -and $newState -eq 1)
    {
        FOW_updateForPlayer $posX $posY 3 $owner $True
    }
}

function addBuildingAtPositionForPlayer($posX, $posY, $building, $player, $percent, $isFree)
{
    Write-Host "addBuildingAtPositionForPlayer($posX, $posY, $building, $player, $percent, $isFree)"

    if($Debug) {$percent = 1.0}

    $isValidPosition = isValidClickPosition $posX $posY

    if(!$isValidPosition) {return;}

    if($building -lt 0 -or $building -gt $global:arrBuildingIDToKey.Length)
    {
        Write-Host "addBuildingAtPositionForPlayer - ERROR invalid building id ($building)"
        return;
    }
    
    if($player -lt 0 -or $player -gt $global:arrSettingsInternal["PLAYER_MAX"])
    {
        Write-Host "addBuildingAtPositionForPlayer - ERROR invalid player id ($player)"
        return;
    }

    # (1) generate new building
    # (2) add building to lbld array (index)
    # (3) redraw
    # (4) updatePlayerStats

    #
    # 1
    #

    # $global:arrBuildings
    # 0 = loc_x
    # 1 = loc_y
    # 2 = owner
    # 3 = bldID ($global:arrBuilding array)
    # 4 = state (0 building, 1 finished maybe 2 burning later)
    # 5 = % state (0 = nothing, 1 = done)
    # 6 = current hitpoints


    $bldIndex = $global:arrMap["BUILDING_INDEX"]
    $global:arrMap["BUILDING_INDEX"] = $global:arrMap["BUILDING_INDEX"] + 1
    # updateBuildingState($bldIndex, $newPercent, $newState)

    $global:arrBuildings[$bldIndex] = @{}
    $global:arrBuildings[$bldIndex][0] = $posX #locx
    $global:arrBuildings[$bldIndex][1] = $posY #loc_y
    $global:arrBuildings[$bldIndex][2] = $player #owner
    $global:arrBuildings[$bldIndex][3] = $building #building ID

    if($percent -ge 1.0) {
        updateBuildingState $bldIndex 1 1
    } else {
        updateBuildingState $bldIndex $percent 0 
    }
    
    # play sound if
    # not multiplayer and not free
    # 

    if(!$isFree -and ((!(MP_isMultiplayer)) -or (MP_isCurrentMPPlayer $player)))
    {
        playSFX "SND_HUM_BUILDING"
    }

    $global:arrBuildings[$bldIndex][6] = $arrBuilding[$global:arrBuildingIDToKey[$building]].hitpoints

    #
    # 2
    #
    $global:arrMap["WORLD_LBLD"][$posX][$posY] = $bldIndex

    #
    # 3 + 4 (for instant)
    #
    if($percent -ge 1.0)
    {
        Write-Host "Adding new instant building"
        drawBuildingAt $posX $posY $building $player 0
        updatePlayerProduction $player $building 1
    }
    else
    {
        Write-Host "adding new non instant building"
        drawBuildingAt $posX $posY $building $player 1
    }

    #
    # 5 update playerstats
    #
    if(!$isFree -and !$global:arrMultiplayer.isClient)
    {
        updatePlayerStat $player 6 (-1 * ($arrBuilding[$global:arrBuildingIDToKey[$building]].gold_cost))
        updatePlayerStat $player 7 (-1 * ($arrBuilding[$global:arrBuildingIDToKey[$building]].wood_cost))
    }

    #
    # 6 Server logic
    #
    if($global:arrMultiplayer.isServer)
    {
        # send updated wares
        SERVER_sendDataAll ("0x200/" + $player + "/" + $global:arrPlayerInfo[$player][6] + "/" + $global:arrPlayerInfo[$player][7] + "/" + $global:arrPlayerInfo[$player][8] + "/" + $global:arrPlayerInfo[$player][9])
        # send new building site
        SERVER_sendDataAll ("0x201/" + $player + "/" + $posX + "/" + $posY + "/" + $building)
    }
}

function BLD_DestroyBuilding($bld, $byServer, $silent)
{
    Write-Host "BLD_DestroyBuilding($bld, $byServer, $silent)"

    if($bld -eq -1) {return}

    # $global:arrBuildings
    # 0 = loc_x
    # 1 = loc_y
    # 2 = owner
    # 3 = bldID ($global:arrBuilding array)
    # 4 = state (0 building, 1 finished maybe 2 burning later)
    # 5 = % state (0 = nothing, 1 = done)
    # 6 = current hitpoints
    $posX = $global:arrBuildings[$bld][0]
    $posY = $global:arrBuildings[$bld][1]
    $player = $global:arrBuildings[$bld][2]
    $bldID = $global:arrBuildings[$bld][3]
    $state = $global:arrBuildings[$bld][4]

    if($global:arrMultiplayer.isClient -and !$byServer)
    {
        CLIENT_sendData("0x205/" + $bld)
        return;
    }

    if(!$silent)
    {
        $sfx = "SND_BLD_DESTROY_0"

        # 1 update playerStat if building was finished / play sound
        if($state -eq 1)
        {
            updatePlayerProduction $player $bldID -1
            $sfx = "SND_BLD_DESTROY_1"
        }

        if((MP_isCurrentMPPlayer $player) -or !(MP_isMultiplayer))
        {
            playSFX $sfx
        }
    }

    # 2 update world
    $global:arrMap["WORLD_LBLD"][$posX][$posY] = -1
    MAP_drawTile $posX $posY $True

    # 3 update building array
    $global:arrBuildings.Remove($bld)

    # 4 Server logic
    if($global:arrMultiplayer.isServer)
    {
        # this is a simple destroy command
        if($silent)
        {
            SERVER_sendDataAll("0x204/" + $bld + "/1")
        }
        else
        {
            SERVER_sendDataAll("0x204/" + $bld + "/0")
        }
    }

}

function updatePlayerProduction($player, $building, [int]$factor)
{
    Write-Host "updatePlayerProduction($player, $building, $factor)"
    # There is at least one production type
    if($arrBuilding[$global:arrBuildingIDToKey[$building]].productionType -ne 0)
    {
        # only one type
        if($arrBuilding[$global:arrBuildingIDToKey[$building]].productionType -lt 5)
        {
            updatePlayerStat $player ($arrBuilding[$global:arrBuildingIDToKey[$building]].productionType) ($factor * ($arrBuilding[$global:arrBuildingIDToKey[$building]].productionAmount))
        }
        else
        {
            updatePlayerStat $player 1 ($factor * ($arrBuilding[$global:arrBuildingIDToKey[$building]].productionAmount))
            updatePlayerStat $player 2 ($factor * ($arrBuilding[$global:arrBuildingIDToKey[$building]].productionAmount))
            updatePlayerStat $player 3 ($factor * ($arrBuilding[$global:arrBuildingIDToKey[$building]].productionAmount))
            updatePlayerStat $player 4 ($factor * ($arrBuilding[$global:arrBuildingIDToKey[$building]].productionAmount))
        }
    }
}

function updatePlayerStat($player, $index, $amount)
{
    Write-Host "updatePlayerStat($player, $index, $amount)"

    $global:arrPlayerInfo[([int]($player))][([int]($index))] += $amount
}

function MAP_drawTile($posX, $posY, $redraw)
{
    Write-Host "MAP_drawTile($posX, $posY, $redraw)"

    if(!(WORLD_isInWorld $posX $posY)) {return;}

    MAP_changeTile ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrMap["WORLD_L1"][[int]$posX][[int]$posY]]].bitmap) ($posX + 2) ($posY + 2)

    if([int]$global:arrMap["WORLD_L2"][([int]$posX)][([int]$posY)] -ne -1)
    {
        MAP_changeTile ($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrMap["WORLD_L2"][$posX][$posY]]].bitmap) ($posX + 2) ($posY + 2)
    }

    if([int]($global:arrMap["WORLD_L3"][$posX][$posY]) -ne -1)
    {
        MAP_changeTile ($global:arrTextures[$arrObjectTextureIDToKey[$global:arrMap["WORLD_L3"][$posX][$posY]]].bitmap) ($posX + 2) ($posY + 2)
    }

    if($global:strGameState -eq "EDIT_MAP")
    {
        $playerID = getPlayerAtPosition $posX $posY

        if($playerID -ne 0)
        {
            MAP_changeTile ($global:arrTextures[$arrPlayerIconsIDToKey[$playerID]].bitmap) ($posX + 2) ($posY + 2)
        }
    }
    else
    {
        $bldIndex = $global:arrMap["WORLD_LBLD"][$posX][$posY]

        if($bldIndex -ne -1)
        {
            $state = $global:arrBuildings[$bldIndex][4]

            Write-Host "State: $state"

            if($state -eq 1)
            {
                drawBuildingAt $posX  $posY ($global:arrBuildings[$bldIndex][3]) ($global:arrBuildings[$bldIndex][2]) 0
            }
            else
            {
                drawBuildingAt $posX  $posY ($global:arrBuildings[$bldIndex][3]) ($global:arrBuildings[$bldIndex][2]) 1
            }
        }
    }

    $armyIndex = $global:arrMap["WORLD_LARMY"][$posX][$posY]

    if($armyIndex -ne -1)
    {
        $owner = $global:arrArmies[$armyIndex][2]

        MAP_changeTile $arrIcons[('HUM_UNIT_' + $owner)].bitmap ($posX + 2) ($posY + 2)
    }

    $overlay = $global:arrMap["WORLD_OVERLAY"][$posX][$posY]

    if($overlay -ne $null)
    {
        MAP_changeTile $overlay ($posX + 2) ($posY + 2)
    }

    if($redraw)
    {
        $pictureBox.Refresh();
    }
}

# offset 0 = inProgress, offset 1 = isFinished
function drawBuildingAt($posX, $posY, $bld, $player, $offset)
{
    Write-Host "drawBuildingAt($posX, $posY, $bld, $player, $offset)"

    $bldKey = $global:arrBuildingIDToKey[$bld]
    MAP_changeTile $global:arrIcons[($bldKey + "_" + $player + "_" + $offset)].bitmap ($posX + 2) ($posY + 2)

    $bldIndex = $global:arrMap["WORLD_LBLD"][$posX][$posY]

    MAP_addBuildingBar $bldIndex 
}

function checkIfPlayerHasWares($iPlayerID, $iIndex, $fAmount)
{
    return (($global:arrPlayerInfo[$iPlayerID][$iIndex]) -ge $fAmount)
}

function checkIfPlayerHasWaresForBuilding($iPlayerID, $iBuildingID)
{
    Write-Host "checkIfPlayerHasWaresForBuilding($iPlayerID, $iBuildingID)"

    $hasWares = $True

    if($arrBuilding[$global:arrBuildingIDToKey[$iBuildingID]].gold_cost -gt $global:arrPlayerInfo[$iPlayerID][6]) {$hasWares = $False}
    if($arrBuilding[$global:arrBuildingIDToKey[$iBuildingID]].wood_cost -gt $global:arrPlayerInfo[$iPlayerID][7]) {$hasWares = $False}

    return $hasWares
}

function checkIfPlayerHasWaresForArmy($iPlayerID)
{
    # gold
    $hasWares = checkIfPlayerHasWares $iPlayerID 6 ($global:arrSettingsInternal["ARMY_UNIT_COSTS"][0])
    if(!$hasWares) {return $False}

    # food
    $hasWares = checkIfPlayerHasWares $iPlayerID 8 ($global:arrSettingsInternal["ARMY_UNIT_COSTS"][1])
    if(!$hasWares) {return $False}

    $hasWares = checkIfPlayerHasWares $iPlayerID 9 ($global:arrSettingsInternal["ARMY_UNIT_COSTS"][2])

    return $hasWares;
}

# 0 = not possible
# 1 = possible
# 2 = merge recruit
function getRecruitOption($posX, $posY, $iPlayerID)
{
    Write-Host "getRecruitOption($posX, $posY, $iPlayerID)"

    if($Debug) {return 1;}

    # world check
    if(!(WORLD_isInWorld $posX $posY)) {return 0;}

    # ware check
    if(!(checkIfPlayerHasWaresForArmy $iPlayerID)) {return 0;}

    # continent check
    if(!($global:arrMap["WORLD_CONTINENT"][$posX][$posY] -eq 1)) {return 0;}

    # check if barracks in range
    if(!(hasBuildingInRange 2 8 $posX $posY $iPlayerID)) {return 0;}

    # check if hostile
    if(hasHostileInRange 2 $iPlayerID $posX $posY) {return 0;}

    # blocking army check (either none or own)
    $armyID = $global:arrMap["WORLD_LARMY"][$posX][$posY];
    if($armyID -eq -1) {return 1;}
    elseif($global:arrArmies[$armyID][2] -eq $iPlayerID) {return 2;}

    # should never reach this point
    throw "'getRecruitOption($posX, $posY, $iPlayerID)' Function had no result!"
    return 0;
}

function checkIfBuildingPossible($iBuildingID, $posX, $posY, $iPlayerID)
{
    Write-Host "checkIfBuildingPossible($iBuildingID, $posX, $posY, $iPlayerID)"

    ## firstfirst check if player has wares
    $canBuild = checkIfPlayerHasWaresForBuilding $iPlayerID $iBuildingID

    if(!$canBuild) {return $canBuild}

    ## firstfirstsecond check if continent correct
    $canBuild = ($global:arrMap["WORLD_CONTINENT"][$posX][$posY] -eq 1)
    if(!$canBuild) {return $canBuild}

    # first check if it's a valid position
    $canBuild = (checkBuildingQuality $iBuildingID $posX $posY $iPlayerID)
    # The building quality is not enough - so return and skip the next check
    if(!$canBuild){return $canBuild}

    $canBuild = (checkBuildingPrerequisites $iBuildingID $posX $posY $iPlayerID)
    # prerequisites not met, skip next check
    if(!$canBuild){return $canBuild}

    # check if hostiles around
    $canBuild = !(hasHostileInRange 2 $iPlayerID $posX $posY)

    return $canBuild
}

function checkBuildingQuality($iBuildingID, $posX, $posY, $iPlayerID)
{
    Write-Host "checkBuildingQuality($iBuildingID, $posX, $posY, $iPlayerID)"

    if($posX -ge $arrCreateMapOptions["WIDTH"] -or $posY -ge $arrCreateMapOptions["HEIGHT"])
    {
        return $False;
    }

    if($posY -lt 0 -or $posY -lt 0)
    {
        return $False
    }

    if([int]$global:arrMap["WORLD_L1"][$posX][$posY] -ge 0 -and [int]$global:arrMap["WORLD_L1"][$posX][$posY] -lt 4)
    {
        # LAYER 2 check
        if([int]$global:arrMap["WORLD_L2"][$posX][$posY] -ge 12 -and [int]$global:arrMap["WORLD_L2"][$posX][$posY] -le 22 -or [int]$global:arrMap["WORLD_L2"][$posX][$posY] -eq -1)
        {
            if([int]$global:arrMap["WORLD_L3"][$posX][$posY] -eq -1)
            {
                if($global:arrMap["WORLD_LBLD"][$posX][$posY] -eq -1)
                {
                    Write-Host "Valid buildingspot"
                    return $True
                }
                else
                {
                    Write-Host "Invalid BQ - LBLD"
                }
            }
            else
            {
                Write-Host "Invalid BQ - L3"
            }
        }
        else
        {
            Write-Host "Invalid BQ - L2"
        }
    }
    else
    {
        Write-Host "Invalid BQ - L1"
    }

    return $False
}

function checkBuildingPrerequisites($iBuildingID, $iPosX, $iPosY, $iPlayerID)
{
    Write-Host "checkBuildingPrerequisites($iBuildingID, $iPosX, $iPosY, $iPlayerID)"

    switch($iBuildingID)
    {
        0 # HUM_HQ
        {
            # no prereq for HQs
            return $True
        }
        1 # HUM_HOUSE_SMALL
        {
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        }
        2 # HUM_HOUSE_MEDIUM
        {
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        }
        3 # HUM_HOUSE_LARGE
        {
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        }
        4 # HUM_FARM
        {
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        }
        5 # HUM_FIELD
        {
            # close to farm?
            $canBuild = hasBuildingInRange 1 4 $iPosX $iPosY $iPlayerID

            if(!$canBuild){return $False}

            # close to HQ or Tower?
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        }
        6 # HUM_MINE
        {
            $hasGold = hasObjectInRange 0 18 $iPosX $iPosY

            if(!$hasGold) {return $False}

            # close to HQ or Tower?
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        }
        7 # HUM_SAWMILL
        {
            $hasWood = hasWoodInRange 0 $iPosX $iPosY
            #$hasWood = hasObjectInRange 0 13 $iPosX $iPosY
            #
            #if(!$hasWood) {$hasWood = hasObjectInRange 0 14 $iPosX $iPosY}
            #if(!$hasWood) {$hasWood = hasObjectInRange 0 15 $iPosX $iPosY}
            #if(!$hasWood) {$hasWood = hasObjectInRange 0 16 $iPosX $iPosY}

            if(!$hasWood) {return $False}

            # close to HQ or Tower?
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        } # HUM_BARRACKS
        8
        {
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        } # HUM_TOWER
        9
        {
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        }
        default{return $True}
    }
}

function hasHQTower($iRange, $iPosX, $iPosY, $iPlayerID)
{
    # close to HQ?
    $canBuild = hasBuildingInRange $iRange 0 $iPosX $iPosY $iPlayerID

    if($canBuild){return $True}

    # close to tower?
    $canBuild = hasBuildingInRange $iRange 9 $iPosX $iPosY $iPlayerID

    return $canBuild
}

function hasHQTowerBarracks($iRange, $iPosX, $iPosY, $iPlayerID)
{
    $canBuild = hasHQTower $iRange $iPosX $iPosY $iPlayerID

    if($canBuild){return $True}

    $canBuild = hasBuildingInRange $iRange 8 $iPosX $iPosY $iPlayerID

    return $canBuild
}

function getOwnerTile($iPosX, $iPosY, $checkBuildings)
{
    if(!(WORLD_isInWorld $iPosX $iPosY)) {return -1}

    $bldID = ([int]($global:arrMap["WORLD_LBLD"][$iPosX][$iPosY]))

    if($checkBuildings)
    {
        if($bldID -ne -1)
        {
            return ($global:arrBuildings[$bldID][2])
        }
    }

    $armyID = ([int]($global:arrMap["WORLD_LARMY"][$iPosX][$iPosY]))

    if($armyID -ne -1)
    {
        return ($global:arrArmies[$armyID][2])
    }

    return -1
}

function hasHostileInRange($iMode, $iPlayerID, $iPosX, $iPosY)
{
    Write-Host "hasHostileInRange($iMode, $iPlayerID, $iPosX, $iPosY)"

    if($iMode -eq 0)
    {
        # new mode
        for($i = 0; $i -lt 4; $i++)
        {
            $locX = $iPosX + ($i % 2 * (2 - $i))
            $locY = $iPosY + (($i + 1) % 2 * (-1 + $i))

            $tileOwner = (getOwnerTile $locX $locY)

            if($tileOwner -ne $iPlayerID -and $tileOwner -ne -1) {return $True;}
        }

        return $False
    }
    elseif($iMode -gt 0 -and $iMode -le 5)
    {
        # each column
        for($i = ($iPosX - $iMode); $i -le ($iPosX + $iMode); $i++)
        {
            for($j = ($iPosY - $iMode);$j -le ($iPosY + $iMode); $j++)
            {
                $tileOwner = (getOwnerTile $i $j)

                if($tileOwner -ne $iPlayerID -and $tileOwner -ne -1) {return $True;}
            }
        }

        return $False
    }

    return $False
}

function hasWoodInRange($iMode, $iPosX, $iPosY)
{
    $hasWood = hasObjectInRange 0 13 $iPosX $iPosY

    if(!$hasWood) {$hasWood = hasObjectInRange 0 14 $iPosX $iPosY}
    if(!$hasWood) {$hasWood = hasObjectInRange 0 15 $iPosX $iPosY}
    if(!$hasWood) {$hasWood = hasObjectInRange 0 16 $iPosX $iPosY}

    return $hasWood
}

function hasObjectInRange($iMode, $iObjectID, $iPosX, $iPosY)
{
    Write-Host "hasObjectInRange($iMode, $iObjectID, $iPosX, $iPosY)"
    if($iMode -eq 0)
    {
        # new mode
        for($i = 0; $i -lt 4; $i++)
        {
            $locX = $iPosX + ($i % 2 * (2 - $i))
            $locY = $iPosY + (($i + 1) % 2 * (-1 + $i))

            if(!(WORLD_isInWorld $locX $locY)) {continue;}

            $iObjID = ([int]($global:arrMap["WORLD_L3"][$locX][$locY]))

            if($iObjID -eq $iObjectID) {return $True}
        }

        return $False
    }
    elseif($iMode -gt 0 -and $iMode -le 5)
    {
        # each column
        for($i = ($iPosX - $iMode); $i -le ($iPosX + $iMode); $i++)
        {
            if($i -lt 0) {continue}
            if($i -ge [int]$global:arrCreateMapOptions["WIDTH"]) {continue}

            for($j = ($iPosY - $iMode);$j -le ($iPosY + $iMode); $j++)
            {
                if($j -lt 0) {continue}
                if($j -ge [int]$global:arrCreateMapOptions["HEIGHT"]) {continue}

                $iObjID = ([int]($global:arrMap["WORLD_L3"][$i][$j]))

                if($iObjID -eq $iBldID) {return $True}

                Write-Host "Not at: $i $j"
            }
        }
        return $False
    }

    return $False
}

function getBuildingCountInRange($iMode, $iBldID, $iPosX, $iPosY, $iPlayerID, $doAll)
{
    Write-Host "getBuildingCountInRange($iMode, $iBldID, $iPosX, $iPosY, $iPlayerID, $doAll)"
    # 0  = cross
    #    ?
    #   ?B?
    #    ?
    # 1> = around
    #   ???
    #   ?B?
    #   ???
    #  etc

    $bldCount = 0

    if($iMode -eq 0)
    {
        # new mode
        for($i = 0; $i -lt 4; $i++)
        {
            $locX = $iPosX + ($i % 2 * (2 - $i))
            $locY = $iPosY + (($i + 1) % 2 * (-1 + $i))

            if(!(WORLD_isInWorld $locX $locY)) {continue;}

            $bldID = ([int]($global:arrMap["WORLD_LBLD"][$locX][$locY]))

            if($bldID -ne -1)
            {
                $iOwner = $global:arrBuildings[$bldID][2]
                $type = $global:arrBuildings[$bldID][3]
                $state = $global:arrBuildings[$bldID][4]
                if($type -eq $iBldID -and $state -eq 1 -and $iOwner -eq $iPlayerID) 
                {
                    $bldCount = $bldCount + 1

                    if(!$doAll -and $bldCount -ge 1) {break;}
                }
            }
        }
    }
    elseif($iMode -gt 0 -and $iMode -le 5)
    {
        # each column
        for($i = ($iPosX - $iMode); $i -le ($iPosX + $iMode); $i++)
        {
            if($i -lt 0) {continue}
            if($i -ge [int]$global:arrCreateMapOptions["WIDTH"]) {continue}

            for($j = ($iPosY - $iMode);$j -le ($iPosY + $iMode); $j++)
            {
                if($j -lt 0) {continue}
                if($j -ge [int]$global:arrCreateMapOptions["HEIGHT"]) {continue}

                $bldID = ([int]($global:arrMap["WORLD_LBLD"][$i][$j]))
                if($bldID -ne -1)
                {
                    $iOwner = $global:arrBuildings[$bldID][2]
                    $type = $global:arrBuildings[$bldID][3]
                    $state = $global:arrBuildings[$bldID][4]
                    if($type -eq $iBldID -and $state -eq 1 -and $iOwner -eq $iPlayerID) 
                    {
                        $bldCount = $bldCount + 1

                        if(!$doAll -and $bldCount -ge 1) {break;}
                    }
                }
            }
        }
    }

    return $bldCount
}

function hasBuildingInRange($iMode, $iBldID, $iPosX, $iPosY, $iPlayerID)
{
    Write-Host "hasBuildingInRange($iMode, $iBldID, $iPosX, $iPosY, $iPlayerID)"
    # 0  = cross
    #    ?
    #   ?B?
    #    ?
    # 1> = around
    #   ???
    #   ?B?
    #   ???
    #  etc

    if($iMode -eq 0)
    {
        # new mode
        for($i = 0; $i -lt 4; $i++)
        {
            $locX = $iPosX + ($i % 2 * (2 - $i))
            $locY = $iPosY + (($i + 1) % 2 * (-1 + $i))

            if(!(WORLD_isInWorld $locX $locY)) {continue;}

            $bldID = ([int]($global:arrMap["WORLD_LBLD"][$locX][$locY]))

            if($bldID -ne -1)
            {
                $iOwner = $global:arrBuildings[$bldID][2]
                $type = $global:arrBuildings[$bldID][3]
                $state = $global:arrBuildings[$bldID][4]
                if($type -eq $iBldID -and $state -eq 1 -and $iOwner -eq $iPlayerID) {return $True}
            }
        }

        return $False
    }
    elseif($iMode -gt 0 -and $iMode -le 5)
    {
        # each column
        for($i = ($iPosX - $iMode); $i -le ($iPosX + $iMode); $i++)
        {
            if($i -lt 0) {continue}
            if($i -ge [int]$global:arrCreateMapOptions["WIDTH"]) {continue}

            for($j = ($iPosY - $iMode);$j -le ($iPosY + $iMode); $j++)
            {
                if($j -lt 0) {continue}
                if($j -ge [int]$global:arrCreateMapOptions["HEIGHT"]) {continue}

                $bldID = ([int]($global:arrMap["WORLD_LBLD"][$i][$j]))
                if($bldID -ne -1)
                {
                    $iOwner = $global:arrBuildings[$bldID][2]
                    $type = $global:arrBuildings[$bldID][3]
                    $state = $global:arrBuildings[$bldID][4]
                    if($type -eq $iBldID -and $state -eq 1 -and $iOwner -eq $iPlayerID) {return $True}
                }
            }
        }

        return $False
    }

    return $False
}

function handleClickEditor($posX, $posY)
{
    $tile_x = [math]::floor($posX / $global:arrSettingsInternal["TILESIZE"]) + $global:arrCreateMapOptions["EDITOR_CHUNK_X"]
    $tile_y = [math]::floor($posY / $global:arrSettingsInternal["TILESIZE"]) + $global:arrCreateMapOptions["EDITOR_CHUNK_Y"]
    
    if($tile_x -lt 2 -or $tile_y -lt 2 -or $tile_x -gt ($arrCreateMapOptions["WIDTH"] + 1) -or $tile_y -gt ($arrCreateMapOptions["HEIGHT"] + 1))
    {
        Write-Host "But border tile"
        return;
    }
    
    if($global:arrCreateMapOptions["SELECT_LAYER01"] -ne -1 -and (($global:arrCreateMapOptions["LAST_CHANGED_X"] -ne $tile_x) -or ($global:arrCreateMapOptions["LAST_CHANGED_Y"] -ne $tile_y) -or ($global:arrCreateMapOptions["LAST_MODE"] -ne 1) -or ($global:arrCreateMapOptions["LAST_CHANGED_TEX"] -ne $global:arrCreateMapOptions["SELECT_LAYER01"])))
    {
        $playerAtPos = getPlayerAtPosition ([int]$tile_x - 2) ([int]$tile_y - 2)
        if($playerAtPos -ne 0) {return}

        MAP_changeTile ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER01"]]].bitmap) $tile_x $tile_y
        $global:arrCreateMapOptions["LAST_CHANGED_TEX"] = $global:arrCreateMapOptions["SELECT_LAYER01"];
        $global:arrCreateMapOptions["LAST_MODE"] = $global:arrCreateMapOptions["EDIT_MODE"];
        $global:arrCreateMapOptions["LAST_CHANGED_X"] = $tile_x;
        $global:arrCreateMapOptions["LAST_CHANGED_Y"] = $tile_y;

        $global:arrMap["WORLD_L1"][([int]$tile_x - 2)][([int]$tile_y - 2)] = $global:arrCreateMapOptions["SELECT_LAYER01"]
        $global:arrMap["WORLD_L2"][([int]$tile_x - 2)][([int]$tile_y - 2)] = -1
        $global:arrMap["WORLD_L3"][([int]$tile_x - 2)][([int]$tile_y - 2)] = -1

    }
    elseif($global:arrCreateMapOptions["SELECT_LAYER02"] -ne -1 -and (($global:arrCreateMapOptions["LAST_CHANGED_X"] -ne $tile_x) -or ($global:arrCreateMapOptions["LAST_CHANGED_Y"] -ne $tile_y) -or ($global:arrCreateMapOptions["LAST_MODE"] -ne 2) -or ($global:arrCreateMapOptions["LAST_CHANGED_TEX"] -ne $global:arrCreateMapOptions["SELECT_LAYER02"])))
    {
        $playerAtPos = getPlayerAtPosition ([int]$tile_x - 2) ([int]$tile_y - 2)
        if($playerAtPos -ne 0) {return}

        MAP_changeTile ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrMap["WORLD_L1"][([int]$tile_x - 2)][([int]$tile_y - 2)]]].bitmap) $tile_x $tile_y

        MAP_changeTile ($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER02"]]].bitmap) $tile_x $tile_y
        $global:arrCreateMapOptions["LAST_CHANGED_TEX"] = $global:arrCreateMapOptions["SELECT_LAYER02"];
        $global:arrCreateMapOptions["LAST_MODE"] = $global:arrCreateMapOptions["EDIT_MODE"];
        $global:arrCreateMapOptions["LAST_CHANGED_X"] = $tile_x;
        $global:arrCreateMapOptions["LAST_CHANGED_Y"] = $tile_y;

        $global:arrMap["WORLD_L2"][([int]$tile_x - 2)][([int]$tile_y - 2)] = $global:arrCreateMapOptions["SELECT_LAYER02"]
        $global:arrMap["WORLD_L3"][([int]$tile_x - 2)][([int]$tile_y - 2)] = -1
    }
    elseif($global:arrCreateMapOptions["SELECT_LAYER03"] -ne -1 -and (($global:arrCreateMapOptions["LAST_CHANGED_X"] -ne $tile_x) -or ($global:arrCreateMapOptions["LAST_CHANGED_Y"] -ne $tile_y) -or ($global:arrCreateMapOptions["LAST_MODE"] -ne 3) -or ($global:arrCreateMapOptions["LAST_CHANGED_TEX"] -ne $global:arrCreateMapOptions["SELECT_LAYER03"])))
    {
        #MAP_changeTile ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER01"]]]) $tile_x $tile_y
        $playerAtPos = getPlayerAtPosition ([int]$tile_x - 2) ([int]$tile_y - 2)
        if($playerAtPos -ne 0) {return}

        MAP_changeTile ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrMap["WORLD_L1"][([int]$tile_x - 2)][([int]$tile_y - 2)]]].bitmap) $tile_x $tile_y
        # we can have objects without overlay texture
        if([int]$global:arrMap["WORLD_L2"][([int]$tile_x - 2)][([int]$tile_y - 2)] -ne -1)
        {
            MAP_changeTile ($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrMap["WORLD_L2"][([int]$tile_x - 2)][([int]$tile_y - 2)]]].bitmap) $tile_x $tile_y
        }

        MAP_changeTile ($global:arrTextures[$arrObjectTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER03"]]].bitmap) $tile_x $tile_y
        $global:arrCreateMapOptions["LAST_CHANGED_TEX"] = $global:arrCreateMapOptions["SELECT_LAYER03"];
        $global:arrCreateMapOptions["LAST_MODE"] = $global:arrCreateMapOptions["EDIT_MODE"];
        $global:arrCreateMapOptions["LAST_CHANGED_X"] = $tile_x;
        $global:arrCreateMapOptions["LAST_CHANGED_Y"] = $tile_y;

        $global:arrMap["WORLD_L3"][([int]$tile_x - 2)][([int]$tile_y - 2)] = $global:arrCreateMapOptions["SELECT_LAYER03"]
    }
    elseif($global:arrCreateMapOptions["SELECT_PLAYER"] -ne -1)
    {
        # first check if it's a valid position
        # LAYER 1 check
        if([int]$global:arrMap["WORLD_L1"][([int]$tile_x - 2)][([int]$tile_y - 2)] -ge 0 -and [int]$global:arrMap["WORLD_L1"][([int]$tile_x - 2)][([int]$tile_y - 2)] -lt 4)
        {
            # LAYER 2 check
            if([int]$global:arrMap["WORLD_L2"][([int]$tile_x - 2)][([int]$tile_y - 2)] -ge 12 -and [int]$global:arrMap["WORLD_L2"][([int]$tile_x - 2)][([int]$tile_y - 2)] -le 22 -or [int]$global:arrMap["WORLD_L2"][([int]$tile_x - 2)][([int]$tile_y - 2)] -eq -1)
            {
                if([int]$global:arrMap["WORLD_L3"][([int]$tile_x - 2)][([int]$tile_y - 2)] -eq -1)
                {
                    $playerAtPos = getPlayerAtPosition ([int]$tile_x - 2) ([int]$tile_y - 2)
                    Write-Host "Player at position is: $playerAtPos"

                    if($playerAtPos -ne 0) 
                    {
                        removePlayerFromPosition $playerAtPos
                    }
                    
                    if($global:arrCreateMapOptions["SELECT_PLAYER"] -gt 0)
                    {
                        removePlayerFromPosition $global:arrCreateMapOptions["SELECT_PLAYER"]
                    }

                    if($global:arrCreateMapOptions["SELECT_PLAYER"] -gt 0)
                    {
                        setPlayerPosition ([int]$tile_x - 2) ([int]$tile_y - 2) $global:arrCreateMapOptions["SELECT_PLAYER"]

                    }
                }
            }
        }
    }
}

function ARMY_resetOverlay($posX, $posY)
{
    Write-Host "ARMY_resetOverlay($posX, $posY)"

    if($posY -gt 0)
    {
        $global:arrMap["WORLD_OVERLAY"][$posX][($posY - 1)] = $null
        MAP_drawTile $posX ($posY - 1)
    }

    if($posX -lt ($global:arrMap["WIDTH"] - 1))
    {
        $global:arrMap["WORLD_OVERLAY"][($posX + 1)][$posY] = $null
        MAP_drawTile ($posX + 1)  $posY
    }

    if($posY -lt ($global:arrMap["HEIGHT"] - 1))
    {
        $global:arrMap["WORLD_OVERLAY"][$posX][($posY + 1)] = $null
        MAP_drawTile $posX  ($posY + 1)
    }

    if($posX -gt 0)
    {
        $global:arrMap["WORLD_OVERLAY"][($posX - 1)][$posY] = $null
        MAP_drawTile ($posX - 1) $posY
    }

    MAP_drawTile $posX $posY
}

function ARMY_setSleepState($iArmyID, $iSleepState)
{
    Write-Host "ARMY_setSleepState($iArmyID, $iSleepState)"

    $global:arrArmies[$iArmyID][6] = $iSleepState
}

function ARMY_setMovepoints($iArmyID, $iMovepoints)
{
    Write-Host "ARMY_setMovepoints($iArmyID, $iMovepoints)"

    $global:arrArmies[$iArmyID][5] = $iMovepoints
}

function ARMY_setHitpoints($iArmyID, $iHitpoints)
{
    Write-Host "ARMY_setHitpoints($iArmyID, $iHitpoints)"

    $global:arrArmies[$iArmyID][4] = $iHitpoints
}

function ARMY_setLevel($iArmyID, $iLevel)
{
    Write-Host "ARMY_setLevel($iArmyID, $iLevel)"

    $global:arrArmies[$iArmyID][7] = $iLevel
}

function ARMY_changePosition($armyID, $targetX, $targetY)
{
    Write-Host "ARMY_changePosition($armyID, $targetX, $targetY)"

    $posX = $global:arrArmies[$armyID][0]
    $posY = $global:arrArmies[$armyID][1]
    $global:arrArmies[$armyID][0] = $targetX
    $global:arrArmies[$armyID][1] = $targetY

    $global:arrMap["WORLD_LARMY"][$posX][$posY] = -1

    $global:arrMap["WORLD_LARMY"][$targetX][$targetY] = $armyID

    MAP_drawTile $posX $posY $True
    MAP_drawTile $targetX $targetY $True

    $owner = $global:arrArmies[$armyID][2]
    FOW_updateForPlayer $targetX $targetY 1 $owner $True
}

function ARMY_DoAction($armyID, $action, $targetX, $targetY)
{
    Write-Host "ARMY_DoAction($armyID, $action, $targetX, $targetY)"

    $plrID = $global:arrArmies[$armyID][2]
    switch($action)
    {
        1 # move
        {
            if((MP_isCurrentMPPlayer $plrID) -or !(MP_isMultiplayer))
            {
                playSFX "SND_HUM_ARMY_MOVE"
            }

            # always update movepoints
            ARMY_UpdateMovepoints $armyID -1

            # client logic
            if($global:arrMultiplayer.isClient)
            {
                CLIENT_sendData ("0x304/" + $armyID + "/" + $targetX + "/" + $targetY)
                # prevent multimove
                ARMY_UpdateMovepoints $armyID -2
            }
            else
            {
                ARMY_changePosition $armyID $targetX $targetY
            }

            $global:arrPlayerInfo.combatEvent[0] = 4
            $global:arrPlayerInfo.combatEvent[1] = $global:arrArmies[$armyID][2]
            $global:arrPlayerInfo.combatEvent[2] = $targetX
            $global:arrPlayerInfo.combatEvent[3] = $targetY

            # server logic
            if($global:arrMultiplayer.isServer)
            {
                # armyID, targetX, targetY, resultMovepoints, resultSleepState
                SERVER_sendDataAll("0x303/" + $armyID + "/" + ($global:arrArmies[$armyID][0]) + "/" + ($global:arrArmies[$armyID][1]) + "/" + ($global:arrArmies[$armyID][5]) + "/" + ($global:arrArmies[$armyID][7]))
            }
        }
        2 # attack Army
        {
            if((MP_isCurrentMPPlayer $plrID) -or !(MP_isMultiplayer))
            {
                playSFX "SND_HUM_ARMY_ATTACK"
            }

            # prevent multimove
            ARMY_UpdateMovepoints $armyID -2

            if($global:arrMultiplayer.isClient)
            {
                CLIENT_sendData ("0x311/" + $armyID + "/" + $targetX + "/" + $targetY)
                return $action;
            }

            $targetArmy = $global:arrMap["WORLD_LARMY"][$targetX][$targetY]

            $owner1 = $global:arrArmies[$armyID][2]
            $owner2 = $global:arrArmies[$targetArmy][2]

            $winner = ARMY_DoArmyBattle $armyID $targetArmy

            Write-Host "ARMY_DoArmyBattle Result: $armyID $targetArmy $owner1 $owner2 $winner"

            if((MP_isMultiplayer) -and $winner -ne -1)
            {
                $data1 = "0"
                $data2 = "1"

                if($winner -eq $owner1)
                {
                    $data1 = "1"
                    $data2 = "0"
                }

                if($owner1 -ne 1)
                {
                    SERVER_sendData ($global:arrPlayerInfo[$owner1][10]) ("0x312/" + $data1)
                }

                if($owner2 -ne 1)
                {
                    SERVER_sendData ($global:arrPlayerInfo[$owner2][10]) ("0x312/" + $data2)
                }
            }

            # need to know we lost the army
            if($winner -ne -1)
            {
                $sfx = "SND_HUM_ARMY_WIN"
                if($winner -eq $owner2 -or $winner -eq 0) 
                {
                    $sfx = "SND_HUM_ARMY_LOSE"
                    $action = 4
                }

                if((MP_isCurrentMPPlayer $plrID) -or !(MP_isMultiplayer))
                {
                    playSFX $sfx
                }
            }

            $global:arrPlayerInfo.combatEvent[0] = 5 #eventType
            $global:arrPlayerInfo.combatEvent[1] = $owner1 # playerA
            $global:arrPlayerInfo.combatEvent[2] = $owner2 # playerB
            $global:arrPlayerInfo.combatEvent[3] = $winner # winnerID
        }
        3 # attack building
        {
            if((MP_isCurrentMPPlayer $plrID) -or !(MP_isMultiplayer))
            {
                playSFX ("SND_HUM_ARMY_ATTACKBLD_" + (urand 1 3)) 
            }

            # client logic
            if($global:arrMultiplayer.isClient)
            {
                CLIENT_sendData ("0x305/" + $armyID + "/" + $targetX + "/" + $targetY)
                # prevent multimove
                ARMY_UpdateMovepoints $armyID -2
                return $action;
            }

            $bldID = $global:arrMap["WORLD_LBLD"][$targetX][$targetY]

            $dmgBuilding = $global:arrSettingsInternal["ARMY_DEFAULT_DMG"] * $global:arrArmies[$armyID][5] * $global:arrArmies[$armyID][7]

            ARMY_UpdateMovepoints $armyID -2

            $ownerID = $global:arrBuildings[$bldID][2]
            $buildingID = $global:arrBuildings[$bldID][3]
            $attackerID = $global:arrArmies[$armyID][2]

            $bldLost = BLD_DamageBuilding $bldID $dmgBuilding

            if($global:arrMultiplayer.isServer)
            {
                # no need to handle building lost, already done in BLD_DamageBuilding
                if(!$bldLost)
                {
                    # update building HP
                    SERVER_sendDataAll("0x206/" + $bldID + "/" + ($global:arrBuildings[$bldID][6]))
                    # if this was done by a client, we need to trigger a redraw
                    MAP_addBuildingBar $bldID
                }

                # armyID, armyX, armyY, resultMovepoints, resultSleepState
                SERVER_sendDataAll("0x303/" + $armyID + "/" + ($global:arrArmies[$armyID][0]) + "/" + ($global:arrArmies[$armyID][1]) + "/" + ($global:arrArmies[$armyID][5]) + "/" + ($global:arrArmies[$armyID][6]))
            }

            $global:arrPlayerInfo.combatEvent[0] = 6 #eventType
            if($bldLost) {$global:arrPlayerInfo.combatEvent[0] = 7}
            $global:arrPlayerInfo.combatEvent[1] = $ownerID # playerID
            $global:arrPlayerInfo.combatEvent[2] = $buildingID # buildingID
            $global:arrPlayerInfo.combatEvent[3] = $attackerID # attackerID
        }
        4 # merge army
        {
            $targetArmy = $global:arrMap["WORLD_LARMY"][$targetX][$targetY]
            ARMY_MergeArmies $armyID $targetArmy
        }
    }

    return $action;
}

function BLD_updateHitpoints($bldIndex, $newHitpoints)
{
    Write-Host "BLD_updateHitpoints($bldIndex, $newHitpoints)"
    $global:arrBuildings[$bldIndex][6] = $newHitpoints
}

function ARMY_DealDamage($armyID, $damage)
{
    Write-Host "ARMY_DealDamage($armyID, $damage)"
    # hp left?
    if($global:arrArmies[$armyID][4] -gt $damage)
    {
        $global:arrArmies[$armyID][4] = $global:arrArmies[$armyID][4] - $damage
        return $False
    }
    else
    {
        ARMY_DestroyArmy $armyID
        return $True
    }
}

# army battle needs rewrite, as I need to know who wins...

function ARMY_DoArmyBattle($attackerID, $defenderID)
{
    Write-Host "ARMY_DoArmyBattle($attackerID, $defenderID)"

    $winner = -1

    # army might be lost after battle
    $dmgFromAttacker = $global:arrArmies[$attackerID][7] * $global:arrSettingsInternal["ARMY_DEFAULT_DMG"]
    $dmgFromDefender = [int]($global:arrArmies[$defenderID][7] * $global:arrSettingsInternal["ARMY_DEFAULT_DMG"] * 0.5)

    $defenderDefeat = ARMY_DealDamage $defenderID $dmgFromAttacker
    $attackerDefeat = ARMY_DealDamage $attackerID $dmgFromDefender

    # -1, none defeat, 0 both defeat, 1-4 plr won
    if($defenderDefeat -and $attackerDefeat)
    {
        $winner = 0
    }
    elseif($attackerDefeat)
    {
        $winner = $global:arrArmies[$defenderID][2]

        if($global:arrMultiplayer.isServer)
        {
            SERVER_sendDataAll ("0x306/" + $defenderID + "/" + ($global:arrArmies[$defenderID][4]) + "/" + ($global:arrArmies[$defenderID][5]) + "/" + ($global:arrArmies[$defenderID][6]))
        }
    }
    elseif($defenderDefeat)
    {
        $winner = $global:arrArmies[$attackerID][2]

        if($global:arrMultiplayer.isServer)
        {
            SERVER_sendDataAll ("0x306/" + $attackerID + "/" + ($global:arrArmies[$attackerID][4]) + "/" + ($global:arrArmies[$attackerID][5]) + "/" + ($global:arrArmies[$attackerID][6]))
        }
    }
    else
    {
        if($global:arrMultiplayer.isServer)
        {
            SERVER_sendDataAll ("0x306/" + $attackerID + "/" + ($global:arrArmies[$attackerID][4]) + "/" + ($global:arrArmies[$attackerID][5]) + "/" + ($global:arrArmies[$attackerID][6]))
            SERVER_sendDataAll ("0x306/" + $defenderID + "/" + ($global:arrArmies[$defenderID][4]) + "/" + ($global:arrArmies[$defenderID][5]) + "/" + ($global:arrArmies[$defenderID][6]))
        }
    }

    return $winner
}

function ARMY_DestroyArmy($armyID)
{
    Write-Host "ARMY_DestroyArmy($armyID)"

    if($armyID -eq -1) {return}

    $posX = $global:arrArmies[$armyID][0]
    $posY = $global:arrArmies[$armyID][1]
    #$plrID = $global:arrArmies[$armyID][2]

    # retrieve people
    # no wait, this is wrong - destroying 2 buildings and killing an army then might give more people
    #updatePlayerStat $plrID 9 ($global:arrSettingsInternal["ARMY_UNIT_COSTS"][2])

    # 2 update world
    $global:arrMap["WORLD_LARMY"][$posX][$posY] = -1
    MAP_drawTile $posX $posY $True

    # 3 update building array
    $global:arrArmies.Remove($armyID)

    if($global:arrMultiplayer.isServer)
    {
        SERVER_sendDataAll ("0x309/" + $armyID)
    }
}

function BLD_DamageBuilding($bldID, $dmgBuilding, $silent)
{
    Write-Host "BLD_DamageBuilding($bldID, $dmgBuilding, $silent)"

    $global:arrBuildings[$bldID][6] = $global:arrBuildings[$bldID][6] - $dmgBuilding

    $state = $global:arrBuildings[$bldID][4]

    $bldLost = $False

    # 2x dmg if building isn't finished
    if($state -ne 1)
    {
        $global:arrBuildings[$bldID][6] = $global:arrBuildings[$bldID][6] - $dmgBuilding
    }

    if($global:arrBuildings[$bldID][6] -le 0)
    {
        # how should we know a client has won?
        # maybe as simple: if a building is destroyed in combat
        # send everyone a dedicated package
        # if the client is the current player (ignore server, he never gets the message)
        # simply play the win sound

        $ownerID = $global:arrBuildings[$bldID][2]

        # play sound if not in multiplayer
        # or if server and currentplayer -eq 
        if((!(MP_isMultiplayer) -or ($global:arrMultiplayer.isServer -and ($global:arrPlayerInfo.currentPlayer -eq 1))) -and !$silent)
        {
            playSFX "SND_HUM_ARMY_WIN"
        }

        if($global:arrMultiplayer.isServer -and !$silent)
        {
            SERVER_sendDataAll("0x207/" + $ownerID)
        }

        BLD_DestroyBuilding $bldID $global:arrMultiplayer.isServer $silent
        $bldLost = $True
    }

    return $bldLost
}

function ARMY_HandleActionIfAny($posX, $posY)
{
    if($global:arrPlayerInfo.selectedTile.mode -ne "ARMY") {return 0;}

    if($global:arrArmies[$global:arrPlayerInfo.selectedTile.armyID][2] -ne $global:arrPlayerInfo.currentPlayer) {return 0;}

    Write-Host "ARMY_HandleActionIfAny($posX, $posY)"

    $tile_x = [int](([math]::floor($posX / $global:arrSettingsInternal["TILESIZE"]) + $global:arrCreateMapOptions["EDITOR_CHUNK_X"]) - 2)
    $tile_y = [int](([math]::floor($posY / $global:arrSettingsInternal["TILESIZE"]) + $global:arrCreateMapOptions["EDITOR_CHUNK_Y"]) - 2)

    $locX = [int]($global:arrPlayerInfo.selectedTile.x)
    $locY = [int]($global:arrPlayerInfo.selectedTile.y)

    if($locX -eq -1 -or $locY -eq -1) {return 0}

    ARMY_resetOverlay $locX $locY

    $actionWas = 0

    # up
    if($tile_x -eq $locX -and $tile_y -eq ($locY - 1))
    {
        Write-Host "Up Action"
        $actionWas = ARMY_DoAction $global:arrPlayerInfo.selectedTile.armyID $global:arrPlayerInfo.selectedTileArmyActions[0] $tile_x $tile_y
    }
    elseif($tile_x -eq ($locX + 1) -and $tile_y -eq $locY)
    {
        Write-Host "Right Action"
        $actionWas = ARMY_DoAction $global:arrPlayerInfo.selectedTile.armyID $global:arrPlayerInfo.selectedTileArmyActions[1] $tile_x $tile_y
    }
    elseif($tile_x -eq $locX -and $tile_y -eq ($locY + 1))
    {
        Write-Host "Down Action"
        $actionWas = ARMY_DoAction $global:arrPlayerInfo.selectedTile.armyID $global:arrPlayerInfo.selectedTileArmyActions[2] $tile_x $tile_y
    }
    elseif($tile_x -eq ($locX - 1) -and $tile_y -eq $locY)
    {
        Write-Host "Left Action"
        $actionWas = ARMY_DoAction $global:arrPlayerInfo.selectedTile.armyID $global:arrPlayerInfo.selectedTileArmyActions[3] $tile_x $tile_y
    }
    else
    {
        Write-Host "No Action (Army: $locX/$locY Click: $tile_x/$tile_Y)"
        return $actionWas;
    }

    # in multiplayer, the client has to wait for selecting his army
    if($global:arrMultiplayer.isClient)
    {
        return $actionWas;
    }

    if($actionWas -eq 1)
    {
        $global:arrCreateMapOptions["SELECTED_X"] = $tile_x + 2;
        $global:arrCreateMapOptions["SELECTED_Y"] = $tile_y + 2;

        openTileInfoIfNeeded $tile_x $tile_y
    }
    elseif($actionWas -eq 2)
    {
        return $actionWas;
    }
    elseif($actionWas -eq 4)
    {
        return $actionWas;
    }
    elseif($actionWas -ne 0)
    {
        openTileInfoIfNeeded $locX $locY
    }

    Write-Host "Returning action $actionWas"
    return $actionWas;
}

function handleNClickWindow($posX, $posY, $strPreClickedButton)
{
    Write-Host "handleNClickWindow($posX, $posY, $strPreClickedButton)"

    $relX = $posX -  $global:arrWindows[$global:arrWindows.WindowCurrent].loc_x
    $relY = $posY -  $global:arrWindows[$global:arrWindows.WindowCurrent].loc_y

    $strCurrentWindow = $global:arrWindows.WindowCurrent

    if($global:arrWindows.WindowOpen -and !$global:arrWindows[$strCurrentWindow].nbtn)
    {
        Write-Host "handleNClickWindow: No buttons?"
        return $False;
    }

    if($posX -lt $global:arrWindows[$strCurrentWindow].loc_x -or $posX -gt ($global:arrWindows[$strCurrentWindow].loc_x + $global:arrWindows[$strCurrentWindow].wnd.Width))
    {
        Write-Host "handleNClickWindow: Outside X?"
        return $False;
    }
    
    if($posY -lt $global:arrWindows[$strCurrentWindow].loc_y -or $posY -gt ($global:arrWindows[$strCurrentWindow].loc_y + $global:arrWindows[$strCurrentWindow].wnd.Height))
    {
        Write-Host "handleNClickWindow: Outside Y?"
        return $False;
    }

    $keys    = $global:arrWindows[$strCurrentWindow].nbtn.Keys
    foreach($key in $keys)
    {
        if($global:arrWindows[$strCurrentWindow].nbtn[$key].disabled) {continue;}
    
        if($global:arrWindows[$strCurrentWindow].nbtn[$key].hidden) {continue;}
    
        if($global:arrWindows[$strCurrentWindow].nbtn[$key].function -eq "") {continue;}

        if($strPreClickedButton -ne $key) {continue;}
    
        if(($global:arrWindows[$strCurrentWindow].nbtn[$key].loc_x -lt $relX) -and ($global:arrWindows[$strCurrentWindow].nbtn[$key].loc_x + $global:arrWindows[$strCurrentWindow].nbtn[$key].size_x -gt $relX))
        {
            if(($global:arrWindows[$strCurrentWindow].nbtn[$key].loc_y -lt $relY) -and ($global:arrWindows[$strCurrentWindow].nbtn[$key].loc_y + $global:arrWindows[$strCurrentWindow].nbtn[$key].size_y -gt $relY))
            {
                CTL_handleClicked $strCurrentWindow $key ($global:arrWindows[$strCurrentWindow].nbtn[$key].function) ($global:arrWindows[$strCurrentWindow].nbtn[$key].parameter)
                return $True;
            }
        }
    }

    if($global:arrWindows[$strCurrentWindow].ninp)
    {
        $keys    = $global:arrWindows[$strCurrentWindow].ninp.Keys
        foreach($key in $keys)
        {
            if(($global:arrWindows[$strCurrentWindow].ninp[$key].loc_x -lt $relX) -and ($global:arrWindows[$strCurrentWindow].ninp[$key].loc_x + $global:arrWindows[$strCurrentWindow].ninp[$key].size_x -gt $relX))
            {
                if(($global:arrWindows[$strCurrentWindow].ninp[$key].loc_y -lt $relY) -and ($global:arrWindows[$strCurrentWindow].ninp[$key].loc_y + $global:arrWindows[$strCurrentWindow].ninp[$key].size_y -gt $relY))
                {
                    playSFX "SND_UI_INPUT"
                    INP_handleClicked $strCurrentWindow $key
                    return $True;
                }
            }
        }
    }

    return $False;
}

function handleClickWindow($posX, $posY)
{
    $relX = $posX -  $global:arrWindows[$global:arrWindows.WindowCurrent].loc_x
    $relY = $posY -  $global:arrWindows[$global:arrWindows.WindowCurrent].loc_y

    # relative to window click    
    if($global:strGameState -eq "EDIT_MAP" -and $posX -lt ($DrawingSizeX - 160))
    {
        Write-Host "Send click to editor"
        handleClickEditor $posX $posY
    }

    if($global:strGameState -eq "SINGLEPLAYER_INGAME" -and $posX -lt ($DrawingSizeX - 160))
    {
        Write-Host "Send click to gameworld"
        handleClickGameworld $posX $posY
        return;
    }

    if($global:strGameState -eq "SINGLEPLAYER_TILEINFO" -and $posX -lt ($DrawingSizeX - 160) -and $global:arrWindows.WindowCurrent -ne "WND_COMBAT_RESULTS_N")
    {
        # handle possible army actions
        $armyAction = ARMY_HandleActionIfAny $posX $posY

        Write-Host "Army Action: $armyAction"

        $wasEvent = $False

        if($global:arrPlayerInfo.combatEvent.Count -ne 0)
        {
            if($global:arrPlayerInfo.combatEvent[0] -eq 4)
            {
                $wasEvent = CMP_checkEvent "ON_ARMY_AT" ($global:arrPlayerInfo.combatEvent[1], $global:arrPlayerInfo.combatEvent[2], $global:arrPlayerInfo.combatEvent[3])
            }
            elseif($global:arrPlayerInfo.combatEvent[0] -eq 5)
            {
                $wasEvent = CMP_checkEvent "ON_ARMY_BATTLE" ($global:arrPlayerInfo.combatEvent[1], $global:arrPlayerInfo.combatEvent[2], $global:arrPlayerInfo.combatEvent[3])
            }
            elseif($global:arrPlayerInfo.combatEvent[0] -eq 6)
            {
                $wasEvent = CMP_checkEvent "ON_BUILDING_ATTACKED" ($global:arrPlayerInfo.combatEvent[1], $global:arrPlayerInfo.combatEvent[2], $global:arrPlayerInfo.combatEvent[3])
            }
            elseif($global:arrPlayerInfo.combatEvent[0] -eq 7)
            {
                $wasEvent = CMP_checkEvent "ON_BUILDING_LOST" ($global:arrPlayerInfo.combatEvent[1], $global:arrPlayerInfo.combatEvent[2], $global:arrPlayerInfo.combatEvent[3])
            }

            $global:arrPlayerInfo.combatEvent = @{}
        }

        if(!$wasEvent)
        {
            if($armyAction -eq 4 -or $armyAction -eq 2 -or $armyAction -eq 0)
            {
                GAME_SP_closeTileinfo
            }
        }

        return;
    }
}

function changeScrollSpeed($strBy)
{
    if($strBy -eq "INCREASE")
    {
        $global:arrSettings["SCROLLSPEED"] = [int]$global:arrSettings["SCROLLSPEED"] + 1
    }
    else
    {
        $global:arrSettings["SCROLLSPEED"] = [int]$global:arrSettings["SCROLLSPEED"] - 1
    }

    if($global:arrSettings["SCROLLSPEED"] -gt 10)
    {
        $global:arrSettings["SCROLLSPEED"] = 10
    }
    elseif($global:arrSettings["SCROLLSPEED"] -lt 1)
    {
        $global:arrSettings["SCROLLSPEED"] = 1
    }
}

function changeVolume($strType, $strBy)
{
    if($strBy -eq "INCREASE")
    {
        $global:arrSettings[$strType] = [int]$global:arrSettings[$strType] + 1
    }
    else
    {
        $global:arrSettings[$strType] = [int]$global:arrSettings[$strType] - 1
    }

    if($global:arrSettings[$strType] -gt 10)
    {
        $global:arrSettings[$strType] = 10
    }
    elseif($global:arrSettings[$strType] -lt 0)
    {
        $global:arrSettings[$strType] = 0
    }
}

function INP_handleLeave($strWindow, $strInput, $strFunction)
{
    Write-Host "INP_handleLeave($strWindow, $strInput, $strFunction)"

    switch($strFunction)
    {
        "FNK_LEAVE_PLAYERNAME"
        {
            $global:arrSettings["PLAYER_NAME"] = $global:arrWindows[$strWindow].ninp[$strInput].text
        }
        "FNK_LEAVE_MP_IP"
        {
            $strIP = $global:arrWindows["WND_MULTIPLAYER_TYPESELECTION"].ninp["INP_MULTIPLAYER_IP"].text

            try
            {
                [IPAddress]::Parse($strIP)
            }
            catch
            {
                $strIP = "127.0.0.1"
                INP_setText "WND_MULTIPLAYER_TYPESELECTION" "INP_MULTIPLAYER_IP" $strIP
            }

            $global:arrSettings["MP_LASTIP"] = $strIP

            saveConfig
        }
        "FNK_LEAVE_MP_PORT"
        {
            $iPort = 3665

            try
            {
                $iPort = ([int]$global:arrWindows["WND_MULTIPLAYER_TYPESELECTION"].ninp["INP_MULTIPLAYER_PORT"].text)
            }
            catch
            {
                $iPort = 3665
            }

            if($iPort -lt 1000 -or $iPort -gt 65536)
            {
                $iPort = 3665
            }

            INP_setText "WND_MULTIPLAYER_TYPESELECTION" "INP_MULTIPLAYER_PORT" ([string]$iPort)
            $global:arrSettings["MP_LASTPORT"] = ([string]$iPort)
            saveConfig
        }
    }
}

function CTL_handleClicked($strCurrentWindow, $strButton, $strFunction, $strParameter)
{
    Write-Host "CTL_handleClicked($strCurrentWindow, $strButton, $strFunction, $strParameter)"

    playSFX "SND_UI_BUTTON"

    switch($strFunction)
    {
        "FNK_SHOW_WINDOW"
        {
            # param = Window name
            showWindow $strParameter
        }
        "FNK_QUIT_GAME"
        {
            $objForm.Close();
        }
        "FNK_SWITCH_TOPMOST"
        {
            $global:arrSettings["TOPMOST"] = !$global:arrSettings["TOPMOST"]
            $objForm.Topmost = $global:arrSettings["TOPMOST"];
            WND_setTopmostButtonByState
        }
        "FNK_SWITCH_FOW"
        {
            WND_setFOWButtonState $strCurrentWindow $strButton (!$global:EnableFoW)
        }
        "FNK_MUSIC_VOLUME"
        {
            # param = increase or decrease
            changeVolume "VOLUMEMUSIC" $strParameter
            if([int]$global:arrSettingsInternal["SONGS"] -gt 0){ playSongs }
            BAR_SetTextValue "WND_GAME_OPTIONS_N" "BAR_MUSIC_VALUE" ("" + ([int](10 * [float]$global:arrSettings["VOLUMEMUSIC"])) + "%") ($global:arrSettings["VOLUMEMUSIC"] * 0.1)

        }
        "FNK_EFFECTS_VOLUME"
        {
            changeVolume "VOLUMEEFFECTS" $strParameter
            BAR_SetTextValue "WND_GAME_OPTIONS_N" "BAR_EFFECTS_VALUE" ("" + ([int](10 * [float]$global:arrSettings["VOLUMEEFFECTS"])) + "%") ($global:arrSettings["VOLUMEEFFECTS"] * 0.1)
        }
        "FNK_SCROLL_SPEED"
        {
            changeScrollSpeed $strParameter
            BAR_SetTextValue "WND_GAME_OPTIONS_N" "BAR_SCROLL_VALUE" ("" + $global:arrSettings["SCROLLSPEED"] + " Tile(s)") ($global:arrSettings["SCROLLSPEED"] / 10)
        }
        "FNK_LEAVE_OPTIONS"
        {
            saveConfig
            showWindow "WND_ESC_MAIN_N"
        }
        "FNK_MAP_CHANGE_HEIGHT"
        {
            EDITOR_changeCreateMapSize "HEIGHT" ([int]$strParameter)
        }
        "FNK_MAP_CHANGE_WIDTH"
        {
            EDITOR_changeCreateMapSize "WIDTH" ([int]$strParameter)
        }
        "FNK_MAP_CHANGE_BASETEXTURE"
        {
            EDITOR_changeCreateBasetexture ([int]$strParameter)
        }
        "FNK_MAP_CONTINUE"
        {
            $global:strGameState = "EDIT_MAP";
            initMapArray
            MAP_NcreateMapImage

            showWindow "WND_INTERFACE_EDITOR_LAYER_01"
        }
        "FNK_MAP_LOAD"
        {
            openMapFile
            if($global:strMapFile -ne "")
            {
                $global:strGameState = "EDIT_MAP";
                loadMap $global:strMapFile
                showWindow "WND_INTERFACE_EDITOR_LAYER_01"
            }
        }
        "FNK_EDITOR_SHOW_WINDOW"
        {
            # this resets stuff
            $global:arrCreateMapOptions["SELECT_PLAYER"] = -1
            $global:arrCreateMapOptions["SELECT_LAYER01"] = -1;
            $global:arrCreateMapOptions["SELECT_LAYER02"] = -1;
            $global:arrCreateMapOptions["SELECT_LAYER03"] = -1;

            EDIT_setActiveButton $strCurrentWindow $strButton $False

            showWindow $strParameter
        }
        "FNK_EDITOR_LAYER_PLAYER"
        {
            $global:arrCreateMapOptions["SELECT_PLAYER"] = [int]$strParameter

            EDIT_setActiveButton $strCurrentWindow $strButton $True
        }
        "FNK_EDITOR_LAYER_BASE"
        {
            $global:arrCreateMapOptions["SELECT_LAYER01"] = [int]$strParameter

            EDIT_setActiveButton $strCurrentWindow $strButton $True
        }
        "FNK_EDITOR_LAYER_OVERLAY"
        {
            $global:arrCreateMapOptions["SELECT_LAYER02"] = [int]$strParameter

            EDIT_setActiveButton $strCurrentWindow $strButton $True
        }
        "FNK_EDITOR_LAYER_OBJECT"
        {
            $global:arrCreateMapOptions["SELECT_LAYER03"] = [int]$strParameter

            EDIT_setActiveButton $strCurrentWindow $strButton $True
        }
        "FNK_EDITOR_SAVEMAP"
        {
            showWindow "WND_EDITOR_WAIT_N"
            buildMMAP
            saveMap ""
            showWindow "WND_ESC_EDITOR_N"
        }
        "FNK_EDITOR_SAVEIMAGE"
        {
            $global:objWorld.Save((".\MAP\" + ($global:arrWindows["WND_ESC_EDITOR_N"].ninp["INP_EDITOR_MAPNAME"].text) + ".png"))
        }
        "FNK_EDITOR_BACK"
        {
            $global:strGameState = "EDIT_MAP";
            showWindow "WND_INTERFACE_EDITOR_LAYER_01"
        }
        "FNK_EDITOR_LEAVE"
        {
            $global:strGameState = "MAIN_MENU"
            $global:arrWindows.WindowCurrent = "WND_ESC_MAIN_N"
        }
        "FNK_FP_OPENMAP"
        {
            openMapFile

            $strWindow = "WND_SINGLEPLAYER_SETUP_N"

            # no map selected
            if($global:strMapFile -eq "")
            {
                LBL_setText $strWindow "LBL_FP_PLAYERS" "-"
                LBL_setText $strWindow "LBL_FP_AUTHOR" "-"
                LBL_setText $strWindow "LBL_FP_SIZE" "-"
                BTN_setActiveStateAndText $strWindow "BTN_FP_OPENMAP" $False "Open Map..."

                for($p = 1; $p -le 4; $p++)
                {
                    $global:arrPlayerInfo[$p] = @{}
                    $global:arrPlayerInfo[$p][5] = 0 #playerType

                    BTN_setDisabledState $strWindow ("BTN_FP_PLAYER" + ($p - 1)) $True
                    BTN_setTextAndColor $strWindow ("BTN_FP_PLAYER" + ($p - 1)) "Closed" "RED"
                }

                return;
            }

            # a mapfile has been set
            $filename = Split-Path $global:strMapFile -leaf
            BTN_setActiveStateAndText $strWindow "BTN_FP_OPENMAP" $True $filename

            loadMapHeader $global:strMapFile

            LBL_setText $strWindow "LBL_FP_PLAYERS" ([string](getPlayerCount))
            LBL_setText $strWindow "LBL_FP_AUTHOR" ($global:arrMap["AUTHOR"])
            LBL_setText $strWindow "LBL_FP_SIZE" ("" + $global:arrMap["WIDTH"] + " x " + $global:arrMap["HEIGHT"])

            for($p = 1; $p -le 4; $p++)
            {
                $global:arrPlayerInfo[$p] = @{}
                $global:arrPlayerInfo[$p][0] = ("Player " + $p) # name
                $global:arrPlayerInfo[$p][1] = 0
                $global:arrPlayerInfo[$p][2] = 0
                $global:arrPlayerInfo[$p][3] = 0
                $global:arrPlayerInfo[$p][4] = 0
                $global:arrPlayerInfo[$p][5] = 0 #playerType
                $global:arrPlayerInfo[$p][6] = 250
                $global:arrPlayerInfo[$p][7] = 250
                $global:arrPlayerInfo[$p][8] = 50
                $global:arrPlayerInfo[$p][9] = 5

                if($global:arrMap[("PLAYER_0" + $p + "X")] -ne -1 -and $global:arrMap[("PLAYER_0" + $p + "Y")] -ne -1)
                {
                    $global:arrPlayerInfo[$p][0] = $global:arrSettings["PLAYER_NAME"]
                    $global:arrPlayerInfo[$p][5] = 3
                    BTN_setDisabledState $strWindow ("BTN_FP_PLAYER" + ($p - 1)) $False
                    BTN_setTextAndColor $strWindow ("BTN_FP_PLAYER" + ($p - 1)) "Local" "GRAY"
                }
                else
                {
                    BTN_setDisabledState $strWindow ("BTN_FP_PLAYER" + ($p - 1)) $True
                    BTN_setTextAndColor $strWindow ("BTN_FP_PLAYER" + ($p - 1)) "Closed" "RED"
                }
            }
        }
        "FNK_FP_SWITCH_PLAYERTYPE"
        {
            #$strParameter = id
            $plrID = [int]$strParameter
            $global:arrPlayerInfo[$plrID][5] = $global:arrPlayerInfo[$plrID][5] + 1
            if($global:arrPlayerInfo[$plrID][5] -gt $global:arrSettingsInternal["PLAYERTYPE_MAX"])
            {
                $global:arrPlayerInfo[$plrID][5] = 0
            }

            if($global:arrPlayerInfo[$plrID][5] -eq 3)
            {
                $global:arrPlayerInfo[$plrID][0] = $global:arrSettings["PLAYER_NAME"]
            }
            else
            {
                $global:arrPlayerInfo[$plrID][0] = (($global:arrPlayertypeIndexString[$global:arrPlayerInfo[$plrID][5]])+ " " + $plrID) # name
            }

            $strClr = "GRAY"
            if($global:arrPlayerInfo[$plrID][5] -eq 0) { $strClr = "RED"}

            BTN_setTextAndColor "WND_SINGLEPLAYER_SETUP_N" ("BTN_FP_PLAYER" + ($plrID - 1)) ($global:arrPlayertypeIndexString[$global:arrPlayerInfo[$plrID][5]]) $strClr
        }
        "FNK_FP_START"
        {
            # no map selected
            if($global:strMapFile -eq "")
            {
                showWindow "WND_FP_ERRORS"
                LBL_setText "WND_FP_ERRORS" "LBL_MESSAGE" "No Map selected!"
                return;
            }

            if(!(gameHasPlayerType(3)))
            {
                showWindow "WND_FP_ERRORS"
                LBL_setText "WND_FP_ERRORS" "LBL_MESSAGE" "No Human Player!"
                return;
            }

            $global:arrBuildings = @{}
            $global:arrBuildings[0] = @{}
            $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1

            try
            {
                loadMap $global:strMapFile
            }
            catch
            {
                showWindow "WND_FP_ERRORS"
                LBL_setText "WND_FP_ERRORS" "LBL_MESSAGE" "Bad Mapfile!"
                return;
            }

            $global:strGameState = "SINGLEPLAYER_INGAME";
            $global:arrPlayerInfo.currentPlayer = getFirstActivePlayer

            initPlayerDay $global:arrPlayerInfo.currentPlayer $False

            $global:arrPlayerInfo.roundNo = 1

            centerOnPlayer ($global:arrPlayerInfo.currentPlayer)

            showWindow "WND_SP_NEXT_PLAYER_N"
        }
        "FNK_SET_BUILDING"
        {
            GAME_setActiveButton $strCurrentWindow $strButton ([int]$strParameter) $False
            GAME_setBuildingValues
        }
        "FNK_SP_SHOW_WINDOW"
        {
            GAME_setActiveButton "" "" -1 $True
            GAME_SP_setRecruit $False
            showWindow $strParameter
        }
        "FNK_SP_SET_RECRUIT"
        {
            GAME_SP_setRecruit (!$global:arrSettingsInternal["RECRUIT_ARMY"])
        }
        "FNK_SP_TILEINFO_DESTROY"
        {
            BLD_DestroyBuilding ($global:arrPlayerInfo.selectedTile.buildingID)
            GAME_SP_closeTileinfo
        }
        "FNK_SP_CLOSE_TILEINFO"
        {
            GAME_SP_closeTileinfo
        }
        "FNK_SP_BACK"
        {
            $global:strGameState = "SINGLEPLAYER_INGAME"
            showWindow "WND_SP_MENU_BUILDING_N"
        }
        "FNK_SP_QUIT"
        {
            $global:strGameState = "MAIN_MENU"
            showWindow "WND_ESC_MAIN_N"
        }
        "FNK_SP_END_TURN"
        {
            handleEndTurnPlayer
            if(!$global:arrMultiplayer.isServer -and !$global:arrMultiplayer.isClient)
            {
                showWindow "WND_SP_NEXT_PLAYER_N"
                # hacky
                CMP_checkEvent "ON_BUILDING_COUNT"
                CMP_checkEvent "ON_ROUND" ($global:arrPlayerInfo.roundNo)
            }
        }
        "FNK_SP_NEXT_UNIT"
        {
            ARMY_FindNonSleepingUnit ($global:arrPlayerInfo.currentplayer)
        }
        "FNK_SP_CR_CLOSE"
        {
            $global:strGameState = "SINGLEPLAYER_INGAME"
            showWindow "WND_SP_MENU_ARMY_N"
        }
        "FNK_SP_SETLISTOFFSET"
        {
            changeArmyOffset $strParameter
        }
        "FNK_SP_SWITCH_SLEEP"
        {
            ARMY_SwitchArmySleepByIndex ($global:arrPlayerInfo.offsetArmies + ([int]$strParameter)) ($global:arrPlayerInfo.currentplayer) ([int]$strParameter)
        }
        "FNK_SP_SELECT_ARMY"
        {
            ARMY_SelectArmyByID ($global:arrPlayerInfo.offsetArmies + ([int]$strParameter)) ($global:arrPlayerInfo.currentplayer)
        }
        "FNK_MP_SETUP_WINDOW"
        {
            showWindow "WND_MULTIPLAYER_SERVER"
            WND_setFOWButtonState "WND_MULTIPLAYER_SERVER" "BTN_FOW_TOGGLE" $False

            BTN_setActiveStateAndText "WND_MULTIPLAYER_SERVER" "BTN_MP_OPENMAP" $False "Open Map..."
            LBL_setText "WND_MULTIPLAYER_SERVER" "LBL_MP_PLAYERS" "-"
            LBL_setText "WND_MULTIPLAYER_SERVER" "LBL_MP_AUTHOR" "-"
            LBL_setText "WND_MULTIPLAYER_SERVER" "LBL_MP_SIZE" "-"
            BTN_setPressedState "WND_MULTIPLAYER_SERVER" "BTN_FOW_TOGGLE" $False
            BTN_setTextAndColor "WND_MULTIPLAYER_SERVER" "BTN_FOW_TOGGLE" "Off" "RED"

            for($i = 0; $i -lt 4; $i++)
            {
                BTN_setTextAndColor "WND_MULTIPLAYER_SERVER" ("BTN_MP_PLAYER" + $i) "Closed" "RED"
                BTN_setDisabledState "WND_MULTIPLAYER_SERVER" ("BTN_MP_PLAYER" + $i) $True
            }

            SERVER_setupServer
        }
        "FNK_MP_CLOSE_SERVER"
        {
            SERVER_stopServer
            showWindow "WND_MULTIPLAYER_TYPESELECTION"
        }
        "FNK_MP_JOIN_GAME"
        {
            CLIENT_setupConnection
            #showWindow "WND_MULTIPLAYER_TYPESELECTION"
        }
        "FNK_MP_CLOSE_CLIENT"
        {
            CLIENT_stopClient
            showWindow "WND_MULTIPLAYER_TYPESELECTION"
        }
        "FNK_MP_OPENMAP"
        {
            if($global:strMapFile -ne "")
            {
                if((gameGetPlayerCountType(2)) -gt 1)
                {
                    SERVER_showError "You are not alone!"
                    return;
                }
            }

            openMapFile

            $strWindow = "WND_MULTIPLAYER_SERVER"

            # no map selected
            if($global:strMapFile -eq "")
            {
                LBL_setText $strWindow "LBL_MP_PLAYERS" "-"
                LBL_setText $strWindow "LBL_MP_AUTHOR" "-"
                LBL_setText $strWindow "LBL_MP_SIZE" "-"
                BTN_setActiveStateAndText $strWindow "BTN_MP_OPENMAP" $False "Open Map..."

                for($p = 1; $p -le 4; $p++)
                {
                    $global:arrPlayerInfo[$p] = @{}
                    $global:arrPlayerInfo[$p][5] = 0 #playerType
                
                    BTN_setDisabledState $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $True
                    BTN_setTextAndColor $strWindow ("BTN_MP_PLAYER" + ($p - 1)) "Closed" "RED"
                }

                $global:arrMultiplayer.Server.MapInfo.MaxPlayer = ""
                $global:arrMultiplayer.Server.MapInfo.Hash = ""

                return;
            }

            # a mapfile has been set
            $filename = Split-Path $global:strMapFile -leaf
            BTN_setActiveStateAndText $strWindow "BTN_MP_OPENMAP" $True $filename
            $global:arrMultiplayer.Server.MapInfo.MaxPlayer = 0

            loadMapHeader $global:strMapFile

            MAP_loadMD5Sum $global:strMapFile

            $global:arrMultiplayer.Server.MapInfo.Name = $filename
            $global:arrMultiplayer.Server.MapInfo.Hash = $global:arrMap["HASH"]

            LBL_setText $strWindow "LBL_MP_PLAYERS" ([string](getPlayerCount))
            LBL_setText $strWindow "LBL_MP_AUTHOR" ($global:arrMap["AUTHOR"])
            LBL_setText $strWindow "LBL_MP_SIZE" ("" + $global:arrMap["WIDTH"] + " x " + $global:arrMap["HEIGHT"])

            for($p = 1; $p -le 4; $p++)
            {
                $global:arrPlayerInfo[$p] = @{}
                $global:arrPlayerInfo[$p][0] = ("Player " + $p) # name
                $global:arrPlayerInfo[$p][1] = 0
                $global:arrPlayerInfo[$p][2] = 0
                $global:arrPlayerInfo[$p][3] = 0
                $global:arrPlayerInfo[$p][4] = 0
                $global:arrPlayerInfo[$p][5] = 0 #playerType
                $global:arrPlayerInfo[$p][6] = 250
                $global:arrPlayerInfo[$p][7] = 250
                $global:arrPlayerInfo[$p][8] = 50
                $global:arrPlayerInfo[$p][9] = 5
                $global:arrPlayerInfo[$p][10] = "" # multiplayer, endpoint

                if($global:arrMap[("PLAYER_0" + $p + "X")] -ne -1 -and $global:arrMap[("PLAYER_0" + $p + "Y")] -ne -1)
                {
                    $global:arrPlayerInfo[$p][5] = 1
                    BTN_setDisabledState $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $False
                    BTN_setTextAndColor $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $global:arrMPPlayerTypeIDString[1] "GRAY"
                    $global:arrMultiplayer.Server.MapInfo.MaxPlayer = $global:arrMultiplayer.Server.MapInfo.MaxPlayer + 1
                }
                else
                {
                    BTN_setDisabledState $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $True
                    BTN_setTextAndColor $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $global:arrMPPlayerTypeIDString[0] "RED"
                }
            }

            $global:arrMultiplayer.Server.MapInfo.Loaded = $True

            Write-Host "Max Players: " $global:arrMultiplayer.Server.MapInfo.MaxPlayer

            # set first player to host
            if($global:arrMultiplayer.Server.MapInfo.MaxPlayer -ge 1)
            {
                $global:arrPlayerInfo[1][5] = 2
                $global:arrPlayerInfo[1][0] = $global:arrSettings["PLAYER_NAME"]
                BTN_setDisabledState $strWindow "BTN_MP_PLAYER0" $True
                BTN_setTextAndColor $strWindow "BTN_MP_PLAYER0" $global:arrSettings["PLAYER_NAME"] "GRAY"
            }
        }
        "FNK_MP_SWITCH_PLAYERTYPE"
        {
            $strWindow = "WND_MULTIPLAYER_SERVER"

            $p = ([int]$strParameter)

            $type = $global:arrPlayerInfo[$p][5]

            if($type -eq 0)
            {
                $type = 1
            }
            elseif($type -eq 1)
            {
                $type = 0
            }
            else
            {
                $type = 1
                $strEndpoint = ($global:arrPlayerInfo[([int]$strParameter)][10])

                SERVER_sendData $strEndpoint ("0x04/1")
                SERVER_removeEndpoint $strEndpoint
            }

            $global:arrPlayerInfo[$p][5] = $type
            SERVER_sendDataAll ("0x03" + (SERVER_serializePlayers))
            SERVER_setupPlayerButtons
        }
        "FNK_MP_START"
        {
            if($global:strMapFile -eq "")
            {
                SERVER_showError "No Map selected!"
                return;
            }

            if((gameHasPlayerType(1)))
            {
                SERVER_showError "There are open slots!"
                return;
            }

            if((gameGetPlayerCountType(2)) -le 1)
            {
                SERVER_showError "There is only one player!"
                return;
            }

            $global:arrBuildings = @{}
            $global:arrBuildings[0] = @{}
            $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1

            try
            {
                loadMap $global:strMapFile
            }
            catch
            {
                SERVER_showError "Bad Mapfile!"
                return;
            }

            Write-Host "We are good to go!"
            SERVER_sendDataAll "0x100/1"

            $keys    = $global:arrMultiplayer.Server.Clients.Keys
            foreach($key in $keys)
            {
                $global:arrMultiplayer.Server.Clients[$key].clientState = "CLIENT_MAP_LOADING"
            }

            $global:strGameState = "SINGLEPLAYER_INGAME";
            showWindow "WND_SERVER_WAITING"
            $global:arrMultiplayer.State = "SERVER_WAIT_FOR_PLAYERS"
        }
        "FNK_MP_SERVER_START_INGAME"
        {
            # set current player to 1
            $global:arrPlayerInfo.currentplayer = 1
            $plrID = $global:arrPlayerInfo.currentplayer

            # tell all clients the current player
            SERVER_sendDataAll ("0x102/" + $plrID + "/" + $global:arrPlayerInfo[$plrID][6] + "/" + $global:arrPlayerInfo[$plrID][7] + "/" + $global:arrPlayerInfo[$plrID][8] + "/" + $global:arrPlayerInfo[$plrID][9] + "/" + $global:arrPlayerInfo[$plrID][1] + "/" + $global:arrPlayerInfo[$plrID][2] + "/" + $global:arrPlayerInfo[$plrID][3] + "/" + $global:arrPlayerInfo[$plrID][4])

            initPlayerDay $global:arrPlayerInfo.currentPlayer $False

            # this is called for the server only
            playSFX "SND_TURN_SELF"
            showWindow "WND_SP_MENU_WARES_N"
            $global:arrMultiplayer.State = "SERVER_TURN_SELF"
        }
        "FNK_SELECT_CAMPAIGN"
        {
            Write-Host "Select Campaign $strParameter"

            if($global:Campaigns.selected -ne -1)
            {
                BTN_setActiveState $strCurrentWindow ("BTN_CAMPAIGN_" + $global:Campaigns.selected) $False
            }

            $global:Campaigns.selected = [int]$strParameter

            for($i = 0; $i -lt 12; $i++)
            {
                $strText = ""

                if($global:Campaigns.data[($global:Campaigns.selected)]["DESC"][$i]) {$strText = $global:Campaigns.data[($global:Campaigns.selected)]["DESC"][$i]}

                if($strText.Length -gt 27)
                {
                    $strText = $strText.Substring(0, 22) + "[...]"
                }

                LBL_setText $strCurrentWindow ("LBL_LINE_" + $i) $strText
            }

            

            BTN_setActiveState $strCurrentWindow $strButton $True
        }
        "FNK_SHOW_WINDOW_CAMPAIGNSELECT"
        {
            #$strCurrentWindow

            if($global:Campaigns.selected -ne -1)
            {
                BTN_setActiveState ($global:arrWindows.WindowCurrent) ("BTN_CAMPAIGN_" + $global:Campaigns.selected) $False
            }

            for($i = 0; $i -lt 12; $i++)
            {
                LBL_setText ($global:arrWindows.WindowCurrent) ("LBL_LINE_" + $i) ""
            }

            $global:Campaigns.selected = -1

            $global:arrWindows.WindowCurrent = $strParameter

            #showWindow $strParameter
        }
        "FNK_LOAD_CAMPAIGN"
        {
            $cmpID = $global:Campaigns.selected

            if($cmpID -eq -1) {return;}

            Write-Host "Load Campaign: $cmpID"

            CMP_loadMaps $cmpID

            $global:Campaigns.selectedMap = -1

            showWindow "WND_CAMPAIGN_SELECT_MAP"
        }
        "FNK_CAMPAIGN_SELECT_MAP"
        {
            if($global:Campaigns.selectedMap -ne -1)
            {
                BTN_setActiveState "WND_CAMPAIGN_SELECT_MAP" ("BTN_SELECT_MAP" + $global:Campaigns.selectedMap) $False
            }

            $global:Campaigns.selectedMap = [int]$strParameter

            BTN_setActiveState "WND_CAMPAIGN_SELECT_MAP" ("BTN_SELECT_MAP" + $global:Campaigns.selectedMap) $True
        }
        "FNK_CAMPAIGN_START"
        {
            if($global:Campaigns.selectedMap -eq -1) {return;}

            $strMapFile = ".\CAMPAIGN\" + $global:Campaigns.data[($global:Campaigns.selected)]["TITLE"] + "\" + $global:Campaigns.data[($global:Campaigns.selected)]["MAPS"][($global:Campaigns.selectedMap)]
            $strMapScriptFile = ".\CAMPAIGN\" + $global:Campaigns.data[($global:Campaigns.selected)]["TITLE"] + "\" + ($global:Campaigns.data[($global:Campaigns.selected)]["MAPS"][($global:Campaigns.selectedMap)]).Replace(".smf", ".msf")

            $global:arrBuildings = @{}
            $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1

            try
            {
                loadMapHeader $strMapFile
                loadMapScript $strMapScriptFile
            }
            catch
            {
                #$ErrorMessage = $_.Exception.Message
                #Write-Host "ErrorMsg: $ErrorMessage"
                throw "Error loading Map '$strMapFile'!"
                return;
            }

            for($p = 1; $p -le 4; $p++)
            {
                $global:arrPlayerInfo[$p] = @{}
                $global:arrPlayerInfo[$p][0] = ("Player " + $p) # name
                $global:arrPlayerInfo[$p][1] = 0
                $global:arrPlayerInfo[$p][2] = 0
                $global:arrPlayerInfo[$p][3] = 0
                $global:arrPlayerInfo[$p][4] = 0
                $global:arrPlayerInfo[$p][5] = 0 #playerType -> CMP = AI
                $global:arrPlayerInfo[$p][6] = 250
                $global:arrPlayerInfo[$p][7] = 250
                $global:arrPlayerInfo[$p][8] = 50
                $global:arrPlayerInfo[$p][9] = 5

                if($global:arrMap[("PLAYER_0" + $p + "X")] -ne -1 -and $global:arrMap[("PLAYER_0" + $p + "Y")] -ne -1)
                {
                    if($p -eq 1)
                    {
                        $global:arrPlayerInfo[$p][0] = $global:arrSettings["PLAYER_NAME"]
                        $global:arrPlayerInfo[$p][5] = 3
                    }
                    else
                    {
                        $global:arrPlayerInfo[$p][5] = 2
                    }
                }
            }

            # need to enable FOW before loadMap
            CMP_checkEvent "ON_LOAD_MAP"

            try
            {
                loadMap $strMapFile
            }
            catch
            {
                throw "Error loading Map '$strMapFile'!"
                return;
            }

            $global:strGameState = "SINGLEPLAYER_INGAME";
            $global:arrPlayerInfo.currentPlayer = getFirstActivePlayer

            initPlayerDay $global:arrPlayerInfo.currentPlayer $False

            $global:arrPlayerInfo.roundNo = 1
            showWindow "WND_SP_NEXT_PLAYER_N"

            centerOnPlayer ($global:arrPlayerInfo.currentPlayer)

            # emit on start event
            CMP_checkEvent "ON_START"
        }
        "FNK_NEXT_PLAYER_CONTINUE"
        {
            #$global:arrPlayerInfo.currentPlayer
            #$global:arrPlayerInfo[$p][5] = 2
            $plrType = $global:arrPlayerInfo[$global:arrPlayerInfo.currentPlayer][5]

            if($plrType -eq 2)
            {
                AI_handleTurn
            }
            else
            {
                #"FNK_SHOW_WINDOW" "WND_SP_MENU_WARES_N"
                showWindow "WND_SP_MENU_WARES_N"
            }
        }
        "FNK_MP_CLIENT_BACK"
        {
            if($global:arrMultiplayer.State -eq "CLIENT_TURN_SELF")
            {
                showWindow "WND_SP_MENU_BUILDING_N"
            }
            elseif($global:arrMultiplayer.State -eq "CLIENT_TURN_OTHER")
            {
                showWindow "WND_CLIENT_WAITINGFOR"
            }
            else
            {
                showWindow "WND_CLIENT_WAITING"
            }
        }
        "FNK_MP_CLIENT_QUIT"
        {
            CLIENT_stopClient
            $global:strGameState = "MAIN_MENU"
            showWindow "WND_MULTIPLAYER_TYPESELECTION"
        }
        "FNK_MP_SERVER_BACK"
        {
            if($global:arrMultiplayer.State -eq "SERVER_TURN_SELF")
            {
                showWindow "WND_SP_MENU_BUILDING_N"
            }
            elseif($global:arrMultiplayer.State -eq "SERVER_TURN_OTHER")
            {
                showWindow "WND_CLIENT_WAITINGFOR"
            }
            else
            {
                showWindow "WND_SERVER_WAITING"
            }
        }
        "FNK_MP_SERVER_QUIT"
        {
            SERVER_stopServer
            $global:strGameState = "MAIN_MENU"
            showWindow "WND_MULTIPLAYER_TYPESELECTION"
        }
        "FNK_MP_KICK"
        {
            SERVER_KickPlayerIngame ([int]$strParameter)
        }
        "FNK_ARMY_SWITCH_SLEEP"
        {
            $sleep = 0

            if ($global:arrArmies[($global:arrPlayerInfo.selectedTile.armyID)][6] -eq 0) { $sleep = 1 }

            ARMY_setSleepState ($global:arrPlayerInfo.selectedTile.armyID) $sleep
            GAME_setArmyTileinfo
        }
        "FNK_OPEN_LINK"
        {
            start $strParameter
        }
    }
}

function AI_displayBlockValues($iPosX, $iPosY, $iPlrID)
{
    Write-Host "AI_displayBlockValues($iPosX, $iPosY, $iPlrID)"

    if(!($global:arrAIPlayer.MapInfo))
    {
        Write-Host "Not calculated!"
        return;
    }

    if(!($global:arrAIPlayer.MapInfo[$iPosX][$iPosY]))
    {
        Write-Host "Not Visited"
        return;
    }

    #Write-Host "Visited     :" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].isVisited)
    #Write-Host "Occupied    :" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].isOccupied)
    Write-Host "Gold        :" ($global:arrAIPlayer.MapInfo[$iPosX][$iPosY].isGoldSpot)
    Write-Host "Wood        :" ($global:arrAIPlayer.MapInfo[$iPosX][$iPosY].isWoodSpot)
    Write-Host "canBuild    :" ($global:arrAIPlayer.MapInfo[$iPosX][$iPosY].canBuild)
    #Write-Host "towerCount  :" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerCount)
    #Write-Host "towerQuality:"
    #Write-Host "  newGold   :" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newGold)
    #Write-Host "  newWood   :" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newWood)
    #Write-Host "  newSpace  :" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newSpace)

    #AI_calculateTowerValue $iPosX $iPosY $iPlrID
    #
    #Write-Host "towerQuality:"
    #Write-Host "  newGold   :" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newGold)
    #Write-Host "  newWood   :" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newWood)
    #Write-Host "  newSpace  :" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newSpace)
}

function AI_calculateTowerValue($iPosX, $iPosY, $iPlrID)
{
    Write-Host "AI_calculateTowerValue($iPosX, $iPosY, $iPlrID)"
    # quality for a tower
    # this one should iterare over all points around
    # actually doesn't make sense if spot is not occupied
    $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality = @{}
    # spots with canBuild && gold
    $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newGold = 0;
    # spots with canBuild && wood
    $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newWood = 0;
    # spots with canBuild && !goold && !wood
    $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newSpace = 0;

    # spot has been visited (initial values set)
    #$global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].isVisited = $True

    # problem here is recursion...
    #if($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].isOccupied -and $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality)
    #{
        for($i = ($iPosX - 3); $i -le ($iPosX + 3); $i++)
        {
            if($i -lt 0) {continue}
            if($i -ge [int]$global:arrCreateMapOptions["WIDTH"]) {continue}

            for($j = ($iPosY - 3);$j -le ($iPosY + 3); $j++)
            {
                if($j -lt 0) {continue}
                if($j -ge [int]$global:arrCreateMapOptions["HEIGHT"]) {continue}

                #Write-Host "At: $i $j"

                if($i -eq $iPosX -and $j -eq $iPosY) {Write-Host "Same"; continue}

                # init/update that spot

                if($global:arrAIPlayer[$iPlrID].BQ[$i][$j].canBuild -and !($global:arrAIPlayer[$iPlrID].BQ[$i][$j].isOccupied))
                {
                    if($global:arrAIPlayer[$iPlrID].BQ[$i][$j].isGoldSpot)
                    {
                        #Write-Host "NewGold At: $i $j" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newGold)
                        $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newGold = $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newGold + 1
                        #Write-Host "AddedGold At: $i $j" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newGold)
                    }
                    elseif($global:arrAIPlayer[$iPlrID].BQ[$i][$j].isWoodSpot)
                    {
                        #Write-Host "NewWood At: $i $j" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newWood)
                        $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newWood = $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newWood + 1
                        #Write-Host "AddedWood At: $i $j" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newWood)
                    }
                    else
                    {
                        #Write-Host "NewSpace At: $i $j" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newSpace)
                        $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newSpace = $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newSpace + 1
                        #Write-Host "AddedSpace At: $i $j" ($global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerQuality.newSpace)
                    }
                }
            }
        }
    #}
}

#$global:arrAIPlayer.MapInfo

function AI_Build($iAIID)
{
    # find all HQs/Towers the AI currently posesses

    $Towers = @{}

    for($i = 0; $i -lt $global:arrMap["BUILDING_INDEX"]; $i++)
    {
        # no longer valid (destroyed)
        if(!($global:arrBuildings[$i])){continue}

        # must be given AI
        if($global:arrBuildings[$i][2] -ne $iAIID) {continue;}

        # must be HQ or Tower
        if($global:arrBuildings[$i][3] -ne 0 -and $global:arrBuildings[$i][3] -ne 11) {continue;}

        # and finised
        if(([int]($global:arrBuildings[$i][4]) -ne 1)) {continue;}

        $id = $Towers.Count

        Write-Host "NextTowerID: $id"

        $Towers[$id] = @{}
        $Towers[$id].x = $global:arrBuildings[$i][0]
        $Towers[$id].y = $global:arrBuildings[$i][1]

    }

    Write-Host "AI $iAIID TowerCount: " ($Towers.Count)

    $BQs = @{}

    for($i = 0; $i -lt $Towers.Count; $i++)
    {
        Write-Host "Checking Tower $i at " ($Towers[$i].x) ($Towers[$i].y)
        
        # first of all, for what building should the AI search a good building spot?
        # e.g. towers and farms should check all spots
        # simply every spot should have a value for every building

        for($locX = ($Towers[$i].x - 3); $locX -le ($Towers[$i].x + 3); $locX++)
        {
            for($locY = ($Towers[$i].y - 3); $locY -le ($Towers[$i].y + 3); $locY++)
            {
                # invalid spot
                if(!(WORLD_isInWorld $locX $locY)){continue;}

                if(!$BQs[$locX]) {$BQs[$locX] = @{}}
                if(!$BQs[$locX][$locY]) {$BQs[$locX][$locY] = @{}}

                Write-Host "Checking around Tower: $locX $locY"

                $bldID = $global:arrMap["WORLD_LBLD"][$locX][$locY]

                $BQs[$locX][$locY].hasBuilding = ($bldID -eq -1)

                # check for field, no score
                $BQs[$locX][$locY].isField = hasBuildingInRange 1 4 $locX $locY $iAIID

                # tower quality, score
                # this depends on new buildable spots, should gold/wood count extra?

                # farm quality, this depends on free spots around (not blocking gold or wood, or should they count less?)
                # should farms check weather a point is occupied?
                $BQs[$locX][$locY].farmScore = 0

                for($checkX = $locX - 1; $checkX -le $locX + 1; $checkX++)
                {
                    for($checkY = $locY -1; $checkY -le $locY + 1; $checkY++)
                    {
                        # not in world
                        if(!(WORLD_isInWorld $checkX $checkY)){continue;}

                        # there alreay is a building
                        if($global:arrMap["WORLD_LBLD"][$checkX][$checkY] -ne -1) {continue}

                        # can't build there
                        if(!($global:arrAIPlayer.MapInfo[$checkX][$checkY].canBuild)) {continue}

                        # gold
                        if($global:arrAIPlayer.MapInfo[$checkX][$checkY].isGoldSpot) {continue}

                        # wood
                        if($global:arrAIPlayer.MapInfo[$checkX][$checkY].isWoodSpot) {continue}

                        # another farm is already in range, so no new field spot
                        if(hasBuildingInRange 1 4 $checkX $checkY $iAIID) {continue}

                        # update score
                        $BQs[$locX][$locY].farmScore = $BQs[$locX][$locY].farmScore + 1 
                    }
                }
            }
        }
    }

    # output scoring
    $keysX    = $BQs.Keys

    foreach($keyX in $keysX)
    {
        $keysY    = $BQs[$keyX].Keys

        foreach($keyY in $keysY)
        {
            Write-Host "AI Info at: $keyX $keyY"
            Write-Host "isGoldSpot  :" ($global:arrAIPlayer.MapInfo[$keyX][$keyY].isGoldSpot)
            Write-Host "isWoodSpot  :" ($global:arrAIPlayer.MapInfo[$keyX][$keyY].isWoodSpot)
            Write-Host "canBuild    :" ($global:arrAIPlayer.MapInfo[$keyX][$keyY].canBuild)
            Write-Host "hasBuilding :" ($BQs[$keyX][$keyY].hasBuilding)
            Write-Host "isField     :" ($BQs[$keyX][$keyY].isField)
            Write-Host "farmScore   :" ($BQs[$keyX][$keyY].farmScore)
            Write-Host ""
        }
    }
}

# I think this one should also be responsible for updating
function AI_GenerateMapInfo()
{
    Write-Host "AI_GenerateMapInfo()"

    if($global:arrAIPlayer.MapInfo)
    {
        Write-Host "MapInfo exists, returning"
        return;
    }


    $global:arrAIPlayer.MapInfo = @{}

    for($i = 0; $i -lt $global:arrMap["WIDTH"]; $i++)
    {
        $global:arrAIPlayer.MapInfo[$i] = @{}

        for($j = 0; $j -lt $global:arrMap["HEIGHT"]; $j++)
        {
            $global:arrAIPlayer.MapInfo[$i][$j] = @{}

            $canBuild = (checkBuildingQuality -1 $i $j -1)
            $isGold = $False
            $isWood = $False

            if($canBuild)
            {
                $isGold = (hasObjectInRange 0 18 $i $j)
                $isWood = (hasWoodInRange 0 $i $j)
            }

            $global:arrAIPlayer.MapInfo[$i][$j].canBuild = $canBuild
            $global:arrAIPlayer.MapInfo[$i][$j].isGoldSpot = $isGold
            $global:arrAIPlayer.MapInfo[$i][$j].isWoodSpot = $isWood
        }
    }


    # spot occupation by self
    #$global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].isOccupied = (hasHQTower 3 $iPosX $iPosY $iPlrID)

    # a spot could grant gold or wood (wont change)
    #$global:arrAIPlayer.MapInfo[$iPosX][$iPosY].isGoldSpot = (hasObjectInRange 0 18 $iPosX $iPosY)
    #$global:arrAIPlayer.MapInfo[$iPosX][$iPosY].isWoodSpot = (hasWoodInRange 0 $iPosX $iPosY)

    # if building is possible
    #$global:arrAIPlayer.MapInfo[$iPosX][$iPosY].canBuild = (checkBuildingQuality -1 $iPosX $iPosY -1)

    # how much towers or HQs are in range - this determnins how much new space this possibly gives
    #$global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerCount = (getBuildingCountInRange 3 0 $iPosX $iPosY $iPlrID $True)
    #$global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerCount = $global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].towerCount + (getBuildingCountInRange 3 9 $iPosX $iPosY $iPlrID $True)

    # spot has been visited (initial values set)
    #$global:arrAIPlayer[$iPlrID].BQ[$iPosX][$iPosY].isVisited = $True
}

function AI_handleTurn()
{
    Write-Host "---------------"
    Write-Host "AI_handleTurn()"
    Write-Host "---------------"

    ## step 0 initialize information
    #if(!$global:AI_InformationArray.isInitialized)
    #{
    #    AI_initializeInformationArray
    #}

    # This was the last stuff I was working on...
    ######$aiPlrID = $global:arrPlayerInfo.currentPlayer
    ######
    ######AI_GenerateMapInfo
    ######
    ######AI_Build $aiPlrID

    #AI_calculateBlockValue 6 7 1

    #AI_GenerateMapInfo

    #$x = 6
    #$y = 7
    #$aiPlrID = 1
    #
    #for($i = ($x - 6); $i -le ($x + 6); $i++)
    #{
    #    if($i -lt 0) {continue}
    #    if($i -ge [int]$global:arrCreateMapOptions["WIDTH"]) {continue}
    #
    #    for($j = ($y - 6);$j -le ($y + 6); $j++)
    #    {
    #        if($j -lt 0) {continue}
    #        if($j -ge [int]$global:arrCreateMapOptions["HEIGHT"]) {continue}
    #        if($i -eq $x -and $j -eq $y) {continue}
    #
    #        # init/update that spot
    #        #AI_calculateBlockValue $i $j $aiPlrID
    #
    #        #AI_calculateTowerValue $i $j $aiPlrID
    #
    #        #AI_GenerateMapInfo
    #    }
    #}

    #for($i = ($x - 3); $i -le ($x + 3); $i++)
    #{
    #    if($i -lt 0) {continue}
    #    if($i -ge [int]$global:arrCreateMapOptions["WIDTH"]) {continue}
    #
    #    for($j = ($y - 3);$j -le ($y + 3); $j++)
    #    {
    #        if($j -lt 0) {continue}
    #        if($j -ge [int]$global:arrCreateMapOptions["HEIGHT"]) {continue}
    #        if($i -eq $x -and $j -eq $y) {continue}
    #
    #        AI_calculateTowerValue $i $j $aiPlrID
    #    }
    #}

    # step 1: possibly create / update information

    # step 2: iterate over building
    # 0 = ERROR
    # 1 = not Possible (Wares)
    # this possibly sets holdBLD
    # 2 = not Possible (Spots)
    # 3 = Success
    #####AI_buildBuilding $aiPlrID

    # it's actually not that easy to determin a good build order
    # the AI needs to consider several things
    # a) is the AI already expanding or not?
    # a1) if it is expanding, which direction?
    # a2) if it is expanding, what for?
    # a3) if it is not expanding, why not?
    # a3a) missing wares
    # a3b) missing buildspots
    # a3c) no more room

    # this alone makes it quite hard to build a good and reliable AI
    # so let's take an easier approach
    # calculate priority for all buildings
    # place buildings in currently occupied space if possible
    # problem: make sure AI doesn't block itself off
    # ideas for a solution: reserve spots in advance
    # could be done when a tower is finished (and initially for the HQ)
    # ideas for a solution: calculate block values
    # each owned tile could get a value on how much building a tower there is worth
    # e.g. reaching a free slot gives + 1, gold +4, wood +2
    # that way the AI could decide where to build a new tower
    # question: does this need recalculation?
    # possibly yes
    # - if a tower is lost
    # - if a hostile tower is near
    # anyway, this sounds like a more generic approach

    # this would require the AI to know much less
    # nearly nothing, as it'd just had to calculate those values on tower finish/lose
    # question: what's the threshold for reserving a spot?
    # actually, it's not that important, each point gets 0 points when a new building site is placed

    CTL_handleClicked "" "" "FNK_SP_END_TURN" ""
}

function CMP_checkEvent($eventType, $eventData)
{
    Write-Host "CMP_checkEvent($eventType, $eventData)"

    $eventTriggered = $False

    # whe have an event emitted and got some data - now check if an event should trigger
    for($i = 0; $i -lt $global:Campaigns.script.events.Count; $i++)
    {
        # ignore events that are no longer active
        if([int]($global:Campaigns.script.events[$i][0]) -ne 1) { continue;}

        # ignore wrong event types
        if([string]($global:Campaigns.script.events[$i][1]) -ne $eventType) { continue;}

        Write-Host "Event: " $global:Campaigns.script.events[$i][1]

        if(!(CMP_checkEventRequirements $i $eventData)) {continue;}

        Write-Host "Event should be excecuted!"

        $global:Campaigns.script.events[$i][0] = 0

        CMP_excecuteActionsForEvent ([int]($global:Campaigns.script.events[$i][3]))
        $eventTriggered = $True
    }

    if($eventTriggered)
    {
        CMP_checkEvent "ON_EVENTS_MET"
    }

    return $eventTriggered
}

function CMP_checkEventRequirements($iInternalID, $eventData)
{
    Write-Host "CMP_checkEventRequirements($iInternalID, $eventData)"

    $event = $global:Campaigns.script.events[$iInternalID]

    switch($event[1])
    {
        "ON_START"
        {
            return $True
        }
        "ON_LOAD_GAME"
        {
            return $True
        }
        "ON_LOAD_MAP"
        {
            return $True
        }
        "ON_BUILDING_PLACED"
        {
            # 0 = playerID
            # 1 = typeID

            # basic event data doesn't fit
            if([int]($event[4]) -ne $eventData[0] -or [int]($event[5]) -ne $eventData[1]) {return $False}

            return $True
        }
        "ON_BUILDING_COUNT"
        {
            # 0 = playerID
            # 1 = typeID

            # basic event data doesn't fit
            #if([int]($event[4]) -ne $eventData[0] -or [int]($event[5]) -ne $eventData[1]) {return $False}

            # check building count
            $bldCount = BLD_getPlayerBuildingCount ([int]($event[4])) ([int]($event[5]))

            Write-Host "BLD Count: $bldCount"

            if([int]($event[6]) -ne $bldCount -and [int]($event[6]) -ne -1) {return $False}

            return $True
        }
        "ON_BUILDING_LOST"
        {
            # 0 = playerID
            # 1 = typeID
            # 2 = attackerID

            # playerID check
            if([int]($event[4]) -ne [int]($eventData[0]) -and [int]($event[4]) -ne -1) {return $False}

            # typeID check
            if([int]($event[5]) -ne [int]($eventData[1]) -and [int]($event[5]) -ne -1) {return $False}

            # attackerID check
            if([int]($event[6]) -ne [int]($eventData[2]) -and [int]($event[6]) -ne -1) {return $False}

            return $True
        }
        "ON_BUILDING_ATTACKED"
        {
            # 0 = playerID
            # 1 = typeID
            # 2 = attackerID

            # playerID check
            if([int]($event[4]) -ne $eventData[0] -and [int]($event[4]) -ne -1) {return $False}

            # typeID check
            if([int]($event[5]) -ne $eventData[1] -and [int]($event[5]) -ne -1) {return $False}

            # attackerID check
            if([int]($event[6]) -ne $eventData[2] -and [int]($event[6]) -ne -1) {return $False}

            return $True
        }
        "ON_ROUND"
        {
            # 0 = roundNo

            # roundNo check
            if([int]($event[4]) -ne $eventData[0] -and [int]($event[4]) -ne -1) {return $False}

            return $True
        }
        "ON_ARMY_RAISED"
        {
            # 0 = playerID

            # playerID check
            if([int]($event[4]) -ne $eventData[0] -and [int]($event[4]) -ne -1) {return $False}

            # sumCheck
            $sumArmies = ARMY_getPlayerArmyCount ([int]($event[4]))
            if([int]($event[5]) -ne $sumArmies -and [int]($event[5]) -ne -1){return $False}

            return $True
        }
        "ON_ARMY_BATTLE"
        {
            # 0 = playerID1
            # 1 = playerID2
            # 2 = winnerID

            # playerID1 check
            if([int]($event[4]) -ne $eventData[0] -and [int]($event[4]) -ne $eventData[1] -and [int]($event[4]) -ne -1) {return $False}

            # playerID2 check
            if([int]($event[5]) -ne $eventData[0] -and [int]($event[5]) -ne $eventData[1] -and [int]($event[5]) -ne -1) {return $False}

            # winnerID check
            if([int]($event[6]) -ne $eventData[2] -and [int]($event[6]) -ne -1) {return $False}

            return $True
        }
        "ON_ARMY_AT"
        {
            # 0 = playerID
            # 1 = x
            # 2 = y

            # playerID check
            if([int]($event[4]) -ne $eventData[0] -and [int]($event[4]) -ne -1) {return $False}

            # x check
            if([int]($event[5]) -ne $eventData[1] -and [int]($event[5]) -ne -1) {return $False}

            # y check
            if([int]($event[6]) -ne $eventData[2] -and [int]($event[6]) -ne -1) {return $False}

            return $True
        }
        "ON_WARE_AMOUNT"
        {
            # 0 = playerID
            # 1 = wareID
            # 2 = amount

            # playerID check
            if([int]($event[4]) -ne $eventData[0] -and [int]($event[4]) -ne -1) {return $False}

            # x check
            if([int]($event[5]) -ne $eventData[1] -and [int]($event[5]) -ne -1) {return $False}

            # y check
            if([int]($event[6]) -ne $eventData[2] -and [int]($event[6]) -ne -1) {return $False}

            return $True
        }
        #"ON_GAME_WON"
        #{
        #    return $True
        #}
        "ON_EVENTS_MET"
        {
            $evState = CMP_getEventActiveState ([int]($event[4]))
            if($evState -ne 0) {return $False}

            $evState = CMP_getEventActiveState ([int]($event[5]))
            if($evState -ne 0) {return $False}

            return $True
        }
        "ON_TILE_CLICKED"
        {
            # 0 = x
            # 1 = y
            if([int]($event[4]) -ne $eventData[0] -and [int]($event[4]) -ne -1) {return $False}

            if([int]($event[5]) -ne $eventData[1] -and [int]($event[5]) -ne -1) {return $False}

            return $True
        }
    }
}

function CMP_excecuteActionsForEvent($iActionGroup)
{
    Write-Host "CMP_excecuteActionsForEvent($iActionGroup)"

    if($iActionGroup -eq -1) {return; }

    for($i = 0; $i -lt $global:Campaigns.script.actions.Count; $i++)
    {
        if($global:Campaigns.script.actions[$i][1] -eq $iActionGroup)
        {
            CMP_excecuteAction $i
        }
    }
}

function CMP_excecuteAction($iActionID)
{
    Write-Host "CMP_excecuteAction($iActionID)"

    $action = $global:Campaigns.script.actions[$iActionID]

    switch($action[0])
    {
        "SET_WARE"
        {
            # 2 = playerID
            # 3 = wareID, 1 = gold, 2 = wood, 3 = food
            # 4 = amount
            $global:arrPlayerInfo[[int]($action[2])][[int](5 + $action[3])] = [int]($action[4])

        }
        "ADD_WARE"
        {
            # 2 = playerID
            # 3 = wareID, 1 = gold, 2 = wood, 3 = food
            # 4 = amount
            $global:arrPlayerInfo[[int]($action[2])][[int](5 + $action[3])] = $global:arrPlayerInfo[[int]($action[2])][[int](5 + $action[3])] + [int]($action[4])
        }
        "ADD_BUILDING"
        {
            # 2 = playerID
            # 3 = bldType
            # 4 = state
            # 5 = x
            # 6 = y
            $hasBQ = checkBuildingQuality ([int]($action[3])) ([int]($action[5])) ([int]($action[6])) ([int]($action[2]))

            if(!$hasBQ)
            {
                Write-Host "Can't add building at: " ([int]($action[5])) ([int]($action[6]))
                return;
            }

            $bldState = ([float]$action[4])
            if($bldState -lt 0.0) {$bldState = 0.0}

            if($bldState -gt 1.0) {$bldState = 1.0}

            addBuildingAtPositionForPlayer ([int]($action[5])) ([int]($action[6])) ([int]($action[3])) ([int]($action[2])) $bldState $True
        }
        "SHOW_TEXT"
        {
            # 2 = text
            # problem for these events is, you may show 2 windows for different events
            # e.g. on roundNo and on BuildingCount - so one overwrites the other.
            # so these SHOW_TEXT should be pushed into an array which is interated after all possible events have been used.
            # then again, this is quite event dependant - e.g. you may have onbattle events which should show a message immediatly after
            GAME_SP_closeTileinfo
            showWindow "WND_CAMPAIGN_SHOW_TEXT" ([string]($action[2]))
        }
        "SET_EVENT_STATE"
        {
            # 2 = extEventID
            # 3 = state
            CMP_setEventState ([int]($action[2])) ([int]($action[3]))
        }
        "SET_NAME"
        {
            # 2 = playerID
            # 3 = PlayerName
            $global:arrPlayerInfo[[int]($action[2])][0] = [string]($action[3])
        }
        "GAME_WIN"
        {
            GAME_SP_closeTileinfo
            showWindow "WND_WIN_GAME"
        }
        "GAME_LOSE"
        {
            GAME_SP_closeTileinfo
            showWindow "WND_LOSE_GAME"
        }
        "ADD_ARMY"
        {
            # 2 = playerID
            # 3 = x
            # 4 = y
            # 5 = level
            addArmyAtPositionForPlayer ([int]($action[3])) ([int]($action[4])) ([int]($action[2])) $True (generateName) ([int]($action[5]))
        }
        "SET_ARMY_HP"
        {
            # 2 = HP
            # works for last army added
            ARMY_setHitpoints ($global:arrMap["ARMY_INDEX"] - 1) ([int]($action[2]))
        }
        "SET_FOW"
        {
            $global:EnableFoW = ([bool]([int]($action[2])))
        }
    }
}

function CMP_setEventState($extEventID, $eventState)
{
    Write-Host "CMP_setEventState($extEventID, $eventState)"

    $stateUpdated = $False

    for($i = 0; $i -lt $global:Campaigns.script.events.Count; $i++)
    {
        if($global:Campaigns.script.events[$i][2] -ne $extEventID) { continue; }

        if($global:Campaigns.script.events[$i][2] -eq $eventState) { continue; }

        $global:Campaigns.script.events[$i][0] = $eventState
        $stateUpdated = $True
    }

    if($stateUpdated)
    {
        CMP_checkEvent "ON_EVENTS_MET"
    }
}

function CMP_getEventActiveState($extEventID)
{
    Write-Host "CMP_getEventActiveState($extEventID)"

    for($i = 0; $i -lt $global:Campaigns.script.events.Count; $i++)
    {
        # ignore events that are no longer active
        if([int]($global:Campaigns.script.events[$i][0]) -ne 0) { continue;}

        if([int]($global:Campaigns.script.events[$i][2]) -ne $extEventID) { continue; }

        return 0
    }

    return 1
}

function ARMY_getPlayerArmyCount($plrID)
{
    Write-Host "ARMY_getPlayerArmyCount($plrID)"

    $armyCount = 0

    for($i = 0; $i -lt $global:arrMap["ARMY_INDEX"]; $i++)
    {
        if(!($global:arrArmies[$i])) {continue; }

        if($global:arrArmies[$i][2] -ne $plrID) {continue; }

        $armyCount = $armyCount + 1
    }

    return $armyCount
}

function BLD_getPlayerBuildingCount($plrID, $bldID)
{
    # TODO: Check if this can be removed and use the overview function

    Write-Host "BLD_getPlayerBuildingCount($plrID, $bldID)"

    $bldCount = 0

    for($i = 0; $i -lt $global:arrMap["BUILDING_INDEX"]; $i++)
    {
        if(!($global:arrBuildings[$i])){continue}

        if($global:arrBuildings[$i][2] -ne $plrID) {continue;}

        if($global:arrBuildings[$i][3] -ne $bldID) {continue;}

        if(([int]($global:arrBuildings[$i][4]) -ne 1)) {continue;}

        $bldCount = $bldCount + 1
    }

    return $bldCount
}

function CMP_loadMaps($cmpID)
{
    Write-Host "CMP_loadMaps($cmpID)"

    $global:Campaigns.data[$cmpID]["MAPS"] = @{}

    $strPath = ".\CAMPAIGN\" + $global:Campaigns.data[$cmpID]["TITLE"]
    $tmpCampMaps = Get-ChildItem $strPath "*.smf"

    if(!$tmpCampMaps) {throw "No maps for campaign found!"; return}

    for($i = 0; $i -lt $tmpCampMaps.Length; $i++)
    {
        $cmpMap = ([string]($tmpCampMaps[$i]))
        $global:Campaigns.data[$cmpID]["MAPS"][$i] = $cmpMap
    }
}

function SERVER_setupPlayerButtons()
{
    $strWindow = "WND_MULTIPLAYER_SERVER"

    #disabled only changes uppon mapchange
    for($p = 1; $p -le 4; $p++)
    {
        $type = $global:arrPlayerInfo[$p][5]

        if($type -eq 0)
        {
            BTN_setTextAndColor $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $global:arrMPPlayerTypeIDString[$type] "RED"
        }
        elseif($type -eq 1)
        {
            BTN_setTextAndColor $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $global:arrMPPlayerTypeIDString[$type] "GRAY"
        }
        else
        {
            BTN_setTextAndColor $strWindow ("BTN_MP_PLAYER" + ($p - 1)) $global:arrPlayerInfo[$p][0] "GRAY"
        }
    }
}

function MAP_loadMD5Sum($strMapfile)
{
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $hash = [System.BitConverter]::ToString($md5.ComputeHash([System.IO.File]::ReadAllBytes($strMapfile)))
    #Write-Host "Hash: " $hash

    $global:arrMap["HASH"] = $hash
}

function GAME_SP_closeTileinfo()
{
    $global:strGameState = "SINGLEPLAYER_INGAME"

    if($global:arrWindows.WindowCurrent -ne "WND_TILEINFO_ARMY_N" -and $global:arrWindows.WindowCurrent -ne "WND_TILEINFO_BUILDING_N") {return;}

    if((MP_isMultiplayer))
    {
        if(!(MP_isCurrentMPPlayer ($global:arrPlayerInfo.currentPlayer)))
        {
            showWindow "WND_CLIENT_WAITINGFOR"
            return;
        }
    }

    if($global:arrPlayerInfo.selectedTile.mode -eq "ARMY")
    {
        showWindow "WND_SP_MENU_ARMY_N"

        $locX = [int]($global:arrPlayerInfo.selectedTile.x)
        $locY = [int]($global:arrPlayerInfo.selectedTile.y)

        if($locX -ne -1 -and $locY -ne -1) 
        {
            ARMY_resetOverlay $locX $locY
        }
    }
    else
    {
        showWindow "WND_SP_MENU_BUILDING_N"
    }
}

function GAME_SP_setRecruit($active)
{
    BTN_setActiveState "WND_SP_MENU_ARMY_N" "BTN_SP_NEW_ARMY" $active
    $global:arrSettingsInternal["RECRUIT_ARMY"] = $active
}

function GAME_setBuildingValues($force)
{
    $bldId = $global:arrSettingsInternal["BUILDINGS_SELECTED"]

    if($bldId -eq -1 -or $force)
    {
        LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_SELECTED_BLD" "---"

        LBL_setTextAndTextColor "WND_SP_MENU_BUILDING_N" "LBL_COST_GOLD" "- 0" "GOLD"
        LBL_setTextAndTextColor "WND_SP_MENU_BUILDING_N" "LBL_COST_WOOD" "- 0" "GOLD"
        LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_COST_FOOD" "- 0"
        LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_COST_PEOPLE" "- 0"

        LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_GOLD" "+ 0"
        LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_WOOD" "+ 0"
        LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_FOOD" "+ 0"
        LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_PEOPLE" "+ 0"
    }
    else
    {
        LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_SELECTED_BLD" ($global:arrBuilding[$arrBuildingIDToKey[$bldId]].Name)

        if(([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].gold_cost)) -ne "")
        {
            $clr = "RED"

            if((checkIfPlayerHasWares ($global:arrPlayerInfo.currentPlayer) 6 ($global:arrBuilding[$arrBuildingIDToKey[$bldId]].gold_cost)))
            {
                $clr = "GREEN"
            }
            
            LBL_setTextAndTextColor "WND_SP_MENU_BUILDING_N" "LBL_COST_GOLD" ("- " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].gold_cost))) $clr
        }
        else
        {
            LBL_setTextAndTextColor "WND_SP_MENU_BUILDING_N" "LBL_COST_GOLD" "- 0" "GOLD"
        }

        if(([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].wood_cost)) -ne "")
        {
            $clr = "RED"

            if((checkIfPlayerHasWares ($global:arrPlayerInfo.currentPlayer) 7 ($global:arrBuilding[$arrBuildingIDToKey[$bldId]].wood_cost)))
            {
                $clr = "GREEN"
            }

            LBL_setTextAndTextColor "WND_SP_MENU_BUILDING_N" "LBL_COST_WOOD" ("- " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].wood_cost))) $clr
        }
        else
        {
            LBL_setTextAndTextColor "WND_SP_MENU_BUILDING_N" "LBL_COST_WOOD" "- 0" "GOLD"
        }

        if(([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].food_cost)) -ne "")
        {
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_COST_FOOD" ("- " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].food_cost)))
        }
        else
        {
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_COST_FOOD" "- 0"
        }

        if(([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].production_cost)) -ne "")
        {
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_COST_FOOD" ("- " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].production_cost)))
        }
        else
        {
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_COST_PEOPLE" "- 0"
        }

        if(($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionType) -eq 1)
        {
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_GOLD" ("+ " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionAmount)))
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_WOOD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_FOOD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_PEOPLE" "+ 0"
        }
        elseif(($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionType) -eq 2)
        {
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_GOLD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_WOOD" ("+ " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionAmount)))
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_FOOD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_PEOPLE" "+ 0"
        }
        elseif(($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionType) -eq 3)
        {
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_GOLD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_WOOD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_FOOD" ("+ " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionAmount)))
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_PEOPLE" "+ 0"
        }
        elseif(($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionType) -eq 4)
        {
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_GOLD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_WOOD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_FOOD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_PEOPLE" ("+ " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionAmount)))
        }
        elseif(($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionType) -eq 5)
        {
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_GOLD" ("+ " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionAmount)))
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_WOOD" ("+ " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionAmount)))
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_FOOD" ("+ " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionAmount)))
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_PEOPLE" ("+ " + ([string]($global:arrBuilding[$arrBuildingIDToKey[$bldId]].productionAmount)))
        }
        else
        {
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_GOLD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_WOOD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_FOOD" "+ 0"
            LBL_setText "WND_SP_MENU_BUILDING_N" "LBL_PROD_PEOPLE" "+ 0"
        }
    }
}

function GAME_setActiveButton($strWindow, $strButton, $bldID, $reset)
{
    if($reset)
    {
        if($global:arrWindows.editorButton -ne "")
        {
            BTN_setActiveStateAndColor $global:arrWindows.editorWindow $global:arrWindows.editorButton $False "GRAY"
        }

        $global:arrWindows.editorWindow = "";
        $global:arrWindows.editorButton = "";

        Write-Host "Selected Building: " ($global:arrSettingsInternal["BUILDINGS_SELECTED"])

        if($global:arrSettingsInternal["BUILDINGS_SELECTED"] -ne -1)
        {
            GAME_setBuildingValues $True
        }

        $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1;

        return;
    }

    if($global:arrSettingsInternal["BUILDINGS_SELECTED"] -eq -1)
    {
        $global:arrWindows.editorWindow = $strWindow
        $global:arrWindows.editorButton = $strButton

        BTN_setActiveStateAndColor $global:arrWindows.editorWindow $global:arrWindows.editorButton $True "RED"

        $global:arrSettingsInternal["BUILDINGS_SELECTED"] = $bldID
    }
    elseif($global:arrSettingsInternal["BUILDINGS_SELECTED"] -ne $bldID)
    {
        BTN_setActiveStateAndColor $global:arrWindows.editorWindow $global:arrWindows.editorButton $False "GRAY"

        $global:arrWindows.editorWindow = $strWindow
        $global:arrWindows.editorButton = $strButton

        BTN_setActiveStateAndColor $global:arrWindows.editorWindow $global:arrWindows.editorButton $True "RED"

        $global:arrSettingsInternal["BUILDINGS_SELECTED"] = $bldID
    }
    elseif($global:arrSettingsInternal["BUILDINGS_SELECTED"] -eq $bldID)
    {
        BTN_setActiveStateAndColor $global:arrWindows.editorWindow $global:arrWindows.editorButton $False "GRAY"

        $global:arrWindows.editorWindow = "";
        $global:arrWindows.editorButton = "";

        $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1;
    }
}

function EDIT_setActiveButton($strWindow, $strButton, $setNew)
{
    if($global:arrWindows.editorWindow -ne "")
    {
        BTN_setActiveStateAndColor $global:arrWindows.editorWindow $global:arrWindows.editorButton $False "GRAY"
    }

    if(!$setNew)
    {
        $global:arrWindows.editorWindow = ""
        $global:arrWindows.editorButton = ""
    }
    else
    {
        $global:arrWindows.editorWindow = $strWindow
        $global:arrWindows.editorButton = $strButton

        BTN_setActiveStateAndColor $global:arrWindows.editorWindow $global:arrWindows.editorButton $True "RED"
    }
}

function EDITOR_changeCreateBasetexture($iBy)
{
    Write-Host "EDITOR_changeCreateBasetexture($iBy)"

    $global:arrCreateMapOptions["BASTEXTUREID"] = $global:arrCreateMapOptions["BASTEXTUREID"] + $iBy

    #
    if($global:arrCreateMapOptions["BASTEXTUREID"] -lt 0)
    {
        $global:arrCreateMapOptions["BASTEXTUREID"] = ($arrBaseTextureIDToKey.Length - 1)
    }
    elseif($global:arrCreateMapOptions["BASTEXTUREID"] -gt ($arrBaseTextureIDToKey.Length - 1))
    {
        $global:arrCreateMapOptions["BASTEXTUREID"] = 0
    }

    IMB_setImage "WND_CREATE_MAP_N" "IMB_BASETEXTURE" ($arrBaseTextureIDToKey[($global:arrCreateMapOptions["BASTEXTUREID"])])
}

function EDITOR_changeCreateMapSize($strSide, $iBy)
{
    Write-Host "EDITOR_changeCreateMapSize($strSide, $iBy)"

    $global:arrCreateMapOptions[$strSide] = $global:arrCreateMapOptions[$strSide] + $iBy

    if($global:arrCreateMapOptions[$strSide] -lt 16)
    {
        $global:arrCreateMapOptions[$strSide] = 16
    }
    elseif($global:arrCreateMapOptions[$strSide] -gt 128)
    {
        $global:arrCreateMapOptions[$strSide] = 128
    }

    LBL_setText "WND_CREATE_MAP_N" ("LBL_" + $strSide + "_ACTUAL") ([string]($global:arrCreateMapOptions["$strSide"]))
}

function handleEndTurnPlayer()
{
    Write-Host "handleEndTurnPlayer"

    GAME_SP_setRecruit $False
    if($global:arrSettingsInternal["BUILDINGS_SELECTED"] -ne -1) {GAME_setBuildingValues $True}
    $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1

    if($global:arrMultiplayer.isClient)
    {
        # send server that my turn ends
        CLIENT_sendData ("0x103")
        showWindow "WND_CLIENT_WAITINGFOR"
        $global:arrMultiplayer.State = "CLIENT_TURN_OTHER"
        return;
    }

    if((isLastPlayer $global:arrPlayerInfo.currentPlayer))
    {
        $global:arrPlayerInfo.currentPlayer = getFirstActivePlayer
        initPlayerDay $global:arrPlayerInfo.currentPlayer $True

        $global:arrPlayerInfo.roundNo = $global:arrPlayerInfo.roundNo + 1
    }
    else
    {
        $global:arrPlayerInfo.currentPlayer = getNextActivePlayer ($global:arrPlayerInfo.currentPlayer)
        initPlayerDay $global:arrPlayerInfo.currentPlayer $False
    }

    

    if($global:arrMultiplayer.isServer)
    {
        # tell all clients the current player
        $plrID = $global:arrPlayerInfo.currentPlayer
        SERVER_sendDataAll ("0x102/" + $plrID + "/" + $global:arrPlayerInfo[$plrID][6] + "/" + $global:arrPlayerInfo[$plrID][7] + "/" + $global:arrPlayerInfo[$plrID][8] + "/" + $global:arrPlayerInfo[$plrID][9] + "/" + $global:arrPlayerInfo[$plrID][1] + "/" + $global:arrPlayerInfo[$plrID][2] + "/" + $global:arrPlayerInfo[$plrID][3] + "/" + $global:arrPlayerInfo[$plrID][4])

        # new player is host, gain control
        if($plrID -eq 1)
        {
            playSFX "SND_TURN_SELF"
            GAME_SP_closeTileinfo
            showWindow "WND_SP_MENU_WARES_N"
            $global:arrMultiplayer.State = "SERVER_TURN_SELF"
        }
        else
        {
            # new player isn't host
            playSFX "SND_TURN_OTHER"
            showWindow "WND_CLIENT_WAITINGFOR"
            $global:arrMultiplayer.State = "SERVER_TURN_OTHER"
        }
    }

    if(!(MP_isMultiplayer))
    {
        centerOnPlayer ($global:arrPlayerInfo.currentPlayer)
    }
}

function initPlayerDay($forPlayerID, $isLastDay)
{
    Write-Host "initPlayerDay($forPlayerID, $isLastDay)"

    # 1 reset production for player
    $global:arrPlayerInfo[$forPlayerID][1] = 0
    $global:arrPlayerInfo[$forPlayerID][2] = 0
    $global:arrPlayerInfo[$forPlayerID][3] = 0
    $global:arrPlayerInfo[$forPlayerID][4] = 0

    # 2 update buildings for player
    for($i = 0; $i -lt $global:arrMap["BUILDING_INDEX"]; $i++)
    {
        # no building
        if(!($global:arrBuildings[$i])){continue;}

        # other player
        if($global:arrBuildings[$i][2] -ne $forPlayerID){continue;}

        # check if building is in progress
        if(([int]($global:arrBuildings[$i][4]) -eq 0))
        {
            #percentage of building state (0 = nothing, 1 = done)
            $global:arrBuildings[$i][5] += $arrBuilding[$global:arrBuildingIDToKey[$global:arrBuildings[$i][3]]].buildspeed

            # building is done, so update it
            if($global:arrBuildings[$i][5] -gt 0.99)
            {
                $global:arrBuildings[$i][5] = 1 # percent
                $global:arrBuildings[$i][4] = 1 # state
                drawBuildingAt ($global:arrBuildings[$i][0]) ($global:arrBuildings[$i][1]) ($global:arrBuildings[$i][3]) ($global:arrBuildings[$i][2]) 0

                $bldID = $global:arrBuildings[$i][3]

                if($bldID -eq 0 -or $bldID -eq 9)
                {
                    FOW_updateForPlayer ($global:arrBuildings[$i][0]) ($global:arrBuildings[$i][1]) 3 $forPlayerID $True
                }

                # emit event
                # drawBuildingAt $posX $posY $building $player 0
                # 0 = playerID
                # 1 = typeID
                # CMP_checkEvent "ON_BUILDING_COUNT" (($global:arrBuildings[$i][3]), ($global:arrBuildings[$i][2]))
            }
            else
            {
                MAP_addBuildingBar $i
            }

            # sever logic, update bldState
            if($global:arrMultiplayer.isServer)
            {
                SERVER_sendDataAll ("0x203/" + $i + "/" + ($global:arrBuildings[$i][5]) + "/" + ($global:arrBuildings[$i][4]))
            }
        }
        else
        {
            # Problem at this point:
            # If production is updated first, the player will get resources for the building and have a false production
            # If production is updated second, the player will receive resources for a building that will no longer exist

            if($global:arrBuildings[$i][3] -eq 5)
            {
                # DamageBuilding handles destroyed buildings
                if((BLD_DamageBuilding $i 2 $True)){continue}

                # only if building still exists
                SERVER_sendDataAll("0x206/" + $i + "/" + ($global:arrBuildings[$i][6]))
                MAP_addBuildingBar $i
            }

            updatePlayerProduction ($global:arrBuildings[$i][2]) ($global:arrBuildings[$i][3]) 1
        }
    }

    # 3 apply income
    $global:arrPlayerInfo[$forPlayerID][6] = $global:arrPlayerInfo[$forPlayerID][6] + $global:arrPlayerInfo[$forPlayerID][1]
    $global:arrPlayerInfo[$forPlayerID][7] = $global:arrPlayerInfo[$forPlayerID][7] + $global:arrPlayerInfo[$forPlayerID][2]
    $global:arrPlayerInfo[$forPlayerID][8] = $global:arrPlayerInfo[$forPlayerID][8] + $global:arrPlayerInfo[$forPlayerID][3]
    # people are not summed but set
    $global:arrPlayerInfo[$forPlayerID][9] = $global:arrPlayerInfo[$forPlayerID][4]

    # 4 - update armies
    for($i = 0; $i -lt $global:arrMap["ARMY_INDEX"]; $i++)
    {
        # no army
        if(!($global:arrArmies[$i])){continue;}

        # other player
        if($global:arrArmies[$i][2] -ne $forPlayerID){continue;}

        # set MP for army
        $global:arrArmies[$i][5] = $global:arrSettingsInternal["ARMY_DEFAULT_MP"]

        # unset sleeping
        $global:arrArmies[$i][6] = 0

        # update people usage, this can also result in negative numbers
        updatePlayerStat ($global:arrArmies[$i][2]) 9 (-1 * $global:arrSettingsInternal["ARMY_UNIT_COSTS"][2] * $global:arrArmies[$i][7])

        if($global:arrMultiplayer.isServer)
        {
            # armyID, armyHP, armyMP, armySleep
            SERVER_sendDataAll("0x306/" + $i + "/" + ($global:arrArmies[$i][4]) + "/" + ($global:arrArmies[$i][5]) + "/" + ($global:arrArmies[$i][6]))
        }
    }

    # 4 updated wares for all
    if($global:arrMultiplayer.isServer)
    {
        SERVER_sendDataAll ("0x200/" + $forPlayerID + "/" + $global:arrPlayerInfo[$forPlayerID][6] + "/" + $global:arrPlayerInfo[$forPlayerID][7] + "/" + $global:arrPlayerInfo[$forPlayerID][8] + "/" + $global:arrPlayerInfo[$forPlayerID][9])
    }

    $pictureBox.Refresh();
}

function WND_SetOffsetButton()
{
    LBL_setText "WND_SP_MENU_ARMY_N" "LBL_SP_ARMY_LIST" ("" + ($global:arrPlayerInfo.offsetArmies + 1) + " - " + ($global:arrPlayerInfo.offsetArmies + 5))

    ARMY_FillUnitList
}

function ARMY_GetMaxArmies($owner)
{
    Write-Host "ARMY_GetMaxArmies($owner)"

    $maxArmies = 0

    for($i = 0; $i -lt $global:arrMap["ARMY_INDEX"]; $i++)
    {
        if(!($global:arrArmies[$i])){continue}

        if($global:arrArmies[$i][2] -eq $owner)
        {
            $maxArmies = $maxArmies + 1
        }
    }

    return $maxArmies;
}

function changeArmyOffset($byValue)
{
    Write-Host "changeArmyOffset($byValue)"

    $maxValue = ARMY_GetMaxArmies ($global:arrPlayerInfo.currentplayer)

    Write-Host "Max Army: $maxValue"

    if($byValue -eq "max")
    {
        $global:arrPlayerInfo.offsetArmies = ($maxValue - 5)
    }
    elseif($byValue -eq "min")
    {
        $global:arrPlayerInfo.offsetArmies = 0
    }
    else
    {
        $global:arrPlayerInfo.offsetArmies = $global:arrPlayerInfo.offsetArmies + $byValue
    }

    if($global:arrPlayerInfo.offsetArmies -gt ($maxValue - 5)) {$global:arrPlayerInfo.offsetArmies = ($maxValue - 5)}

    if($global:arrPlayerInfo.offsetArmies -lt 0) {$global:arrPlayerInfo.offsetArmies = 0}

    WND_SetOffsetButton

    Write-Host "Offset: " $global:arrPlayerInfo.offsetArmies
}

function centerOnPosition($iPosX, $iPosY)
{
    Write-Host "centerOnPosition($iPosX, $iPosY)"

    # <---- 20 ---->
    # ^
    # |
    # 17
    # |
    # v

    # x = x - 10, x < 0, x = 0
    # y = y - 8, y < 0, y = 0

    $global:arrCreateMapOptions["EDITOR_CHUNK_X"] = $iPosX - 10;
    $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] = $iPosY - 8;

    if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -lt 0)
    {
        $global:arrCreateMapOptions["EDITOR_CHUNK_X"] = 0
    }

    if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -lt 0)
    {
        $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] = 0
    }

    if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -gt ($global:arrCreateMapOptions["WIDTH"] - 16))
    {
        $global:arrCreateMapOptions["EDITOR_CHUNK_X"] = ($global:arrCreateMapOptions["WIDTH"] - 16)
    }

    if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -gt ($global:arrCreateMapOptions["HEIGHT"] - 13))
    {
        $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] = ($global:arrCreateMapOptions["HEIGHT"] - 13)
    }

    $objForm.Refresh();
}

function ARMY_FindNonSleepingUnit($owner)
{
    for($i = 0; $i -lt $global:arrMap["ARMY_INDEX"]; $i++)
    {
        if(!($global:arrArmies[$i])){continue}

        if($global:arrArmies[$i][2] -eq $owner -and $global:arrArmies[$i][6] -eq 0)
        {
            ARMY_SelectArmyByIndex $i $True
            return;
        }
    }
}

function ARMY_SelectArmyByIndex($index, $select)
{
    Write-Host "ARMY_SelectArmyByIndex($index, $select)"

    # center on army
    $posX = $global:arrArmies[$index][0]
    $posY = $global:arrArmies[$index][1]
    centerOnPosition $posX $posY

    if($select)
    {
        $global:arrCreateMapOptions["SELECTED_X"] = $posX + 2;
        $global:arrCreateMapOptions["SELECTED_Y"] = $posY + 2;
        
        openTileInfoIfNeeded $posX $posY
    }
}

function ARMY_SelectArmyByID($id, $owner)
{
    Write-Host "ARMY_SelectArmyByID($id, $owner)"

    $locArmyIndex = ARMY_GetArmyByID $id $owner

    if($locArmyIndex -eq -1) {return;}

    if($global:arrArmies[$locArmyIndex][6] -eq 1)
    {
        ARMY_SelectArmyByIndex $locArmyIndex $False
    }
    else
    {
        ARMY_SelectArmyByIndex $locArmyIndex $True
    }
}

function ARMY_SwitchArmySleepByIndex($id, $owner, $listID)
{
    Write-Host "ARMY_SwitchArmySleepByIndex($id, $owner, $listID)"

    $locArmyIndex = ARMY_GetArmyByID $id $owner

    if($locArmyIndex -eq -1) {return;}

    if($global:arrArmies[$locArmyIndex][6] -eq 1)
    {
        $global:arrArmies[$locArmyIndex][6] = 0
    }
    else
    {
        $global:arrArmies[$locArmyIndex][6] = 1
    }
    
    WND_SetOffsetButton
}

function ARMY_GetArmyByID($id, $owner)
{
    $ownerArmyIndex = 0

    for($i = 0; $i -lt $global:arrMap["ARMY_INDEX"]; $i++)
    {
        if(!($global:arrArmies[$i])){continue}

        if($global:arrArmies[$i][2] -eq $owner)
        {
            if($id -eq $ownerArmyIndex)
            {
                return $i
            }

            $ownerArmyIndex = $ownerArmyIndex + 1
        }
    }

    return -1
}

function ARMY_FillUnitList()
{
    Write-Host "ARMY_FillUnitList"

    $strWindow = "WND_SP_MENU_ARMY_N"

    for($i = 0; $i -lt 5; $i++)
    {
        $locArmyIndex = ARMY_GetArmyByID ($global:arrPlayerInfo.offsetArmies + $i) ($global:arrPlayerInfo.currentplayer)

        if($locArmyIndex -eq -1) 
        {
            BTN_SetHiddenState $strWindow ("BTN_SP_SLEEP" + $i) $True
            BTN_SetHiddenState $strWindow ("BTN_SP_SELECT_ARMY" + $i) $True
            BAR_setHiddenState $strWindow ("BAR_SP_HP" + $i) $True
            BAR_setHiddenState $strWindow ("BAR_SP_MP" + $i) $True
        }
        else
        {
            if($global:arrArmies[$locArmyIndex][6] -eq 1) {
                BTN_setActiveState $strWindow ("BTN_SP_SLEEP" + $i) $True
            } else {
                BTN_setActiveState $strWindow ("BTN_SP_SLEEP" + $i) $False
            }

            BTN_setText $strWindow ("BTN_SP_SELECT_ARMY" + $i) ($global:arrArmies[$locArmyIndex][3])

            $percentHP = ($global:arrArmies[$locArmyIndex][4] / ($global:arrArmies[$locArmyIndex][7] * $global:arrSettingsInternal["ARMY_DEFAULT_HP"]))
            BAR_setValue $strWindow ("BAR_SP_HP" + $i) $percentHP

            $percentMP = ($global:arrArmies[$locArmyIndex][5] / $global:arrSettingsInternal["ARMY_DEFAULT_MP"])
            BAR_setValue $strWindow ("BAR_SP_MP" + $i) $percentMP

            BTN_SetHiddenState $strWindow ("BTN_SP_SLEEP" + $i) $False
            BTN_SetHiddenState $strWindow ("BTN_SP_SELECT_ARMY" + $i) $False
            BAR_setHiddenState $strWindow ("BAR_SP_HP" + $i) $False
            BAR_setHiddenState $strWindow ("BAR_SP_MP" + $i) $False
        }
    }
}

function showWindow($strType, $data1)
{
    Write-Host "showWindow($strType)"

    # if a new window is shown (or the same again) disable any inputboxes
    $global:arrWindows.InputCurrent = ""

    switch($strType)
    {
        "WND_ESC_MAIN_N"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
        }
        "WND_SINGLEPLAYER_TYPESELECTION_N"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
        }
        "WND_GAME_OPTIONS_N"
        {
            buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType
        }
        "WND_CREATE_MAP_N"
        {
            buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType
            MAP_resetCreateOptions
        }
        "WND_INTERFACE_EDITOR_LAYER_01"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
        }
        "WND_INTERFACE_EDITOR_LAYER_02"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
        }
        "WND_INTERFACE_EDITOR_LAYER_03"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
        }
        "WND_INTERFACE_EDITOR_LAYER_PLAYER"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
        }
        "WND_ESC_EDITOR_N"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
        }
        "WND_EDITOR_WAIT_N"
        {
            buildWindow 160 56 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 56) / 2) $strType
        }
        "WND_TUTORIAL_N"
        {
            buildWindow 260 220 (($DrawingSizeX - 260) / 2) (($DrawingSizeY - 220) / 2) $strType
        }
        "WND_SINGLEPLAYER_SETUP_N"
        {
            buildWindow 440 220 (($DrawingSizeX - 440) / 2) (($DrawingSizeY - 220) / 2) $strType
            WND_setFOWButtonState "WND_SINGLEPLAYER_SETUP_N" "BTN_FOW_TOGGLE" $False
            $global:arrSettingsInternal["PLAYERTYPE_MAX"] = 3;
        }
        "WND_FP_ERRORS"
        {
            buildWindow 160 56 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 56) / 2) $strType
        }
        "WND_SP_NEXT_PLAYER_N"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
            GAME_SP_setNextPlayerInfo
        }
        "WND_SP_MENU_BUILDING_N"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType

            BTN_changeImage $strType "BTN_SP_BLD1" 0 ("HUM_HOUSE_SMALL_" + $global:arrPlayerInfo.currentplayer + "_0")
            BTN_changeImage $strType "BTN_SP_BLD2" 0 ("HUM_HOUSE_MEDIUM_" + $global:arrPlayerInfo.currentplayer + "_0")
            BTN_changeImage $strType "BTN_SP_BLD3" 0 ("HUM_HOUSE_LARGE_" + $global:arrPlayerInfo.currentplayer + "_0")
            BTN_changeImage $strType "BTN_SP_BLD4" 0 ("HUM_FARM_" + $global:arrPlayerInfo.currentplayer + "_0")
            BTN_changeImage $strType "BTN_SP_BLD5" 0 ("HUM_FIELD_" + $global:arrPlayerInfo.currentplayer + "_0")
            BTN_changeImage $strType "BTN_SP_BLD6" 0 ("HUM_MINE_" + $global:arrPlayerInfo.currentplayer + "_0")
            BTN_changeImage $strType "BTN_SP_BLD7" 0 ("HUM_SAWMILL_" + $global:arrPlayerInfo.currentplayer + "_0")
            BTN_changeImage $strType "BTN_SP_BLD8" 0 ("HUM_BARRACKS_" + $global:arrPlayerInfo.currentplayer + "_0")
            BTN_changeImage $strType "BTN_SP_BLD9" 0 ("HUM_TOWER_" + $global:arrPlayerInfo.currentplayer + "_0")
        }
        "WND_MENU_BUILDINGS"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
            WND_fillBuildingData
        }
        "WND_SP_MENU_ARMY_N"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
            changeArmyOffset 0
        }
        "WND_SP_MENU_WARES_N"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
            WND_SP_setWaresValues ($global:arrPlayerInfo.currentplayer)
        }
        "WND_TILEINFO_BUILDING_N"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
            GAME_SP_setBuildingTileinfo
        }
        "WND_TILEINFO_ARMY_N"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
            GAME_setArmyTileinfo
        }
        "WND_ESC_SINGLEPLAYER_N"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
        }
        "WND_WAIT_INIT_CLICK_N"
        {
            buildWindow 160 40 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 40) / 2) $strType
        }
        "WND_MULTIPLAYER_TYPESELECTION"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
        }
        "WND_MULTIPLAYER_SERVER"
        {
            buildWindow 440 220 (($DrawingSizeX - 440) / 2) (($DrawingSizeY - 220) / 2) $strType
        }
        "WND_MULTIPLAYER_CLIENT"
        {
            buildWindow 440 220 (($DrawingSizeX - 440) / 2) (($DrawingSizeY - 220) / 2) $strType
            WND_setFOWButtonState "WND_MULTIPLAYER_CLIENT" "BTN_FOW_TOGGLE" $global:EnableFoW
            CLIENT_openHostScreen
        }
        "WND_MP_ERRORS"
        {
            buildWindow 320 56 (($DrawingSizeX - 320) / 2) (($DrawingSizeY - 56) / 2) $strType
        }
        "WND_SERVER_ERRORS"
        {
            buildWindow 320 56 (($DrawingSizeX - 320) / 2) (($DrawingSizeY - 56) / 2) $strType
        }
        "WND_CLIENT_WAITING"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
        }
        "WND_CLIENT_WAITINGFOR"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
        }
        "WND_SERVER_WAITING"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
        }
        "WND_CREDITS_N"
        {
            buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType
        }
        "WND_CAMPAIGN_SELECT"
        {
            buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType
        }
        "WND_CAMPAIGN_SELECT_MAP"
        {
            buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType
            CMP_fillMapSelection
        }
        "WND_CAMPAIGN_SHOW_TEXT"
        {
            if(!$data1) {break;}

            $strWindow = $strType

            $lines = 14;
            $linelength = (360 - 24 - 4)
            $charsPerLine = [math]::Floor($linelength / 7)

            $arrTextLines = (WND_splitText $data1 $charsPerLine)

            $pageOffset = 0

            for($pn = 0; $pn -lt ([math]::Ceiling($arrTextLines.Count / $lines)); $pn++)
            {
                $isFirstPage = ($pageOffset -eq 0)
                $isLastPage = (($pageOffset * $lines) + $lines -ge $arrTextLines.Count)
                $pageNumber = ($pageOffset + 1)

                $wnd = $strWindow

                if($pn -ne 0)
                {
                    $wnd = $strWindow + $pn
                    buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $wnd
                }
                else
                {
                    buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strWindow
                }

                $prevName = ($strWindow + ($pn - 1))
                if($pn -eq 1) {$prevName = $strWindow}

                if(!(BTN_existsForWindow $wnd "BTN_PREV_PAGE"))
                {
                    WND_addNButtonToWindow $wnd "BTN_PREV_PAGE" "GRAY" 30 20 248 188 $False "" "CENTER" "GOLD" "FNK_SHOW_WINDOW" $prevName
                    BTN_addImage $wnd "BTN_PREV_PAGE" "ICON_ARROW_GOLD_LEFT" 7 2 1
                    WND_addNButtonToWindow $wnd "BTN_NEXT_PAGE" "GRAY" 30 20 318 188 $False "" "CENTER" "GOLD" "FNK_SHOW_WINDOW" ($strWindow + ($pn + 1))
                    BTN_addImage $wnd "BTN_NEXT_PAGE" "ICON_ARROW_GOLD_RIGHT" 7 2 1
                }

                if($isFirstPage)
                {
                    BTN_setDisabledState $wnd "BTN_PREV_PAGE" $True
                }

                if($isLastPage)
                {
                    BTN_setDisabledState $wnd "BTN_NEXT_PAGE" $True
                }

                if(!(LBL_existsForWindow $wnd "LBL_PAGE"))
                {
                    WND_AddNLabelToWindow $wnd "LBL_PAGE" "CLR_WINDOW_BACK" 40 20 278 188 ("" + $pageNumber + "/" + ([math]::Ceiling($arrTextLines.Count / $lines))) "CENTER" "GOLD"
                }
                else
                {
                    LBL_setText  $wnd "LBL_PAGE" ("" + $pageNumber + "/" + ([math]::Ceiling($arrTextLines.Count / $lines)))
                }

                for($j = 0; $j -lt $lines; $j++)
                {
                    $strTextLine = $arrTextLines[($pageOffset * $lines + $j)]
                    if(!$strTextLine -or $strTextLine -eq "") {$strTextLine = ""}

                    if(!(LBL_existsForWindow $wnd ("LBL_LINE_" + $j)))
                    {
                        WND_AddNLabelToWindow $wnd ("LBL_LINE_" + $j)  "CLR_WINDOW_BACK" 336 12 12 (12 + $j * 12) $strTextLine "LEFT" "GOLD"
                    }
                    else
                    {
                        LBL_setText  $wnd ("LBL_LINE_" + $j) $strTextLine
                    }
                }

                $pageOffset = $pageOffset + 1

                WND_addNButtonToWindow $wnd "BTN_CONTINUE" "GRAY" 136 20 12 188 $False "Continue" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_SP_NEXT_PLAYER_N"
            }
        }
        "WND_LOSE_GAME"
        {
            buildWindow 160 92 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 92) / 2) $strType
        }
        "WND_WIN_GAME"
        {
            buildWindow 160 92 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 92) / 2) $strType
        }
        "WND_ESC_MP_CLIENT"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
        }
        "WND_ESC_MP_SERVER"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
            SERVER_SetupEscapeKickButtons
        }
        "WND_ARMY_HELP"
        {
            buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType
            GAME_SP_setRecruit $False
        }
        default
        {
            Write-Host "Unknown window '$strType'"
        }
    }
    $global:arrWindows.WindowOpen = $True;
    $global:arrWindows.WindowCurrent = $strType;

    $pictureBox.Refresh();
}

function CMP_fillMapSelection()
{
    Write-Host "CMP_fillMapSelection()"

    $cmpID = $global:Campaigns.selected

    LBL_setText "WND_CAMPAIGN_SELECT_MAP" "LBL_TITLE" ($global:Campaigns.data[$cmpID]["TITLE"].Replace("_", " "))

    for($i = 0; $i -lt 12; $i++)
    {
        BTN_setActiveState "WND_CAMPAIGN_SELECT_MAP" ("BTN_SELECT_MAP" + $i) $False
        
        if($i -lt $global:Campaigns.data[$cmpID]["MAPS"].count)
        {
            BTN_SetHiddenState "WND_CAMPAIGN_SELECT_MAP" ("BTN_SELECT_MAP" + $i) $False
            $strName = $global:Campaigns.data[$cmpID]["MAPS"][$i]
            $strName = $strName.ToUpper().Replace(".SMF", "")
            $strName = $strName.Replace("_", " ")
            $strName = $strName.Substring(3)

            BTN_setText "WND_CAMPAIGN_SELECT_MAP" ("BTN_SELECT_MAP" + $i) $strName
        }
        else
        {
            BTN_SetHiddenState "WND_CAMPAIGN_SELECT_MAP" ("BTN_SELECT_MAP" + $i) $True
        }
    }
}

function CMP_loadCampaigns()
{
    Write-Host "CMP_loadCampaigns()"

    $strPath = ".\CAMPAIGN"
    $tmpCampaigns = Get-ChildItem $strPath

    $varType = $tmpCampaigns.GetType()

    if($varType -eq [System.IO.DirectoryInfo])
    {
        $strTmpName = ([string]($tmpCampaigns))
        $tmpCampaigns = @{}
        $tmpCampaigns[0] = $strTmpName
    }

    for($i = 0; $i -lt $tmpCampaigns.Count; $i++)
    {
        $cmp = ([string]($tmpCampaigns[$i]))

        $global:Campaigns.data[$i] = @{}
        $global:Campaigns.data[$i]["TITLE"] = $cmp

        CMP_loadMetaData $i $cmp
    }
}

function CMP_loadMetaData($ID, $strTitle)
{
    Write-Host "CMP_loadMetaData($ID, $strTitle)"

    $strFileName = ".\CAMPAIGN\" + $strTitle + "\DESCRIPTION.dat"

    if (Test-Path $strFileName) { $arrTextsTMP = Get-Content $strFileName }
    else { Write-Host "$strFileName is missing!"; return; }

    $global:Campaigns.data[$ID]["DESC"] = @{}

    for($i = 0; $i -lt $arrTextsTMP.Count; $i++)
    {
        $global:Campaigns.data[$ID]["DESC"][$i] = $arrTextsTMP[$i]
    }
}

function GAME_SP_setNextPlayerInfo()
{
    LBL_setBackColor "WND_SP_NEXT_PLAYER_N" "LBL_NEXT_PLAYER_COLOR" ("CLR_PLAYER_" + [string]($global:arrPlayerInfo.currentplayer) + "1")
    LBL_setText "WND_SP_NEXT_PLAYER_N" "LBL_NEXT_PLAYER_NAME" ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][0])
}

function GAME_setArmyTileinfo()
{
    Write-Host "GAME_setArmyTileinfo()"

    $localArmy = $global:arrPlayerInfo.selectedTile.armyID

    Write-Host "PlayerInfoArmy: " ($global:arrPlayerInfo.selectedTile.armyID)

    if($localArmy -eq -1 -or $localArmy -eq $Null) {Write-Host "GAME_setArmyTileinfo(): No Army!"; return;}

    $localPlr = $global:arrPlayerInfo.currentplayer

    $locX = $global:arrArmies[$localArmy][0]
    $locY = $global:arrArmies[$localArmy][1]

    $owner = $global:arrArmies[$localArmy][2]
    $leader = $global:arrArmies[$localArmy][3]

    $hp = $global:arrArmies[$localArmy][4]
    $movept = $global:arrArmies[$localArmy][5]
    $max_movept = $global:arrSettingsInternal["ARMY_DEFAULT_MP"]

    $sleeping = $global:arrArmies[$localArmy][6]

    $level = $global:arrArmies[$localArmy][7]

    $max_hp = $level * $global:arrSettingsInternal["ARMY_DEFAULT_HP"]

    $strWindow = "WND_TILEINFO_ARMY_N"

    LBL_setText $strWindow "LBL_TITLE" $leader

    if($global:arrPlayerInfo.selectedTile.buildingID -eq -1) {
        BTN_SetHiddenState $strWindow "BTN_TILEINFO_BUILDING" $True
    } else {
        BTN_SetHiddenState $strWindow "BTN_TILEINFO_BUILDING" $False
    }

    $percentHP = ($hp / $max_hp)
    BAR_SetTextValue $strWindow "BAR_HP" ("Health: " + $hp + "/" + $max_hp) $percentHP
    $percentMP = ($movept / $max_movept)
    BAR_SetTextValue $strWindow "BAR_MP" (" Range: " + $movept + "/" + $max_movept) $percentMP

    IMB_setImage $strWindow "IMB_ARMY" ("HUM_UNIT_" + $owner)

    LBL_setText $strWindow "LBL_LEVEL" ("Level   : " + $level)
    LBL_setText $strWindow "LBL_POSITION" ("Position: " + $locX + "|" + $locY)
    LBL_setText $strWindow "LBL_ID" ("Index   : " + $localArmy)

    if($localPlr -ne $owner -or ((MP_isMultiplayer) -and !(MP_isCurrentMPPlayer $owner))) {
        BTN_SetHiddenState $strWindow "BTN_TILEINFO_SLEEP" $True
    } else {
        BTN_SetHiddenState $strWindow "BTN_TILEINFO_SLEEP" $False

        # setup actions (and overlays)
        $posX = $global:arrPlayerInfo.selectedTile.x
        $posY = $global:arrPlayerInfo.selectedTile.y

        for($i = 0; $i -lt 4; $i++)
        {
            $locX = $posX + ($i % 2 * (2 - $i))
            $locY = $posY + (($i + 1) % 2 * (-1 + $i))

            $global:arrPlayerInfo.selectedTileArmyActions[$i] = ARMY_GetPossibleAction $posX $posY $i $locX $locY
            ARMY_SetOverlayForAction ($global:arrPlayerInfo.selectedTileArmyActions[$i]) $locX $locY
        }
    }

    if($sleeping -eq 1) {
        BTN_setActiveState $strWindow "BTN_TILEINFO_SLEEP" $True
    } else {
        BTN_setActiveState $strWindow "BTN_TILEINFO_SLEEP" $False
    }
}

function GAME_SP_setBuildingTileinfo()
{
    Write-Host "GAME_SP_setBuildingTileinfo()"

    $localBld   = $global:arrPlayerInfo.selectedTile.buildingID
    $owner      = $global:arrBuildings[$localBld][2]
    $type       = $global:arrBuildings[$localBld][3]
    $name       = $arrBuilding[$global:arrBuildingIDToKey[$type]].name

    $hp_max     = $arrBuilding[$global:arrBuildingIDToKey[$type]].hitpoints
    $hp_act     = $global:arrBuildings[$localBld][6]

    $state      = [int]($global:arrBuildings[$localBld][4])
    $percent    = [int]($global:arrBuildings[$localBld][5] * 100)

    LBL_setText "WND_TILEINFO_BUILDING_N" "LBL_TITLE" $name

    # health percent
    $percent_HP = ($hp_act / $hp_max)
    BAR_SetTextValue "WND_TILEINFO_BUILDING_N" "BAR_HP" (([string]($hp_act)) + "/" + ([string]($hp_max))) $percent_HP

    playSFX ("SND_" + $global:arrBuildingIDToKey[$type])

    if(($global:arrPlayerInfo.currentPlayer) -ne $owner -or ((MP_isMultiplayer) -and !(MP_isCurrentMPPlayer $owner))) {
        BTN_SetHiddenState "WND_TILEINFO_BUILDING_N" "BTN_SP_TILEINFO_DESTROY" $True
    } else {
        BTN_SetHiddenState "WND_TILEINFO_BUILDING_N" "BTN_SP_TILEINFO_DESTROY" $False }

    if($state -eq 0) {
        $strStateText = ([string]($percent)) + " %"
        BAR_SetTextValueColor "WND_TILEINFO_BUILDING_N" "BAR_PROGRESS" $strStateText ($global:arrBuildings[$localBld][5]) "CLR_BUILDING"
        BAR_setHiddenState "WND_TILEINFO_BUILDING_N" "BAR_PROGRESS" $False
    } else {
        BAR_setHiddenState "WND_TILEINFO_BUILDING_N" "BAR_PROGRESS" $True
    }

    IMB_setImage "WND_TILEINFO_BUILDING_N" "IMB_BUILDING" ($global:arrBuildingIDToKey[$type] + "_" + $owner + "_0")

    if($global:arrPlayerInfo.selectedTile.armyID -eq -1) {
        BTN_SetHiddenState "WND_TILEINFO_BUILDING_N" "BTN_SP_TILEINFO_ARMY" $True
    } else {
        BTN_SetHiddenState "WND_TILEINFO_BUILDING_N" "BTN_SP_TILEINFO_ARMY" $False
    }
}

function ARMY_UpdateMovepoints($iArmyID, $iAmount)
{
    $global:arrArmies[$iArmyID][5] = $global:arrArmies[$iArmyID][5] + $iAmount

    if($global:arrArmies[$iArmyID][5] -lt 0)
    {
        $global:arrArmies[$iArmyID][5] = 0
    }
    elseif($global:arrArmies[$iArmyID][5] -gt $global:arrSettingsInternal["ARMY_DEFAULT_MP"])
    {
        $global:arrArmies[$iArmyID][5] = $global:arrSettingsInternal["ARMY_DEFAULT_MP"]
    }

    # send army to bed
    if($global:arrArmies[$iArmyID][5] -eq 0)
    {
        $global:arrArmies[$iArmyID][6] = 1
    }
}

function INP_setText($strWindow, $strInputName, $strText)
{
    if(!(INP_existsForWindow $strWindow $strInputName)) {return;}

    $global:arrWindows[$strWindow].ninp[$strInputName].text = $strText

    INP_updateNInputGraphic $strWindow $strInputName
}

function INP_setActive($strWindow, $strInputName, $isActive)
{
    if(!(INP_existsForWindow $strWindow $strInputName)) {return;}

    $global:arrWindows[$strWindow].ninp[$strInputName].active = $isActive

    INP_updateNInputGraphic $strWindow $strInputName
}

function WND_addNInputToWindow($strWindow, $strInputName, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $strTextAlignment, $iMaxLength, $strLeaveFunction)
{
    #Write-Host "WND_addNInputToWindow($strWindow, $strInputName, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $strTextAlignment, $iMaxLength, $strLeaveFunction)"

    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "WND_addNInputToWindow: Window '$strWindow' does not exist!"
        return;
    }
    elseif(!$global:arrWindows[$strWindow].ninp)
    {
        Write-Host "WND_addNInputToWindow: Creating input control for window '$strWindow'!"
        $global:arrWindows[$strWindow].ninp = @{}
        $global:arrWindows[$strWindow].ninp[$strInputName] = @{}
    }
    elseif(!$global:arrWindows[$strWindow].ninp[$strInputName])
    {
        Write-Host "WND_addNInputToWindow: New input for window '$strWindow'!"
        $global:arrWindows[$strWindow].ninp[$strInputName] = @{}
    }
    else
    {
        Write-Host "WND_addNInputToWindow: Tried adding input '$strInputName' for window '$strWindow' twice!"
        Write-Host "WND_addNInputToWindow: Did you mean to update the input?"
        return;
    }

    $global:arrWindows[$strWindow].ninp[$strInputName].size_x = $iSizeX;
    $global:arrWindows[$strWindow].ninp[$strInputName].size_y = $iSizeY;
    $global:arrWindows[$strWindow].ninp[$strInputName].loc_x  = $iPosX;
    $global:arrWindows[$strWindow].ninp[$strInputName].loc_y  = $iPosY;
    $global:arrWindows[$strWindow].ninp[$strInputName].text   = ($strText.ToUpper());
    $global:arrWindows[$strWindow].ninp[$strInputName].align  = ($strTextAlignment.ToUpper());
    $global:arrWindows[$strWindow].ninp[$strInputName].length = [int]$iMaxLength;
    $global:arrWindows[$strWindow].ninp[$strInputName].active = $False;
    if($strLeaveFunction)
    {
        $global:arrWindows[$strWindow].ninp[$strInputName].function = $strLeaveFunction;
    }
    else
    {
        $global:arrWindows[$strWindow].ninp[$strInputName].function = "";
    }

    INP_updateNInputGraphic $strWindow $strInputName
}

function INP_updateNInputGraphic($strWindow, $strInputName)
{
    if(!(INP_existsForWindow $strWindow $strInputName)) {return;}

    # images to be drawn on window do not exist - create them
    if(!$global:arrWindows[$strWindow].ninp[$strInputName].bmp -or !$global:arrWindows[$strWindow].ninp[$strInputName].grp)
    {
        $tmp_rec    = New-Object System.Drawing.Rectangle(0, 0, ($global:arrWindows[$strWindow].ninp[$strInputName].size_x), ($global:arrWindows[$strWindow].ninp[$strInputName].size_y))

        $tmp_bmp    = $global:bitmap.Clone($tmp_rec, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

        $tmp_grp = [System.Drawing.Graphics]::FromImage($tmp_bmp);
        $tmp_grp.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor 
        $tmp_grp.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

        $global:arrWindows[$strWindow].ninp[$strInputName].bmp = $tmp_bmp
        $global:arrWindows[$strWindow].ninp[$strInputName].grp = $tmp_grp
    }

    $tmp_grp = $global:arrWindows[$strWindow].ninp[$strInputName].grp

    $iSizeX         = $global:arrWindows[$strWindow].ninp[$strInputName].size_x;
    $iSizeY         = $global:arrWindows[$strWindow].ninp[$strInputName].size_y;
    $strText        = $global:arrWindows[$strWindow].ninp[$strInputName].text;
    $strAlignment   = $global:arrWindows[$strWindow].ninp[$strInputName].align;
    $isActive       = $global:arrWindows[$strWindow].ninp[$strInputName].active;

    if($isActive)
    {
        $tmp_grp.FillRectangle($global:arrColors["CLR_GOLD_3"].brush, 0, 0, $iSizeX, $iSizeY)
        $tmp_grp.FillRectangle($global:arrColors["CLR_BLACK"].brush, 1, 1, ($iSizeX -2), ($iSizeY - 2))
    }
    else
    {
        $tmp_grp.FillRectangle($global:arrColors["CLR_BLACK"].brush, 0, 0, $iSizeX, $iSizeY)
    }

    # STEP: Create Text
    $iTextX = 2

    if($strAlignment -eq "CENTER")
    {
        $iTextX = [int](($iSizeX - 7 * $strText.Length) / 2)
    }
    elseif($strAlignment -eq "RIGHT")
    {
        $iTextX = [int]($iSizeX - 7 * $strText.Length)
    }

    $iTextY = [int](($iSizeY - 7) / 2)

    CTL_addNText $tmp_grp $strText $iTextX $iTextY "GOLD"

    # STEP: redraw Window
    WND_redrawNWindow $strWindow $strInputName
}

function INP_existsForWindow($strWindow, $strInputName)
{
    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "INP_existsForWindow: Window '$strWindow' does not exist!"
        return $False;
    }
    elseif(!$global:arrWindows[$strWindow].ninp)
    {
        Write-Host "INP_existsForWindow: Window '$strWindow' has no inputs!"
        return $False;
    }
    elseif(!$global:arrWindows[$strWindow].ninp[$strInputName])
    {
        Write-Host "INP_existsForWindow: Input '$strInputName' does not exist for window '$strWindow'!"
        return $False;
    }

    return $True;
}

function WND_AddNLabelToWindow($strWindow, $strLblName, $strLblColor, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $strTextAlignment, $strTextColor)
{
    #Write-Host "WND_AddNLabelToWindow($strWindow, $strLblName, $strLblColor, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $strTextAlignment, $strTextColor)"

    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "WND_AddNLabelToWindow: Window '$strWindow' does not exist!"
        return;
    }
    elseif(!$global:arrWindows[$strWindow].nlbl)
    {
        Write-Host "WND_AddNLabelToWindow: Creating label control for window '$strWindow'!"
        $global:arrWindows[$strWindow].nlbl = @{}
        $global:arrWindows[$strWindow].nlbl[$strLblName] = @{}
    }
    elseif(!$global:arrWindows[$strWindow].nlbl[$strLblName])
    {
        Write-Host "WND_AddNLabelToWindow: New label for window '$strWindow'!"
        $global:arrWindows[$strWindow].nlbl[$strLblName] = @{}
    }
    else
    {
        Write-Host "WND_AddNLabelToWindow: Tried adding label '$strLblName' for window '$strWindow' twice!"
        Write-Host "WND_AddNLabelToWindow: Did you mean to update the label? Use changeNButton_* functions!"
        return;
    }

    $global:arrWindows[$strWindow].nlbl[$strLblName].size_x   = $iSizeX;
    $global:arrWindows[$strWindow].nlbl[$strLblName].size_y   = $iSizeY;
    $global:arrWindows[$strWindow].nlbl[$strLblName].loc_x    = $iPosX;
    $global:arrWindows[$strWindow].nlbl[$strLblName].loc_y    = $iPosY;
    $global:arrWindows[$strWindow].nlbl[$strLblName].lblclr   = ($strLblColor.ToUpper());
    $global:arrWindows[$strWindow].nlbl[$strLblName].hidden   = $False;
    $global:arrWindows[$strWindow].nlbl[$strLblName].text     = ($strText.ToUpper());
    $global:arrWindows[$strWindow].nlbl[$strLblName].align    = ($strTextAlignment.ToUpper());
    $global:arrWindows[$strWindow].nlbl[$strLblName].txtclr   = ($strTextColor.ToUpper());

    LBL_updateNLabelGraphic $strWindow $strLblName
}

function LBL_updateNLabelGraphic($strWindow, $strLabelName)
{
    #Write-Host "LBL_updateNLabelGraphic($strWindow, $strLabelName)"

    if(!(LBL_existsForWindow $strWindow $strLabelName)) {return;}

    # images to be drawn on window do not exist - create them
    if(!$global:arrWindows[$strWindow].nlbl[$strLabelName].bmp -or !$global:arrWindows[$strWindow].nlbl[$strLabelName].grp)
    {
        $tmp_rec    = New-Object System.Drawing.Rectangle(0, 0, ($global:arrWindows[$strWindow].nlbl[$strLabelName].size_x), ($global:arrWindows[$strWindow].nlbl[$strLabelName].size_y))

        $tmp_bmp    = $global:bitmap.Clone($tmp_rec, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

        $tmp_grp = [System.Drawing.Graphics]::FromImage($tmp_bmp);
        $tmp_grp.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor 
        $tmp_grp.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

        $global:arrWindows[$strWindow].nlbl[$strLabelName].bmp = $tmp_bmp
        $global:arrWindows[$strWindow].nlbl[$strLabelName].grp = $tmp_grp
    }

    # update is called uppon changing something visual, redraw
    $iSizeX       = $global:arrWindows[$strWindow].nlbl[$strLabelName].size_x;
    $iSizeY       = $global:arrWindows[$strWindow].nlbl[$strLabelName].size_y;
    $strText      = [string]($global:arrWindows[$strWindow].nlbl[$strLabelName].text);
    $strTextClr   = $global:arrWindows[$strWindow].nlbl[$strLabelName].txtclr;
    $strLblColor  = $global:arrWindows[$strWindow].nlbl[$strLabelName].lblclr;
    $strAlignment = $global:arrWindows[$strWindow].nlbl[$strLabelName].align;
    $isDisabled   = $global:arrWindows[$strWindow].nlbl[$strLabelName].disabled;
    $isHidden     = $global:arrWindows[$strWindow].nlbl[$strLabelName].hidden;

    $tmp_grp = $global:arrWindows[$strWindow].nlbl[$strLabelName].grp

    if(!$isHidden)
    {
        # fill background
        $tmp_grp.FillRectangle($global:arrColors[$strLblColor].brush, 0, 0, $iSizeX, $iSizeY)

        # STEP: Create Text
        $iTextX = 4

        if($strAlignment -eq "CENTER")
        {
            $iTextX = [int](($iSizeX - 7 * $strText.Length) / 2)
        }
        elseif($strAlignment -eq "RIGHT")
        {
            $iTextX = [int]($iSizeX - 4 - 7 * $strText.Length)
        }

        $iTextY = [int](($iSizeY - 7) / 2)

        CTL_addNText $tmp_grp $strText $iTextX $iTextY $strTextClr

        # STEP: Overlay if disabled
        if($isDisabled)
        {
            $tmp_grp.FillRectangle($global:arrColors["CLR_BTN_DISABLED"].brush, 0, 0, $iSizeX, $iSizeY)
        }
    }
    else
    {
        $tmp_grp.FillRectangle($global:arrColors["CLR_WINDOW_BACK"].brush, 0, 0, $iSizeX, $iSizeY)
    }

    # STEP: Set graphics back to label
    $global:arrWindows[$strWindow].nlbl[$strLabelName].grp = $tmp_grp

    WND_redrawNWindow $strWindow $strLabelName
}

function LBL_existsForWindow($strWindow, $strLabelName)
{
    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "LBL_existsForWindow: Window '$strWindow' does not exist!"
        return $False;
    }
    elseif(!$global:arrWindows[$strWindow].nlbl)
    {
        Write-Host "LBL_existsForWindow: Window '$strWindow' has no labels!"
        return $False;
    }
    elseif(!$global:arrWindows[$strWindow].nlbl[$strLabelName])
    {
        Write-Host "LBL_existsForWindow: Label '$strLabelName' does not exist for window '$strWindow'!"
        return $False;
    }

    return $True;
}

function LBL_setBackColor($strWindow, $strLabelName, $strLblClr)
{
    #Write-Host "LBL_setBackColor($strWindow, $strLabelName, $strColor)"

    if(!(LBL_existsForWindow $strWindow $strLabelName)) {return;}

    if($global:arrWindows[$strWindow].nlbl[$strLabelName].lblclr -eq $strLblClr) {return;}

    $global:arrWindows[$strWindow].nlbl[$strLabelName].lblclr = $strLblClr;

    LBL_updateNLabelGraphic $strWindow $strLabelName
}

function LBL_setTextAndTextColor($strWindow, $strLabelName, $strText, $strColor)
{
    #Write-Host "LBL_setTextAndTextColor($strWindow, $strLabelName, $strText, $strColor)"

    if(!(LBL_existsForWindow $strWindow $strLabelName)) {return;}

    if($global:arrWindows[$strWindow].nlbl[$strLabelName].txtclr -eq $strColor -and $global:arrWindows[$strWindow].nlbl[$strLabelName].text -eq $strText) {return;}

    $global:arrWindows[$strWindow].nlbl[$strLabelName].text = $strText
    $global:arrWindows[$strWindow].nlbl[$strLabelName].txtclr = $strColor

    LBL_updateNLabelGraphic $strWindow $strLabelName
}

function LBL_setTextColor($strWindow, $strLabelName, $strColor)
{
    #Write-Host "LBL_setTextColor($strWindow, $strLabelName, $strColor)"

    if(!(LBL_existsForWindow $strWindow $strLabelName)) {return;}

    if($global:arrWindows[$strWindow].nlbl[$strLabelName].txtclr -eq $strColor) {return;}

    $global:arrWindows[$strWindow].nlbl[$strLabelName].txtclr = $strColor

    LBL_updateNLabelGraphic $strWindow $strLabelName
}

function LBL_setText($strWindow, $strLabelName, $strText)
{
    #Write-Host "LBL_setText($strWindow, $strLabelName, $strText)"

    if(!(LBL_existsForWindow $strWindow $strLabelName)) {return;}

    if($global:arrWindows[$strWindow].nlbl[$strLabelName].text -eq $strText) {return;}

    $global:arrWindows[$strWindow].nlbl[$strLabelName].text = $strText

    LBL_updateNLabelGraphic $strWindow $strLabelName
}

function WND_addNBarToWindow($strWindow, $strBarName, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $strTextAlignment, $strTextColor, $fPercent, $strBarColor)
{
    #Write-Host "WND_addNBarToWindow($strWindow, $strBarName, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $strTextAlignment, $strTextColor, $fPercent, $strBarColor)"

    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "addNButtonToWindow: Window '$strWindow' does not exist!"
        return;
    }
    elseif(!$global:arrWindows[$strWindow].nbar)
    {
        Write-Host "addNButtonToWindow: Creating bar control for window '$strWindow'!"
        $global:arrWindows[$strWindow].nbar = @{}
        $global:arrWindows[$strWindow].nbar[$strBarName] = @{}
    }
    elseif(!$global:arrWindows[$strWindow].nbar[$strBarName])
    {
        Write-Host "addNButtonToWindow: New bar for window '$strWindow'!"
        $global:arrWindows[$strWindow].nbar[$strBarName] = @{}
    }
    else
    {
        Write-Host "addNButtonToWindow: Tried adding bar '$strBtnName' for window '$strWindow' twice!"
        Write-Host "addNButtonToWindow: Did you mean to update the bar?"
        return;
    }

    $global:arrWindows[$strWindow].nbar[$strBarName].size_x   = $iSizeX;
    $global:arrWindows[$strWindow].nbar[$strBarName].size_y   = $iSizeY;
    $global:arrWindows[$strWindow].nbar[$strBarName].loc_x    = $iPosX;
    $global:arrWindows[$strWindow].nbar[$strBarName].loc_y    = $iPosY;
    $global:arrWindows[$strWindow].nbar[$strBarName].hidden   = $False;
    $global:arrWindows[$strWindow].nbar[$strBarName].text     = ($strText.ToUpper());
    $global:arrWindows[$strWindow].nbar[$strBarName].align    = ($strTextAlignment.ToUpper());
    $global:arrWindows[$strWindow].nbar[$strBarName].txtclr   = ($strTextColor.ToUpper());
    $global:arrWindows[$strWindow].nbar[$strBarName].value    = [float]$fPercent
    if(!$strBarColor) { $global:arrWindows[$strWindow].nbar[$strBarName].barclr = ""}
    else { $global:arrWindows[$strWindow].nbar[$strBarName].barclr = $strBarColor }

    # create bar graphic
    BAR_updateNBarGraphic $strWindow $strBarName
}

function BAR_existsForWindow($strWindow, $strBarName)
{
    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "BAR_existsForWindow: Window '$strWindow' does not exist!"
        return $False;
    }
    elseif(!$global:arrWindows[$strWindow].nbar)
    {
        Write-Host "BAR_existsForWindow: Window '$strWindow' has no bars!"
        return $False;
    }
    elseif(!$global:arrWindows[$strWindow].nbar[$strBarName])
    {
        Write-Host "BAR_existsForWindow: Bar '$strBarName' does not exist for window '$strWindow'!"
        return $False;
    }

    return $True;
}

function BAR_updateNBarGraphic($strWindow, $strBarName)
{
    #Write-Host "BAR_updateNBarGraphic($strWindow, $strBarName)"

    if(!(BAR_existsForWindow $strWindow $strBarName)) {return;}

    # images to be drawn on window do not exist - create them
    if(!$global:arrWindows[$strWindow].nbar[$strBarName].bmp -or !$global:arrWindows[$strWindow].nbar[$strBarName].grp)
    {
        $tmp_rec    = New-Object System.Drawing.Rectangle(0, 0, ($global:arrWindows[$strWindow].nbar[$strBarName].size_x), ($global:arrWindows[$strWindow].nbar[$strBarName].size_y))

        $tmp_bmp    = $global:bitmap.Clone($tmp_rec, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

        $tmp_grp = [System.Drawing.Graphics]::FromImage($tmp_bmp);
        $tmp_grp.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor 
        $tmp_grp.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

        $global:arrWindows[$strWindow].nbar[$strBarName].bmp = $tmp_bmp
        $global:arrWindows[$strWindow].nbar[$strBarName].grp = $tmp_grp
    }

    # update is called uppon changing something visual, redraw
    $iSizeX         = $global:arrWindows[$strWindow].nbar[$strBarName].size_x;
    $iSizeY         = $global:arrWindows[$strWindow].nbar[$strBarName].size_y;
    $iPosX          = $global:arrWindows[$strWindow].nbar[$strBarName].loc_x;
    $iPosY          = $global:arrWindows[$strWindow].nbar[$strBarName].loc_y;
    $isHidden       = $global:arrWindows[$strWindow].nbar[$strBarName].hidden;
    $strText        = $global:arrWindows[$strWindow].nbar[$strBarName].text;
    $strAlignment   = $global:arrWindows[$strWindow].nbar[$strBarName].align;
    $strTextClr     = $global:arrWindows[$strWindow].nbar[$strBarName].txtclr;
    $fPercent       = $global:arrWindows[$strWindow].nbar[$strBarName].value;
    $strBarClr      = $global:arrWindows[$strWindow].nbar[$strBarName].barclr;

    $tmp_grp = $global:arrWindows[$strWindow].nbar[$strBarName].grp

    if(!$isHidden)
    {
        # fill background
        $tmp_grp.FillRectangle($global:arrColors["CLR_BTN_GRAY2"].brush, 2, 2, ($iSizeX - 4), ($iSizeY - 4))

        # set colors depending on state
        $clr1 = $global:arrColors["CLR_BLACK"]

        $clr2 = $global:arrColors["CLR_BTN_GRAY1"]

        # upper side
        $tmp_grp.FillRectangle($clr1.brush, 0, 0, $iSizeX, 2)

        # left side
        $tmp_grp.FillRectangle($clr1.brush, 0, 0, 2, $iSizeY)

        # lower side
        $tmp_grp.FillRectangle($clr2.brush, 2, ($iSizeY - 2), ($iSizeX - 2), 2)

        # right side
        $tmp_grp.FillRectangle($clr2.brush, ($iSizeX - 2), 2, 2, ($iSizeY - 4))

        # special lower left
        $tmp_grp.FillRectangle($clr2.brush, 1,($iSizeY - 1), 1, 1)

        # special top right
        $tmp_grp.FillRectangle($clr2.brush, ($iSizeX - 1),1, 1, 1)

        # STEP: Create Bar
        if($strBarClr -eq "")
        {
            $strBarClr = getColorNameForPercent $fPercent
        }

        $lengthBar = [math]::floor($fPercent * ($iSizeX - 6))
    
        # Make sure, that at least one pixel is colored
        if($lengthBar -eq 0)
        {
            $lengthBar = 1;
        }

        $tmp_grp.FillRectangle($global:arrColors[$strBarClr].brush, 3, 3, $lengthBar, ($iSizeY - 6))

        # STEP: Create Text
        $iTextX = 4

        if($strAlignment -eq "CENTER")
        {
            $iTextX = [int](($iSizeX - 7 * $strText.Length) / 2)
        }
        elseif($strAlignment -eq "RIGHT")
        {
            $iTextX = [int]($iSizeX - 4 - 7 * $strText.Length)
        }

        $iTextY = [int](($iSizeY - 7) / 2)

        if($isPressed -or $isActive)
        {
            $iTextX = $iTextX + 1
            $iTextY = $iTextY + 1
        }

        CTL_addNText $tmp_grp $strText $iTextX $iTextY $strTextClr

        # STEP: Overlay if disabled
        if($isDisabled)
        {
            $tmp_grp.FillRectangle($global:arrColors["CLR_BTN_DISABLED"].brush, 0, 0, $iSizeX, $iSizeY)
        }
    }
    else
    {
        $tmp_grp.FillRectangle($global:arrColors["CLR_WINDOW_BACK"].brush, 0, 0, $iSizeX, $iSizeY)
    }

    # STEP: Set graphics back to button
    $global:arrWindows[$strWindow].nbar[$strBarName].grp = $tmp_grp

    WND_redrawNWindow $strWindow $strBarName
}

function IMB_setHidden($strWindow, $strImageBoxName, $isHidden)
{
    #Write-Host "IMB_setHidden($strWindow, $strImageBoxName, $isHidden)"

    if(!(IMB_existsForWindow $strWindow $strImageBoxName)) {return;}

    if($global:arrWindows[$strWindow].nimb[$strImageBoxName].hidden -eq $isHidden) {return;}

    $global:arrWindows[$strWindow].nimb[$strImageBoxName].hidden = $isHidden

    IMB_updateNImageBoxGraphic $strWindow $strImageBoxName
}

function IMB_setImage($strWindow, $strImageBoxName, $strImageName)
{
    #Write-Host "IMB_setImage($strWindow, $strImageBoxName, $strImageName)"

    if(!(IMB_existsForWindow $strWindow $strImageBoxName)) {return;}

    if($global:arrWindows[$strWindow].nimb[$strImageBoxName].imagename -eq $strImageName) {return;}

    $global:arrWindows[$strWindow].nimb[$strImageBoxName].imagename = $strImageName

    IMB_updateNImageBoxGraphic $strWindow $strImageBoxName
}

function IMB_existsForWindow($strWindow, $strImageBoxName)
{
    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "IMB_existsForWindow: Window '$strWindow' does not exist!"
        return $False;
    }
    elseif(!$global:arrWindows[$strWindow].nimb)
    {
        Write-Host "IMB_existsForWindow: Window '$strWindow' has no bars!"
        return $False;
    }
    elseif(!$global:arrWindows[$strWindow].nimb[$strImageBoxName])
    {
        Write-Host "IMB_existsForWindow: ImageBox '$strImageBoxName' does not exist for window '$strWindow'!"
        return $False;
    }

    return $True;
}

function IMB_updateNImageBoxGraphic($strWindow, $strImageBoxName)
{
    #Write-Host "IMB_updateNImageBoxGraphic($strWindow, $strImageBoxName)"

    if(!(IMB_existsForWindow $strWindow $strImageBoxName)) {return;}

    # images to be drawn on window do not exist - create them
    if(!$global:arrWindows[$strWindow].nimb[$strImageBoxName].bmp -or !$global:arrWindows[$strWindow].nimb[$strImageBoxName].grp)
    {
        $tmp_rec    = New-Object System.Drawing.Rectangle(0, 0, ($global:arrWindows[$strWindow].nimb[$strImageBoxName].size_x), ($global:arrWindows[$strWindow].nimb[$strImageBoxName].size_y))

        $tmp_bmp    = $global:bitmap.Clone($tmp_rec, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

        $tmp_grp = [System.Drawing.Graphics]::FromImage($tmp_bmp);
        $tmp_grp.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor 
        $tmp_grp.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

        $global:arrWindows[$strWindow].nimb[$strImageBoxName].bmp = $tmp_bmp
        $global:arrWindows[$strWindow].nimb[$strImageBoxName].grp = $tmp_grp
    }

    $iSizeX         = $global:arrWindows[$strWindow].nimb[$strImageBoxName].size_x;
    $iSizeY         = $global:arrWindows[$strWindow].nimb[$strImageBoxName].size_y;
    $iPosX          = $global:arrWindows[$strWindow].nimb[$strImageBoxName].loc_x;
    $iPosY          = $global:arrWindows[$strWindow].nimb[$strImageBoxName].loc_y;
    $strImageName   = $global:arrWindows[$strWindow].nimb[$strImageBoxName].imagename;
    $iOffsetX       = $global:arrWindows[$strWindow].nimb[$strImageBoxName].off_x;
    $iOffsetY       = $global:arrWindows[$strWindow].nimb[$strImageBoxName].off_y;
    $iScale         = $global:arrWindows[$strWindow].nimb[$strImageBoxName].scale;
    $isHidden      =  $global:arrWindows[$strWindow].nimb[$strImageBoxName].hidden;

    $tmp_grp = $global:arrWindows[$strWindow].nimb[$strImageBoxName].grp

    if(!$isHidden)
    {
        if($global:arrIcons[$strImageName])
        {
            $objImage = $global:arrIcons[$strImageName].bitmap;

            $iSizeImgX = $objImage.Width;
            $iSizeImgY = $objImage.Height;

            $rect_src = New-Object System.Drawing.Rectangle(0, 0, $iSizeImgX, $iSizeImgY);
            $rect_dst = New-Object System.Drawing.Rectangle($iOffsetX, $iOffsetY, ($iSizeImgX * $iScale), ($iSizeImgY * $iScale));
            $objImage.MakeTransparent($global:arrColors["CLR_MAGENTA"].color);

            $tmp_grp.FillRectangle($global:arrColors["CLR_WINDOW_BACK"].brush, 0, 0, $iSizeX, $iSizeY)
            $tmp_grp.DrawImage($objImage, $rect_dst, $rect_src, [System.Drawing.GraphicsUnit]::Pixel);
        }
        else
        {
            Write-Host "IMB_updateNImageBoxGraphic: Image '$strImageName' does not exist!"
        }
    }
    else
    {
        $tmp_grp.FillRectangle($global:arrColors["CLR_WINDOW_BACK"].brush, 0, 0, $iSizeX, $iSizeY)
    }

    $global:arrWindows[$strWindow].nimb[$strImageBoxName].grp = $tmp_grp

    WND_redrawNWindow $strWindow $strImageBoxName
}

function WND_addNImageBoxToWindow($strWindow, $strImageBoxName, $iSizeX, $iSizeY, $iPosX, $iPosY, $strImageName, $iOffsetX, $iOffsetY, $iScale)
{
    #Write-Host "WND_addNImageBoxToWindow($strWindow, $strImageBoxName, $iSizeX, $iSizeY, $iPosX, $iPosY, $strImageName, $iScale)"

    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "addNButtonToWindow: Window '$strWindow' does not exist!"
        return;
    }
    elseif(!$global:arrWindows[$strWindow].nimb)
    {
        Write-Host "addNButtonToWindow: Creating imagebox control for window '$strWindow'!"
        $global:arrWindows[$strWindow].nimb = @{}
        $global:arrWindows[$strWindow].nimb[$strImageBoxName] = @{}
    }
    elseif(!$global:arrWindows[$strWindow].nimb[$strImageBoxName])
    {
        Write-Host "addNButtonToWindow: New imagebox for window '$strWindow'!"
        $global:arrWindows[$strWindow].nimb[$strImageBoxName] = @{}
    }
    else
    {
        Write-Host "addNButtonToWindow: Tried adding imagebox '$strImageBoxName' for window '$strWindow' twice!"
        Write-Host "addNButtonToWindow: Did you mean to update the imagebox?"
        return;
    }

    $global:arrWindows[$strWindow].nimb[$strImageBoxName].size_x    = $iSizeX;
    $global:arrWindows[$strWindow].nimb[$strImageBoxName].size_y    = $iSizeY;
    $global:arrWindows[$strWindow].nimb[$strImageBoxName].loc_x     = $iPosX;
    $global:arrWindows[$strWindow].nimb[$strImageBoxName].loc_y     = $iPosY;
    $global:arrWindows[$strWindow].nimb[$strImageBoxName].imagename = $strImageName;
    $global:arrWindows[$strWindow].nimb[$strImageBoxName].off_x     = $iOffsetX;
    $global:arrWindows[$strWindow].nimb[$strImageBoxName].off_y     = $iOffsetY;
    $global:arrWindows[$strWindow].nimb[$strImageBoxName].scale     = [int]$iScale;
    $global:arrWindows[$strWindow].nimb[$strImageBoxName].hidden    = $False;

    IMB_updateNImageBoxGraphic $strWindow $strImageBoxName
}

function WND_addNButtonToWindow($strWindow, $strBtnName, $strBtnColor, $iSizeX, $iSizeY, $iPosX, $iPosY, $isActive, $strText, $strTextAlignment, $strTextColor, $strFnkName, $strFnkParam)
{
    #Write-Host "addNButtonToWindow($strWindow, $strBtnName, $strBtnColor, $iSizeX, $iSizeY, $iPosX, $iPosY, $isActive, $strText, $strTextAlignment, $strTextColor, $strFnkName, $strFnkParam)"

    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "addNButtonToWindow: Window '$strWindow' does not exist!"
        return;
    }
    elseif(!$global:arrWindows[$strWindow].nbtn)
    {
        Write-Host "addNButtonToWindow: Creating button control for window '$strWindow'!"
        $global:arrWindows[$strWindow].nbtn = @{}
        $global:arrWindows[$strWindow].nbtn[$strBtnName] = @{}
    }
    elseif(!$global:arrWindows[$strWindow].nbtn[$strBtnName])
    {
        Write-Host "addNButtonToWindow: New button for window '$strWindow'!"
        $global:arrWindows[$strWindow].nbtn[$strBtnName] = @{}
    }
    else
    {
        Write-Host "addNButtonToWindow: Tried adding button '$strBtnName' for window '$strWindow' twice!"
        Write-Host "addNButtonToWindow: Did you mean to update the button? Use changeNButton_* functions!"
        return;
    }

    # setup button definition
    $global:arrWindows[$strWindow].nbtn[$strBtnName].size_x   = $iSizeX;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].size_y   = $iSizeY;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].loc_x    = $iPosX;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].loc_y    = $iPosY;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr   = ($strBtnColor.ToUpper());
    $global:arrWindows[$strWindow].nbtn[$strBtnName].hidden   = $False;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].active   = $isActive;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].pressed  = $False;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].disabled = $False;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].text     = ($strText.ToUpper());
    $global:arrWindows[$strWindow].nbtn[$strBtnName].align    = ($strTextAlignment.ToUpper());
    $global:arrWindows[$strWindow].nbtn[$strBtnName].txtclr   = ($strTextColor.ToUpper());
    if($strFnkName)
    {
        $global:arrWindows[$strWindow].nbtn[$strBtnName].function = $strFnkName;
    }
    else
    {
        $global:arrWindows[$strWindow].nbtn[$strBtnName].function = "";
    }
    if($strFnkParam -or $strFnkParam -eq 0)
    {
        $global:arrWindows[$strWindow].nbtn[$strBtnName].parameter = $strFnkParam;
    }
    else
    {
        $global:arrWindows[$strWindow].nbtn[$strBtnName].parameter = "";
    }
    # some buttons have multiple images
    $global:arrWindows[$strWindow].nbtn[$strBtnName].images  = @{};

    # create button graphic
    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BTN_changeImage($strWindow, $strBtnName, $iID, $strNewGraphicName)
{
    #Write-Host "BTN_changeImage($strWindow, $strBtnName, $iID, $strNewGraphicName)"

    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    if($iID -ge $global:arrWindows[$strWindow].nbtn[$strBtnName].images.Count) {return;}

    $strImgID = [string]($iID)

    if($global:arrWindows[$strWindow].nbtn[$strBtnName].images[$strImgID].graphic -eq $strNewGraphicName) {return;}

    $global:arrWindows[$strWindow].nbtn[$strBtnName].images[$strImgID].graphic = $strNewGraphicName;

    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BTN_addImage($strWindow, $strBtnName, $strGraphicName, $iPosX, $iPosY, $iScale)
{
    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    $strImgID = [string]($global:arrWindows[$strWindow].nbtn[$strBtnName].images.Count)

    $global:arrWindows[$strWindow].nbtn[$strBtnName].images[$strImgID] = @{}
    $global:arrWindows[$strWindow].nbtn[$strBtnName].images[$strImgID].loc_x    = $iPosX;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].images[$strImgID].loc_y    = $iPosY;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].images[$strImgID].scale    = $iScale;
    $global:arrWindows[$strWindow].nbtn[$strBtnName].images[$strImgID].graphic  = $strGraphicName;

    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BTN_updateNButtonGraphic($strWindow, $strBtnName)
{
    #Write-Host "BTN_updateNButtonGraphic($strWindow, $strBtnName)"

    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    # images to be drawn on window do not exist - create them
    if(!$global:arrWindows[$strWindow].nbtn[$strBtnName].bmp -or !$global:arrWindows[$strWindow].nbtn[$strBtnName].grp)
    {
        $tmp_rec    = New-Object System.Drawing.Rectangle(0, 0, ($global:arrWindows[$strWindow].nbtn[$strBtnName].size_x), ($global:arrWindows[$strWindow].nbtn[$strBtnName].size_y))

        $tmp_bmp    = $global:bitmap.Clone($tmp_rec, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

        $tmp_grp = [System.Drawing.Graphics]::FromImage($tmp_bmp);
        $tmp_grp.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor 
        $tmp_grp.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

        $global:arrWindows[$strWindow].nbtn[$strBtnName].bmp = $tmp_bmp
        $global:arrWindows[$strWindow].nbtn[$strBtnName].grp = $tmp_grp
    }

    # update is called uppon changing something visual, redraw
    $iSizeX       = $global:arrWindows[$strWindow].nbtn[$strBtnName].size_x;
    $iSizeY       = $global:arrWindows[$strWindow].nbtn[$strBtnName].size_y;
    $strText      = $global:arrWindows[$strWindow].nbtn[$strBtnName].text;
    $strTextClr   = $global:arrWindows[$strWindow].nbtn[$strBtnName].txtclr;
    $strBtnColor  = $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr;
    $strAlignment = $global:arrWindows[$strWindow].nbtn[$strBtnName].align;
    $isPressed    = $global:arrWindows[$strWindow].nbtn[$strBtnName].pressed;
    $isActive     = $global:arrWindows[$strWindow].nbtn[$strBtnName].active;
    $isDisabled   = $global:arrWindows[$strWindow].nbtn[$strBtnName].disabled;
    $isHidden     = $global:arrWindows[$strWindow].nbtn[$strBtnName].hidden;

    $tmp_grp = $global:arrWindows[$strWindow].nbtn[$strBtnName].grp

    if(!$isHidden)
    {
        # fill background
        $tmp_grp.FillRectangle($global:arrColors[("CLR_BTN_" + $strBtnColor + "2")].brush, 2, 2, ($iSizeX - 4), ($iSizeY - 4))

        # set colors depending on state
        $clr1 = $global:arrColors[("CLR_BTN_" + $strBtnColor + "1")]
        if($isActive -or $isPressed) { $clr1 = $global:arrColors["CLR_BLACK"] }

        $clr2 = $global:arrColors["CLR_BLACK"]
        if($isActive -or $isPressed) { $clr2 = $global:arrColors[("CLR_BTN_" + $strBtnColor + "1")]}

        # upper side
        $tmp_grp.FillRectangle($clr1.brush, 0, 0, $iSizeX, 2)

        # left side
        $tmp_grp.FillRectangle($clr1.brush, 0, 0, 2, $iSizeY)

        # lower side
        $tmp_grp.FillRectangle($clr2.brush, 2, ($iSizeY - 2), ($iSizeX - 2), 2)

        # right side
        $tmp_grp.FillRectangle($clr2.brush, ($iSizeX - 2), 2, 2, ($iSizeY - 4))

        # special lower left
        $tmp_grp.FillRectangle($clr2.brush, 1,($iSizeY - 1), 1, 1)

        # special top right
        $tmp_grp.FillRectangle($clr2.brush, ($iSizeX - 1),1, 1, 1)

        # STEP: Button images
        $keys    = $global:arrWindows[$strWindow].nbtn[$strBtnName].images.Keys;
        foreach($key in $keys)
        {
            # key = graphic id, .graphic = graphic name
            $iPosX      = $global:arrWindows[$strWindow].nbtn[$strBtnName].images[$key].loc_x;
            $iPosY      = $global:arrWindows[$strWindow].nbtn[$strBtnName].images[$key].loc_y;
            $iScale     = $global:arrWindows[$strWindow].nbtn[$strBtnName].images[$key].scale;
            $strGraphic = $global:arrWindows[$strWindow].nbtn[$strBtnName].images[$key].graphic;

            if($isPressed -or $isActive)
            {
                $iPosX = $iPosX + 1
                $iPosY = $iPosY + 1
            }

            $objImage = $global:arrIcons[$strGraphic].bitmap;

            $iSizeImgX = $objImage.Width;
            $iSizeImgY = $objImage.Height;

            $rect_src = New-Object System.Drawing.Rectangle(0, 0, $iSizeImgX, $iSizeImgY);
            $rect_dst = New-Object System.Drawing.Rectangle($iPosX, $iPosy, ($iSizeImgX * $iScale), ($iSizeImgY * $iScale));
            $objImage.MakeTransparent($global:arrColors["CLR_MAGENTA"].color);

            $tmp_grp.DrawImage($objImage, $rect_dst, $rect_src, [System.Drawing.GraphicsUnit]::Pixel);
        }

        # STEP: Create Text
        $iTextX = 4

        if($strAlignment -eq "CENTER")
        {
            $iTextX = [int](($iSizeX - 7 * $strText.Length) / 2)
        }
        elseif($strAlignment -eq "RIGHT")
        {
            $iTextX = [int]($iSizeX - 4 - 7 * $strText.Length)
        }

        $iTextY = [int](($iSizeY - 7) / 2)

        if($isPressed -or $isActive)
        {
            $iTextX = $iTextX + 1
            $iTextY = $iTextY + 1
        }

        CTL_addNText $tmp_grp $strText $iTextX $iTextY $strTextClr

        # STEP: Overlay if disabled
        if($isDisabled)
        {
            $tmp_grp.FillRectangle($global:arrColors["CLR_BTN_DISABLED"].brush, 0, 0, $iSizeX, $iSizeY)
        }
    }
    else
    {
        $tmp_grp.FillRectangle($global:arrColors["CLR_WINDOW_BACK"].brush, 0, 0, $iSizeX, $iSizeY)
    }

    # STEP: Set graphics back to button
    $global:arrWindows[$strWindow].nbtn[$strBtnName].grp = $tmp_grp

    WND_redrawNWindow $strWindow $strBtnName
}

function BTN_existsForWindow($strWindow, $strBtnName)
{
    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "BTN_existsForWindow: Window '$strWindow' does not exist!"
        return $False;
    }
    elseif(!$global:arrWindows[$strWindow].nbtn)
    {
        Write-Host "BTN_existsForWindow: Window '$strWindow' has no buttons!"
        return $False;
    }
    elseif(!$global:arrWindows[$strWindow].nbtn[$strBtnName])
    {
        Write-Host "BTN_existsForWindow: Button '$strBtnName' does not exist for window '$strWindow'!"
        return $False;
    }

    return $True;
}

function BTN_SetHiddenState($strWindow, $strBtnName, $hidden)
{
    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    if($global:arrWindows[$strWindow].nbtn[$strBtnName].hidden -eq $hidden) {return;}

    $global:arrWindows[$strWindow].nbtn[$strBtnName].hidden = $hidden
    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BTN_setDisabledState($strWindow, $strBtnName, $disabled)
{
    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    if($global:arrWindows[$strWindow].nbtn[$strBtnName].disabled -eq $disabled) {return;}

    $global:arrWindows[$strWindow].nbtn[$strBtnName].disabled = $disabled
    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BTN_setPressedState($strWindow, $strBtnName, $state)
{
    #Write-Host "BTN_setPressedState($strWindow, $strBtnName, $state)"

    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    if($global:arrWindows[$strWindow].nbtn[$strBtnName].pressed -eq $state) {return;}

    $global:arrWindows[$strWindow].nbtn[$strBtnName].pressed = $state
    BTN_updateNButtonGraphic $strWindow $strBtnName
}


function BTN_setActiveState($strWindow, $strBtnName, $state)
{
    #Write-Host "BTN_setActiveState($strWindow, $strBtnName, $state)"

    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    if($global:arrWindows[$strWindow].nbtn[$strBtnName].active -eq $state) {return;}

    $global:arrWindows[$strWindow].nbtn[$strBtnName].active = $state
    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BTN_setActiveStateAndText($strWindow, $strBtnName, $state, $strText)
{
    #Write-Host "BTN_setActiveStateAndText($strWindow, $strBtnName, $state, $strText)"

    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    if($global:arrWindows[$strWindow].nbtn[$strBtnName].active -eq $state -and $global:arrWindows[$strWindow].nbtn[$strBtnName].text -eq $strText) {return;}

    $global:arrWindows[$strWindow].nbtn[$strBtnName].active = $state
    $global:arrWindows[$strWindow].nbtn[$strBtnName].text = $strText
    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BTN_setActiveStateAndColor($strWindow, $strBtnName, $state, $strColor)
{
    #Write-Host "BTN_setActiveStateAndColor($strWindow, $strBtnName, $state, $strColor)"

    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    if($global:arrWindows[$strWindow].nbtn[$strBtnName].active -eq $state -and $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr -eq $strColor) {return;}

    $global:arrWindows[$strWindow].nbtn[$strBtnName].active = $state
    $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr = $strColor
    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BTN_setTextAndColor($strWindow, $strBtnName, $strText, $strColor)
{
    #Write-Host "BTN_setTextAndColor($strWindow, $strBtnName, $strText, $strColor)"

    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    if($global:arrWindows[$strWindow].nbtn[$strBtnName].text -eq $strText -and $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr -eq $strColor) {return;}

    $global:arrWindows[$strWindow].nbtn[$strBtnName].text = $strText
    $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr = $strColor
    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BTN_setColor($strWindow, $strBtnName, $strColor)
{
    #Write-Host "BTN_setColor($strWindow, $strBtnName, $strColor)"

    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    if($global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr -eq $strColor) {return;}

    $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr = $strColor
    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BTN_setText($strWindow, $strBtnName, $strText)
{
    #Write-Host "BTN_setText($strWindow, $strBtnName, $strText)"

    if(!(BTN_existsForWindow $strWindow $strBtnName)) {return;}

    if($global:arrWindows[$strWindow].nbtn[$strBtnName].text -eq $strText) {return;}

    $global:arrWindows[$strWindow].nbtn[$strBtnName].text = $strText

    BTN_updateNButtonGraphic $strWindow $strBtnName
}


function CTL_addNText($objGraphics, $strText, $iPosX, $iPosY, $strColor)
{
    #Write-Host "CTL_addNText($objGraphics, $strText, $iPosX, $iPosY, $strColor)"

    $strText = ([string]$strText)

    if ($strText -eq "")
    {
        return;
    }

    $strText = $strText.ToUpper();

    $fntWidth = $arrFont["?"].Width
    $fntHeight = $arrFont["?"].Height

    $sizeX      = $strText.Length * $fntWidth;

    # monospace font, no need to recreate this rect all the time
    $rect_src = New-Object System.Drawing.Rectangle(0, 0, $fntWidth, $fntHeight)

    for($i = 0; $i -lt ($strText.Length); $i++)
    {
        $tempChar = $strText.Substring($i, 1);

        # char not in array? use '?'
        if(!$arrFont[$tempChar])
        {
            $tempChar = "?"
        }

        $rect_dst = New-Object System.Drawing.Rectangle(($iPosX + ($i * $fntWidth)), $iPosy, $fntWidth, $fntHeight)

        setCharColor $tempChar $strColor

        $objGraphics.DrawImage($arrFont[$tempChar], $rect_dst, $rect_src, [System.Drawing.GraphicsUnit]::Pixel);
    }
}

function WND_redrawNWindow($strWindow, $strControl)
{
    #Write-Host "WND_redrawNWindow($strWindow, $strControl)"

    if($global:arrWindows.isInitializing) {return;}

    if(!$global:arrWindows[$strWindow])
    {
        Write-Host "WND_redrawNWindow: There is no window named '$strWindow'"
        return;
    }

    $tmp_grd    = $global:arrWindows[$strWindow].graphics;
    $iSizeX     = $global:arrWindows[$strWindow].sizeX;
    $iSizeY     = $global:arrWindows[$strWindow].sizeY;

    if($strControl -eq "")
    {
        #outline
        $brush = $global:arrColors["CLR_BLACK"].brush
        $tmp_grd.FillRectangle($brush, 0, 0, $iSizeX, $iSizeY)

        $brush = $global:arrColors["CLR_WINDOW_GREEN1"].brush
        $tmp_grd.FillRectangle($brush, 1, 1, ($iSizeX - 2), ($iSizeY - 2))

        $brush = $global:arrColors["CLR_WINDOW_GREEN2"].brush
        $tmp_grd.FillRectangle($brush, 3, 3, ($iSizeX - 6), ($iSizeY - 6))

        $brush = $global:arrColors["CLR_WINDOW_GREEN3"].brush
        $tmp_grd.FillRectangle($brush, 4, 4, ($iSizeX - 8), ($iSizeY - 8))

        # back
        $brush = $global:arrColors["CLR_WINDOW_BACK"].brush
        $tmp_grd.FillRectangle($brush, 5, 5, ($iSizeX - 10), ($iSizeY - 10))
    }

    if($global:arrWindows[$strWindow].nbtn)
    {
        $keys    = $global:arrWindows[$strWindow].nbtn.Keys

        foreach($key in $keys)
        {
            if($strControl -ne "" -and $key -ne $strControl){continue;}

            $iSizeX     = $global:arrWindows[$strWindow].nbtn[$key].size_x;
            $iSizeY     = $global:arrWindows[$strWindow].nbtn[$key].size_y;
            $iPosX = $global:arrWindows[$strWindow].nbtn[$key].loc_x;
            $iPosY = $global:arrWindows[$strWindow].nbtn[$key].loc_y;

            $objImage = $global:arrWindows[$strWindow].nbtn[$key].bmp

            $rect_src = New-Object System.Drawing.Rectangle(0, 0, $iSizeX, $iSizeY)
            $rect_dst = New-Object System.Drawing.Rectangle($iPosX, $iPosy, $iSizeX, $iSizeY)

            $tmp_grd.DrawImage($objImage, $rect_dst, $rect_src, [System.Drawing.GraphicsUnit]::Pixel);
        }
    }

    if($global:arrWindows[$strWindow].nlbl)
    {
        $keys    = $global:arrWindows[$strWindow].nlbl.Keys

        foreach($key in $keys)
        {
            if($strControl -ne "" -and $key -ne $strControl){continue;}

            $iSizeX     = $global:arrWindows[$strWindow].nlbl[$key].size_x;
            $iSizeY     = $global:arrWindows[$strWindow].nlbl[$key].size_y;
            $iPosX = $global:arrWindows[$strWindow].nlbl[$key].loc_x;
            $iPosY = $global:arrWindows[$strWindow].nlbl[$key].loc_y;

            $objImage = $global:arrWindows[$strWindow].nlbl[$key].bmp

            $rect_src = New-Object System.Drawing.Rectangle(0, 0, $iSizeX, $iSizeY)
            $rect_dst = New-Object System.Drawing.Rectangle($iPosX, $iPosy, $iSizeX, $iSizeY)

            $tmp_grd.DrawImage($objImage, $rect_dst, $rect_src, [System.Drawing.GraphicsUnit]::Pixel);
        }
    }

    if($global:arrWindows[$strWindow].nbar)
    {
        $keys    = $global:arrWindows[$strWindow].nbar.Keys

        foreach($key in $keys)
        {
            if($strControl -ne "" -and $key -ne $strControl){continue;}

            $iSizeX     = $global:arrWindows[$strWindow].nbar[$key].size_x;
            $iSizeY     = $global:arrWindows[$strWindow].nbar[$key].size_y;
            $iPosX = $global:arrWindows[$strWindow].nbar[$key].loc_x;
            $iPosY = $global:arrWindows[$strWindow].nbar[$key].loc_y;

            $objImage = $global:arrWindows[$strWindow].nbar[$key].bmp

            $rect_src = New-Object System.Drawing.Rectangle(0, 0, $iSizeX, $iSizeY)
            $rect_dst = New-Object System.Drawing.Rectangle($iPosX, $iPosy, $iSizeX, $iSizeY)

            $tmp_grd.DrawImage($objImage, $rect_dst, $rect_src, [System.Drawing.GraphicsUnit]::Pixel);
        }
    }

    if($global:arrWindows[$strWindow].ninp)
    {
        $keys    = $global:arrWindows[$strWindow].ninp.Keys

        foreach($key in $keys)
        {
            if($strControl -ne "" -and $key -ne $strControl){continue;}

            $iSizeX     = $global:arrWindows[$strWindow].ninp[$key].size_x;
            $iSizeY     = $global:arrWindows[$strWindow].ninp[$key].size_y;
            $iPosX = $global:arrWindows[$strWindow].ninp[$key].loc_x;
            $iPosY = $global:arrWindows[$strWindow].ninp[$key].loc_y;

            $objImage = $global:arrWindows[$strWindow].ninp[$key].bmp

            $rect_src = New-Object System.Drawing.Rectangle(0, 0, $iSizeX, $iSizeY)
            $rect_dst = New-Object System.Drawing.Rectangle($iPosX, $iPosy, $iSizeX, $iSizeY)

            $tmp_grd.DrawImage($objImage, $rect_dst, $rect_src, [System.Drawing.GraphicsUnit]::Pixel);
        }
    }

    if($global:arrWindows[$strWindow].nimb)
    {
        $keys    = $global:arrWindows[$strWindow].nimb.Keys

        foreach($key in $keys)
        {
            if($strControl -ne "" -and $key -ne $strControl){continue;}

            $iSizeX     = $global:arrWindows[$strWindow].nimb[$key].size_x;
            $iSizeY     = $global:arrWindows[$strWindow].nimb[$key].size_y;
            $iPosX = $global:arrWindows[$strWindow].nimb[$key].loc_x;
            $iPosY = $global:arrWindows[$strWindow].nimb[$key].loc_y;

            $objImage = $global:arrWindows[$strWindow].nimb[$key].bmp

            $rect_src = New-Object System.Drawing.Rectangle(0, 0, $iSizeX, $iSizeY)
            $rect_dst = New-Object System.Drawing.Rectangle($iPosX, $iPosy, $iSizeX, $iSizeY)

            $tmp_grd.DrawImage($objImage, $rect_dst, $rect_src, [System.Drawing.GraphicsUnit]::Pixel);
        }
    }

    $global:arrWindows[$strWindow].graphics = $tmp_grd;
    $objForm.Refresh();
}

#region FUNCTION BUILDWINDOW
function buildWindow($iSizeX, $iSizeY, $iPosX, $iPosY, $strWindow)
{
    Write-Host "buildWindow($iSizeX, $iSizeY, $iPosX, $iPosY, $strWindow)"

    if($iSizeX % 2 -ne 0 -or $iSizeY % 2 -ne 0)
    {
        Write-Host "ERROR: buildWindow"
        return;
    }
    
    if($iPosX -lt 0 -or $iPosY -lt 0)
    {
        Write-Host "ERROR: buildWindow"
        return;
    }
    
    if($iSizeX -lt 0 -or $iSizeX -gt $DrawingSizeX)
    {
        Write-Host "ERROR: buildWindow"
        return;
    }
    
    if($iSizeY -lt 0 -or $iSizeY -gt $DrawingSizeY)
    {
        Write-Host "ERROR: buildWindow"
        return;
    }
    
    # check if graphic already exists
    # this has quite a big impact on peformance!
    if($global:arrWindows[$strWindow])
    {   
        $objForm.Refresh();
        return;
    }
    
    # create a rect
    $tmp_rec    = New-Object System.Drawing.Rectangle(0, 0, $iSizeX, $iSizeY)
    # cloning is faster than creating a new bitmap
    $tmp_wnd    = $global:bitmap.Clone($tmp_rec, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    $tmp_grd = [System.Drawing.Graphics]::FromImage($tmp_wnd);
    $tmp_grd.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor 
    $tmp_grd.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half 

    #outline
    $brush = $global:arrColors["CLR_BLACK"].brush
    $tmp_grd.FillRectangle($brush, 0, 0, $iSizeX, $iSizeY)

    $brush = $global:arrColors["CLR_WINDOW_GREEN1"].brush
    $tmp_grd.FillRectangle($brush, 1, 1, ($iSizeX - 2), ($iSizeY - 2))

    $brush = $global:arrColors["CLR_WINDOW_GREEN2"].brush
    $tmp_grd.FillRectangle($brush, 3, 3, ($iSizeX - 6), ($iSizeY - 6))

    $brush = $global:arrColors["CLR_WINDOW_GREEN3"].brush
    $tmp_grd.FillRectangle($brush, 4, 4, ($iSizeX - 8), ($iSizeY - 8))

    # back
    $brush = $global:arrColors["CLR_WINDOW_BACK"].brush
    $tmp_grd.FillRectangle($brush, 5, 5, ($iSizeX - 10), ($iSizeY - 10))

    $global:arrWindows[$strWindow] = @{}
    $global:arrWindows[$strWindow].graphics = $tmp_grd;
    $global:arrWindows[$strWindow].wnd = $tmp_wnd;
    $global:arrWindows[$strWindow].loc_x = $iPosX;
    $global:arrWindows[$strWindow].loc_y = $iPosY;
    $global:arrWindows[$strWindow].sizeX = $iSizeX;
    $global:arrWindows[$strWindow].sizeY = $iSizeY;
    #$global:arrWindows[$strWindow].type = "WNDTYPE_BASE";

    WND_AddInitialControls $strWindow

    $objForm.Refresh();
}
#endregion

function WND_setFOWButtonState($strWindow, $strBtnName, $fowState)
{
    $global:EnableFoW = $fowState

    if($global:EnableFoW)
    {
        $global:arrWindows[$strWindow].nbtn[$strBtnName].text = "On";
        $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr = "GREEN";
        $global:arrWindows[$strWindow].nbtn[$strBtnName].active = $True;
    }
    else
    {
        $global:arrWindows[$strWindow].nbtn[$strBtnName].text = "Off";
        $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr = "RED";
        $global:arrWindows[$strWindow].nbtn[$strBtnName].active = $False;
    }

    BTN_updateNButtonGraphic $strWindow $strBtnName

    if($global:arrMultiplayer.isServer)
    {
        SERVER_sendDataAll ("0x06/" + [int]$global:EnableFoW)
    }
}

function WND_setTopmostButtonByState()
{
    $strWindow = "WND_GAME_OPTIONS_N"
    $strBtnName = "BTN_SWITCH_TOPMOST"

    if($global:arrSettings["TOPMOST"])
    {
        $global:arrWindows[$strWindow].nbtn[$strBtnName].text = "On";
        $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr = "GREEN";
        $global:arrWindows[$strWindow].nbtn[$strBtnName].active = $True;
    }
    else
    {
        $global:arrWindows[$strWindow].nbtn[$strBtnName].text = "Off";
        $global:arrWindows[$strWindow].nbtn[$strBtnName].btnclr = "RED";
        $global:arrWindows[$strWindow].nbtn[$strBtnName].active = $False;
    }

    BTN_updateNButtonGraphic $strWindow $strBtnName
}

function BAR_setHiddenState($strWindow, $strBarName, $state)
{
    #Write-Host "BAR_setHiddenState($strWindow, $strBarName, $state)"

    if($global:arrWindows[$strWindow].nbar[$strBarName].hidden -eq $state) {return;}

    $global:arrWindows[$strWindow].nbar[$strBarName].hidden = $state

    BAR_updateNBarGraphic $strWindow $strBarName
}

function BAR_SetTextValueColor($strWindow, $strBarName, $strText, $fValue, $strColor)
{
    #Write-Host "BAR_SetTextValueColor($strWindow, $strBarName, $strText, $fValue, $strColor)"

    $global:arrWindows[$strWindow].nbar[$strBarName].barclr = $strColor

    BAR_SetTextValue $strWindow $strBarName $strText $fValue
}

function BAR_SetTextValue($strWindow, $strBarName, $strText, $fValue)
{
    #Write-Host "BAR_SetTextValue($strWindow, $strBarName, $strText, $fValue)"

    $global:arrWindows[$strWindow].nbar[$strBarName].text = $strText
    $global:arrWindows[$strWindow].nbar[$strBarName].value = [float]$fValue

    BAR_updateNBarGraphic $strWindow $strBarName
}

function BAR_setValue($strWindow, $strBarName, $fValue)
{
    #Write-Host "BAR_setValue($strWindow, $strBarName, $fValue)"

    if($global:arrWindows[$strWindow].nbar[$strBarName].value -eq [float]$fValue) {return;}

    $global:arrWindows[$strWindow].nbar[$strBarName].value = [float]$fValue

    BAR_updateNBarGraphic $strWindow $strBarName
}

function WND_AddInitialControls($strWindow)
{
    $global:arrWindows.isInitializing = $True

    switch($strWindow)
    {
        "WND_ESC_MAIN_N"
        {
            WND_addNButtonToWindow $strWindow "BTN_SINGLEPLAYER" "GRAY" 136 20 12 12 $False "Singleplayer" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_SINGLEPLAYER_TYPESELECTION_N"
            WND_addNButtonToWindow $strWindow "BTN_MULTIPLAYER" "GRAY" 136 20 12 38 $False "Multiplayer" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_MULTIPLAYER_TYPESELECTION"
            WND_addNButtonToWindow $strWindow "BTN_EDITOR" "GRAY" 136 20 12 64 $False "Editor" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_CREATE_MAP_N"
            WND_addNButtonToWindow $strWindow "BTN_OPTIONS" "GRAY" 136 20 12 90 $False "Options" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_GAME_OPTIONS_N"
            WND_addNButtonToWindow $strWindow "BTN_CREDITS" "GRAY" 110 20 12 116 $False "Credits" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_CREDITS_N"
            WND_addNButtonToWindow $strWindow "BTN_DISCORD" "GRAY" 20 20 128 116 $False "" "CENTER" "GOLD" "FNK_OPEN_LINK" "https://discord.com/invite/ATGmvuN"
            BTN_addImage $strWindow "BTN_DISCORD" "ICON_DISCORD" 2 2 1
            WND_AddNLabelToWindow $strWindow "LBL_VERSION" "CLR_WINDOW_BACK" 136 20 12 142 ("v" + $global:VersionInfo[0] + "." + $global:VersionInfo[1] + "." + $global:VersionInfo[2] + " - " + $global:VersionInfo[3]) "CENTER" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_QUIT" "RED" 136 20 12 168 $False "Quit" "CENTER" "GOLD" "FNK_QUIT_GAME"
        }
        "WND_SINGLEPLAYER_TYPESELECTION_N"
        {
            WND_addNButtonToWindow $strWindow "BTN_CAMPAIGN" "GRAY" 136 20 12 12 $False "Campaign" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_CAMPAIGN_SELECT"
            WND_addNButtonToWindow $strWindow "BTN_FREEPLAY" "GRAY" 136 20 12 38 $False "Freeplay" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_SINGLEPLAYER_SETUP_N"
            WND_addNButtonToWindow $strWindow "BTN_TUTORIAL" "GRAY" 136 20 12 64 $False "Tutorial" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_TUTORIAL_N"
            WND_addNButtonToWindow $strWindow "BTN_BACK" "RED" 136 20 12 168 $False "Back" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_ESC_MAIN_N"
        }
        "WND_GAME_OPTIONS_N"
        {
            WND_AddNLabelToWindow $strWindow "LBL_TOPMOST" "CLR_WINDOW_BACK" 136 20 12 12 "Topmost:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_SWITCH_TOPMOST" "GREEN" 40 20 160 12 $True "On" "CENTER" "GOLD" "FNK_SWITCH_TOPMOST"
            WND_setTopmostButtonByState

            WND_AddNLabelToWindow $strWindow "LBL_VOL_MUSIC" "CLR_WINDOW_BACK" 136 20 12 38 "Volume Music:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_MUSIC_DECREASE" "RED" 20 20 160 38 $False "" "CENTER" "GOLD" "FNK_MUSIC_VOLUME" "DECREASE"
            BTN_addImage $strWindow "BTN_MUSIC_DECREASE" "ICON_MINUS" 2 2 1
            WND_addNBarToWindow $strWindow "BAR_MUSIC_VALUE" 136 20 184 38 "0%" "CENTER" "GOLD" 0
            BAR_SetTextValue "WND_GAME_OPTIONS_N" "BAR_MUSIC_VALUE" ("" + ([int](10 * [float]$global:arrSettings["VOLUMEMUSIC"])) + "%") ([int]$global:arrSettings["VOLUMEMUSIC"] * 0.1)
            WND_addNButtonToWindow $strWindow "BTN_MUSIC_INCREASE" "GREEN" 20 20 324 38 $False "" "CENTER" "GOLD" "FNK_MUSIC_VOLUME" "INCREASE"
            BTN_addImage $strWindow "BTN_MUSIC_INCREASE" "ICON_PLUS" 2 2 1

            WND_AddNLabelToWindow $strWindow "LBL_VOL_EFFECTS" "CLR_WINDOW_BACK" 136 20 12 64 "Volume Effects:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_EFFECTS_DECREASE" "RED" 20 20 160 64 $False "" "CENTER" "GOLD" "FNK_EFFECTS_VOLUME" "DECREASE"
            BTN_addImage $strWindow "BTN_EFFECTS_DECREASE" "ICON_MINUS" 2 2 1
            WND_addNBarToWindow $strWindow "BAR_EFFECTS_VALUE" 136 20 184 64 "0%" "CENTER" "GOLD" 0
            BAR_SetTextValue $strWindow "BAR_EFFECTS_VALUE" ("" + ([int](10 * [float]$global:arrSettings["VOLUMEEFFECTS"])) + "%") ([int]$global:arrSettings["VOLUMEEFFECTS"] * 0.1)
            WND_addNButtonToWindow $strWindow "BTN_EFFECTS_INCREASE" "GREEN" 20 20 324 64 $False "" "CENTER" "GOLD" "FNK_EFFECTS_VOLUME" "INCREASE"
            BTN_addImage $strWindow "BTN_EFFECTS_INCREASE" "ICON_PLUS" 2 2 1

            WND_AddNLabelToWindow $strWindow "LBL_PLAYER_NAME" "CLR_WINDOW_BACK" 136 20 12 90 "Player Name:" "LEFT" "GOLD"
            WND_addNInputToWindow $strWindow "INP_PLAYER_NAME" 136 20 160 90 ($global:arrSettings["PLAYER_NAME"]) "LEFT" 15 "FNK_LEAVE_PLAYERNAME"

            WND_AddNLabelToWindow $strWindow "LBL_SCROLL_SPEED" "CLR_WINDOW_BACK" 136 20 12 116 "Key Scrollspeed:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_SCROLL_DECREASE" "RED" 20 20 160 116 $False "" "CENTER" "GOLD" "FNK_SCROLL_SPEED" "DECREASE"
            BTN_addImage $strWindow "BTN_SCROLL_DECREASE" "ICON_MINUS" 2 2 1
            WND_addNBarToWindow $strWindow "BAR_SCROLL_VALUE" 136 20 184 116 ("" + $global:arrSettings["SCROLLSPEED"] + " Tile(s)") "CENTER" "GOLD" ($global:arrSettings["SCROLLSPEED"] / 10)
            WND_addNButtonToWindow $strWindow "BTN_SCROLL_INCREASE" "GREEN" 20 20 324 116 $False "" "CENTER" "GOLD" "FNK_SCROLL_SPEED" "INCREASE"
            BTN_addImage $strWindow "BTN_SCROLL_INCREASE" "ICON_PLUS" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_BACK" "RED" 136 20 112 188 $False "Back" "CENTER" "GOLD" "FNK_LEAVE_OPTIONS"
        }
        "WND_CREATE_MAP_N"
        {
            WND_AddNLabelToWindow $strWindow "LBL_WIDTH" "CLR_WINDOW_BACK" 136 20 12 12 "Width:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_CREATEMAP_DECREASEWIDTH_16" "RED" 30 20 160 12 $False "-16" "CENTER" "GOLD" "FNK_MAP_CHANGE_WIDTH" -16
            WND_addNButtonToWindow $strWindow "BTN_CREATEMAP_DECREASEWIDTH_02" "RED" 30 20 190 12 $False "- 2" "CENTER" "GOLD" "FNK_MAP_CHANGE_WIDTH" -2
            WND_AddNLabelToWindow $strWindow "LBL_WIDTH_ACTUAL" "CLR_WINDOW_BACK" 40 20 220 12 ([string]($global:arrCreateMapOptions["WIDTH"])) "CENTER" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_CREATEMAP_INCREASEWIDTH_02" "GREEN" 30 20 260 12 $False "+ 2" "CENTER" "GOLD" "FNK_MAP_CHANGE_WIDTH" 2
            WND_addNButtonToWindow $strWindow "BTN_CREATEMAP_INCREASEWIDTH_16" "GREEN" 30 20 290 12 $False "+16" "CENTER" "GOLD" "FNK_MAP_CHANGE_WIDTH" 16
            
            WND_AddNLabelToWindow $strWindow "LBL_HEIGHT" "CLR_WINDOW_BACK" 136 20 12 38 "Height:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_CREATEMAP_DECREASEHEIGHT_16" "RED" 30 20 160 38 $False "-16" "CENTER" "GOLD" "FNK_MAP_CHANGE_HEIGHT" -16
            WND_addNButtonToWindow $strWindow "BTN_CREATEMAP_DECREASEHEIGHT_02" "RED" 30 20 190 38 $False "- 2" "CENTER" "GOLD" "FNK_MAP_CHANGE_HEIGHT" -2
            WND_AddNLabelToWindow $strWindow "LBL_HEIGHT_ACTUAL" "CLR_WINDOW_BACK" 40 20 220 38 ([string]($global:arrCreateMapOptions["HEIGHT"])) "CENTER" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_CREATEMAP_INCREASEHEIGHT_02" "GREEN" 30 20 260 38 $False "+ 2" "CENTER" "GOLD" "FNK_MAP_CHANGE_HEIGHT" 2
            WND_addNButtonToWindow $strWindow "BTN_CREATEMAP_INCREASEHEIGHT_16" "GREEN" 30 20 290 38 $False "+16" "CENTER" "GOLD" "FNK_MAP_CHANGE_HEIGHT" 16

            WND_AddNLabelToWindow $strWindow "LBL_BASETEXTURE" "CLR_WINDOW_BACK" 136 20 12 64 "Basetexture:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_BASETEXTURE_PREV" "GRAY" 20 20 160 64 $False "" "CENTER" "GOLD" "FNK_MAP_CHANGE_BASETEXTURE" -1
            BTN_addImage $strWindow "BTN_BASETEXTURE_PREV" "ICON_ARROW_GOLD_LEFT" 2 2 1
            WND_addNImageBoxToWindow $strWindow "IMB_BASETEXTURE" 20 20 180 64 ($arrBaseTextureIDToKey[($global:arrCreateMapOptions["BASTEXTUREID"])]) 2 2 1
            WND_addNButtonToWindow $strWindow "BTN_BASETEXTURE_NEXT" "GRAY" 20 20 200 64 $False "" "CENTER" "GOLD" "FNK_MAP_CHANGE_BASETEXTURE" 1
            BTN_addImage $strWindow "BTN_BASETEXTURE_NEXT" "ICON_ARROW_GOLD_RIGHT" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_LOAD" "GRAY" 136 20 212 162 $False "Load..." "CENTER" "GOLD" "FNK_MAP_LOAD"

            WND_addNButtonToWindow $strWindow "BTN_CONTINUE" "GRAY" 136 20 212 188 $False "Continue" "CENTER" "GOLD" "FNK_MAP_CONTINUE"

            WND_addNButtonToWindow $strWindow "BTN_BACK" "RED" 136 20 12 188 $False "Back" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_ESC_MAIN_N"
        }
        "WND_INTERFACE_EDITOR_LAYER_01"
        {
            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_01" "RED" 28 20 12 12 $True "" "" ""
            BTN_addImage $strWindow "BTN_IFE_LAYER_01" "ICON_LAYER_01" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_02" "GRAY" 28 20 48 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_02"
            BTN_addImage $strWindow "BTN_IFE_LAYER_02" "ICON_LAYER_02" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_03" "GRAY" 28 20 84 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_03"
            BTN_addImage $strWindow "BTN_IFE_LAYER_03" "ICON_LAYER_03" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_PLAYER" "GRAY" 28 20 120 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_PLAYER"
            BTN_addImage $strWindow "BTN_IFE_LAYER_PLAYER" "ICON_LAYER_PLAYER" 6 2 1

            for($i = 0; $i -lt $arrBaseTextureIDToKey.Length; $i++)
            {
                $column = $i % 5
                $row = [math]::Floor($i / 5)

                WND_addNButtonToWindow $strWindow ("BTN_IFE_L1_TEX" + $i) "GRAY" 24 24 (20 + 24 * $column) (38 + 24 * $row) $False "" "" "" "FNK_EDITOR_LAYER_BASE" $i
                BTN_addImage $strWindow ("BTN_IFE_L1_TEX" + $i) ($arrBaseTextureIDToKey[$i]) 4 4 1
            }
        }
        "WND_INTERFACE_EDITOR_LAYER_02"
        {
            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_01" "GRAY" 28 20 12 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_01"
            BTN_addImage $strWindow "BTN_IFE_LAYER_01" "ICON_LAYER_01" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_02" "RED" 28 20 48 12 $True "" "" ""
            BTN_addImage $strWindow "BTN_IFE_LAYER_02" "ICON_LAYER_02" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_03" "GRAY" 28 20 84 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_03"
            BTN_addImage $strWindow "BTN_IFE_LAYER_03" "ICON_LAYER_03" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_PLAYER" "GRAY" 28 20 120 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_PLAYER"
            BTN_addImage $strWindow "BTN_IFE_LAYER_PLAYER" "ICON_LAYER_PLAYER" 6 2 1

            for($i = 0; $i -lt $arrOverlayTextureIDToKey.Length; $i++)
            {
                $column = $i % 5
                $row = [math]::Floor($i / 5)

                WND_addNButtonToWindow $strWindow ("BTN_IFE_L2_TEX" + $i) "GRAY" 24 24 (20 + 24 * $column) (38 + 24 * $row) $False "" "" "" "FNK_EDITOR_LAYER_OVERLAY" $i
                BTN_addImage $strWindow ("BTN_IFE_L2_TEX" + $i) ($arrOverlayTextureIDToKey[$i]) 4 4 1
            }
        }
        "WND_INTERFACE_EDITOR_LAYER_03"
        {
            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_01" "GRAY" 28 20 12 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_01"
            BTN_addImage $strWindow "BTN_IFE_LAYER_01" "ICON_LAYER_01" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_02" "GRAY" 28 20 48 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_02"
            BTN_addImage $strWindow "BTN_IFE_LAYER_02" "ICON_LAYER_02" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_03" "RED" 28 20 84 12 $True "" "" ""
            BTN_addImage $strWindow "BTN_IFE_LAYER_03" "ICON_LAYER_03" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_PLAYER" "GRAY" 28 20 120 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_PLAYER"
            BTN_addImage $strWindow "BTN_IFE_LAYER_PLAYER" "ICON_LAYER_PLAYER" 6 2 1

            for($i = 0; $i -lt $arrObjectTextureIDToKey.Length; $i++)
            {
                $column = $i % 5
                $row = [math]::Floor($i / 5)

                WND_addNButtonToWindow $strWindow ("BTN_IFE_L3_TEX" + $i) "GRAY" 24 24 (20 + 24 * $column) (38 + 24 * $row) $False "" "" "" "FNK_EDITOR_LAYER_OBJECT" $i
                BTN_addImage $strWindow ("BTN_IFE_L3_TEX" + $i) ($arrObjectTextureIDToKey[$i]) 4 4 1
            }
        }
        "WND_INTERFACE_EDITOR_LAYER_PLAYER"
        {
            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_01" "GRAY" 28 20 12 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_01"
            BTN_addImage $strWindow "BTN_IFE_LAYER_01" "ICON_LAYER_01" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_02" "GRAY" 28 20 48 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_02"
            BTN_addImage $strWindow "BTN_IFE_LAYER_02" "ICON_LAYER_02" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_03" "GRAY" 28 20 84 12 $False "" "CENTER" "GOLD" "FNK_EDITOR_SHOW_WINDOW" "WND_INTERFACE_EDITOR_LAYER_03"
            BTN_addImage $strWindow "BTN_IFE_LAYER_03" "ICON_LAYER_03" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_LAYER_PLAYER" "RED" 28 20 120 12 $True "" "" ""
            BTN_addImage $strWindow "BTN_IFE_LAYER_PLAYER" "ICON_LAYER_PLAYER" 6 2 1

            WND_addNButtonToWindow $strWindow "BTN_IFE_L_PLAYER_00" "GRAY" 136 20 12 38 $False "Delete" "CENTER" "GOLD" "FNK_EDITOR_LAYER_PLAYER" 0
            BTN_addImage $strWindow "BTN_IFE_L_PLAYER_00" "PLAYER_00" 6 2 1
            WND_addNButtonToWindow $strWindow "BTN_IFE_L_PLAYER_01" "GRAY" 136 20 12 58 $False "Player #1" "CENTER" "GOLD" "FNK_EDITOR_LAYER_PLAYER" 1
            BTN_addImage $strWindow "BTN_IFE_L_PLAYER_01" "PLAYER_01" 6 2 1
            WND_addNButtonToWindow $strWindow "BTN_IFE_L_PLAYER_02" "GRAY" 136 20 12 78 $False "Player #2" "CENTER" "GOLD" "FNK_EDITOR_LAYER_PLAYER" 2
            BTN_addImage $strWindow "BTN_IFE_L_PLAYER_02" "PLAYER_02" 6 2 1
            WND_addNButtonToWindow $strWindow "BTN_IFE_L_PLAYER_03" "GRAY" 136 20 12 98 $False "Player #3" "CENTER" "GOLD" "FNK_EDITOR_LAYER_PLAYER" 3
            BTN_addImage $strWindow "BTN_IFE_L_PLAYER_03" "PLAYER_03" 6 2 1
            WND_addNButtonToWindow $strWindow "BTN_IFE_L_PLAYER_04" "GRAY" 136 20 12 118 $False "Player #4" "CENTER" "GOLD" "FNK_EDITOR_LAYER_PLAYER" 4
            BTN_addImage $strWindow "BTN_IFE_L_PLAYER_04" "PLAYER_04" 6 2 1
        }
        "WND_ESC_EDITOR_N"
        {
            WND_addNButtonToWindow $strWindow "BTN_EDITOR_SAVEMAP" "GRAY" 136 20 12 12 $False "Save Map" "CENTER" "GOLD" "FNK_EDITOR_SAVEMAP" ""
            WND_addNButtonToWindow $strWindow "BTN_EDITOR_SAVEIMAGE" "GRAY" 136 20 12 38 $False "Save Image" "CENTER" "GOLD" "FNK_EDITOR_SAVEIMAGE" ""

            WND_AddNLabelToWindow $strWindow "LBL_AUTHOR" "CLR_WINDOW_BACK" 136 12 12 64 "Author:" "LEFT" "GOLD"
            WND_addNInputToWindow $strWindow "INP_EDITOR_AUTHOR" 136 20 12 76 ($global:arrSettings["PLAYER_NAME"]) "LEFT" 15 ""

            WND_AddNLabelToWindow $strWindow "LBL_MAPNAME" "CLR_WINDOW_BACK" 136 12 12 102 "Mapname:" "LEFT" "GOLD"
            WND_addNInputToWindow $strWindow "INP_EDITOR_MAPNAME" 136 20 12 114 ($global:arrMap["MAPNAME"]) "LEFT" 15 ""

            WND_addNButtonToWindow $strWindow "BTN_BACK" "GREEN" 136 20 12 142 $False "Back" "CENTER" "GOLD" "FNK_EDITOR_BACK"
            WND_addNButtonToWindow $strWindow "BTN_LEAVE" "RED" 136 20 12 168 $False "Leave Editor" "CENTER" "GOLD" "FNK_EDITOR_LEAVE"
        }
        "WND_EDITOR_WAIT_N"
        {
            WND_AddNLabelToWindow $strWindow "LBL_PLEASE_WAIT" "CLR_WINDOW_BACK" 136 12 12 12 "Please wait..." "LEFT" "GOLD"
            WND_addNBarToWindow $strWindow "BAR_SAVE_PROGRESS" 136 20 12 24 "" "CENTER" "GOLD" 0
        }

        "WND_TUTORIAL_N"
        {
            WND_AddNLabelToWindow $strWindow "LBL_RTFM1" "CLR_WINDOW_BACK" 200 8 32 46   " __________________" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM2" "CLR_WINDOW_BACK" 200 8 32 54   "(\                 \" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM3" "CLR_WINDOW_BACK" 200 8 32 62   "( \                 \" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM4" "CLR_WINDOW_BACK" 200 8 32 70   "(  \ ___ _____ ___ __\ __" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM5" "CLR_WINDOW_BACK" 200 8 32 78   " \  | _ \_   _| __|  \/  |" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM6" "CLR_WINDOW_BACK" 200 8 32 86   "  \ |   / | | | _|| |\/| |" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM7" "CLR_WINDOW_BACK" 200 8 32 94   "   \|_|_\ |_| |_| |_|  |_|" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM8" "CLR_WINDOW_BACK" 200 8 32 102  "    \  \                 \" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM9" "CLR_WINDOW_BACK" 200 8 32 110  "     \  \                 \" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM10" "CLR_WINDOW_BACK" 200 8 32 118 "      \  \_________________\" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM11" "CLR_WINDOW_BACK" 200 8 32 126 "       \ (_________________(" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RTFM12" "CLR_WINDOW_BACK" 200 8 32 134 "        \(_________________(" "LEFT" "GOLD"

            WND_addNButtonToWindow $strWindow "BTN_BACK" "RED" 136 20 62 188 $False "Back" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_SINGLEPLAYER_TYPESELECTION_N"
        }
        "WND_SINGLEPLAYER_SETUP_N"
        {
            WND_AddNLabelToWindow $strWindow "LBL_FP_MAP" "CLR_WINDOW_BACK" 78 20 12 12   "Map:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_FP_OPENMAP" "GRAY" 338 20 90 12 $False "Open Map..." "LEFT" "GOLD" "FNK_FP_OPENMAP" ""

            WND_AddNLabelToWindow $strWindow "LBL_FP_PLAYERS_TEXT" "CLR_WINDOW_BACK" 78 20 12 38 "Players:" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_FP_PLAYERS" "CLR_WINDOW_BACK" 136 20 90 38 "-" "LEFT" "GOLD"

            WND_AddNLabelToWindow $strWindow "LBL_FP_AUTHOR_TEXT" "CLR_WINDOW_BACK" 78 20 12 64 "Author:" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_FP_AUTHOR" "CLR_WINDOW_BACK" 136 20 90 64 "-" "LEFT" "GOLD"

            WND_AddNLabelToWindow $strWindow "LBL_FP_SIZE_TEXT" "CLR_WINDOW_BACK" 78 20 12 90 "Size:" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_FP_SIZE" "CLR_WINDOW_BACK" 136 20 90 90 "-" "LEFT" "GOLD"

            WND_AddNLabelToWindow $strWindow "LBL_FOW_TEXT" "CLR_WINDOW_BACK" 78 20 12 116 "FoW:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_FOW_TOGGLE" "RED" 40 20 90 116 $False "Off" "CENTER" "GOLD" "FNK_SWITCH_FOW" ""

            # as generating a good preview would need more coding
            # this is excluded for now, was never really helpfull as it should have taken n-tiles depending on map size for shading
            #WND_AddNLabelToWindow $strWindow "LBL_FP_PREVIEW_TEXT" "CLR_WINDOW_BACK" 78 20 12 116 "Preview:" "LEFT" "GOLD"
            #WND_addNImageBoxToWindow $strWindow "IMB_FP_PREVIEW" 32 32 90 116 "GROUND_EMPTY_01" 0 0 2
            #IMB_setHidden $strWindow "IMB_FP_PREVIEW" $True

            for($i = 0; $i -lt 4; $i++)
            {
                WND_addNButtonToWindow $strWindow ("BTN_FP_PLAYER" + $i) "RED" 136 20 292 (38 + $i *26) $False "Closed" "LEFT" "GOLD" "FNK_FP_SWITCH_PLAYERTYPE" ($i + 1)
                BTN_setDisabledState $strWindow ("BTN_FP_PLAYER" + $i) $True

                WND_AddNLabelToWindow $strWindow ("LBL_FP_TEXT_PLAYER" + $i) "CLR_WINDOW_BACK" 60 10 230 (38 + $i *26) ("Player " + ($i + 1)) "LEFT" "GOLD"
                WND_AddNLabelToWindow $strWindow ("LBL_FP_TEXT_PLAYERCLR" + $i) ("CLR_PLAYER_" + ($i + 1) + "1") 60 10 230 (48 + $i * 26) "" "LEFT" "GOLD"
            }

            WND_addNButtonToWindow $strWindow "BTN_FP_BACK" "RED" 136 20 12 188 $False "Back" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_SINGLEPLAYER_TYPESELECTION_N"
            WND_addNButtonToWindow $strWindow "BTN_FP_START" "GRAY" 136 20 292 188 $False "Start" "CENTER" "GOLD" "FNK_FP_START" ""
        }
        "WND_FP_ERRORS"
        {
            WND_AddNLabelToWindow $strWindow "LBL_MESSAGE" "CLR_WINDOW_BACK" 136 12 12 12 "Error!" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_FP_ERROR_OK" "GRAY" 136 20 12 24 $False "Ok" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_SINGLEPLAYER_SETUP_N"
        }
        "WND_SP_NEXT_PLAYER_N"
        {
            WND_AddNLabelToWindow $strWindow "LBL_NEXT_PLAYER_TEXT" "CLR_WINDOW_BACK" 136 12 12 20 "Next Player:" "CENTER" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_NEXT_PLAYER_COLOR" ("CLR_PLAYER_" + [string]($global:arrPlayerInfo.currentplayer) + "1") 52 92 54 54 "" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_NEXT_PLAYER_NAME" "CLR_WINDOW_BACK" 136 12 12 160 ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][0]) "CENTER" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_CONTINUE" "GRAY" 136 20 12 238 $False "Continue" "CENTER" "GOLD" "FNK_NEXT_PLAYER_CONTINUE" ""
        }
        "WND_MENU_BUILDINGS"
        {
            WND_addNButtonToWindow $strWindow "BTN_SP_BUILD" "GRAY" 22 20 12 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_SP_MENU_BUILDING_N"
            BTN_addImage $strWindow "BTN_SP_BUILD" "ICON_BUILD" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_ARMY" "GRAY" 22 20 50 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_SP_MENU_ARMY_N"
            BTN_addImage $strWindow "BTN_SP_ARMY" "ICON_ARMIES" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_WARES" "GRAY" 22 20 88 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_SP_MENU_WARES_N"
            BTN_addImage $strWindow "BTN_SP_WARES" "ICON_WARES" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_HOUSES" "RED" 22 20 126 12 $True "" "LEFT" "GOLD" "" ""
            BTN_addImage $strWindow "BTN_SP_HOUSES" "ICON_HOUSES" 3 2 1

            WND_AddNLabelToWindow $strWindow "LBL_TITLE" "CLR_WINDOW_BACK" 136 10 12 34 "Building Overview" "CENTER" "GOLD"

            for($i = 0; $i -lt $global:arrBuildingIDToKey.Count; $i++)
            {
                WND_addNImageBoxToWindow $strWindow ("IMB_HOUSE" + $i) 16 16 (21 + [math]::Floor($i / 6) * 68) (48 + ($i % 6) * 30) ($global:arrBuildingIDToKey[$i] + "_1_0") 0 0 1
                WND_addNImageBoxToWindow $strWindow ("IMB_SITE" + $i) 16 16 (55 + [math]::Floor($i / 6) * 68) (48 + ($i % 6) * 30) ($global:arrBuildingIDToKey[$i] + "_1_1") 0 0 1
                WND_AddNLabelToWindow $strWindow ("LBL_HOUSE" + $i) "CLR_WINDOW_BACK" 34 8 (12 + [math]::Floor($i / 6) * 68) (64 + ($i % 6) * 30) "9999" "CENTER" "GOLD"
                WND_AddNLabelToWindow $strWindow ("LBL_SITE" + $i) "CLR_WINDOW_BACK" 34 8 (46 + [math]::Floor($i / 6) * 68) (64 + ($i % 6) * 30) "9999" "CENTER" "GOLD"
            }

            WND_SP_addNextButtons $strWindow
        }
        "WND_SP_MENU_WARES_N"
        {
            # 12 | 28 | 26 | 28 | 26 | 28 | 12
            WND_addNButtonToWindow $strWindow "BTN_SP_BUILD" "GRAY" 22 20 12 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_SP_MENU_BUILDING_N"
            BTN_addImage $strWindow "BTN_SP_BUILD" "ICON_BUILD" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_ARMY" "GRAY" 22 20 50 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_SP_MENU_ARMY_N"
            BTN_addImage $strWindow "BTN_SP_ARMY" "ICON_ARMIES" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_WARES" "RED" 22 20 88 12 $True "" "LEFT" "GOLD" "" ""
            BTN_addImage $strWindow "BTN_SP_WARES" "ICON_WARES" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_HOUSES" "GRAY" 22 20 126 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_MENU_BUILDINGS"
            BTN_addImage $strWindow "BTN_SP_HOUSES" "ICON_HOUSES" 3 2 1

            WND_AddNLabelToWindow $strWindow "LBL_TITLE" "CLR_WINDOW_BACK" 136 10 12 34 "Wares Overview" "CENTER" "GOLD"
            WND_addNImageBoxToWindow $strWindow "IMB_GOLDCOIN" 20 20 12 76 "ICON_GOLDCOIN" 2 2 1
            WND_addNImageBoxToWindow $strWindow "IMB_WOOD" 20 20 12 94 "ICON_WOOD" 2 2 1
            WND_addNImageBoxToWindow $strWindow "IMB_FOOD" 20 20 12 112 "ICON_FOOD" 2 2 1
            WND_addNImageBoxToWindow $strWindow "IMB_PEOPLE" 20 20 12 130 "ICON_PEOPLE" 2 2 1

            WND_AddNLabelToWindow $strWindow "LBL_AMOUNT" "CLR_WINDOW_BACK" 50 20 32 54 "Amount" "CENTER" "GOLD"

            WND_AddNLabelToWindow $strWindow "LBL_AMOUNT_GOLD" "CLR_WINDOW_BACK" 50 20 32 76 "-" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_AMOUNT_WOOD" "CLR_WINDOW_BACK" 50 20 32 94 "-" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_AMOUNT_FOOD" "CLR_WINDOW_BACK" 50 20 32 112 "-" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_AMOUNT_PEOPLE" "CLR_WINDOW_BACK" 50 20 32 130 "-" "RIGHT" "GOLD"

            WND_AddNLabelToWindow $strWindow "LBL_PRODUCTION" "CLR_WINDOW_BACK" 50 20 96 54 "Prod." "CENTER" "GOLD"

            WND_AddNLabelToWindow $strWindow "LBL_PROD_GOLD" "CLR_WINDOW_BACK" 50 20 96 76 "-" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_PROD_WOOD" "CLR_WINDOW_BACK" 50 20 96 94 "-" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_PROD_FOOD" "CLR_WINDOW_BACK" 50 20 96 112 "-" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_PROD_PEOPLE" "CLR_WINDOW_BACK" 50 20 96 130 "-" "RIGHT" "GOLD"

            WND_SP_addNextButtons $strWindow
        }
        "WND_SP_MENU_BUILDING_N"
        {
            WND_addNButtonToWindow $strWindow "BTN_SP_BUILD" "RED" 22 20 12 12 $True "" "LEFT" "GOLD" "" "WND_SP_MENU_BUILDING_N"
            BTN_addImage $strWindow "BTN_SP_BUILD" "ICON_BUILD" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_ARMY" "GRAY" 22 20 50 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_SP_MENU_ARMY_N"
            BTN_addImage $strWindow "BTN_SP_ARMY" "ICON_ARMIES" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_WARES" "GRAY" 22 20 88 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_SP_MENU_WARES_N"
            BTN_addImage $strWindow "BTN_SP_WARES" "ICON_WARES" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_HOUSES" "GRAY" 22 20 126 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_MENU_BUILDINGS"
            BTN_addImage $strWindow "BTN_SP_HOUSES" "ICON_HOUSES" 3 2 1

            WND_AddNLabelToWindow $strWindow "LBL_TITLE_BLD1" "CLR_WINDOW_BACK" 136 10 12 34 "Civil Buildings" "CENTER" "GOLD"

            # 12 | 22 | 16 | 22 | 16 | 22  | 16  | 22  | 12
            # 12 | 34 | 50 | 72 | 88 | 110 | 126 | 148 | 160
            # "HUM_HQ", "HUM_HOUSE_SMALL", "HUM_HOUSE_MEDIUM", "HUM_HOUSE_LARGE", "HUM_FARM", "HUM_FIELD", "HUM_MINE", "HUM_SAWMILL", "HUM_BARRACKS", "HUM_ARCHERRANGE", "HUM_STABLE", "HUM_TOWER"
            WND_addNButtonToWindow $strWindow "BTN_SP_BLD1" "GRAY" 22 22 12 48 $False "" "LEFT" "GOLD" "FNK_SET_BUILDING" 1
            BTN_addImage $strWindow "BTN_SP_BLD1" "HUM_HOUSE_SMALL_1_0" 3 3 1
            WND_addNButtonToWindow $strWindow "BTN_SP_BLD2" "GRAY" 22 22 50 48 $False "" "LEFT" "GOLD" "FNK_SET_BUILDING" 2
            BTN_addImage $strWindow "BTN_SP_BLD2" "HUM_HOUSE_MEDIUM_1_0" 3 3 1
            WND_addNButtonToWindow $strWindow "BTN_SP_BLD3" "GRAY" 22 22 88 48 $False "" "LEFT" "GOLD" "FNK_SET_BUILDING" 3
            BTN_addImage $strWindow "BTN_SP_BLD3" "HUM_HOUSE_LARGE_1_0" 3 3 1
            WND_addNButtonToWindow $strWindow "BTN_SP_BLD4" "GRAY" 22 22 126 48 $False "" "LEFT" "GOLD" "FNK_SET_BUILDING" 4
            BTN_addImage $strWindow "BTN_SP_BLD4" "HUM_FARM_1_0" 3 3 1

            WND_addNButtonToWindow $strWindow "BTN_SP_BLD5" "GRAY" 22 22 12 74 $False "" "LEFT" "GOLD" "FNK_SET_BUILDING" 5
            BTN_addImage $strWindow "BTN_SP_BLD5" "HUM_FIELD_1_0" 3 3 1
            WND_addNButtonToWindow $strWindow "BTN_SP_BLD6" "GRAY" 22 22 50 74 $False "" "LEFT" "GOLD" "FNK_SET_BUILDING" 6
            BTN_addImage $strWindow "BTN_SP_BLD6" "HUM_MINE_1_0" 3 3 1
            WND_addNButtonToWindow $strWindow "BTN_SP_BLD7" "GRAY" 22 22 88 74 $False "" "LEFT" "GOLD" "FNK_SET_BUILDING" 7
            BTN_addImage $strWindow "BTN_SP_BLD7" "HUM_SAWMILL_1_0" 3 3 1

            WND_AddNLabelToWindow $strWindow "LBL_TITLE_BLD2" "CLR_WINDOW_BACK" 136 10 12 100 "Military Buildings" "CENTER" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_SP_BLD8" "GRAY" 22 22 12 112 $False "" "LEFT" "GOLD" "FNK_SET_BUILDING" 8
            BTN_addImage $strWindow "BTN_SP_BLD8" "HUM_BARRACKS_1_0" 3 3 1
            WND_addNButtonToWindow $strWindow "BTN_SP_BLD9" "GRAY" 22 22 50 112 $False "" "LEFT" "GOLD" "FNK_SET_BUILDING" 9
            BTN_addImage $strWindow "BTN_SP_BLD9" "HUM_TOWER_1_0" 3 3 1

            WND_AddNLabelToWindow $strWindow "LBL_SELECTED_BLD" "CLR_LBL_BACK_WND" 136 14 12 138 "---" "CENTER" "GOLD"

            WND_addNImageBoxToWindow $strWindow "IMB_GOLDCOIN" 18 18 12 158 "ICON_GOLDCOIN" 1 1 1
            WND_addNImageBoxToWindow $strWindow "IMB_WOOD" 18 18 12 176 "ICON_WOOD" 1 1 1
            WND_addNImageBoxToWindow $strWindow "IMB_FOOD" 18 18 12 194 "ICON_FOOD" 1 1 1
            WND_addNImageBoxToWindow $strWindow "IMB_PEOPLE" 18 18 12 212 "ICON_PEOPLE" 1 1 1

            WND_AddNLabelToWindow $strWindow "LBL_COST_GOLD" "CLR_WINDOW_BACK" 50 20 32 158 "- 0" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_COST_WOOD" "CLR_WINDOW_BACK" 50 20 32 176 "- 0" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_COST_FOOD" "CLR_WINDOW_BACK" 50 20 32 194 "- 0" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_COST_PEOPLE" "CLR_WINDOW_BACK" 50 20 32 212 "- 0" "RIGHT" "GOLD"

            WND_AddNLabelToWindow $strWindow "LBL_PROD_GOLD" "CLR_WINDOW_BACK" 50 20 96 158 "+ 0" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_PROD_WOOD" "CLR_WINDOW_BACK" 50 20 96 176 "+ 0" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_PROD_FOOD" "CLR_WINDOW_BACK" 50 20 96 194 "+ 0" "RIGHT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_PROD_PEOPLE" "CLR_WINDOW_BACK" 50 20 96 212 "+ 0" "RIGHT" "GOLD"

            WND_SP_addNextButtons $strWindow
        }
        "WND_SP_MENU_ARMY_N"
        {
            WND_addNButtonToWindow $strWindow "BTN_SP_BUILD" "GRAY" 22 20 12 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_SP_MENU_BUILDING_N"
            BTN_addImage $strWindow "BTN_SP_BUILD" "ICON_BUILD" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_ARMY" "RED" 22 20 50 12 $True "" "LEFT" "GOLD" "" ""
            BTN_addImage $strWindow "BTN_SP_ARMY" "ICON_ARMIES" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_WARES" "GRAY" 22 20 88 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_SP_MENU_WARES_N"
            BTN_addImage $strWindow "BTN_SP_WARES" "ICON_WARES" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_HOUSES" "GRAY" 22 20 126 12 $False "" "LEFT" "GOLD" "FNK_SP_SHOW_WINDOW" "WND_MENU_BUILDINGS"
            BTN_addImage $strWindow "BTN_SP_HOUSES" "ICON_HOUSES" 3 2 1

            WND_AddNLabelToWindow $strWindow "LBL_TITLE" "CLR_WINDOW_BACK" 136 10 12 34 "Army Management" "CENTER" "GOLD"

            for($i = 0; $i -lt 5; $i++)
            {
                WND_addNButtonToWindow $strWindow ("BTN_SP_SLEEP" + $i) "GRAY" 12 20 12 (48 + $i * 30) $False "" "LEFT" "GOLD" "FNK_SP_SWITCH_SLEEP" $i
                BTN_addImage $strWindow ("BTN_SP_SLEEP" + $i) "ICON_SLEEP" 2 2 1

                WND_addNButtonToWindow $strWindow ("BTN_SP_SELECT_ARMY" + $i) "GRAY" 124 20 24 (48 + $i * 30) $False "" "LEFT" "GOLD" "FNK_SP_SELECT_ARMY" $i

                WND_addNBarToWindow $strWindow ("BAR_SP_HP" + $i) 68 8 12 (68 + $i * 30) "" "CENTER" "GOLD" 1
                WND_addNBarToWindow $strWindow ("BAR_SP_MP" + $i) 68 8 80 (68 + $i * 30) "" "CENTER" "GOLD" 1 "CLR_MOVEPOINTS"
            }

            WND_addNButtonToWindow $strWindow "BTN_SP_ARMY_LIST_LEFTEND" "GRAY" 20 12 12 198 $False "" "CENTER" "GOLD" "FNK_SP_SETLISTOFFSET" "min"
            BTN_addImage $strWindow "BTN_SP_ARMY_LIST_LEFTEND" "ICON_ARROW_GOLD_LEFTEND_SMALL" 0 2 1
            WND_addNButtonToWindow $strWindow "BTN_SP_ARMY_LIST_LEFT" "GRAY" 20 12 32 198 $False "" "CENTER" "GOLD" "FNK_SP_SETLISTOFFSET" -5
            BTN_addImage $strWindow "BTN_SP_ARMY_LIST_LEFT" "ICON_ARROW_GOLD_LEFT_SMALL" 0 2 1

            WND_addNButtonToWindow $strWindow "BTN_SP_ARMY_LIST_RIGHT" "GRAY" 20 12 108 198 $False "" "CENTER" "GOLD" "FNK_SP_SETLISTOFFSET" 5
            BTN_addImage $strWindow "BTN_SP_ARMY_LIST_RIGHT" "ICON_ARROW_GOLD_RIGHT_SMALL" 2 2 1
            WND_addNButtonToWindow $strWindow "BTN_SP_ARMY_LIST_RIGHTEND" "GRAY" 20 12 128 198 $False "" "CENTER" "GOLD" "FNK_SP_SETLISTOFFSET" "max"
            BTN_addImage $strWindow "BTN_SP_ARMY_LIST_RIGHTEND" "ICON_ARROW_GOLD_RIGHTEND_SMALL" 2 2 1

            WND_AddNLabelToWindow $strWindow "LBL_SP_ARMY_LIST" "CLR_WINDOW_BACK" 56 12 52 198 "nnn-nnn" "CENTER" "GOLD"

            #WND_addNButtonToWindow $strWindow "BTN_SP_NEW_ARMY" "GRAY" 136 20 12 214 $False "New Army" "CENTER" "GOLD" "FNK_SP_SET_RECRUIT" ""
            WND_addNButtonToWindow $strWindow "BTN_SP_NEW_ARMY" "GRAY" 114 20 12 214 $False "New Army" "CENTER" "GOLD" "FNK_SP_SET_RECRUIT" ""
            BTN_addImage $strWindow "BTN_SP_NEW_ARMY" "ICON_PLUS" 2 2 1

            WND_addNButtonToWindow $strWindow "BTN_ARMY_HELP" "GRAY" 20 20 128 214 $False "" "" "GOLD" "FNK_SHOW_WINDOW" "WND_ARMY_HELP"
            BTN_addImage $strWindow "BTN_ARMY_HELP" "ICON_QUESTION" 2 2 1

            WND_SP_addNextButtons $strWindow
        }
        "WND_ARMY_HELP"
        {
            WND_AddNLabelToWindow $strWindow "LBL_TITLE" "CLR_WINDOW_BACK" 336 12 12 12 "+++ Information on Armies +++" "CENTER" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT01" "CLR_WINDOW_BACK" 336 12 12 24 "1) You may only recruit a new army 2 tiles" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT02" "CLR_WINDOW_BACK" 336 12 12 36 "   around a barracks" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT03" "CLR_WINDOW_BACK" 336 12 12 48 "2) You need 35 gold, 60 food and 5 people" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT04" "CLR_WINDOW_BACK" 336 12 12 60 "3) Movement points (MP) are gained each round" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT05" "CLR_WINDOW_BACK" 336 12 12 72 "4) Attacking costs 1 MP" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT06" "CLR_WINDOW_BACK" 336 12 12 84 "5) It's possible to merge armies, which" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT07" "CLR_WINDOW_BACK" 336 12 12 96 "   increases the level of an army" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT08" "CLR_WINDOW_BACK" 336 12 12 108 "6) Armies deal 3 Damage and have 1 HP" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT09" "CLR_WINDOW_BACK" 336 12 12 120 "   for each level" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT10" "CLR_WINDOW_BACK" 336 12 12 132 "7) Attacking armies deal 100% damage" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_RECRUIT11" "CLR_WINDOW_BACK" 336 12 12 144 "8) Defending armies deal 50% damage" "LEFT" "GOLD"

            WND_addNButtonToWindow $strWindow "BTN_CLOSE" "RED" 136 20 112 188 $False "Close" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_SP_MENU_ARMY_N"
        }
        "WND_TILEINFO_BUILDING_N"
        {
            WND_AddNLabelToWindow $strWindow "LBL_TITLE" "CLR_WINDOW_BACK" 136 10 12 12 "NAME_BLD" "CENTER" "GOLD"

            WND_addNBarToWindow $strWindow "BAR_HP" 136 20 12 30 "TEXT" "CENTER" "GOLD" 1
            WND_addNBarToWindow $strWindow "BAR_PROGRESS" 136 20 12 50 "TEXT" "CENTER" "GOLD" 1 "CLR_BUILDING"
            WND_addNImageBoxToWindow $strWindow "IMB_BUILDING" 64 64 48 76 "HUM_HOUSE_SMALL_00" 0 0 4

            WND_addNButtonToWindow $strWindow "BTN_SP_TILEINFO_DESTROY" "RED" 22 22 12 118 $False "" "CENTER" "GOLD" "FNK_SP_TILEINFO_DESTROY" ""
            BTN_addImage $strWindow "BTN_SP_TILEINFO_DESTROY" "ICON_BOMB" 3 3 1

            WND_addNButtonToWindow $strWindow "BTN_SP_TILEINFO_BUILDING" "GRAY" 64 20 12 214 $True "Building" "CENTER" "GOLD" "" ""
            WND_addNButtonToWindow $strWindow "BTN_SP_TILEINFO_ARMY" "GRAY" 64 20 84 214 $False "Army" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_TILEINFO_ARMY_N"
            WND_addNButtonToWindow $strWindow "BTN_SP_TILEINFO_CLOSE" "GRAY" 136 20 12 238 $False "Close" "CENTER" "GOLD" "FNK_SP_CLOSE_TILEINFO" ""
        }
        "WND_TILEINFO_ARMY_N"
        {
            WND_AddNLabelToWindow $strWindow "LBL_TITLE" "CLR_WINDOW_BACK" 136 10 12 12 "NAME_ARMY" "CENTER" "GOLD"
            WND_addNBarToWindow $strWindow "BAR_HP" 136 20 12 30 "HEALTH: n/n" "CENTER" "GOLD" 1
            WND_addNBarToWindow $strWindow "BAR_MP" 136 20 12 50 " RANGE: n/n" "CENTER" "GOLD" 1 "CLR_BUILDING"

            WND_addNImageBoxToWindow $strWindow "IMB_ARMY" 64 64 48 76 "HUM_UNIT_0" 0 0 4
            WND_addNButtonToWindow $strWindow "BTN_TILEINFO_SLEEP" "GRAY" 22 22 12 118 $False "" "CENTER" "GOLD" "FNK_ARMY_SWITCH_SLEEP" ""
            BTN_addImage $strWindow "BTN_TILEINFO_SLEEP" "ICON_SLEEP" 7 3 1

            WND_AddNLabelToWindow $strWindow "LBL_LEVEL" "CLR_WINDOW_BACK" 136 12 12 150 "Level   : nnnn" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_POSITION" "CLR_WINDOW_BACK" 136 12 12 162 "Position: nnn|nnn" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_ID" "CLR_WINDOW_BACK" 136 12 12 174 "Index   : nnnn" "LEFT" "GOLD"

            WND_addNButtonToWindow $strWindow "BTN_TILEINFO_BUILDING" "GRAY" 64 20 12 214 $False "Building" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_TILEINFO_BUILDING_N"
            WND_addNButtonToWindow $strWindow "BTN_TILEINFO_ARMY" "GRAY" 64 20 84 214 $True "Army" "CENTER" "GOLD" "" ""
            WND_addNButtonToWindow $strWindow "BTN_TILEINFO_CLOSE" "GRAY" 136 20 12 238 $False "Close" "CENTER" "GOLD" "FNK_SP_CLOSE_TILEINFO" ""
        }
        "WND_ESC_SINGLEPLAYER_N"
        {
            WND_addNButtonToWindow $strWindow "BTN_SP_SAVE_GAME" "GRAY" 136 20 12 12 $False "Save" "CENTER" "GOLD" "" ""
            BTN_setDisabledState $strWindow "BTN_SP_SAVE_GAME" $True
            WND_addNButtonToWindow $strWindow "BTN_SP_LOAD_GAME" "GRAY" 136 20 12 38 $False "Load" "CENTER" "GOLD" "" ""
            BTN_setDisabledState $strWindow "BTN_SP_LOAD_GAME" $True
            WND_addNButtonToWindow $strWindow "BTN_SP_SURRENDER" "GRAY" 136 20 12 66 $False "Surrender" "CENTER" "GOLD" "" ""
            BTN_setDisabledState $strWindow "BTN_SP_SURRENDER" $True


            WND_addNButtonToWindow $strWindow "BTN_SP_BACK" "GREEN" 136 20 12 140 $False "Back" "CENTER" "GOLD" "FNK_SP_BACK"
            WND_addNButtonToWindow $strWindow "BTN_SP_QUIT" "RED" 136 20 12 168 $False "Quit" "CENTER" "GOLD" "FNK_SP_QUIT"
        }
        "WND_WAIT_INIT_CLICK_N"
        {
            WND_AddNLabelToWindow $strWindow "LBL_TEXT" "CLR_WINDOW_BACK" 136 20 12 10 "Click to Start" "CENTER" "GOLD"
        }
        "WND_MULTIPLAYER_SERVER"
        {
            WND_AddNLabelToWindow $strWindow "LBL_MP_MAP" "CLR_WINDOW_BACK" 78 20 12 12   "Map:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_MP_OPENMAP" "GRAY" 338 20 90 12 $False "Open Map..." "LEFT" "GOLD" "FNK_MP_OPENMAP" ""

            WND_AddNLabelToWindow $strWindow "LBL_MP_PLAYERS_TEXT" "CLR_WINDOW_BACK" 78 20 12 38 "Players:" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_MP_PLAYERS" "CLR_WINDOW_BACK" 136 20 90 38 "-" "LEFT" "GOLD"
            
            WND_AddNLabelToWindow $strWindow "LBL_MP_AUTHOR_TEXT" "CLR_WINDOW_BACK" 78 20 12 64 "Author:" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_MP_AUTHOR" "CLR_WINDOW_BACK" 136 20 90 64 "-" "LEFT" "GOLD"
            
            WND_AddNLabelToWindow $strWindow "LBL_MP_SIZE_TEXT" "CLR_WINDOW_BACK" 78 20 12 90 "Size:" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_MP_SIZE" "CLR_WINDOW_BACK" 136 20 90 90 "-" "LEFT" "GOLD"

            WND_AddNLabelToWindow $strWindow "LBL_FOW_TEXT" "CLR_WINDOW_BACK" 78 20 12 116 "FoW:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_FOW_TOGGLE" "RED" 40 20 90 116 $False "Off" "CENTER" "GOLD" "FNK_SWITCH_FOW" ""

            # as generating a good preview would need more coding
            # this is excluded for now, was never really helpfull as it should have taken n-tiles depending on map size for shading
            #WND_AddNLabelToWindow $strWindow "LBL_FP_PREVIEW_TEXT" "CLR_WINDOW_BACK" 78 20 12 116 "Preview:" "LEFT" "GOLD"
            #WND_addNImageBoxToWindow $strWindow "IMB_FP_PREVIEW" 32 32 90 116 "GROUND_EMPTY_01" 0 0 2
            #IMB_setHidden $strWindow "IMB_FP_PREVIEW" $True

            for($i = 0; $i -lt 4; $i++)
            {
                WND_addNButtonToWindow $strWindow ("BTN_MP_PLAYER" + $i) "RED" 136 20 292 (38 + $i *26) $False "Closed" "LEFT" "GOLD" "FNK_MP_SWITCH_PLAYERTYPE" ($i + 1)
                BTN_setDisabledState $strWindow ("BTN_MP_PLAYER" + $i) $True
            
                WND_AddNLabelToWindow $strWindow ("LBL_MP_TEXT_PLAYER" + $i) "CLR_WINDOW_BACK" 60 10 230 (38 + $i *26) ("Player " + ($i + 1)) "LEFT" "GOLD"
                WND_AddNLabelToWindow $strWindow ("LBL_MP_TEXT_PLAYERCLR" + $i) ("CLR_PLAYER_" + ($i + 1) + "1") 60 10 230 (48 + $i * 26) "" "LEFT" "GOLD"
            }

            WND_addNButtonToWindow $strWindow "BTN_MP_BACK" "RED" 136 20 12 188 $False "Back" "CENTER" "GOLD" "FNK_MP_CLOSE_SERVER" ""
            WND_addNButtonToWindow $strWindow "BTN_FP_START" "GRAY" 136 20 292 188 $False "Start" "CENTER" "GOLD" "FNK_MP_START" ""
        }
        "WND_MULTIPLAYER_CLIENT"
        {
            WND_AddNLabelToWindow $strWindow "LBL_MP_MAP" "CLR_WINDOW_BACK" 78 20 12 12   "Map:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_MP_OPENMAP" "GRAY" 338 20 90 12 $False "" "LEFT" "GOLD"
            BTN_setDisabledState $strWindow "BTN_MP_OPENMAP" $True

            WND_AddNLabelToWindow $strWindow "LBL_MP_PLAYERS_TEXT" "CLR_WINDOW_BACK" 78 20 12 38 "Players:" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_MP_PLAYERS" "CLR_WINDOW_BACK" 136 20 90 38 "-" "LEFT" "GOLD"
            
            WND_AddNLabelToWindow $strWindow "LBL_MP_AUTHOR_TEXT" "CLR_WINDOW_BACK" 78 20 12 64 "Author:" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_MP_AUTHOR" "CLR_WINDOW_BACK" 136 20 90 64 "-" "LEFT" "GOLD"
            
            WND_AddNLabelToWindow $strWindow "LBL_MP_SIZE_TEXT" "CLR_WINDOW_BACK" 78 20 12 90 "Size:" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_MP_SIZE" "CLR_WINDOW_BACK" 136 20 90 90 "-" "LEFT" "GOLD"

            WND_AddNLabelToWindow $strWindow "LBL_FOW_TEXT" "CLR_WINDOW_BACK" 78 20 12 116 "FoW:" "LEFT" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_FOW_TOGGLE" "RED" 40 20 90 116 $False "Off" "CENTER" "GOLD" "" ""
            BTN_setDisabledState $strWindow "BTN_FOW_TOGGLE" $True

            for($i = 0; $i -lt 4; $i++)
            {
                WND_addNButtonToWindow $strWindow ("BTN_MP_PLAYER" + $i) "RED" 136 20 292 (38 + $i *26) $False "Closed" "LEFT" "GOLD"
                BTN_setDisabledState $strWindow ("BTN_MP_PLAYER" + $i) $True
            
                WND_AddNLabelToWindow $strWindow ("LBL_MP_TEXT_PLAYER" + $i) "CLR_WINDOW_BACK" 60 10 230 (38 + $i *26) ("Player " + ($i + 1)) "LEFT" "GOLD"
                WND_AddNLabelToWindow $strWindow ("LBL_MP_TEXT_PLAYERCLR" + $i) ("CLR_PLAYER_" + ($i + 1) + "1") 60 10 230 (48 + $i * 26) "" "LEFT" "GOLD"
            }

            WND_addNButtonToWindow $strWindow "BTN_MP_BACK" "RED" 136 20 12 188 $False "Back" "CENTER" "GOLD" "FNK_MP_CLOSE_CLIENT" ""
        }
        "WND_MULTIPLAYER_TYPESELECTION"
        {
            WND_addNButtonToWindow $strWindow "BTN_NEW_SERVER" "GRAY" 136 20 12 12 $False "Open Server" "CENTER" "GOLD" "FNK_MP_SETUP_WINDOW"
            WND_addNButtonToWindow $strWindow "BTN_LOAD_MULTIPLAYER" "GRAY" 136 20 12 38 $False "Load Game" "CENTER" "GOLD"
            BTN_setDisabledState $strWindow "BTN_LOAD_MULTIPLAYER" $True

            WND_addNButtonToWindow $strWindow "BTN_JOIN" "GRAY" 136 20 12 64 $False "Join Game" "CENTER" "GOLD" "FNK_MP_JOIN_GAME" ""

            WND_AddNLabelToWindow $strWindow "LBL_MULTIPLAYER_IP" "CLR_WINDOW_BACK" 136 10 12 90 "IP:" "LEFT" "GOLD"
            WND_addNInputToWindow $strWindow "INP_MULTIPLAYER_IP" 136 20 12 100 ([string]$global:arrSettings["MP_LASTIP"]) "LEFT" 15 "FNK_LEAVE_MP_IP"

            WND_AddNLabelToWindow $strWindow "LBL_MULTIPLAYER_PORT" "CLR_WINDOW_BACK" 136 10 12 126 "Port:" "LEFT" "GOLD"
            WND_addNInputToWindow $strWindow "INP_MULTIPLAYER_PORT" 136 20 12 136 ([string]$global:arrSettings["MP_LASTPORT"]) "LEFT" 5 "FNK_LEAVE_MP_PORT"


            WND_addNButtonToWindow $strWindow "BTN_BACK" "RED" 136 20 12 168 $False "Back" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_ESC_MAIN_N"
        }
        "WND_MP_ERRORS"
        {
            WND_AddNLabelToWindow $strWindow "LBL_MESSAGE" "CLR_WINDOW_BACK" 296 12 12 12 "Error!" "CENTER" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_MP_ERROR_OK" "GRAY" 136 20 92 24 $False "Ok" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_MULTIPLAYER_TYPESELECTION"
        }
        "WND_SERVER_ERRORS"
        {
            WND_AddNLabelToWindow $strWindow "LBL_MESSAGE" "CLR_WINDOW_BACK" 296 12 12 12 "Error!" "CENTER" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_MP_ERROR_OK" "GRAY" 136 20 92 24 $False "Ok" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_MULTIPLAYER_SERVER"
        }
        "WND_CLIENT_WAITING"
        {
            WND_AddNLabelToWindow $strWindow "LBL_PLEASE_WAIT" "CLR_WINDOW_BACK" 136 12 12 20 "Please wait..." "CENTER" "GOLD"
        }
        "WND_CLIENT_WAITINGFOR"
        {
            WND_AddNLabelToWindow $strWindow "LBL_NEXT_PLAYER_TEXT" "CLR_WINDOW_BACK" 136 12 12 20 "Active Player:" "CENTER" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_NEXT_PLAYER_COLOR" ("CLR_PLAYER_" + [string]($global:arrPlayerInfo.currentplayer) + "1") 52 92 54 54 "" "LEFT" "GOLD"
            WND_AddNLabelToWindow $strWindow "LBL_NEXT_PLAYER_NAME" "CLR_WINDOW_BACK" 136 12 12 160 ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][0]) "CENTER" "GOLD"
        }
        "WND_SERVER_WAITING"
        {
            WND_AddNLabelToWindow $strWindow "LBL_WAITING_FOR" "CLR_WINDOW_BACK" 136 12 12 20 "Waiting for: " "CENTER" "GOLD"

            WND_AddNLabelToWindow $strWindow "LBL_PLR01" "CLR_WINDOW_BACK" 136 12 12 32 $global:arrSettings["PLAYER_NAME"] "LEFT" "GREEN"

            for($i = 2; $i -le 4; $i++)
            {
                if($global:arrPlayerInfo[$i][5] -eq 2)
                {
                    $plrAdress = $global:arrPlayerInfo[$i][10]
                    $plrName = $global:arrMultiplayer.Server.Clients[$plrAdress].Name
                    WND_AddNLabelToWindow $strWindow ("LBL_PLR0" + $i) "CLR_WINDOW_BACK" 136 12 12 (20 + 12 * $i) $plrName "LEFT" "RED"
                }
            }

            WND_addNButtonToWindow $strWindow "BTN_CONTINUE" "GRAY" 136 20 12 238 $False "Continue" "CENTER" "GOLD" "FNK_MP_SERVER_START_INGAME" ""
            BTN_setDisabledState $strWindow "BTN_CONTINUE" $True
        }
        "WND_CREDITS_N"
        {
            # TODO: This should be a function call for use in missions

            $lines = 14;
            $linelength = (360 - 24 - 4)
            $charsPerLine = [math]::Floor($linelength / 7)
            
            #Write-Host "Lines: $lines LineLength: $linelength CharsPerLine: $charsPerLine"

            $arrTextLines = (WND_splitText (getText "LICENSE") $charsPerLine)

            $pageOffset = 0

            #Write-Host "IsFirst:$isFirstPage IsLast:$isLastPage Page:$pageNumber"

            for($pn = 0; $pn -lt ([math]::Ceiling($arrTextLines.Count / $lines)); $pn++)
            {
                $isFirstPage = ($pageOffset -eq 0)
                $isLastPage = (($pageOffset * $lines) + $lines -ge $arrTextLines.Count)
                $pageNumber = ($pageOffset + 1)

                $wnd = $strWindow

                if($pn -ne 0)
                {
                    $wnd = $strWindow + $pn
                    buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $wnd
                }

                $prevName = ($strWindow + ($pn - 1))
                if($pn -eq 1) {$prevName = $strWindow}

                WND_addNButtonToWindow $wnd "BTN_PREV_PAGE" "GRAY" 30 20 248 188 $False "" "CENTER" "GOLD" "FNK_SHOW_WINDOW" $prevName
                BTN_addImage $wnd "BTN_PREV_PAGE" "ICON_ARROW_GOLD_LEFT" 7 2 1
                WND_addNButtonToWindow $wnd "BTN_NEXT_PAGE" "GRAY" 30 20 318 188 $False "" "CENTER" "GOLD" "FNK_SHOW_WINDOW" ($strWindow + ($pn + 1))
                BTN_addImage $wnd "BTN_NEXT_PAGE" "ICON_ARROW_GOLD_RIGHT" 7 2 1
                if($isFirstPage)
                {
                    BTN_setDisabledState $wnd "BTN_PREV_PAGE" $True
                }

                if($isLastPage)
                {
                    BTN_setDisabledState $wnd "BTN_NEXT_PAGE" $True
                }

                WND_AddNLabelToWindow $wnd "LBL_PAGE" "CLR_WINDOW_BACK" 40 20 278 188 ("" + $pageNumber + "/" + ([math]::Ceiling($arrTextLines.Count / $lines))) "CENTER" "GOLD"

                for($j = 0; $j -lt $lines; $j++)
                {
                    $strTextLine = $arrTextLines[($pageOffset * $lines + $j)]
                    if(!$strTextLine -or $strTextLine -eq "") {$strTextLine = ""}
                    WND_AddNLabelToWindow $wnd ("LBL_LINE_" + $j)  "CLR_WINDOW_BACK" 336 12 12 (12 + $j * 12) $strTextLine "LEFT" "GOLD"
                }

                $pageOffset = $pageOffset + 1

                WND_addNButtonToWindow $wnd "BTN_BACK" "RED" 136 20 12 188 $False "Back" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_ESC_MAIN_N"
            }
        }
        "WND_CAMPAIGN_SELECT"
        {
            #buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType
            CMP_loadCampaigns

            Write-Host "Campaign Count: " $global:Campaigns.Count
            Write-Host "Campaign Count: " $global:Campaigns.data.Count
            ### Whats TODO: ###
            # if Campaign < 6, hide buttons
            # if Campaign > 6, create pages
            # if Campaign == 6, well, create no pages but show buttons
            # set name of buttons

            $campPerPage = 6
            $pageOffset = 0

            for($pn = 0; $pn -lt ([math]::Ceiling($global:Campaigns.data.Count / $campPerPage)); $pn++)
            {
                $isFirstPage = ($pageOffset -eq 0)
                $isLastPage = (($pageOffset * $campPerPage) + $campPerPage -ge $global:Campaigns.data.Count)
                $pageNumber = ($pageOffset + 1)

                $wnd = $strWindow

                if($pn -ne 0)
                {
                    $wnd = $strWindow + $pn
                    buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $wnd
                }

                $prevName = ($strWindow + ($pn - 1))
                if($pn -eq 1) {$prevName = $strWindow}

                Write-Host "WND   : $wnd"
                Write-Host "First : $isFirstPage"
                Write-Host "Last  : $isLastPage"
                Write-Host "Number: $pageNumber"

                for($i = 0; $i -lt $campPerPage; $i++)
                {
                    Write-Host "ID: " ($pageOffset * $campPerPage + $i)
                    Write-Host "CAmpaigns: " ($global:Campaigns.data.Count)

                    if($pageOffset * $campPerPage + $i -ge $global:Campaigns.data.Count) {break}

                    WND_addNButtonToWindow $wnd ("BTN_CAMPAIGN_" + ($pageOffset * $campPerPage + $i)) "GRAY" 136 20 12 (12 + $i * 24) $False ($global:Campaigns.data[($pageOffset * $campPerPage + $i)]["TITLE"].Replace("_", " ")) "LEFT" "GOLD" "FNK_SELECT_CAMPAIGN" ($pageOffset * $campPerPage + $i)
                }
                
                for($i = 0; $i -lt 12; $i++)
                {
                    WND_AddNLabelToWindow $wnd ("LBL_LINE_" + $i)  "CLR_WINDOW_BACK" 196 12 152 (12 + $i * 12) "" "LEFT" "GOLD"
                }

                WND_addNButtonToWindow $wnd "BTN_PREV_PAGE" "GRAY" 30 20 12 156 $False "" "CENTER" "GOLD" "FNK_SHOW_WINDOW_CAMPAIGNSELECT" $prevName
                BTN_addImage $wnd "BTN_PREV_PAGE" "ICON_ARROW_GOLD_LEFT" 7 2 1
                WND_addNButtonToWindow $wnd "BTN_NEXT_PAGE" "GRAY" 30 20 118 156 $False "" "CENTER" "GOLD" "FNK_SHOW_WINDOW_CAMPAIGNSELECT" ($strWindow + ($pn + 1))
                BTN_addImage $wnd "BTN_NEXT_PAGE" "ICON_ARROW_GOLD_RIGHT" 7 2 1
                if($isFirstPage)
                {
                    BTN_setDisabledState $wnd "BTN_PREV_PAGE" $True
                }

                if($isLastPage)
                {
                    BTN_setDisabledState $wnd "BTN_NEXT_PAGE" $True
                }

                WND_AddNLabelToWindow $wnd "LBL_PAGE" "CLR_WINDOW_BACK" 76 20 42 156 ("" + $pageNumber + "/" + ([math]::Ceiling($global:Campaigns.data.Count / $campPerPage))) "CENTER" "GOLD"


                WND_addNButtonToWindow $wnd "BTN_BACK" "RED" 136 20 12 188 $False "Back" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_SINGLEPLAYER_TYPESELECTION_N"

                WND_addNButtonToWindow $wnd "BTN_CONTINUE" "GRAY" 136 20 212 188 $False "Continue" "CENTER" "GOLD" "FNK_LOAD_CAMPAIGN" ""
                #BTN_setDisabledState $wnd "BTN_CONTINUE" $True

                $pageOffset = $pageOffset + 1
            }
        }
        "WND_CAMPAIGN_SELECT_MAP"
        {
            WND_AddNLabelToWindow $strWindow "LBL_TITLE" "CLR_WINDOW_BACK" 336 20 12 12 "CAMPAIGN_TITLE" "CENTER" "GOLD"

            for($i = 0; $i -lt 12; $i++)
            {
                $col = [math]::Floor($i / 6)
                $id = ($i - $col * 6)

                WND_addNButtonToWindow $strWindow ("BTN_SELECT_MAP" + $i) "GRAY" 166 20 (12 + $col * 170) (36 + $id * 24) $False ("MAP_" + $i) "CENTER" "GOLD" "FNK_CAMPAIGN_SELECT_MAP" $i
            }

            WND_addNButtonToWindow $strWindow "BTN_BACK" "RED" 136 20 12 188 $False "Back" "CENTER" "GOLD" "FNK_SHOW_WINDOW" "WND_CAMPAIGN_SELECT"

            WND_addNButtonToWindow $strWindow "BTN_START" "GREEN" 136 20 212 188 $False "Start" "CENTER" "GOLD" "FNK_CAMPAIGN_START" ""
        }
        "WND_LOSE_GAME"
        {
            WND_AddNLabelToWindow $strWindow "LBL_TEXT" "CLR_WINDOW_BACK" 136 20 12 12 "You lose!" "CENTER" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_SP_QUIT" "RED" 136 20 12 60 $False "Leave Game" "CENTER" "GOLD" "FNK_SP_QUIT"
        }
        "WND_WIN_GAME"
        {
            WND_AddNLabelToWindow $strWindow "LBL_TEXT" "CLR_WINDOW_BACK" 136 20 12 12 "You win!" "CENTER" "GOLD"
            WND_addNButtonToWindow $strWindow "BTN_SP_BACK" "GRAY" 136 20 12 36 $False "Continue" "CENTER" "GOLD" "FNK_SP_BACK"
            WND_addNButtonToWindow $strWindow "BTN_SP_QUIT" "RED" 136 20 12 60 $False "Leave Game" "CENTER" "GOLD" "FNK_SP_QUIT"
        }
        "WND_ESC_MP_CLIENT"
        {
            WND_addNButtonToWindow $strWindow "BTN_MP_SAVE_GAME" "GRAY" 136 20 12 12 $False "Save" "CENTER" "GOLD" "" ""
            BTN_setDisabledState $strWindow "BTN_MP_SAVE_GAME" $True
            WND_addNButtonToWindow $strWindow "BTN_MP_SURRENDER" "GRAY" 136 20 12 38 $False "Surrender" "CENTER" "GOLD" "" ""
            BTN_setDisabledState $strWindow "BTN_MP_SURRENDER" $True

            WND_addNButtonToWindow $strWindow "BTN_SP_BACK" "GREEN" 136 20 12 140 $False "Back" "CENTER" "GOLD" "FNK_MP_CLIENT_BACK"
            WND_addNButtonToWindow $strWindow "BTN_MP_DISCONNECT" "RED" 136 20 12 168 $False "Disconnect" "CENTER" "GOLD" "FNK_MP_CLIENT_QUIT"
        }
        "WND_ESC_MP_SERVER"
        {
            WND_addNButtonToWindow $strWindow "BTN_MP_SAVE_GAME" "GRAY" 136 20 12 12 $False "Save" "CENTER" "GOLD" "" ""
            BTN_setDisabledState $strWindow "BTN_MP_SAVE_GAME" $True
            WND_addNButtonToWindow $strWindow "BTN_MP_SURRENDER" "GRAY" 136 20 12 38 $False "Surrender" "CENTER" "GOLD" "" ""
            BTN_setDisabledState $strWindow "BTN_MP_SURRENDER" $True
            WND_AddNLabelToWindow $strWindow "LBL_KICK" "CLR_WINDOW_BACK" 136 10 12 60 "Kick:" "LEFT" "GOLD"

            WND_addNButtonToWindow $strWindow "BTN_MP_KICK0" "GRAY" 136 20 12 72 $False "Kick #1" "CENTER" "GOLD" "FNK_MP_KICK" "2"
            BTN_setDisabledState $strWindow "BTN_MP_KICK0" $True
            WND_addNButtonToWindow $strWindow "BTN_MP_KICK1" "GRAY" 136 20 12 92 $False "Kick #2" "CENTER" "GOLD" "FNK_MP_KICK" "3"
            BTN_setDisabledState $strWindow "BTN_MP_KICK1" $True
            WND_addNButtonToWindow $strWindow "BTN_MP_KICK2" "GRAY" 136 20 12 112 $False "Kick #3" "CENTER" "GOLD" "FNK_MP_KICK" "4"
            BTN_setDisabledState $strWindow "BTN_MP_KICK2" $True

            WND_addNButtonToWindow $strWindow "BTN_SP_BACK" "GREEN" 136 20 12 140 $False "Back" "CENTER" "GOLD" "FNK_MP_SERVER_BACK"
            WND_addNButtonToWindow $strWindow "BTN_MP_DISCONNECT" "RED" 136 20 12 168 $False "Disconnect" "CENTER" "GOLD" "FNK_MP_SERVER_QUIT"
        }
    }

    $global:arrWindows.isInitializing = $False
    WND_redrawNWindow $strWindow ""
}

function WND_fillBuildingData()
{
    $owner = $global:arrPlayerInfo.currentplayer
    $bldCount = @{}

    for($i = 0; $i -lt $global:arrBuildingIDToKey.Count; $i++)
    {
        $bldCount[$i] = 0
        $bldCount[($i + $global:arrBuildingIDToKey.Count)] = 0
    }

    for($i = 0; $i -lt $global:arrMap["BUILDING_INDEX"]; $i++)
    {
        if(!($global:arrBuildings[$i])){continue}

        if($global:arrBuildings[$i][2] -ne $owner) {continue}

        if($global:arrBuildings[$i][4] -eq 1)
        {
            $bldCount[($global:arrBuildings[$i][3])] = $bldCount[($global:arrBuildings[$i][3])] + 1
        }
        else
        {
            $bldCount[($global:arrBuildings[$i][3] + $global:arrBuildingIDToKey.Count)] = $bldCount[($global:arrBuildings[$i][3] + $global:arrBuildingIDToKey.Count)] + 1
        }
    }

    for($i = 0; $i -lt $global:arrBuildingIDToKey.Count; $i++)
    {
        IMB_setImage "WND_MENU_BUILDINGS" ("IMB_HOUSE" + $i) ($global:arrBuildingIDToKey[$i] + "_" + $owner + "_0")
        IMB_setImage "WND_MENU_BUILDINGS" ("IMB_SITE" + $i) ($global:arrBuildingIDToKey[$i] + "_" + $owner + "_1")

        LBL_setText "WND_MENU_BUILDINGS" ("LBL_HOUSE" + $i) ("" + $bldCount[$i])
        LBL_setText "WND_MENU_BUILDINGS" ("LBL_SITE" + $i) ("" + $bldCount[($i + $global:arrBuildingIDToKey.Count)])
    }
}

function WND_splitText($objText, $charsPerLine)
{
    Write-Host "WND_splitText($objText, $charsPerLine)"

    $arrTextLines = @{}

    $varType = $objText.GetType()

    $strText = ""

    if($varType -eq [string])
    {
        $strText = $objText
    }
    elseif($varType -eq [System.Object[]])
    {
        for($i = 0; $i -lt $objText.Count; $i++)
        {
            if($strText -ne "") {$strText = $strText + " \n "}
            $strText = $strText + $objText[$i]
        }
    }
    elseif($varType -eq [hashtable])
    {
        for($i = 0; $i -lt $objText.Count; $i++)
        {
            if($strText -ne "") {$strText = $strText + " \n "}
            $strText = $strText + $objText[$i]
        }
    }
    else
    {
        Write-Host "It's a: $varType"
    }

    $arrSplitText = $strText.Split(" ")

    $lineText = ""
    $charCount = 0

    for($i = 0; $i -lt $arrSplitText.Count; $i++)
    {
        #Write-Host "$i -> " $arrSplitText[$i] " ($charCount) C:" $arrTextLines.Count

        #Write-Host "Line(C:$charCount): $lineText"

        if($arrSplitText[$i] -eq "\n")
        {
            $charCount = 0;
            $arrTextLines[($arrTextLines.Count)] = $lineText
            $lineText = ""
        }
        elseif($charCount + 1 + $arrSplitText[$i].Length -gt $charsPerLine)
        {
            $arrTextLines[($arrTextLines.Count)] = $lineText
            $lineText = $arrSplitText[$i]
            $charCount = $arrSplitText[$i].Length;
        }
        else
        {
            if($charCount -ne 0)
            {
                $charCount = $charCount + 1;
                $lineText = $lineText + " "
            }

            $charCount = $charCount + $arrSplitText[$i].Length;
            $lineText = $lineText + $arrSplitText[$i]
        }
    }

    if($lineText -ne "")
    {
        $arrTextLines[($arrTextLines.Count)] = $lineText
    }

    return $arrTextLines
}

function WND_SP_setActiveBuilding($active, $bldID)
{
    LBL_setText $strWindow "LBL_COST_GOLD" "- 0"
    LBL_setText $strWindow "LBL_COST_WOOD" "- 0"
    LBL_setText $strWindow "LBL_COST_FOOD" "- 0"
    LBL_setText $strWindow "LBL_COST_PEOPLE" "- 0"

    LBL_setText $strWindow "LBL_PROD_GOLD" "+ 0"
    LBL_setText $strWindow "LBL_PROD_WOOD" "+ 0"
    LBL_setText $strWindow "LBL_PROD_FOOD" "+ 0"
    LBL_setText $strWindow "LBL_PROD_PEOPLE" "+ 0"
}

function WND_SP_setWaresValues($playerID)
{
    $strWindow = "WND_SP_MENU_WARES_N"
    
    LBL_setText $strWindow "LBL_AMOUNT_GOLD" ($global:arrPlayerInfo[$playerID][6])
    LBL_setText $strWindow "LBL_AMOUNT_WOOD" ($global:arrPlayerInfo[$playerID][7])
    LBL_setText $strWindow "LBL_AMOUNT_FOOD" ($global:arrPlayerInfo[$playerID][8])
    LBL_setText $strWindow "LBL_AMOUNT_PEOPLE" ($global:arrPlayerInfo[$playerID][9])
    
    LBL_setText $strWindow "LBL_PROD_GOLD" ($global:arrPlayerInfo[$playerID][1])
    LBL_setText $strWindow "LBL_PROD_WOOD" ($global:arrPlayerInfo[$playerID][2])
    LBL_setText $strWindow "LBL_PROD_FOOD" ($global:arrPlayerInfo[$playerID][3])
    LBL_setText $strWindow "LBL_PROD_PEOPLE" ($global:arrPlayerInfo[$playerID][4])
}

function WND_SP_addNextButtons($strWindow)
{
    WND_addNButtonToWindow $strWindow "BTN_SP_NEXT_UNIT" "GRAY" 64 20 12 238 $False "" "LEFT" "GOLD" "FNK_SP_NEXT_UNIT" ""
    BTN_addImage $strWindow "BTN_SP_NEXT_UNIT" "ICON_ARROW_GOLD_RIGHT" 4 2 1
    BTN_addImage $strWindow "BTN_SP_NEXT_UNIT" "ICON_ARMY" 24 2 1
    BTN_addImage $strWindow "BTN_SP_NEXT_UNIT" "ICON_ARROW_GOLD_LEFT" 44 2 1

    WND_addNButtonToWindow $strWindow "BTN_SP_END_TURN" "GRAY" 64 20 84 238 $False "" "LEFT" "GOLD" "FNK_SP_END_TURN" ""
    BTN_addImage $strWindow "BTN_SP_END_TURN" "ICON_HOURGLAS" 4 2 1
    BTN_addImage $strWindow "BTN_SP_END_TURN" "ICON_ARROW_GOLD_RIGHT" 24 2 1
    BTN_addImage $strWindow "BTN_SP_END_TURN" "ICON_ARROW_GOLD_RIGHT" 44 2 1

}

#region FUNCTION SCALEGAME
function scaleGame($scaleUp)
{
    $currentFactor = ($objForm.Size.Width - $wndOffsetX)  / ($DrawingSizeX)
    $newFactor = 1
    
    if($currentFactor -ge 3) {$newFactor = 3}
    elseif($currentFactor -le 1) {$newFactor = 1}
    else 
    {
        if($scaleUp) {$newFactor = [math]::Ceiling($currentFactor)}
        else {$newFactor = [math]::Floor($currentFactor)}
    }
    
    $pictureBox.Size = New-Object System.Drawing.Size(($newFactor * $DrawingSizeX), ($newFactor * $DrawingSizeY))
    $objForm.size = New-Object System.Drawing.Size(($newFactor * $DrawingSizeX + $wndOffsetX), ($newFactor * $DrawingSizeY + $wndOffsetY))
    $global:arrSettings["SIZE"] = $currentFactor
}
#endregion

# this function generates an empty background
function generateBackgroundImage()
{
    $tilesX = [math]::Ceiling($DrawingSizeX / $global:arrSettingsInternal["TILESIZE"])
    $tilesY = [math]::Ceiling($DrawingSizeY / $global:arrSettingsInternal["TILESIZE"])

    $tmp_grd = [System.Drawing.Graphics]::FromImage($global:objWorldBackground);

    for($i = 0; $i -lt $tilesX; $i++)
    {
        for($j = 0; $j -lt $tilesY; $j++)
        {
            $rect_dst = New-Object System.Drawing.Rectangle(($i * $global:arrSettingsInternal["TILESIZE"]), ($j * $global:arrSettingsInternal["TILESIZE"]), $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"])
            $tmp_grd.DrawImage($global:arrTextures["GROUND_EMPTY_01"].bitmap, $rect_dst, ($global:arrSettingsInternal["TILERECT"]), [System.Drawing.GraphicsUnit]::Pixel);
        }
    }
}

function onRedraw($Sender, $EventArgs)
{
    $EventArgs.Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $EventArgs.Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

    $fac_x = ($objForm.Size.Width - $wndOffsetX)  / ($DrawingSizeX)
    $fac_y = ($objForm.Size.Height - $wndOffsetY) / ($DrawingSizeY)

    $rect = New-Object System.Drawing.Rectangle(0, 0, $pictureBox.Size.Width, $pictureBox.Size.Height)
    
    if($global:strGameState -eq "EDIT_MAP" -or $global:strGameState -eq "EDIT_MAP_ESCAPE" -or $global:strGameState -eq "SINGLEPLAYER_INGAME" -or $global:strGameState -eq "SINGLEPLAYER_TILEINFO" -or $global:strGameState -eq "SINGLEPLAYER_ESCAPE")
    {
        $offset_x = $global:arrCreateMapOptions["EDITOR_CHUNK_X"] * $global:arrSettingsInternal["TILESIZE"];
        $offset_y = $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] * $global:arrSettingsInternal["TILESIZE"];
        
        $offset_curx = ($global:arrCreateMapOptions["SELECTED_X"] - $global:arrCreateMapOptions["EDITOR_CHUNK_X"]) * ($fac_x * $global:arrSettingsInternal["TILESIZE"]);
        $offset_cury = ($global:arrCreateMapOptions["SELECTED_Y"] - $global:arrCreateMapOptions["EDITOR_CHUNK_Y"]) * ($fac_y * $global:arrSettingsInternal["TILESIZE"]);
        
        $EventArgs.Graphics.DrawImage($global:objWorldBackground, $rect, 0, 0, $DrawingSizeX, $DrawingSizeY, [System.Drawing.GraphicsUnit]::Pixel)

        $EventArgs.Graphics.DrawImage($global:objWorld, $rect, ($offset_x), ($offset_y), $DrawingSizeX, $DrawingSizeY, [System.Drawing.GraphicsUnit]::Pixel)

        
        if($global:EnableFoW)
        {
            $plrFow = MP_getLocalPlayerID

            $EventArgs.Graphics.DrawImage($global:arrPlayerInfo.FoW[$plrFow], $rect, ($offset_x), ($offset_y), $DrawingSizeX, $DrawingSizeY, [System.Drawing.GraphicsUnit]::Pixel)
        }

        $rect_cur = New-Object System.Drawing.Rectangle($offset_curx, $offset_cury, ($fac_x * $global:arrSettingsInternal["TILESIZE"]), ($fac_y * $global:arrSettingsInternal["TILESIZE"]))
        
        if($global:arrCreateMapOptions["SHOW_PREVIEW"])
        {
            if($global:arrCreateMapOptions["SELECT_LAYER01"] -ne -1)
            {
                $EventArgs.Graphics.DrawImage(($global:arrTextures[$arrBaseTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER01"]]].bitmap), $rect_cur, 0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"], [System.Drawing.GraphicsUnit]::Pixel)
            }
            elseif($global:arrCreateMapOptions["SELECT_LAYER02"] -ne -1)
            {
                $EventArgs.Graphics.DrawImage(($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER02"]]].bitmap), $rect_cur, 0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"], [System.Drawing.GraphicsUnit]::Pixel)
            }
            elseif($global:arrCreateMapOptions["SELECT_LAYER03"] -ne -1)
            {
                $EventArgs.Graphics.DrawImage(($global:arrTextures[$arrObjectTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER03"]]].bitmap), $rect_cur, 0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"], [System.Drawing.GraphicsUnit]::Pixel)
            }
            else
            {
                $global:arrCreateMapOptions["SHOW_PREVIEW"] = $False
            }
        }
        else
        {
            if([int]$global:arrSettingsInternal["BUILDINGS_SELECTED"] -ne -1 -or $global:arrSettingsInternal["RECRUIT_ARMY"])
            {
                $hovering_X = ($offset_curx/($fac_x* $global:arrSettingsInternal["TILESIZE"]))
                $hovering_Y = ($offset_cury/($fac_y* $global:arrSettingsInternal["TILESIZE"]))

                $hoovering_off_x = ($offset_x/ $global:arrSettingsInternal["TILESIZE"])
                $hoovering_off_y = ($offset_y/ $global:arrSettingsInternal["TILESIZE"])

                $hovering_X += $hoovering_off_x
                $hovering_Y += $hoovering_off_y


                # check if the currently hoovered tile is the same
                if([int]$global:arrSettingsInternal["HOOVER_X"] -ne $hovering_X -or [int]$global:arrSettingsInternal["HOOVER_Y"] -ne $hovering_Y -and $hovering_X -gt 1 -and $hovering_Y -gt 1 -and $hovering_X -lt ([int]$arrCreateMapOptions["WIDTH"] + 2) -and $hovering_Y -lt ([int]$arrCreateMapOptions["HEIGHT"] + 2))
                {
                    $global:arrSettingsInternal["HOOVER_X"] = $hovering_X
                    $global:arrSettingsInternal["HOOVER_Y"] = $hovering_Y

                    $global:arrSettingsInternal["HOOVER_CANBUILD"] = $False
                    if([int]$global:arrSettingsInternal["BUILDINGS_SELECTED"] -ne -1)
                    {
                        $global:arrSettingsInternal["HOOVER_CANBUILD"] = checkIfBuildingPossible ([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"])) ([int]($global:arrSettingsInternal["HOOVER_X"] - 2)) ([int]($global:arrSettingsInternal["HOOVER_Y"] - 2)) ($global:arrPlayerInfo.currentPlayer)
                    }

                    $global:arrSettingsInternal["HOOVER_CANRECRUIT"] = 0
                    if($global:arrSettingsInternal["RECRUIT_ARMY"])
                    {
                        $global:arrSettingsInternal["HOOVER_CANRECRUIT"] = getRecruitOption ([int]($global:arrSettingsInternal["HOOVER_X"] - 2)) ([int]($global:arrSettingsInternal["HOOVER_Y"] - 2)) ($global:arrPlayerInfo.currentPlayer)
                    }
                }
                elseif($hovering_X -lt 2 -or $hovering_Y -lt 2 -or $hovering_X -ge ([int]$arrCreateMapOptions["WIDTH"] + 2) -or $hovering_Y -ge ([int]$arrCreateMapOptions["HEIGHT"] + 2))
                {
                    $global:arrSettingsInternal["HOOVER_CANBUILD"] = $False
                    $global:arrSettingsInternal["HOOVER_CANRECRUIT"] = 0
                    $global:arrSettingsInternal["HOOVER_X"] = -1
                    $global:arrSettingsInternal["HOOVER_Y"] = -1
                }

                $tileCursor = "SELECTION_TILE_INVALID"

                if($global:arrSettingsInternal["HOOVER_CANBUILD"])
                {
                    $tileCursor = "SELECTION_TILE_VALID"
                }
                elseif($global:arrSettingsInternal["RECRUIT_ARMY"] -and $global:arrSettingsInternal["HOOVER_CANRECRUIT"])
                {
                    $tileCursor = "SELECTION_TILE_VALID"
                    if($global:arrSettingsInternal["HOOVER_CANRECRUIT"] -eq 2) {$tileCursor = "SELECTION_TILE_MERGE"}
                }

                $EventArgs.Graphics.DrawImage($global:arrInterface[$tileCursor].bitmap, $rect_cur, 0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"], [System.Drawing.GraphicsUnit]::Pixel)
            }
            else
            {
                $EventArgs.Graphics.DrawImage($global:arrInterface["SELECTION_TILE_RED"].bitmap, $rect_cur, 0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"], [System.Drawing.GraphicsUnit]::Pixel)
            }
        }
    }
    else
    {
        $EventArgs.Graphics.DrawImage($global:bitmap, $rect, 0, 0, $global:bitmap.Width, $global:bitmap.Height, [System.Drawing.GraphicsUnit]::Pixel)
    }

    # overlays take quite some time as a lot of graphics are drawn
    # draw overlays
    ## this is the general picturebox size
    ## $rect = New-Object System.Drawing.Rectangle(0, 0, $pictureBox.Size.Width, $pictureBox.Size.Height)
    #$tilesX = $DrawingSizeX / $global:arrSettingsInternal["TILESIZE"]
    #$tilesY = $DrawingSizeY / $global:arrSettingsInternal["TILESIZE"]
    #
    #$rect_cur = New-Object System.Drawing.Rectangle(0, 0, ($fac_x * $global:arrSettingsInternal["TILESIZE"]), ($fac_y * $global:arrSettingsInternal["TILESIZE"]))
    #
    #for($i = 0; $i -lt $tilesX; $i++)
    #{
    #    for($j = 0; $j -lt $tilesY; $j++)
    #    {
    #        $rect_cur = New-Object System.Drawing.Rectangle(($i * 16 * $fac_x), ($j * 16 * $fac_y), ($fac_x * $global:arrSettingsInternal["TILESIZE"]), ($fac_y * $global:arrSettingsInternal["TILESIZE"]))
    #
    #        #$EventArgs.Graphics.DrawImage($global:arrInterface["SELECTION_TILE_INVALID"].bitmap, ($i * 16 * $fac_x), ($j * 16 * $fac_y), $rect_cur, [System.Drawing.GraphicsUnit]::Pixel)
    #        $EventArgs.Graphics.DrawImage($global:arrInterface["SELECTION_TILE_VALID"].bitmap, $rect_cur, 0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"], [System.Drawing.GraphicsUnit]::Pixel)
    #    }
    #}

    if($global:arrWindows.WindowOpen)
    {
        $rect_wnd = New-Object System.Drawing.Rectangle(($fac_x * $global:arrWindows[$global:arrWindows.WindowCurrent].loc_x), ($fac_y * $global:arrWindows[$global:arrWindows.WindowCurrent].loc_y), ($fac_x * $global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Size.Width),($fac_y * $global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Size.Height))

        $EventArgs.Graphics.DrawImage($global:arrWindows[$global:arrWindows.WindowCurrent].wnd, $rect_wnd, 0, 0, $global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Width, $global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Height, [System.Drawing.GraphicsUnit]::Pixel)
    }
    
    if($global:strGameState -eq "EDIT_MAP")
    {
    }
}

#region FUNCTION INITGAME
function initGame()
{
    Write-Host "Init game"
    loadConfig
    applyConfig
    $global:bitmap = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathImageGFX + 'SCREEN_SPLASH.png'))));
    generateBackgroundImage
    showWindow "WND_WAIT_INIT_CLICK_N"
    playSFX "SND_INIT_DONE"
}
#endregion

#region FUNCTION LOADCONFIG
function loadConfig
{
    Write-Host "Loading Config..."

    $strFileName = ".\game.cfg"

    if (Test-Path $strFileName)
    {
        $arrConfigTMP = Get-Content $strFileName
    }
    else
    {
        return;
    }

    for($i = 0; $i -lt $arrConfigTMP.Length; $i++)
    {
        $arrConfigLine = $arrConfigTMP[$i].split("=")
        
        $valKey = $arrConfigLine[0]
        $valValue = $arrConfigLine[1]
        
        Write-Host "Key: $valKey Value: $valValue"
        
        if($valValue -eq "True")
        {
            $global:arrSettings[$valKey] = $True;
        }
        elseif($valValue -eq "False")
        {
            $global:arrSettings[$valKey] = $False;
        }
        else
        {
            $global:arrSettings[$valKey] = $valValue;
        }
    }
}
#endregion

#region FUNCTION SAVECONFIG
function saveConfig
{
    $strFileName = ".\game.cfg"
    
    Write-Host "Saving Config"
    
    If (Test-Path $strFileName){
        Remove-Item $strFileName
    }
    
    $keys    = $global:arrSettings.Keys
    
    foreach($key in $keys)
    {
        $strOutput = "";
        
        if($global:arrSettings[$key].GetType() -eq "bool")
        {
            if($global:arrSettings[$key])
            {
                $strOutput = $key + "=True"
            }
            else
            {
                $strOutput = $key + "=False"
            }
        }
        else
        {
            $strOutput = $key + "=" + $global:arrSettings[$key]
        }
        
        $strOutput | Out-File -FilePath $strFileName -Append
    }
}
#endregion

#region FUNCTION APPLYCONFIG
function applyConfig
{
    $objForm.Topmost = $global:arrSettings["TOPMOST"];
    
    $factor = [convert]::ToDouble($global:arrSettings["SIZE"], $global:arrSettingsInternal["CULTURE"])
    $global:arrSettings["SIZE"] = $factor

    $pictureBox.size = New-Object System.Drawing.Size(($factor * $DrawingSizeX), ($factor * $DrawingSizeY))
    $objForm.size = New-Object System.Drawing.Size(($factor * $DrawingSizeX + $wndOffsetX), ($factor * $DrawingSizeY + $wndOffsetY))

    $objForm.Location = New-Object System.Drawing.Point(($global:arrSettings["LAST_X"]), ($global:arrSettings["LAST_Y"]))

    #$objForm.size = New-Object System.Drawing.Size(($factor * $DrawingSizeX + 16 + 6), ($factor * $DrawingSizeY + 38 + 18))
}
#endregion

#region FUNCTION OPENMAPFILE
Function openMapFile()
{   
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = ".\MAP"
    #"All files (*.*)| *.*"
    $OpenFileDialog.filter = "Maps (*.SMF, *.MMF)|*.smf;*.mmf|All files (*.*)| *.*"
    $OpenFileDialog.ShowHelp = $True
    $OpenFileDialog.Title = "Open map..."
    $OpenFileDialog.AddExtension = $True
    
    $Show = $OpenFileDialog.ShowDialog()
    If ($Show -eq "OK")
    {
        $global:strMapFile = $OpenFileDialog.FileName
    }
    Else 
    {
        $global:strMapFile = ""
    }
}
#endregion

initGame
$objForm.Refresh();

[void] $objForm.ShowDialog()