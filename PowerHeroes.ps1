#http://www.techotopia.com/index.php/Drawing_Graphics_using_PowerShell_1.0_and_GDI%2B
# $arrImage = New-Object 'object[,]' sizeX,sizeY

param(
    [bool]$QuickStart = $False
)

#Set-ExecutionPolicy Unrestricted

# load forms (GUI)
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing.Icon") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing.Graphics")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Globalization")

# Mediaplayer
Add-Type -AssemblyName PresentationCore
# Visual Styles
[void] [System.Windows.Forms.Application]::EnableVisualStyles() 

# STA Modus (Single Threading Apartment) - benötigt für OpenFileDialog
try {[threading.thread]::CurrentThread.SetApartmentState(0)}
catch { Write-Host "ERROR: [threading.thread]::CurrentThread.SetApartmentState(0)"}

$global:VersionInfo = @{}
# major
$global:VersionInfo[0] = "0"
# minor
$global:VersionInfo[1] = "4"
# patch
$global:VersionInfo[2] = "2"
# build
$global:VersionInfo[3] = "20191019"

$global:arrWindows = @{}
$global:arrWindows.WindowOpen = $False
$global:arrWindows.InputCurrent = ""
$global:arrWindows.WindowCurrent = ""

$global:arrSettings = @{}
$global:arrSettings["TOPMOST"] = $False;
$global:arrSettings["SCROLLSPEED"] = 1;
$global:arrSettings["SIZE"] = 2;
$global:arrSettings["VOLUMEMUSIC"] = 0.1;
$global:arrSettings["VOLUMEEFFECTS"] = 0.1;
$global:arrSettings["PLAYER_FACE"] = 0;

$global:arrSettingsInternal = @{}
$global:arrSettingsInternal["SONG_CURRENT"] = 0;
$global:arrSettingsInternal["SONGS"] = 0;
$global:arrSettingsInternal["HOOVER_X"] = -1;
$global:arrSettingsInternal["HOOVER_Y"] = -1;
$global:arrSettingsInternal["HOOVER_CANBUILD"] = $False;
$global:arrSettingsInternal["PLAYER_FACE_MAX"] = 23;
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
$global:arrSettingsInternal["HOOVER_CANRECRUIT"] = $False
$global:arrSettingsInternal["ARMY_DEFAULT_MP"] = 2
$global:arrSettingsInternal["ARMY_DEFAULT_HP"] = 5
$global:arrSettingsInternal["ARMY_DEFAULT_PEOPLE"] = 5
$global:arrSettingsInternal["ARMY_UNIT_COSTS"] = @{}
$global:arrSettingsInternal["ARMY_UNIT_COSTS"][0] = 5
$global:arrSettingsInternal["ARMY_UNIT_COSTS"][1] = 10
$global:arrSettingsInternal["ARMY_UNIT_COSTS"][2] = 20

$global:arrMap = @{}
function initMapArray()
{
    $global:arrMap = @{}
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

    $global:arrMap["WORLD_OVERLAY"] = @{}
}

initMapArray

#region PLAYER_INFO

$global:arrPlayerInfo = @{}
$global:arrPlayerInfo.currentPlayer = -1
$global:arrPlayerInfo.currentSelection = -1
$global:arrPlayerInfo.selectedTile = @{}
$global:arrPlayerInfo.combatData = @{}


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
#endregion

#region COLORS
$global:arrColors = @{}

function addcolor($type, $r, $g, $b, $a = 255)
{
    Write-Host "addcolor($type, $r, $g, $b, $a)"

    $global:arrColors[$type] = @{}; 
    $global:arrColors[$type].color = [System.Drawing.Color]::FromArgb($a, $r, $g, $b); 
    $global:arrColors[$type].pen = New-Object System.Drawing.Pen($global:arrColors[$type].color, 3); 
    $global:arrColors[$type].brush = New-Object System.Drawing.SolidBrush($global:arrColors[$type].color)
}

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
    }
}

loadDat $null ".\DAT\COLOR.dat" "COLOR"
##endregion

$global:strGameState = "WAIT_INIT_CLICK"
$global:strMapFile = "";

$global:arrCreateMapOptions = @{}
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
$global:arrCreateMapOptions["SELECT_LAYER01"] = 0;
$global:arrCreateMapOptions["SELECT_LAYER02"] = 0;
$global:arrCreateMapOptions["SELECT_LAYER03"] = 0;
$global:arrCreateMapOptions["SELECT_PLAYER"] = 0;
$global:arrCreateMapOptions["LAST_CHANGED_TEX"] = 0;
$global:arrCreateMapOptions["LAST_MODE"] = 0;
$global:arrCreateMapOptions["LAST_CHANGED_X"] = 0;
$global:arrCreateMapOptions["LAST_CHANGED_Y"] = 0;
$global:arrCreateMapOptions["SELECTED_X"] = 0;
$global:arrCreateMapOptions["SELECTED_Y"] = 0;
$global:arrCreateMapOptions["SHOW_PREVIEW"] = $False;

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

function nameToId($strPrefix, $iID)
{
    if(([int]($iID)) -gt 9)
    {
        return ($strPrefix + ([string]($iID)))
    }
    else
    {
        return ($strPrefix + '0' + ([string]($iID)))
    }
}
#endregion

#region \GFX\ICON
$strPathIconGFX = ".\GFX\ICON\"
$global:arrIcons = @{}

loadGraphicsByName $global:arrIcons $strPathIconGFX "ICON_*" $True

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
$global:arrTextureMovement = @{}

loadGraphicsByName $global:arrTextures $strPathIconGFX "FACE_*" $False

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

function getTerrainDat($strKey, $iIndex)
{
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
        $moveL1 = ((getTerrainDat $texL1 3) -gt 0)
    }

    $moveL2 = $True
    if($global:arrMap["WORLD_L2"][$x][$y] -ne -1)
    {
        $moveL2 = ((getTerrainDat $texL2 3) -gt 0)
    }
    $moveL3 = $True
    if($global:arrMap["WORLD_L3"][$x][$y] -ne -1)
    {
        $moveL3 = ((getTerrainDat $texL3 3) -gt 0)
    }

    return($moveL1 -and $moveL2 -and $moveL3)
}

function hasMoveFlag($x, $y, $flag)
{
    if($x -lt 0 -or $y -lt 0) {return $False}
    if($x -ge $global:arrMap["WIDTH"]) {return $False}
    if($y -ge $global:arrMap["HEIGHT"]) {return $False}

    #Write-Host "Flag: $flag"
    #Write-Host "Result: " $global:arrMap["WORLD_MMAP"][$j][$i] " -> " ($global:arrMap["WORLD_MMAP"][$j][$i] -band $flag)

    return (($global:arrMap["WORLD_MMAP"][$i][$j] -band $flag) -eq $flag)
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
            $canMoveU = ((canTerrainMoveDirection $i $j 0) -and (canTerrainMoveDirection $i ($j - 1) 2))
            $canMoveR = ((canTerrainMoveDirection $i $j 1) -and (canTerrainMoveDirection ($i + 1)  $j 3))
            $canMoveD = ((canTerrainMoveDirection $i $j 2) -and (canTerrainMoveDirection $i  ($j + 1)  0))
            $canMoveL = ((canTerrainMoveDirection $i $j 3) -and (canTerrainMoveDirection ($i - 1)  $j 1))

            if($canMoveU) {$global:arrMap["WORLD_MMAP"][$i][$j] = ($global:arrMap["WORLD_MMAP"][$i][$j] -bxor 1)}
            if($canMoveR) {$global:arrMap["WORLD_MMAP"][$i][$j] = ($global:arrMap["WORLD_MMAP"][$i][$j] -bxor 2)}
            if($canMoveD) {$global:arrMap["WORLD_MMAP"][$i][$j] = ($global:arrMap["WORLD_MMAP"][$i][$j] -bxor 4)}
            if($canMoveL) {$global:arrMap["WORLD_MMAP"][$i][$j] = ($global:arrMap["WORLD_MMAP"][$i][$j] -bxor 8)}

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
    if ($global:arrSFX[$strName]) 
    {
        $global:arrSFX[$strName].Position = New-TimeSpan -Hour 0 -Minute 0 -Seconds 0;
        $global:arrSFX[$strName].Volume = $global:arrSettings["VOLUMEEFFECTS"];
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

    if($global:arrSettings["VOLUMEMUSIC"] -eq 0) { return;}

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
    $global:arrMusic[([int]$global:arrSettingsInternal["SONG_CURRENT"])].player.Volume = $global:arrSettings["VOLUMEMUSIC"];
    $global:arrMusic[([int]$global:arrSettingsInternal["SONG_CURRENT"])].player.Play();
}

function loadSoundByName($objTargetArray, $strPath, $strFilter)
{
    foreach($file in (Get-ChildItem -Path $strPath $strFilter))
    {
        $arrSplit = $file.Name.split(".")

        $objTargetArray[$arrSplit[0]] = New-Object System.Windows.Media.Mediaplayer
        $objTargetArray[$arrSplit[0]].Open([uri]($file.FullName))
        $objTargetArray[$arrSplit[0]].Volume = $global:arrSettings["VOLUMEEFFECTS"];
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
        $global:arrMusic[$iID].player.Volume = $global:arrSettings["VOLUMEEFFECTS"];
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
            if($arrFont[$strChar].GetPixel($i, $j).A -gt 0 -and $arrFont[$strChar].GetPixel($i, $j) -ne $global:arrColors["CLR_MAGENTA"].color -and (($arrFont[$strChar].GetPixel($i, $j) -ne ($global:arrColors["CLR_BLACK"].color)) -or ($doOutline -and $arrFont[$strChar].GetPixel($i, $j) -eq ($global:arrColors["CLR_BLACK"].color))))
            {
                $tmpClr = $arrFont[$strChar].GetPixel($i, $j)

                switch($strColor)
                {
                    "Gold" {$tmpClr = $global:arrColors["CLR_GOLD_1"].color}
                    "Red" {$tmpClr = $global:arrColors["CLR_RED"].color}
                    "Gray" {$tmpClr = $global:arrColors["CLR_GRAY"].color}
                    "Green" {$tmpClr = $global:arrColors["CLR_GREEN"].color}
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
        setCharColor ("""") "Gold" $False
    }
    elseif($i -eq 4)
    {
        $arrFont["`$"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + $i + '.png'  ))));
        $arrFont["`$"].MakeTransparent($global:arrColors["CLR_MAGENTA"].color);
        setCharColor ("`$") "Gold" $False
    }
    else
    {
        $arrFont[$fontString.Substring(($i - 1), 1)] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + $i + '.png'  ))));
        $arrFont[$fontString.Substring(($i - 1), 1)].MakeTransparent($global:arrColors["CLR_MAGENTA"].color);
        setCharColor ($fontString.Substring(($i - 1), 1)) "Gold" $False
    }
    
}

function replaceColor($objImage, $colorSource, $colorTarget)
{
    #$clrMap = New-Object System.Drawing.Imaging.ColorMap
    #$clrMap.OldColor = $colorSource
    #$clrMap.NewColor = $colorTarget
    #$imgAttributes = New-Object System.Drawing.Imaging.ImageAttributes
    #$imgAttributes.SetRemapTable($clrMap)
    #
    #$tmp_grd = [System.Drawing.Graphics]::FromImage($objImage);
    #
    #$rect_src = New-Object System.Drawing.Rectangle(0, 0, $objImage.Width, $objImage.Height)
    #$tmp_grd.DrawImage($objImage, $rect_src, 0, 0, $objImage.Width, $objImage.Height, [System.Drawing.GraphicsUnit]::Pixel, $imgAttributes);
    #
    #return;

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

$global:arrBuildingIDToKey = "HUM_HQ", "HUM_HOUSE_SMALL", "HUM_HOUSE_MEDIUM", "HUM_HOUSE_LARGE", "HUM_FARM", "HUM_FIELD", "HUM_WELL", "HUM_MINE", "HUM_SAWMILL", "HUM_BARRACKS", "HUM_ARCHERRANGE", "HUM_STABLE", "HUM_TOWER"

$rect_tile    = New-Object System.Drawing.Rectangle(0, 0, 16, 16)
$strPathToBuildingGFX = ".\GFX\BUILDING\"
$global:arrBuilding = @{}

for($i = 0; $i -lt $global:arrBuildingIDToKey.Length; $i++)
{
    $arrBuilding[$global:arrBuildingIDToKey[$i]] = @{}

    # load player 0
    $arrBuilding[$global:arrBuildingIDToKey[$i]][0] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToBuildingGFX + ($global:arrBuildingIDToKey[$i] + '_00.png')  ))));
    $arrBuilding[$global:arrBuildingIDToKey[$i]][1] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToBuildingGFX + ($global:arrBuildingIDToKey[$i] + '_01.png')  ))));

    for($j = 1; $j-le $global:arrSettingsInternal["PLAYER_MAX"]; $j++)
    {
        $arrBuilding[$global:arrBuildingIDToKey[$i]][($j * 2)] = $arrBuilding[$global:arrBuildingIDToKey[$i]][0].Clone($rect_tile, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        replaceColor $arrBuilding[$global:arrBuildingIDToKey[$i]][($j * 2)] $global:arrColors["CLR_PLAYER_DEF00"].color $global:arrColors[("CLR_PLAYER_" + $j + "0")].color
        replaceColor $arrBuilding[$global:arrBuildingIDToKey[$i]][($j * 2)] $global:arrColors["CLR_PLAYER_DEF01"].color $global:arrColors[("CLR_PLAYER_" + $j + "1")].color
        
        $arrBuilding[$global:arrBuildingIDToKey[$i]][(($j * 2) + 1)] = $arrBuilding[$global:arrBuildingIDToKey[$i]][1].Clone($rect_tile, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        replaceColor $arrBuilding[$global:arrBuildingIDToKey[$i]][(($j * 2) + 1)] $global:arrColors["CLR_PLAYER_DEF00"].color $global:arrColors[("CLR_PLAYER_" + $j + "0")].color
        replaceColor $arrBuilding[$global:arrBuildingIDToKey[$i]][(($j * 2) + 1)] $global:arrColors["CLR_PLAYER_DEF01"].color $global:arrColors[("CLR_PLAYER_" + $j + "1")].color
    }
}

#endregion

#region UNITS
$strPathToUnitGFX = ".\GFX\UNIT\"
$global:arrUnitGFX = @{}
$global:arrArmies = @{}

for($i = 0; $i -lt 4; $i++)
{
    $arrUnitGFX[$i] = @{}

    # load player 0
    $arrUnitGFX[$i][0] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToUnitGFX + ('HUM_UNIT_' + $i + '.png')  ))));

    for($j = 1; $j -le $global:arrSettingsInternal["PLAYER_MAX"]; $j++)
    {
        $arrUnitGFX[$i][$j] = $arrUnitGFX[$i][0].Clone($rect_tile, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        replaceColor $arrUnitGFX[$i][$j] $global:arrColors["CLR_PLAYER_DEF00"].color $global:arrColors[("CLR_PLAYER_" + $j + "0")].color
        replaceColor $arrUnitGFX[$i][$j] $global:arrColors["CLR_PLAYER_DEF01"].color $global:arrColors[("CLR_PLAYER_" + $j + "1")].color
    }
}
#endregion

#region BUILDING_INFO
$arrBuilding["HUM_HQ"].name = "Headquarter"
$arrBuilding["HUM_HOUSE_SMALL"].name = "House small"
$arrBuilding["HUM_HOUSE_MEDIUM"].name = "House medium"
$arrBuilding["HUM_HOUSE_LARGE"].name = "House large"
$arrBuilding["HUM_FARM"].name = "Farm"
$arrBuilding["HUM_FIELD"].name = "Field"
$arrBuilding["HUM_WELL"].name = "Well"
$arrBuilding["HUM_MINE"].name = "Mine"
$arrBuilding["HUM_SAWMILL"].name = "Sawmill"
$arrBuilding["HUM_BARRACKS"].name = "Barracks"
$arrBuilding["HUM_ARCHERRANGE"].name = "Archer range"
$arrBuilding["HUM_STABLE"].name = "Stable"
$arrBuilding["HUM_TOWER"].name = "Tower"

$arrBuilding["HUM_HQ"].gold_cost = 100
$arrBuilding["HUM_HOUSE_SMALL"].gold_cost = 10
$arrBuilding["HUM_HOUSE_MEDIUM"].gold_cost = 19
$arrBuilding["HUM_HOUSE_LARGE"].gold_cost = 28
$arrBuilding["HUM_FARM"].gold_cost = 15
$arrBuilding["HUM_FIELD"].gold_cost = 5
$arrBuilding["HUM_WELL"].gold_cost = 15
$arrBuilding["HUM_MINE"].gold_cost = 10
$arrBuilding["HUM_SAWMILL"].gold_cost = 10
$arrBuilding["HUM_BARRACKS"].gold_cost = 20
$arrBuilding["HUM_ARCHERRANGE"].gold_cost = 40
$arrBuilding["HUM_STABLE"].gold_cost = 60
$arrBuilding["HUM_TOWER"].gold_cost = 80

$arrBuilding["HUM_HQ"].wood_cost = 100
$arrBuilding["HUM_HOUSE_SMALL"].wood_cost = 20
$arrBuilding["HUM_HOUSE_MEDIUM"].wood_cost = 38
$arrBuilding["HUM_HOUSE_LARGE"].wood_cost = 56
$arrBuilding["HUM_FARM"].wood_cost = 40
$arrBuilding["HUM_FIELD"].wood_cost = 15
$arrBuilding["HUM_WELL"].wood_cost = 25
$arrBuilding["HUM_MINE"].wood_cost = 30
$arrBuilding["HUM_SAWMILL"].wood_cost = 20
$arrBuilding["HUM_BARRACKS"].wood_cost = 40
$arrBuilding["HUM_ARCHERRANGE"].wood_cost = 70
$arrBuilding["HUM_STABLE"].wood_cost = 100
$arrBuilding["HUM_TOWER"].wood_cost = 120

$arrBuilding["HUM_HQ"].hitpoints = 1000
$arrBuilding["HUM_HOUSE_SMALL"].hitpoints = 150
$arrBuilding["HUM_HOUSE_MEDIUM"].hitpoints = 250
$arrBuilding["HUM_HOUSE_LARGE"].hitpoints = 400
$arrBuilding["HUM_FARM"].hitpoints = 100
$arrBuilding["HUM_FIELD"].hitpoints = 50
$arrBuilding["HUM_WELL"].hitpoints = 100
$arrBuilding["HUM_MINE"].hitpoints = 300
$arrBuilding["HUM_SAWMILL"].hitpoints = 250
$arrBuilding["HUM_BARRACKS"].hitpoints = 400
$arrBuilding["HUM_ARCHERRANGE"].hitpoints = 500
$arrBuilding["HUM_STABLE"].hitpoints = 600
$arrBuilding["HUM_TOWER"].hitpoints = 750

$arrBuilding["HUM_HQ"].buildspeed = 0.05
$arrBuilding["HUM_HOUSE_SMALL"].buildspeed = 0.5
$arrBuilding["HUM_HOUSE_MEDIUM"].buildspeed = 0.25
$arrBuilding["HUM_HOUSE_LARGE"].buildspeed = 0.125
$arrBuilding["HUM_FARM"].buildspeed = 0.3
$arrBuilding["HUM_FIELD"].buildspeed = 0.5
$arrBuilding["HUM_WELL"].buildspeed = 0.25
$arrBuilding["HUM_MINE"].buildspeed = 0.2
$arrBuilding["HUM_SAWMILL"].buildspeed = 0.25
$arrBuilding["HUM_BARRACKS"].buildspeed = 0.25
$arrBuilding["HUM_ARCHERRANGE"].buildspeed = 0.2
$arrBuilding["HUM_STABLE"].buildspeed = 0.15
$arrBuilding["HUM_TOWER"].buildspeed = 0.1

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
$arrBuilding["HUM_FARM"].productionType = 3
$arrBuilding["HUM_FIELD"].productionType = 3
$arrBuilding["HUM_WELL"].productionType = 0
$arrBuilding["HUM_MINE"].productionType = 1
$arrBuilding["HUM_SAWMILL"].productionType = 2
$arrBuilding["HUM_BARRACKS"].productionType = 0
$arrBuilding["HUM_ARCHERRANGE"].productionType = 0
$arrBuilding["HUM_STABLE"].productionType = 0
$arrBuilding["HUM_TOWER"].productionType = 0

$arrBuilding["HUM_HQ"].productionAmount = 5
$arrBuilding["HUM_HOUSE_SMALL"].productionAmount = 2
$arrBuilding["HUM_HOUSE_MEDIUM"].productionAmount = 4
$arrBuilding["HUM_HOUSE_LARGE"].productionAmount = 6
$arrBuilding["HUM_FARM"].productionAmount = 1
$arrBuilding["HUM_FIELD"].productionAmount = 2
$arrBuilding["HUM_WELL"].productionAmount = 0
$arrBuilding["HUM_MINE"].productionAmount = 3
$arrBuilding["HUM_SAWMILL"].productionAmount = 2
$arrBuilding["HUM_BARRACKS"].productionAmount = 0
$arrBuilding["HUM_ARCHERRANGE"].productionAmount = 0
$arrBuilding["HUM_STABLE"].productionAmount = 0
$arrBuilding["HUM_TOWER"].productionAmount = 0

#endregion

$DrawingSizeX    = 480
$DrawingSizeY    = 270

$global:objWorldBackground = New-Object System.Drawing.Bitmap($DrawingSizeX, $DrawingSizeY);
$global:bitmap  = New-Object System.Drawing.Bitmap($DrawingSizeX, $DrawingSizeY);

# Create the form
$objForm = New-Object System.Windows.Forms.Form
$objForm.MaximizeBox = $False;
$objForm.MinimizeBox = $False;
$objForm.size = New-Object System.Drawing.Size(($DrawingSizeX + 16), ($DrawingSizeY + 38))
$objForm.Topmost = $global:arrSettings["TOPMOST"]; 
#https://i-msdn.sec.s-msft.com/dynimg/IC24340.jpeg

$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.SizeMode = 4
$pictureBox.Size = New-Object System.Drawing.Size($DrawingSizeX, $DrawingSizeY)
$objForm.controls.add($pictureBox)
$objForm.AutoSize = $False
$pictureBox.Add_Click({onMouseClick "Picturebox" $_})
$objForm.Add_Shown({$objForm.Activate()})
$pictureBox.Add_Paint({onRedraw $this $_})
$objForm.Add_KeyDown({onKeyPress $this $_})
#$objForm.Add_MouseMove({onMouseMove $this $_})
$pictureBox.Add_MouseMove({onMouseMove $this $_})
$objForm.Add_Click({onMouseClick "Form" $_})
$objForm.Text = ("PowerHeroes v" + $global:VersionInfo[0] + "." + $global:VersionInfo[1] + "." + $global:VersionInfo[2] + " - " + $global:VersionInfo[3])
If(!$QuickStart) {If (Test-Path ".\PowerHeroes.exe") { $objForm.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon(".\PowerHeroes.exe")}}

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
    $fac_x = ($objForm.Size.Width - 16)  / ($DrawingSizeX)
    $fac_y = ($objForm.Size.Height - 38) / ($DrawingSizeY)
    
    if($fac_x -gt $fac_y)
    {
        $objForm.size = New-Object System.Drawing.Size($objForm.Size.Width, ($fac_x * $DrawingSizeY + 38))
        $global:arrSettings["SIZE"] = $fac_x
    }
    else
    {
        $objForm.size = New-Object System.Drawing.Size(($fac_y * $DrawingSizeX + 16), $objForm.Size.Height)
        $global:arrSettings["SIZE"] = $fac_y
    }

}

$objForm.Add_ResizeEnd({

    keepFormRatio
    
    $val_x = $objForm.Size.Width
    $val_y = $objForm.Size.Height
    
    $pictureBox.Size = New-Object System.Drawing.Size(($val_x - 16), ($val_y - 38))
    saveConfig
})

function onMouseMove($sender, $EventArgs)
{
    if($global:strGameState -ne "EDIT_MAP" -and $global:strGameState -ne "SINGLEPLAYER_INGAME")
    {
        return;
    }
    
    $relX = [System.Windows.Forms.Cursor]::Position.X - $objForm.Location.X - 8 # 8 = left border
    $relY = [System.Windows.Forms.Cursor]::Position.Y - $objForm.Location.Y - 30 # 30 = upper border
    
    $fac_x = ($objForm.Size.Width - 16)  / ($DrawingSizeX)
    $fac_y = ($objForm.Size.Height - 38) / ($DrawingSizeY)

    $relX = ($relX / $fac_x)
    $relY = ($relY / $fac_y)
    
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
    $offset_x = ($global:arrBuildings[$bldIndex][0] + 2) * $global:arrSettingsInternal["TILESIZE"]
    $offset_y = ($global:arrBuildings[$bldIndex][1] + 2) * $global:arrSettingsInternal["TILESIZE"]

    #calc percent
    $percent = ($global:arrBuildings[$bldIndex][6] / $arrBuilding[$global:arrBuildingIDToKey[$global:arrBuildings[$bldIndex][3]]].hitpoints)

    if(([int]($global:arrBuildings[$bldIndex][4])) -eq 0)
    {
        $percent = $global:arrBuildings[$bldIndex][5]
    }

    if($percent -lt 0) { return; }
    elseif($percent -gt 1) { $percent = ($percent / 100)}

    $lengthBar = [math]::floor($percent * 10)
    
    # Make sure, that at least one pixel is colored
    if($lengthBar -eq 0)
    {
        $lengthBar = 1;
    }

    $clrBar = getColorForPercent $percent

    $tmp_grd = [System.Drawing.Graphics]::FromImage($global:objWorld);
    $tmp_grd.FillRectangle($global:arrColors["CLR_BLACK"].brush, ($offset_x + 2), ($offset_y + 2), 12, 3)
    $tmp_grd.FillRectangle($clrBar.brush, ($offset_x + 3), ($offset_y + 3), $lengthBar, 1)

    $objForm.Refresh();
}

function getColorForPercent($fPercent)
{
    if($fPercent -gt 0.66)
    {
        return $global:arrColors["CLR_GOOD"]
    }
    elseif($fPercent -gt 0.33)
    {
        return $global:arrColors["CLR_OKAY"]
    }
    
    return $global:arrColors["CLR_BAD"]
}

function MAP_createMapImage()
{
    $global:arrMap["WIDTH"] = $global:arrCreateMapOptions["WIDTH"]
    $global:arrMap["HEIGHT"] = $global:arrCreateMapOptions["HEIGHT"]

    $size_x = $global:arrMap["WIDTH"] + 4;
    $size_y = $global:arrMap["HEIGHT"] + 4;
    
    $global:objWorld = New-Object System.Drawing.Bitmap(($size_x * $global:arrSettingsInternal["TILESIZE"]), ($size_y * $global:arrSettingsInternal["TILESIZE"]));
    
    $runs = $size_x * $size_y
    $runs5 = [math]::floor($runs * 0.05)
    $runs = $runs5;

    #$global:arrSettingsInternal["TILERECT"]

    # TODO: Copy Rect
    $arrImage = New-Object 'object[,]' $global:arrSettingsInternal["TILESIZE"],$global:arrSettingsInternal["TILESIZE"]
    
    for($i = 0; $i -lt $global:arrSettingsInternal["TILESIZE"]; $i++)
    {
        for($j = 0; $j -lt $global:arrSettingsInternal["TILESIZE"]; $j++)
        {
            $arrImage[$i,$j] = $global:arrTextures[$arrBaseTextureIDToKey[$global:arrCreateMapOptions["BASTEXTUREID"]]].bitmap.getPixel($i, $j)
        }
    }
    
    $arrImageNothing = New-Object 'object[,]' $global:arrSettingsInternal["TILESIZE"],$global:arrSettingsInternal["TILESIZE"]
    
    for($i = 0; $i -lt $global:arrSettingsInternal["TILESIZE"]; $i++)
    {
        for($j = 0; $j -lt $global:arrSettingsInternal["TILESIZE"]; $j++)
        {
            $arrImageNothing[$i,$j] = $global:arrTextures["GROUND_EMPTY_01"].bitmap.getPixel($i, $j)
        }
    }
      
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
            }


            $offset_x = ([int]$global:arrSettingsInternal["TILESIZE"] * $i);
            $offset_y = ([int]$global:arrSettingsInternal["TILESIZE"] * $j);
            
            for($ix = 0; $ix -lt $global:arrSettingsInternal["TILESIZE"]; $ix ++)
            {
                for($iy = 0; $iy -lt $global:arrSettingsInternal["TILESIZE"]; $iy++)
                {
                    #Borders
                    if($i -lt 2 -or $i -ge ($size_x - 2) -or $j -lt 2 -or $j -ge ($size_y - 2))
                    {
                        $global:objWorld.SetPixel(($offset_x + $ix), ($offset_y + $iy), ($arrImageNothing[$ix,$iy]));
                    }
                    else
                    {
                        $global:objWorld.SetPixel(($offset_x + $ix), ($offset_y + $iy), ($arrImage[$ix,$iy]));
                    }
                }
            }
            
            
            if(($i * $j) -gt $runs)
            {
                $percent = [math]::floor(($i * $j) / ($size_x * $size_y) * 100)
                Write-Host "$percent percent generated..."

                $runs += $runs5;
                [System.Windows.Forms.Application]::DoEvents() 
                $objForm.Refresh();
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

function gameHasPlayerType($type)
{
    for($i = 1; $i -le 4; $i++)
    {
        if($global:arrPlayerInfo[$i][5] -eq $type)
        {
            return $True
        }
    }
    return $False;
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

function loadMapHeader($strPath)
{
    if($strPath -eq "")
    {
        return;
    }

    initMapArray

    $arrMap_TMP = Get-Content $strPath
    $global:arrMap["AUTHOR"] =  ($arrMap_TMP[0].split("="))[1]
    $global:arrMap["MAPNAME"] = ($arrMap_TMP[1].split("="))[1]
    $global:arrMap["WIDTH"] =   ($arrMap_TMP[2].split("="))[1]
    $global:arrMap["HEIGHT"] =  ($arrMap_TMP[3].split("="))[1]

    $global:arrMap["PLAYER_01X"] = ($arrMap_TMP[4].split("="))[1]
    $global:arrMap["PLAYER_01Y"] = ($arrMap_TMP[5].split("="))[1]
    $global:arrMap["PLAYER_02X"] = ($arrMap_TMP[6].split("="))[1]
    $global:arrMap["PLAYER_02Y"] = ($arrMap_TMP[7].split("="))[1]
    $global:arrMap["PLAYER_03X"] = ($arrMap_TMP[8].split("="))[1]
    $global:arrMap["PLAYER_03Y"] = ($arrMap_TMP[9].split("="))[1]
    $global:arrMap["PLAYER_04X"] = ($arrMap_TMP[10].split("="))[1]
    $global:arrMap["PLAYER_04Y"] = ($arrMap_TMP[11].split("="))[1]

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
        }
    }

    for($i = 12; $i -lt $arrMap_TMP.Length; $i++)
    {
        $strValues = ($arrMap_TMP[$i].split("="))[1]
        $arrValues = $strValues.split(",")
        #calc current tile
        $x = [math]::floor((([int]$i - 12) / [int]$global:arrMap["WIDTH"]))
        $y = ($i - 12) - $x * [int]$global:arrMap["WIDTH"]

        #but in map file its saved 15 -> 0 and not 0 -> 15
        $realx = [int]$global:arrMap["WIDTH"] - 1 - $x
        $realy = [int]$global:arrMap["HEIGHT"] - 1 - $y

        $global:arrMap["WORLD_L1"][[int]$realx][[int]$realy] = [int]$arrValues[0]
        $global:arrMap["WORLD_L2"][[int]$realx][[int]$realy] = [int]$arrValues[1]
        $global:arrMap["WORLD_L3"][[int]$realx][[int]$realy] = [int]$arrValues[2]
        $global:arrMap["WORLD_CONTINENT"][[int]$realx][[int]$realy] = [int]$arrValues[3]
        $global:arrMap["WORLD_MMAP"][[int]$realx][[int]$realy] = [int]$arrValues[4]
        
    }

    generateMapPreview
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
    if($strPath -eq "")
    {
        return;
    }

    loadMapHeader $strPath

    $arrMap_TMP = Get-Content $strPath

    $global:arrCreateMapOptions["WIDTH"] = $global:arrMap["WIDTH"]
    $global:arrCreateMapOptions["HEIGHT"] = $global:arrMap["HEIGHT"]

    # create map image
    $size_x = [int]$global:arrMap["WIDTH"] + 4;
    $size_y = [int]$global:arrMap["HEIGHT"] + 4;

    $global:objWorld = New-Object System.Drawing.Bitmap(($size_x * $global:arrSettingsInternal["TILESIZE"]), ($size_y * $global:arrSettingsInternal["TILESIZE"]));

    for ($i = 0; $i -lt $global:arrMap["HEIGHT"]; $i++)
    {
        for($j = 0; $j -lt $global:arrMap["WIDTH"]; $j++)
        {
            $playerID = getPlayerAtPosition $i $j
            if($playerID -ne 0 -and $global:strGameState -eq "EDIT_MAP")
            {
                drawPlayerIndicatorAtPosition $i $j $playerID
            }
            elseif($playerID -ne 0 -and (isActivePlayer $playerID))
            {
                addBuildingAtPositionForPlayer $i $j 0 ([int]$playerID) $True
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

    $objForm.Refresh();
}

function saveMap($strName)
{

    # get name from user input
    $global:arrMap["MAPNAME"]   = $global:arrWindows["WND_ESC_EDITOR"].inp["INP_EDIT_MAPNAME"].text
    $global:arrMap["AUTHOR"]    = $global:arrWindows["WND_ESC_EDITOR"].inp["INP_EDIT_AUTHOR"].text

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
        $keys_b = $global:arrMap["WORLD_L1"][$key]

        foreach($key_out in $keys_a)
        {
            $strOutput = "";
            $strOutput = "" + $key + ":" + $key_out + "=" + $global:arrMap["WORLD_L1"][$key][$key_out] + "," + $global:arrMap["WORLD_L2"][$key][$key_out]+ "," + $global:arrMap["WORLD_L3"][$key][$key_out] + "," + $global:arrMap["WORLD_CONTINENT"][$key][$key_out] + "," + $global:arrMap["WORLD_MMAP"][$key][$key_out]
            $strOutput | Out-File -FilePath $strFileName -Append
        }
    }
}

function MAP_changeMapsizeBy($strSide, $iValue, $updateInfobutton)
{
    if(($global:arrCreateMapOptions[$strSide] + $iValue) -lt 16)
    {
        $global:arrCreateMapOptions[$strSide] = 16;
    }
    elseif(($global:arrCreateMapOptions[$strSide] + $iValue) -gt 128)
    {
        $global:arrCreateMapOptions[$strSide] = 128;
    }
    else
    {
        $global:arrCreateMapOptions[$strSide] += $iValue;
    }
    
    
    if($updateInfobutton)
    {
        if($strSide -eq "WIDTH")
        {
            $global:arrWindows["WND_CREATE_MAP"].btn.Remove("BTN_CREATEMAP_WIDTH")
            addButtonToWindow "WND_CREATE_MAP" "BTN_CREATEMAP_WIDTH" "Red"   40 20 200 12 $False ([string]($global:arrCreateMapOptions["WIDTH"])) -1 -1 "Gold" $False
        }
        else
        {
            $global:arrWindows["WND_CREATE_MAP"].btn.Remove("BTN_CREATEMAP_HEIGHT")
            addButtonToWindow "WND_CREATE_MAP" "BTN_CREATEMAP_HEIGHT" "Red"   40 20 200 42 $False ([string]($global:arrCreateMapOptions["HEIGHT"])) -1 -1 "Gold" $False
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

function handleInputClick($strWindow, $strInput)
{
    Write-Host "handleInputClick($strWindow, $strInput)"

    # set as active input
    $global:arrWindows.InputCurrent = $strInput

    # redraw with border
    buildInput $strWindow $strInput $True

    # activate this input
}

function handleInput($key)
{
    switch($key)
    {
        "Escape"
        {
            handleInputInactive $global:arrWindows.WindowCurrent $global:arrWindows.InputCurrent
        }
        "Return"
        {
            handleInputInactive $global:arrWindows.WindowCurrent $global:arrWindows.InputCurrent
        }
        "Back"
        {
            if($global:arrWindows[$global:arrWindows.WindowCurrent].inp[$global:arrWindows.InputCurrent].text.Length -gt 0)
            {
                $global:arrWindows[$global:arrWindows.WindowCurrent].inp[$global:arrWindows.InputCurrent].text = ($global:arrWindows[$global:arrWindows.WindowCurrent].inp[$global:arrWindows.InputCurrent].text).Substring(0, ($global:arrWindows[$global:arrWindows.WindowCurrent].inp[$global:arrWindows.InputCurrent].text.Length - 1))
                buildInput $global:arrWindows.WindowCurrent $global:arrWindows.InputCurrent $True
            }
        }
        default
        {
            if($key.Length -gt 1)
            {
                Write-Host "Invalid Character: '$key'"
            }
            else
            {
                if($global:arrWindows[$global:arrWindows.WindowCurrent].inp[$global:arrWindows.InputCurrent].text.Length -ge $global:arrWindows[$global:arrWindows.WindowCurrent].inp[$global:arrWindows.InputCurrent].length)
                {
                    Write-Host "Maximum Input length reached!"
                }
                else
                {
                    $global:arrWindows[$global:arrWindows.WindowCurrent].inp[$global:arrWindows.InputCurrent].text = $global:arrWindows[$global:arrWindows.WindowCurrent].inp[$global:arrWindows.InputCurrent].text + $key
                    buildInput $global:arrWindows.WindowCurrent $global:arrWindows.InputCurrent $True
                }
            }
        }
    }
}

function onKeyPress($sender, $EventArgs)
{
    $keyCode = [string]($EventArgs.KeyCode)
    
    if($global:arrWindows.InputCurrent -ne "")
    {
        handleInput $keyCode
        return;
    }
    
    switch($keyCode)
    {   
        # handle zoom
        "Add"       
        {
            scaleGame $True
        }
        "Oemplus"
        {
            scaleGame $True
        }
        "Subtract"
        {
            scaleGame $False
        }
        "OemMinus"
        {
            scaleGame $False
        }
        "C"
        {
            showWindow "WND_TEST"
        }
        "Escape"
        {
            #showWindow "WND_ESC_MAIN"
            if($global:strGameState -eq "EDIT_MAP")
            {
                showWindow "WND_ESC_EDITOR"
                $global:strGameState = "EDIT_MAP_ESCAPE"
                $objForm.Refresh();
            }
            elseif($global:strGameState -eq "EDIT_MAP_ESCAPE")
            {
                $global:strGameState = "EDIT_MAP"
                showWindow "WND_INTERFACE_EDITOR"
                $objForm.Refresh();
            }

            if($global:strGameState -eq "SINGLEPLAYER_INGAME")
            {
                showWindow "WND_ESC_SINGLEPLAYER"
                $global:strGameState = "SINGLEPLAYER_ESCAPE"
                $objForm.Refresh();
            }
            elseif($global:strGameState -eq "SINGLEPLAYER_ESCAPE")
            {
                $global:strGameState = "SINGLEPLAYER_INGAME"
                showWindow "WND_SINGLEPLAYER_MENU"
                $objForm.Refresh();
            }
        }
        "T"
        {
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
        "P"
        {
            if($global:strGameState -eq "EDIT_MAP")
            {
                $global:arrCreateMapOptions["SHOW_PREVIEW"] = !$global:arrCreateMapOptions["SHOW_PREVIEW"]
            }
        }
        "Right"
        {
            if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -lt ($global:arrCreateMapOptions["WIDTH"] - 16) -and $global:strGameState -eq "EDIT_MAP")
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_X"] += $global:arrSettings["SCROLLSPEED"];
            }
            if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -lt ($global:arrCreateMapOptions["WIDTH"] - 16) -and $global:strGameState -eq "SINGLEPLAYER_INGAME")
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_X"] += $global:arrSettings["SCROLLSPEED"];
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -gt ($global:arrCreateMapOptions["WIDTH"] - 16))
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_X"] = ($global:arrCreateMapOptions["WIDTH"] - 16)
            }
            $objForm.Refresh();
        }
        "Left"
        {
            if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -gt 0 -and $global:strGameState -eq "EDIT_MAP")
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_X"] -= $global:arrSettings["SCROLLSPEED"];
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -gt 0 -and $global:strGameState -eq "SINGLEPLAYER_INGAME")
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_X"] -= $global:arrSettings["SCROLLSPEED"];
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_X"] -lt 0)
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_X"] = 0
            }
            $objForm.Refresh();
        }
        "Down"
        {
            if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -lt ($global:arrCreateMapOptions["HEIGHT"] - 13) -and $global:strGameState -eq "EDIT_MAP")
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] += $global:arrSettings["SCROLLSPEED"];
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -lt ($global:arrCreateMapOptions["HEIGHT"] - 13) -and $global:strGameState -eq "SINGLEPLAYER_INGAME")
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] += $global:arrSettings["SCROLLSPEED"];
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -gt ($global:arrCreateMapOptions["HEIGHT"] - 13))
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] = ($global:arrCreateMapOptions["HEIGHT"] - 13)
            }
            $objForm.Refresh();
        }
        "Up"
        {
            if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -gt 0 -and $global:strGameState -eq "EDIT_MAP")
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -= $global:arrSettings["SCROLLSPEED"];
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -gt 0 -and $global:strGameState -eq "SINGLEPLAYER_INGAME")
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -= $global:arrSettings["SCROLLSPEED"];
            }

            if($global:arrCreateMapOptions["EDITOR_CHUNK_Y"] -lt 0)
            {
                $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] = 0
            }
            $objForm.Refresh();
        }
        "H"
        {
            $posX = $global:arrMap[("PLAYER_0" + $global:arrPlayerInfo.currentPlayer + "X")]
            $posY = $global:arrMap[("PLAYER_0" + $global:arrPlayerInfo.currentPlayer + "Y")]

            centerOnPosition $posX $posY
        }
        
        default     {Write-Host "Unhandled keypress, code '$keyCode'"}
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
        abortActionsOnRightClick
    }

    if($global:strGameState -eq "WAIT_INIT_CLICK")
    {
        showWindow "WND_ESC_MAIN"
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

function abortActionsOnRightClick()
{

}

function openTileInfoIfNeeded($posX, $posY)
{
    Write-Host "openTileInfoIfNeeded($posX, $posY)"
    #  x ->
    # y
    # |
    # v
    Write-Host "Move left: " ((canTerrainMoveDirection $posX $posY 3) -and (canTerrainMoveDirection ($posX - 1)  $posY 1))
    Write-Host "Move right: " ((canTerrainMoveDirection $posX $posY 1) -and (canTerrainMoveDirection ($posX + 1)  $posY 3))
    Write-Host "Move up: " ((canTerrainMoveDirection $posX $posY 0) -and (canTerrainMoveDirection $posX ($posY - 1) 2))
    Write-Host "Move down: " ((canTerrainMoveDirection $posX $posY 2) -and (canTerrainMoveDirection $posX  ($posY + 1)  0))

    $objID = ([int]($global:arrMap["WORLD_L3"][$posX][$posY]))

    Write-Host "WorldL3 = $objId"

    $bldID = ([int]($global:arrMap["WORLD_LBLD"][$posX][$posY]))

    $global:arrPlayerInfo.currentSelection = $bldID

    $armyID = ([int]($global:arrMap["WORLD_LARMY"][$posX][$posY]))

    resetPlayerTileSelection

    if($bldID -eq -1 -and $objID -eq -1 -and $armyID -eq -1)
    {
        $pictureBox.Refresh();
        return
    }

    $global:arrPlayerInfo.selectedTile.x = $posX
    $global:arrPlayerInfo.selectedTile.y = $posY
    $global:arrPlayerInfo.selectedTile.objectID = $objID
    $global:arrPlayerInfo.selectedTile.buildingID = $bldID
    $global:arrPlayerInfo.selectedTile.armyID = $armyID

    showWindow "WND_TILEINFO"
    $global:strGameState = "SINGLEPLAYER_TILEINFO"

   $pictureBox.Refresh();
}

function ARMY_SetOverlayForAction($action, $posX, $posY)
{
    if($action -eq 1)
    {
        $global:arrMap["WORLD_OVERLAY"][$posX][$posY] = $global:arrInterface["SELECTION_TILE_MOVE"].bitmap
    }
    elseif($action -eq 2 -or $action -eq 3)
    {
        $global:arrMap["WORLD_OVERLAY"][$posX][$posY] = $global:arrInterface["SELECTION_TILE_ATTACK"].bitmap
    }
    else
    {
        $global:arrMap["WORLD_OVERLAY"][$posX][$posY] = $global:arrInterface["SELECTION_TILE_INVALID"].bitmap
    }

    MAP_drawTile $posX $posY
}

function ARMY_GetPossibleAction($posX, $posY, $dir, $posTargetX, $posTargetY)
{
    # scenarios:
    # 0) no movepoints
    # 1) cant move to direction = 0
    # 2) can move to direction, no building, no army = 1
    # 3) can move to direction, hostile army = 2
    # 4) can move to direction, friendly army = 0
    # 5) can move to direction, hostile building = 2
    # 6) can move to direction, friendly building = 1 # if not hostile, simply dont check it
    # 7) can move to direction, hostile army, hostile building = 2

    # 0 = none
    # 1 = move
    # 2 = attack army
    # 3 = attack building

    $sourceArmy = ([int]($global:arrMap["WORLD_LARMY"][$posX][$posY]))

    # 0)
    $canMove = ($global:arrArmies[$sourceArmy][5] -ge 1)

    if(!$canMove) { return 0;}

    # 1)
    $canMove = canTerrainMoveDirection $posX $posY $dir

    if(!$canMove) { return 0;}

    # canTerrainMoveDirection checks for out of world
    $targetArmy = ([int]($global:arrMap["WORLD_LARMY"][$posTargetX][$posTargetY]))
    $targetBuilding = ([int]($global:arrMap["WORLD_LBLD"][$posTargetX][$posTargetY]))

    # 2) no army and no building at target
    if($targetArmy -eq -1 -and $targetBuilding -eq -1) {return 1;}

    $targetArmyOwner = -1
    if($targetArmy -ne -1) {$targetArmyOwner = $global:arrArmies[$targetArmy][2]}
    $sourceArmyOwner = $global:arrArmies[$sourceArmy][2]

    # 3) target army is not owned by the same player
    if($targetArmyOwner -ne -1 -and $targetArmyOwner -ne $sourceArmyOwner) {return 2;}

    # 4) target army is owned by the same player
    if($targetArmyOwner -ne -1 -and $targetArmyOwner -eq $sourceArmyOwner) {return 0;}

    $targetBuildingOwner = -1
    if($targetBuilding -ne -1) {$targetBuildingOwner = $global:arrBuildings[$targetBuilding][2]}

    # 5) hostile building
    if($targetBuildingOwner -ne $sourceArmyOwner) {return 3;}
    # 6) friendly building
    elseif($targetBuildingOwner -eq $sourceArmyOwner) {return 1;}

    # 7) is already checked
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

    if(([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"])) -eq -1 -and !$global:arrSettingsInternal["RECRUIT_ARMY"])
    {
        Write-Host "lets check tile info..."
        openTileinfoIfNeeded ([int]($tile_x - 2)) ([int]($tile_y - 2))
    }
    elseif($global:arrSettingsInternal["RECRUIT_ARMY"])
    {
        $canRecruit = checkIfRecruitingPossible ([int]($tile_x - 2)) ([int]($tile_y - 2)) ($global:arrPlayerInfo.currentPlayer)

        if($canRecruit)
        {
            addArmyAtPositionForPlayer ([int]($tile_x - 2)) ([int]($tile_y - 2)) ($global:arrPlayerInfo.currentPlayer) "Lord Locus"
            $global:arrSettingsInternal["RECRUIT_ARMY"] = $False
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_TILEINFO_RECRUIT")
            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_TILEINFO_RECRUIT" "Green" 136 20 12 214 ($global:arrSettingsInternal["RECRUIT_ARMY"]) "New Army" -1 -1 "Gold" $False
        }
    }
    else
    {
        $canBuild = checkIfBuildingPossible ([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"])) ([int]($tile_x - 2)) ([int]($tile_y - 2)) ($global:arrPlayerInfo.currentPlayer)

        if($canBuild -and ([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"])) -ge 0)
        {
            addBuildingAtPositionForPlayer ([int]($tile_x - 2)) ([int]($tile_y - 2)) $global:arrSettingsInternal["BUILDINGS_SELECTED"] ($global:arrPlayerInfo.currentPlayer) $False

            if(([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"])) -gt 0)
            {
                if($global:arrCreateMapOptions["CLICK_MODE"] -eq 1)
                {
                    $prevColID = [math]::floor(($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"]) / 3)
                    $prevRowID = ($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"]) - 3 *  $prevColID

                    buildButton "Gray"  20 20 (10 + $prevColID * 20 + $prevColID * 18) (58 + $prevRowID * 20 + $prevRowID * 6) $False
                    addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrBuilding[$arrBuildingIDToKey[$global:arrSettingsInternal["BUILDINGS_SELECTED"]]][0]) (11 + $prevColID * 20 + $prevColID * 18) (59 + $prevRowID * 20 + $prevRowID * 6) 1
                }
                else
                {
                    $prevColID = [math]::floor(($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"] - $global:arrSettingsInternal["BUILDINGS_CIVILS"]) / 3)
                    $prevRowID = ($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"] - $global:arrSettingsInternal["BUILDINGS_CIVILS"]) - 3 *  $prevColID

                    buildButton "Gray"  20 20 (10 + $prevColID * 20 + $prevColID * 18) (58 + $prevRowID * 20 + $prevRowID * 6) $False
                    addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrBuilding[$arrBuildingIDToKey[$global:arrSettingsInternal["BUILDINGS_SELECTED"]]][0]) (11 + $prevColID * 20 + $prevColID * 18) (59 + $prevRowID * 20 + $prevRowID * 6) 1
                }
            }

            $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1

            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT2")
            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT2" "Gray" 136 20 12 134 $False "" -1 -1 "Gold" $False

            addColoredArea "WND_SINGLEPLAYER_MENU" 30 162 120 62 "CLR_WINDOW_BACK"
        }
    }

}

function isValidClickPosition($posX, $posY)
{
    if($posX -lt 0 -or $posX -gt $global:arrMap["WIDTH"])
    {
        Write-Host "addBuildingAtPositionForPlayer - ERROR out of world ($posX)"
        return $False;
    }
    
    if($posY -lt 0 -or $posY -gt $global:arrMap["HEIGHT"])
    {
        Write-Host "addBuildingAtPositionForPlayer - ERROR out of world ($posY)"
        return $False;
    }

    return $True;
}

function urand($min, $max)
{
    if($min -eq $max) {return $min}
    return (Get-Random -Minimum $min -Maximum ($max + 1))
}

function addArmyAtPositionForPlayer($posX, $posY, $plrID, $strName)
{
    Write-Host "addArmyAtPositionForPlayer($posX, $posY, $plrID, $strName)"

    $isValidPosition = isValidClickPosition $posX $posY

    if(!$isValidPosition) {return;}

    #$global:arrArmies = @{}
    # 0 = loc_x
    # 1 = loc_y
    # 2 = owner
    # 3 = leaderName
    # 4 = movepoints
    # 5 = level

    # 1 = create new army at current army index
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]] = @{}

    # 2 = set values
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]][0] = $posX
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]][1] = $posY
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]][2] = $plrID
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]][3] = ($strName + $global:arrMap["ARMY_INDEX"])
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]][4] = (urand 0 3) # display graphic
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]][5] = $global:arrSettingsInternal["ARMY_DEFAULT_MP"] # MP
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]][6] = $global:arrSettingsInternal["ARMY_DEFAULT_HP"] # HP
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]][7] = 1 # melee?
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]][8] = 0 # range?
    $global:arrArmies[$global:arrMap["ARMY_INDEX"]][9] = 0 # horse?

    # 3 = set layer
    $global:arrMap["WORLD_LARMY"][$posX][$posY] = $global:arrMap["ARMY_INDEX"]

    # 4 = draw at
    #drawArmyAt $posX $posY ($global:arrMap["ARMY_INDEX"])
    MAP_drawTile $posX $posY

    # 5 = pay?
    updatePlayerStat $plrID 6 (-1 * $global:arrSettingsInternal["ARMY_UNIT_COSTS"][0])
    updatePlayerStat $plrID 9 (-1 * $global:arrSettingsInternal["ARMY_DEFAULT_PEOPLE"])

    # last
    $global:arrMap["ARMY_INDEX"] = $global:arrMap["ARMY_INDEX"] + 1
}

function addBuildingAtPositionForPlayer($posX, $posY, $building, $player, $instant)
{
    Write-Host "addBuildingAtPositionForPlayer($posX, $posY, $building, $player, $instant)"

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

    Write-Host "addBuildingAtPositionForPlayer($posX, $posY, $building, $player)"

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

    $global:arrBuildings[$global:arrMap["BUILDING_INDEX"]] = @{}
    $global:arrBuildings[$global:arrMap["BUILDING_INDEX"]][0] = $posX #locx
    $global:arrBuildings[$global:arrMap["BUILDING_INDEX"]][1] = $posY #loc_y
    $global:arrBuildings[$global:arrMap["BUILDING_INDEX"]][2] = $player #owner
    $global:arrBuildings[$global:arrMap["BUILDING_INDEX"]][3] = $building #building ID
    if($instant)
    {
        $global:arrBuildings[$global:arrMap["BUILDING_INDEX"]][4] = 1 #state (0 building, 1 finished maybe 2 burning later)
        $global:arrBuildings[$global:arrMap["BUILDING_INDEX"]][5] = 1 #percentage of building state (0 = nothing, 1 = done)
    }
    else
    {
        $global:arrBuildings[$global:arrMap["BUILDING_INDEX"]][4] = 0 #state (0 building, 1 finished maybe 2 burning later)
        $global:arrBuildings[$global:arrMap["BUILDING_INDEX"]][5] = 0 #percentage of building state (0 = nothing, 1 = done)
        playSFX "SND_HUM_BUILDING"
    }
    
    $global:arrBuildings[$global:arrMap["BUILDING_INDEX"]][6] = $arrBuilding[$global:arrBuildingIDToKey[$building]].hitpoints

    #
    # 2
    #
    $global:arrMap["WORLD_LBLD"][$posX][$posY] = $global:arrMap["BUILDING_INDEX"]

    # 
    # 2.5
    #
    $global:arrMap["BUILDING_INDEX"] = $global:arrMap["BUILDING_INDEX"] + 1

    #
    # 3 + 4 (for instant)
    #
    if($instant)
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
    updatePlayerStat $player 6 (-1 * ($arrBuilding[$global:arrBuildingIDToKey[$building]].gold_cost))
    updatePlayerStat $player 7 (-1 * ($arrBuilding[$global:arrBuildingIDToKey[$building]].wood_cost))
}

function BLD_DestroyBuilding($bld)
{
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

    # 1 update playerStat if building was finished
    if($state -eq 1)
    {
        updatePlayerProduction $player $bldID -1
    }

    # 2 update world
    $global:arrMap["WORLD_LBLD"][$posX][$posY] = -1
    MAP_drawTile $posX $posY

    # 3 update building array
    $global:arrBuildings.Remove($bld)
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

function MAP_drawTile($posX, $posY)
{
    Write-Host "MAP_drawTile($posX, $posY)"

    if($posX -lt 0 -or $posX -gt $global:arrMap["WIDTH"])
    {
        Write-Host "ERROR: MAP_drawTile($posX, $posY) -> out of bounds (X)"
    }

    if($posY -lt 0 -or $posY -gt $global:arrMap["HEIGHT"])
    {
        Write-Host "ERROR: MAP_drawTile($posX, $posY) -> out of bounds (Y)"
    }

    # ground texture and objects
    MAP_changeTile ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrMap["WORLD_L1"][[int]$posX][[int]$posY]]].bitmap) ($posX + 2) ($posY + 2)

    if([int]$global:arrMap["WORLD_L2"][([int]$posX)][([int]$posY)] -ne -1)
    {
        MAP_changeTile ($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrMap["WORLD_L2"][$posX][$posY]]].bitmap) ($posX + 2) ($posY + 2)
    }

    if([int]($global:arrMap["WORLD_L3"][$posX][$posY]) -ne -1)
    {
        MAP_changeTile ($global:arrTextures[$arrObjectTextureIDToKey[$global:arrMap["WORLD_L3"][$posX][$posY]]].bitmap) ($posX + 2) ($posY + 2)
    }

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

    $armyIndex = $global:arrMap["WORLD_LARMY"][$posX][$posY]

    if($armyIndex -ne -1)
    {
        $owner = $global:arrArmies[$armyIndex][2]
        $graphic = $global:arrArmies[$armyIndex][4]

        MAP_changeTile $arrUnitGFX[$graphic][$owner] ($posX + 2) ($posY + 2)
    }

    $overlay = $global:arrMap["WORLD_OVERLAY"][$posX][$posY]

    if($overlay -ne $null)
    {
        MAP_changeTile $overlay ($posX + 2) ($posY + 2)
    }
}

# offset 0 = inProgress, offset 1 = isFinished
function drawBuildingAt($posX, $posY, $bld, $player, $offset)
{
    Write-Host "drawBuildingAt($posX, $posY, $bld, $player)"

    MAP_changeTile $arrBuilding[$arrBuildingIDToKey[$bld]][($player * 2 + $offset)] ($posX + 2) ($posY + 2)

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

    Write-Host "Cost Gold: " $arrBuilding[$global:arrBuildingIDToKey[$iBuildingID]].gold_cost "/" $global:arrPlayerInfo[$iPlayerID][6]
    Write-Host "Wood Gold: " $arrBuilding[$global:arrBuildingIDToKey[$iBuildingID]].wood_cost "/" $global:arrPlayerInfo[$iPlayerID][7]

    if($arrBuilding[$global:arrBuildingIDToKey[$iBuildingID]].gold_cost -gt $global:arrPlayerInfo[$iPlayerID][6]) {$hasWares = $False}
    if($arrBuilding[$global:arrBuildingIDToKey[$iBuildingID]].wood_cost -gt $global:arrPlayerInfo[$iPlayerID][7]) {$hasWares = $False}

    return $hasWares
}

function checkIfPlayerHasWaresForArmy($iPlayerID)
{
    $hasWares = checkIfPlayerHasWares $iPlayerID 6 50

    if(!$hasWares) {return $False}

    $hasWares = checkIfPlayerHasWares $iPlayerID 9 5

    return $hasWares;
}

function checkIfRecruitingPossible($posX, $posY, $iPlayerID)
{
    $canRecruit = checkIfPlayerHasWaresForArmy $iPlayerID

    if(!$canRecruit) {return $canRecruit}

     $canRecruit = ($global:arrMap["WORLD_CONTINENT"][$posX][$posY] -eq 1)
    if(!$canRecruit) {return $canRecruit}

    $canRecruit = ($global:arrMap["WORLD_LARMY"][$posX][$posY] -eq -1)
    if(!$canRecruit) {return $canRecruit}

    # check if barracks in range
    # TEMPDISABLED
    $canRecruit = hasBuildingInRange 2 9 $iPosX $iPosY $iPlayerID

    if(!$canRecruit) {return $canRecruit}

    return $canRecruit;
}

function checkIfBuildingPossible($iBuildingID, $posX, $posY, $iPlayerID)
{
    ## firstfirst check if player has wares
    $canBuild = checkIfPlayerHasWaresForBuilding $iPlayerID $iBuildingID

    if(!$canBuild) {return $canBuild}

    ## firstfirstsecond check if continent correct
    $canBuild = ($global:arrMap["WORLD_CONTINENT"][$posX][$posY] -eq 1)
    if(!$canBuild) {return $canBuild}

    # first check if it's a valid position
    # LAYER 1 check

    Write-Host "checkIfBuildingPossible($iBuildingID, $posX, $posY, $iPlayerID)"

    if($posX -ge $arrCreateMapOptions["WIDTH"] -or $posY -ge $arrCreateMapOptions["HEIGHT"])
    {
        return $False;
    }

    if($posY -lt 0 -or $posY -lt 0)
    {
        return $False
    }

    $canBuild = $False

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
                    $canBuild = $True
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

    # The building quality is not enough - so return and skip the next check
    if(!$canBuild){return $canBuild}

    $canBuild = checkBuildingPrerequisites $iBuildingID $posX $posY $iPlayerID

    return $canBuild
}

function checkBuildingPrerequisites($iBuildingID, $iPosX, $iPosY, $iPlayerID)
{
    Write-Host "checkBuildingPrerequisites($iBuildingID, $iPosX, $iPosY, $iPlayerID)"

    # TODO: Use hasHQOrTower

    switch($iBuildingID)
    {
        0 # HUM_HQ
        {
            # no prereq for HQs
            return $True
        }
        1 # HUM_HOUSE_SMALL
        {
            # close to HQ?
            $canBuild = hasBuildingInRange 2 0 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            # close to Well?
            $canBuild = hasBuildingInRange 2 6 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            return $False
        }
        2 # HUM_HOUSE_MEDIUM
        {
            # close to HQ?
            $canBuild = hasBuildingInRange 1 0 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            # close to Well?
            $canBuild = hasBuildingInRange 1 6 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            return $False
        }
        3 # HUM_HOUSE_LARGE
        {
            # next to HQ?
            $canBuild = hasBuildingInRange 0 0 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            # next to Well?
            $canBuild = hasBuildingInRange 0 6 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            return $False
        }
        4 # HUM_FARM
        {
            # close to HQ?
            $canBuild = hasBuildingInRange 3 0 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            # close to tower?
            $canBuild = hasBuildingInRange 3 12 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            return $False
        }
        5 # HUM_FIELD
        {
            # close to farm?
            $canBuild = hasBuildingInRange 1 4 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            return $False
        }
        6 # HUM_WELL
        {
            # close to HQ?
            $canBuild = hasBuildingInRange 3 0 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            # close to Tower?
            $canBuild = hasBuildingInRange 3 12 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            return $False
        }
        7 # HUM_MINE
        {
            $hasGold = hasObjectInRange 0 18 $iPosX $iPosY

            if(!$hasGold) {return $False}

            # close to HQ?
            $canBuild = hasBuildingInRange 3 0 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            # close to Tower?
            $canBuild = hasBuildingInRange 3 12 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            return $False
        }
        8 # HUM_SAWMILL
        {
            $hasWood = hasObjectInRange 0 13 $iPosX $iPosY

            if(!$hasWood) {$hasWood = hasObjectInRange 0 14 $iPosX $iPosY}
            if(!$hasWood) {$hasWood = hasObjectInRange 0 15 $iPosX $iPosY}
            if(!$hasWood) {$hasWood = hasObjectInRange 0 16 $iPosX $iPosY}

            if(!$hasWood) {return $False}

            # close to HQ?
            $canBuild = hasBuildingInRange 3 0 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            # close to Tower?
            $canBuild = hasBuildingInRange 3 12 $iPosX $iPosY $iPlayerID

            if($canBuild){return $True}

            return $False
        }
        9
        {
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        }
        10
        {
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        }
        11
        {
            return hasHQTower 3 $iPosX $iPosY $iPlayerID
        }
        12
        {
            return hasHQTower 4 $iPosX $iPosY $iPlayerID
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
    $canBuild = hasBuildingInRange $iRange 12 $iPosX $iPosY $iPlayerID

    if($canBuild){return $True}

    return $False
}

function hasMilitaryBuilding($iRange, $iPosX, $iPosY, $iPlayerID)
{
    # close to HQ?
    $hasInRange = hasBuildingInRange $iRange 0 $iPosX $iPosY $iPlayerID

    if($hasInRange){return $True}

    # close to HUM_BARRACKS?
    $hasInRange = hasBuildingInRange $iRange 9 $iPosX $iPosY $iPlayerID

    if($hasInRange){return $True}

    # close to HUM_ARCHERRANGE?
    $hasInRange = hasBuildingInRange $iRange 10 $iPosX $iPosY $iPlayerID

    if($hasInRange){return $True}

    # close to HUM_STABLE?
    $hasInRange = hasBuildingInRange $iRange 11 $iPosX $iPosY $iPlayerID

    if($hasInRange){return $True}

    # close to HUM_TOWER?
    $hasInRange = hasBuildingInRange $iRange 12 $iPosX $iPosY $iPlayerID

    if($hasInRange){return $True}

    return $False
}

function hasObjectInRange($iMode, $iObjectID, $iPosX, $iPosY)
{
    if($iMode -eq 0)
    {
        ## left
        if($iPosX -gt 0)
        {
            $iObjID = ([int]($global:arrMap["WORLD_L3"][($iPosX - 1)][$iPosY]))
            Write-Host "Left: $iObjID"
            if($iObjID -ne -1)
            {
                if($iObjID -eq $iObjectID) {return $True}
            }
        }
        
        #top 
        if($iPosY -gt 0)
        {
            $iObjID = ([int]($global:arrMap["WORLD_L3"][$iPosX][($iPosY - 1)]))
            Write-Host "top: $iObjID"
            if($iObjID -ne -1)
            {
                if($iObjID -eq $iObjectID) {return $True}
            }
        }
        
        #right
        if($iPosX -lt [int]$global:arrCreateMapOptions["WIDTH"])
        {
            $iObjID = ([int]($global:arrMap["WORLD_L3"][$iPosX + 1][($iPosY)]))
            Write-Host "right: $iObjID"
            if($iObjID -ne -1)
            {
                if($iObjID -eq $iObjectID) {return $True}
            }
            
        }
        
        #bot 
        if($iPosY -lt [int]$global:arrCreateMapOptions["HEIGHT"])
        {
            $iObjID = ([int]($global:arrMap["WORLD_L3"][$iPosX][($iPosY + 1)]))
            Write-Host "bot: $iObjID"
            if($iObjID -ne -1)
            {
                if($iObjID -eq $iObjectID) {return $True}
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

                $iObjID = ([int]($global:arrMap["WORLD_L3"][$i][$j]))
                if($iObjID -ne -1)
                {
                    if($iObjID -eq $iBldID) {return $True}
                }

                Write-Host "Not at: $i $j"
            }
        }
        return $False
    }

    return $False
}

function hasBuildingInRange($iMode, $iBldID, $iPosX, $iPosY, $iPlayerID)
{
    Write-Host "hasBuildingInRange($iMode, $iBldID, $iPosX, $iPosY, $iPlayerID)"
    # 0 = cross
    #    ?
    #   ?B?
    #    ?
    # 1 = around
    #   ???
    #   ?B?
    #   ???
    # 2 = around 2
    #  ?????
    #  ?????
    #  ??B??
    #  ?????
    #  ?????
    #  etc

    if($iMode -eq 0)
    {
        $bldID = ([int]($global:arrMap["WORLD_LBLD"][$iPosX][$iPosY]))

            ## left
            if($iPosX -gt 0)
            {
                $bldID = ([int]($global:arrMap["WORLD_LBLD"][($iPosX - 1)][$iPosY]))
                if($bldID -ne -1)
                {
                    $iOwner = $global:arrBuildings[$bldID][2]
                    $type = $global:arrBuildings[$bldID][3]
                    $state = $global:arrBuildings[$bldID][4]
                    if($type -eq $iBldID -and $state -eq 1 -and $iOwner -eq $iPlayerID) {return $True}
                }
            }
            
            #top 
            if($iPosY -gt 0)
            {
                $bldID = ([int]($global:arrMap["WORLD_LBLD"][$iPosX][($iPosY - 1)]))
                if($bldID -ne -1)
                {
                    $iOwner = $global:arrBuildings[$bldID][2]
                    $type = $global:arrBuildings[$bldID][3]
                    $state = $global:arrBuildings[$bldID][4]
                    if($type -eq $iBldID -and $state -eq 1 -and $iOwner -eq $iPlayerID) {return $True}
                }
            }
            
            #right
            if($iPosX -lt [int]$global:arrCreateMapOptions["WIDTH"])
            {
                $bldID = ([int]($global:arrMap["WORLD_LBLD"][$iPosX + 1][($iPosY)]))
                if($bldID -ne -1)
                {
                    $iOwner = $global:arrBuildings[$bldID][2]
                    $type = $global:arrBuildings[$bldID][3]
                    $state = $global:arrBuildings[$bldID][4]
                    if($type -eq $iBldID -and $state -eq 1 -and $iOwner -eq $iPlayerID) {return $True}
                }
                
            }
            
            #bot 
            if($iPosY -lt [int]$global:arrCreateMapOptions["HEIGHT"])
            {
                $bldID = ([int]($global:arrMap["WORLD_LBLD"][$iPosX][($iPosY + 1)]))
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
    
    if($global:arrCreateMapOptions["EDIT_MODE"] -eq 1 -and (($global:arrCreateMapOptions["LAST_CHANGED_X"] -ne $tile_x) -or ($global:arrCreateMapOptions["LAST_CHANGED_Y"] -ne $tile_y) -or ($global:arrCreateMapOptions["LAST_MODE"] -ne 1) -or ($global:arrCreateMapOptions["LAST_CHANGED_TEX"] -ne $global:arrCreateMapOptions["SELECT_LAYER01"])))
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
    elseif($global:arrCreateMapOptions["EDIT_MODE"] -eq 2 -and (($global:arrCreateMapOptions["LAST_CHANGED_X"] -ne $tile_x) -or ($global:arrCreateMapOptions["LAST_CHANGED_Y"] -ne $tile_y) -or ($global:arrCreateMapOptions["LAST_MODE"] -ne 2) -or ($global:arrCreateMapOptions["LAST_CHANGED_TEX"] -ne $global:arrCreateMapOptions["SELECT_LAYER02"])))
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
    elseif($global:arrCreateMapOptions["EDIT_MODE"] -eq 3 -and (($global:arrCreateMapOptions["LAST_CHANGED_X"] -ne $tile_x) -or ($global:arrCreateMapOptions["LAST_CHANGED_Y"] -ne $tile_y) -or ($global:arrCreateMapOptions["LAST_MODE"] -ne 3) -or ($global:arrCreateMapOptions["LAST_CHANGED_TEX"] -ne $global:arrCreateMapOptions["SELECT_LAYER03"])))
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
    elseif($global:arrCreateMapOptions["EDIT_MODE"] -eq 5)
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
                    
                    if($global:arrCreateMapOptions["SELECT_PLAYER"] -ne 0)
                    {
                        removePlayerFromPosition $global:arrCreateMapOptions["SELECT_PLAYER"]
                    }

                    if($global:arrCreateMapOptions["SELECT_PLAYER"] -ne 0)
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

    if($posX -lt $global:arrMap["WIDTH"])
    {
        $global:arrMap["WORLD_OVERLAY"][($posX + 1)][$posY] = $null
        MAP_drawTile ($posX + 1)  $posY
    }

    if($posY -lt $global:arrMap["HEIGHT"])
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

function ARMY_DoAction($armyID, $action, $targetX, $targetY)
{
    Write-Host "ARMY_DoAction($armyID, $action, $targetX, $targetY)"
    switch($action)
    {
        1 # move
        {
            ARMY_UpdateMovepoints $armyID -1

            $posX = $global:arrArmies[$armyID][0]
            $posY = $global:arrArmies[$armyID][1]
            $global:arrArmies[$armyID][0] = $targetX
            $global:arrArmies[$armyID][1] = $targetY

            $global:arrMap["WORLD_LARMY"][$posX][$posY] = -1

            $global:arrMap["WORLD_LARMY"][$targetX][$targetY] = $armyID

            MAP_drawTile $posX $posY
            MAP_drawTile $targetX $targetY
        }
        2 # attack Army
        {
            ARMY_UpdateMovepoints $armyID -1

            $targetArmy = $global:arrMap["WORLD_LARMY"][$targetX][$targetY]

            $defeat = ARMY_DoArmyBattle $armyID $targetArmy

            # need to know we lost the army
            if($defeat) {$action = 4}
        }
        3 # attack building
        {
            ARMY_UpdateMovepoints $armyID -1

            $posX = $global:arrArmies[$armyID][0]
            $posY = $global:arrArmies[$armyID][1]

            $bldID = $global:arrMap["WORLD_LBLD"][$targetX][$targetY]

            ## 6 = current hitpoints

            $dmgBuilding = ARMY_GetDamageBuilding $armyID

            BLD_DamageBuilding $bldID $dmgBuilding
        }
    }

    return $action;
}

function ARMY_DoArmyBattle($attackerID, $defenderID)
{
    $combatData = @{}

    $combatData[0] = $global:arrArmies[$attackerID][2] #owner1
    $combatData[1] = $global:arrArmies[$attackerID][3] #lord1
    $combatData[2] = $global:arrArmies[$defenderID][2] #owner2
    $combatData[3] = $global:arrArmies[$defenderID][3] #lord2

    $combatData[4] = $global:arrArmies[$attackerID][6] #hp1
    $combatData[5] = $global:arrArmies[$attackerID][7] #melee1
    $combatData[6] = $global:arrArmies[$attackerID][8] #range1
    $combatData[7] = $global:arrArmies[$attackerID][9] #horse1
    $combatData[8] = $global:arrArmies[$defenderID][6] #hp2
    $combatData[9] = $global:arrArmies[$defenderID][7] #melee2
    $combatData[10] = $global:arrArmies[$defenderID][8] #range2
    $combatData[11] = $global:arrArmies[$defenderID][9] #horse2
    $combatData.fights = @{}

    # 2 = set values
    $attHP = $global:arrArmies[$attackerID][6]
    $defHP = $global:arrArmies[$defenderID][6]

    while($True)
    {
        $combatID = ($combatData.fights.Count)
        $combatData.fights[$combatID] = @{}

        $attReg = ARMY_GetRandomRegiment $attackerID
        $defReg = ARMY_GetRandomRegiment $defenderID

        $combatData.fights[$combatID][1] = ($attReg -7)#regiment1
        $combatData.fights[$combatID][4] = ($defReg -7)#regiment2

        $attackerDefeated = $False
        $defenderDefeated = $False

        if($attReg -eq $defReg)
        {
            # either both receive damage if they still have HP
            # if one does not have any HP left, the regiment is lost
            # if no regiment and no HP left, the army is lost
            $attackerDefeated = ARMY_DamageWithRegiment $attackerID $attReg
            $defenderDefeated = ARMY_DamageWithRegiment $defenderID $defReg

            $combatData.fights[$combatID][2] = 0
            $combatData.fights[$combatID][5] = 0
        }
        else
        {
            # either of the combatants loses HP, depending on the armies fighting

            $loser = ARMY_GetFightLoser $attackerID ($attReg - 6) $defenderID ($defReg - 6)
            if($loser -eq $attackerID)
            {
                $attackerDefeated = ARMY_DamageWithRegiment $attackerID $attReg

                $combatData.fights[$combatID][2] = 0
                $combatData.fights[$combatID][5] = 1
            }
            else
            {
                $defenderDefeated = ARMY_DamageWithRegiment $defenderID $defReg
                $combatData.fights[$combatID][2] = 1
                $combatData.fights[$combatID][5] = 0
            }
        }

        if(!$attackerDefeated) {$combatData.fights[$combatID][0] = $global:arrArmies[$attackerID][6]} #hp1
        else{$combatData.fights[$combatID][0] = 0}

        if(!$defenderDefeated) {$combatData.fights[$combatID][3] = $global:arrArmies[$defenderID][6]} #hp2
        else{$combatData.fights[$combatID][3] = 0}

        $combatData[12] = !$attackerDefeated # won1?
        $combatData[13] = !$defenderDefeated

        if($attackerDefeated) {$global:arrPlayerInfo.combatData = $combatData; return $True;}
        if($defenderDefeated) {$global:arrPlayerInfo.combatData = $combatData; return $False;}
    }
}

function ARMY_DamageWithRegiment($armyID, $regimentID)
{
    # hp left? lose one
    if($global:arrArmies[$armyID][6] -gt 1)
    {
        $global:arrArmies[$armyID][6] = $global:arrArmies[$armyID][6] - 1
        return $False
    }
    else
    {
        $global:arrArmies[$armyID][$regimentID] = 0
    }

    if(([int]($global:arrArmies[$armyID][7] + $global:arrArmies[$armyID][8] + $global:arrArmies[$armyID][9])) -le 0)
    {
        ARMY_DestroyArmy $armyID
        return $True
    }

    return $False
}

function ARMY_DestroyArmy($armyID)
{
    if($armyID -eq -1) {return}

    $posX = $global:arrArmies[$armyID][0]
    $posY = $global:arrArmies[$armyID][1]

    # 2 update world
    $global:arrMap["WORLD_LARMY"][$posX][$posY] = -1
    MAP_drawTile $posX $posY

    # 3 update building array
    $global:arrArmies.Remove($armyID)
}

function ARMY_GetFightLoser($armyID1, $armyRegiment1, $armyID2, $armyRegiment2)
{
    #       MELEE   RANGE   HORSE
    # MELEE none    RANGE   MELEE
    # RANGE RANGE   none    HORSE
    # HORSE MELEE   HORSE   none
    # melee vs range = range
    if($armyRegiment1 -eq 1 -and $armyRegiment2 -eq 2)
    {
        return $armyID1
    }
    elseif($armyRegiment1 -eq 2 -and $armyRegiment2 -eq 1)
    {
        return $armyID2
    }

    # range vs horse = horse
    if($armyRegiment1 -eq 2 -and $armyRegiment2 -eq 3)
    {
        return $armyID1
    }
    elseif($armyRegiment1 -eq 3 -and $armyRegiment2 -eq 2)
    {
        return $armyID2
    }

    # horse vs melee = melee
    if($armyRegiment1 -eq 1 -and $armyRegiment2 -eq 3)
    {
        return $armyID2
    }
    elseif($armyRegiment1 -eq 3 -and $armyRegiment2 -eq 1)
    {
        return $armyID1
    }

    Write-Host "$armyID1 $armyRegiment1 vs $armyID2 $armyRegiment2"

    throw "ARMY_GetFightLoser did not yield any loser?"
}

function ARMY_GetRandomRegiment($armyID)
{
    Write-Host "ARMY_GetRandomRegiment($armyID)"
    # possibly: 0 0 1, 0 1 0, 0 1 1, 1 0 1 etc., need to 'patch' holes
    $iRegiments = [int]($global:arrArmies[$armyID][7] + $global:arrArmies[$armyID][8] + $global:arrArmies[$armyID][9])

    # if only 1 regiment, this yields 1 - so the first valid regiment should be used
    # if there are 2 regiments (e.g. 0,1,1) the second should be used
    $iRandomReg = (urand 1 $iRegiments)

    for($i = 7; $i -lt 10; $i++)
    {
        if($global:arrArmies[$armyID][$i] -ne 0) {$iRandomReg = $iRandomReg - 1}

        if($iRandomReg -le 0) {return $i}
    }

    throw "Random Regiment did not result in any valid!"
}

function BLD_DamageBuilding($bldID, $dmgBuilding)
{
    Write-Host "BLD_DamageBuilding($bldID, $dmgBuilding)"

    $global:arrBuildings[$bldID][6] = $global:arrBuildings[$bldID][6] - $dmgBuilding

    $state = $global:arrBuildings[$bldID][4]

    # 2x dmg if building isn't finished
    if($state -ne 1)
    {
        $global:arrBuildings[$bldID][6] = $global:arrBuildings[$bldID][6] - $dmgBuilding
    }

    if($global:arrBuildings[$bldID][6] -le 0)
    {
        BLD_DestroyBuilding $bldID
    }
}

function ARMY_GetDamageBuilding($armyID)
{
    Write-Host "ARMY_GetDamageBuilding($armyID)"

    # dmgMin = regiments, so maximum 3, minimum 1
    $dmgMin = [int]($global:arrArmies[$armyID][7] + $global:arrArmies[$armyID][8] + $global:arrArmies[$armyID][9])
    # dmgMax = regiments + HP, so maximum 8, minimum 2
    $dmgMax = [int]($dmgMin + $global:arrArmies[$armyID][6])

    return (urand ($dmgMin * 10) ($dmgMax * 10))
}

function ARMY_HandleActionIfAny($posX, $posY)
{
    if($global:arrPlayerInfo.selectedTile.mode -ne "ARMY") {return 0;}

    Write-Host "ARMY_HandleActionIfAny($posX, $posY)"

    $tile_x = [int](([math]::floor($posX / $global:arrSettingsInternal["TILESIZE"]) + $global:arrCreateMapOptions["EDITOR_CHUNK_X"]) - 2)
    $tile_y = [int](([math]::floor($posY / $global:arrSettingsInternal["TILESIZE"]) + $global:arrCreateMapOptions["EDITOR_CHUNK_Y"]) - 2)

    $locX = [int]($global:arrPlayerInfo.selectedTile.x)
    $locY = [int]($global:arrPlayerInfo.selectedTile.y)

    if($locX -eq -1 -or $locY -eq -1) {return $False; }

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

    if($global:strGameState -eq "SINGLEPLAYER_TILEINFO" -and $posX -lt ($DrawingSizeX - 160) -and $global:arrWindows.WindowCurrent -ne "WND_COMBAT_RESULTS")
    {
        Write-Host "Host korrekte stelle aber army action check?"
        # handle possible army actions
        $armyAction = ARMY_HandleActionIfAny $posX $posY

        Write-Host "Army Action: $armyAction"

        if($armyAction -eq 4 -or $armyAction -eq 2)
        {
            showWindow "WND_COMBAT_RESULTS" $global:arrPlayerInfo.combatData
        }
        elseif($armyAction -eq 0)
        {
            handleButtonKlick "BTN_TILEINFO_QUIT"
        }
        return;
    }
    
    if($global:arrWindows.WindowOpen -and !$global:arrWindows[$global:arrWindows.WindowCurrent].btn -and !$global:arrWindows[$global:arrWindows.WindowCurrent].inp)
    {
        Write-Host "Active window but no buttons?"
        return;
    }

    if($global:arrWindows.InputCurrent -ne "")
    {
        handleInputInactive $global:arrWindows.WindowCurrent $global:arrWindows.InputCurrent
    }
    
    if($posX -lt $global:arrWindows[$global:arrWindows.WindowCurrent].loc_x -or $posX -gt ($global:arrWindows[$global:arrWindows.WindowCurrent].loc_x + $global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Width))
    {
        return;
    }
    
    if($posY -lt $global:arrWindows[$global:arrWindows.WindowCurrent].loc_y -or $posY -gt ($global:arrWindows[$global:arrWindows.WindowCurrent].loc_y + $global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Height))
    {
        return;
    }
    
    $keys    = $global:arrWindows[$global:arrWindows.WindowCurrent].btn.Keys
    
    Try
    {
        foreach($key in $keys)
        {
            if(!$global:arrWindows[$global:arrWindows.WindowCurrent].btn)
            {
                return;
            }
            
            if(($global:arrWindows[$global:arrWindows.WindowCurrent].btn[$key].loc_x -lt $relX) -and ($global:arrWindows[$global:arrWindows.WindowCurrent].btn[$key].loc_x + $global:arrWindows[$global:arrWindows.WindowCurrent].btn[$key].size_x -gt $relX))
            {
                if(($global:arrWindows[$global:arrWindows.WindowCurrent].btn[$key].loc_y -lt $relY) -and ($global:arrWindows[$global:arrWindows.WindowCurrent].btn[$key].loc_y + $global:arrWindows[$global:arrWindows.WindowCurrent].btn[$key].size_y -gt $relY))
                {
                    handleButtonKlick $key ($relX - $global:arrWindows[$global:arrWindows.WindowCurrent].btn[$key].loc_x) ($relY - $global:arrWindows[$global:arrWindows.WindowCurrent].btn[$key].loc_y) $global:arrWindows[$global:arrWindows.WindowCurrent].btn[$key].size_x $global:arrWindows[$global:arrWindows.WindowCurrent].btn[$key].size_y
                }
            }
        }
    }
    Catch [system.exception]
    {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Warning: Maybe a click has not properly been registered!"
        Write-Host "Error: $ErrorMessage"
    }

    $keys    = $global:arrWindows[$global:arrWindows.WindowCurrent].inp.Keys
    Try
    {
        foreach($key in $keys)
        {
            if(!$global:arrWindows[$global:arrWindows.WindowCurrent].btn)
            {
                return;
            }
            
            if(($global:arrWindows[$global:arrWindows.WindowCurrent].inp[$key].loc_x -lt $relX) -and ($global:arrWindows[$global:arrWindows.WindowCurrent].inp[$key].loc_x + $global:arrWindows[$global:arrWindows.WindowCurrent].inp[$key].size_x -gt $relX))
            {
                if(($global:arrWindows[$global:arrWindows.WindowCurrent].inp[$key].loc_y -lt $relY) -and ($global:arrWindows[$global:arrWindows.WindowCurrent].inp[$key].loc_y + $global:arrWindows[$global:arrWindows.WindowCurrent].inp[$key].size_y -gt $relY))
                {
                    Write-Host "Input $key was clicked"
                    handleInputClick $global:arrWindows.WindowCurrent $key
                }
            }
        }
    }
    Catch [system.exception]
    {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Warning: Maybe a click has not properly been registered!"
        Write-Host "Error: $ErrorMessage"
    }
}

function handleEndTurnPlayer()
{
    Write-Host "handleEndTurnPlayer"

    if((isLastPlayer $global:arrPlayerInfo.currentPlayer))
    {
        Write-Host "isLastPlayer"
        handleNextDay
        Write-Host "afterNextDay"
        $global:arrPlayerInfo.currentPlayer = getFirstActivePlayer
    }
    else
    {
        $global:arrPlayerInfo.currentPlayer = getNextActivePlayer ($global:arrPlayerInfo.currentPlayer)
    }

    $posX = $global:arrMap[("PLAYER_0" + $global:arrPlayerInfo.currentPlayer + "X")]
    $posY = $global:arrMap[("PLAYER_0" + $global:arrPlayerInfo.currentPlayer + "Y")]

    centerOnPosition $posX $posY
}

function handleNextDay
{
    # 1 - reset production
    for($i = 1; $i -le $global:arrSettingsInternal["PLAYER_MAX"];$i++)
    {
        #$global:arrPlayerInfo[$i][6] = $global:arrPlayerInfo[$i][6] + $global:arrPlayerInfo[$i][1]
        #$global:arrPlayerInfo[$i][7] = $global:arrPlayerInfo[$i][7] + $global:arrPlayerInfo[$i][2]
        #$global:arrPlayerInfo[$i][8] = $global:arrPlayerInfo[$i][8] + $global:arrPlayerInfo[$i][3]
        $global:arrPlayerInfo[$i][1] = 0
        $global:arrPlayerInfo[$i][2] = 0
        $global:arrPlayerInfo[$i][3] = 0
        $global:arrPlayerInfo[$i][4] = 0
    }

    # 2 - update buildings (after wares because buildings which are finished dont produce something this day)
    for($i = 0; $i -lt $global:arrMap["BUILDING_INDEX"]; $i++)
    {
        if(!($global:arrBuildings[$i])){continue}

        # check if building is in progress
        if(([int]($global:arrBuildings[$i][4]) -eq 0))
        {
            #percentage of building state (0 = nothing, 1 = done)
            $global:arrBuildings[$i][5] += $arrBuilding[$global:arrBuildingIDToKey[$global:arrBuildings[$i][3]]].buildspeed

            $percent = $global:arrBuildings[$i][5]
            $buildspeed = $arrBuilding[$global:arrBuildingIDToKey[$global:arrBuildings[$i][3]]].buildspeed

            # building is done, so update it
            if($global:arrBuildings[$i][5] -ge 0.99)
            {
                $global:arrBuildings[$i][5] = 1
                $global:arrBuildings[$i][4] = 1
                drawBuildingAt ($global:arrBuildings[$i][0]) ($global:arrBuildings[$i][1]) ($global:arrBuildings[$i][3]) ($global:arrBuildings[$i][2]) 0

                #updatePlayerProduction ($global:arrBuildings[$i][2]) ($global:arrBuildings[$i][3]) 1
            }
            else
            {
                MAP_addBuildingBar $i
            }
        }
        
        # means a building that is finished counts
        if($global:arrBuildings[$i][4] -eq 1)
        {
            updatePlayerProduction ($global:arrBuildings[$i][2]) ($global:arrBuildings[$i][3]) 1
        }
    }

    # 2.1 apply income
    for($i = 1; $i -le $global:arrSettingsInternal["PLAYER_MAX"];$i++)
    {
        $global:arrPlayerInfo[$i][6] = $global:arrPlayerInfo[$i][6] + $global:arrPlayerInfo[$i][1]
        $global:arrPlayerInfo[$i][7] = $global:arrPlayerInfo[$i][7] + $global:arrPlayerInfo[$i][2]
        $global:arrPlayerInfo[$i][8] = $global:arrPlayerInfo[$i][8] + $global:arrPlayerInfo[$i][3]
        # people are not summed but set
        $global:arrPlayerInfo[$i][9] = $global:arrPlayerInfo[$i][4]
    }

    # 3 - update armies
    for($i = 0; $i -lt $global:arrMap["ARMY_INDEX"]; $i++)
    {
        if(!($global:arrArmies[$i])){continue}

        # regen HP
        if($global:arrArmies[$i][5] -ge 1)
        {
            $global:arrArmies[$i][6] = [int]($global:arrArmies[$i][6] + $global:arrArmies[$i][5])

            if($global:arrArmies[$i][6] -gt $global:arrSettingsInternal["ARMY_DEFAULT_HP"])
            {
                $global:arrArmies[$i][6] = $global:arrSettingsInternal["ARMY_DEFAULT_HP"]
            }
        }

        $global:arrArmies[$i][5] = $global:arrSettingsInternal["ARMY_DEFAULT_MP"]

        # update people usage, this can also result in negative numbers
        $global:arrPlayerInfo[($global:arrArmies[$i][2])][9] = $global:arrPlayerInfo[($global:arrArmies[$i][2])][9] - ([int]($global:arrArmies[$i][7] + $global:arrArmies[$i][8] + $global:arrArmies[$i][9])) * 5

    }


    $pictureBox.Refresh();
}

function handleButtonKlick($strButtonID, $iPosX, $iPosY, $iSizeX, $iSizeY)
{
    switch($strButtonID)
    {
        "BTN_QUIT"
        {
            showWindow "WND_QUIT_MAIN"
        }
        "BTN_QUIT_NO"
        {
            showWindow "WND_ESC_MAIN"
        }
        "BTN_CREDITS"
        {
            showWindow "WND_CREDITS"
        }
        "BTN_QUIT_YES"
        {
            $objForm.Close();
        }
        "BTN_OPTIONS"
        {
            showWindow "WND_GAME_OPTIONS"
        }
        "BTN_GAME_OPTIONS_BACK"
        {
            saveConfig
            showWindow "WND_ESC_MAIN"
        }
        "BTN_CREDITS_BACK"
        {
            showWindow "WND_ESC_MAIN"
        }
        "BTN_SINGLEPLAYER"
        {
            showWindow "WND_SINGLEPLAYER_TYPESELECTION"
        }
        "BTN_BACK_TO_SINGLEPLAYER"
        {
            showWindow "WND_SINGLEPLAYER_TYPESELECTION"
        }
        "BTN_CAMPAIGN"
        {
            showWindow "WND_ERROR_NOTIMPLEMENTED_SINGLEPLAYER"
        }
        "BTN_FREEPLAY"
        {
            showWindow "WND_SINGLEPLAYER_SETUP"
        }
        "BTN_TUTORIAL"
        {
            showWindow "WND_RTFM"
        }
        "BTN_BACK_TO_MAINMENU"
        {
            showWindow "WND_ESC_MAIN"
        }
        "BTN_MULTIPLAYER"
        {
            showWindow "WND_ERROR_NOTIMPLEMENTED_MULTIPLAYER"
        }
        "BTN_SINGLEPLAYER_SETUP_START"
        {
            Write-Host "BTN_SINGLEPLAYER_SETUP_START"

            if($global:strMapFile -eq "")
            {
                Write-Host "No mapfile"
                return;
            }

            Write-Host "check slots"
            # no local player?
            if(!(gameHasPlayerType(3)))
            {
                Write-Host "no local"
                showWindow "WND_ERROR_NOLOCALPLAYER"
                return;
            }
            # open slots?
            elseif (gameHasPlayerType(4))
            {
                Write-Host "openslots"
                showWindow "WND_ERROR_HASOPENSLOTS"
                return;
            }

            Write-Host "reset some stuff..."

            $global:arrMap["WIDTH"] = 0
            $global:arrMap["HEIGHT"] = 0
            
            # reset buildings
            $global:arrBuildings = @{}
            $global:arrBuildings[0] = @{}

            $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1

            Write-Host "now the please wait..."

            showWindow "WND_PLEASE_WAIT"

            Write-Host "before load map"

            try
            {
                loadMap $global:strMapFile
            }
            catch
            {
                $ErrorMessage = $_.Exception.Message
                Write-Host $ErrorMessage
            }

            $global:strGameState = "SINGLEPLAYER_INGAME";

            showWindow "WND_SINGLEPLAYER_MENU"

            Write-Host "before player set"

            $global:arrPlayerInfo.currentPlayer = getFirstActivePlayer
            showWindow "WND_NEXT_PLAYER"

            $pictureBox.Refresh();
        }
        "BTN_ERROR_NOTIMPLEMENTED_BACK"
        {
            showWindow "WND_ESC_MAIN"
        }
        "BTN_ERROR_OK_SINGLEPLAYER_SETUP"
        {
            showWindow "WND_SINGLEPLAYER_SETUP"
        }
        "BTN_EDITOR"
        {
            #Reset Variables
            $global:arrCreateMapOptions["EDITOR_CHUNK_X"] = 0;
            $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] = 0;
        
            showWindow "WND_CREATE_MAP"
        }
        "BTN_CREATE_MAP_CANCEL"
        {
            showWindow "WND_ESC_MAIN"
        }
        "BTN_CREATEMAP_TEXTURE_PREV"
        {
            if($global:arrCreateMapOptions["BASTEXTUREID"] -ne 0)
            {
                $global:arrCreateMapOptions["BASTEXTUREID"] -= 1;
            }
            else
            {
                $global:arrCreateMapOptions["BASTEXTUREID"] = $arrBaseTextureIDToKey.Length - 1;
            }
            addImageToWindow "WND_CREATE_MAP" ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrCreateMapOptions["BASTEXTUREID"]]].bitmap) 210 74 1
            $pictureBox.Refresh();
        }
        "BTN_CREATEMAP_TEXTURE_NEXT"
        {
            if($global:arrCreateMapOptions["BASTEXTUREID"] -ne ($arrBaseTextureIDToKey.Length - 1))
            {
                $global:arrCreateMapOptions["BASTEXTUREID"] += 1;
            }
            else
            {
                $global:arrCreateMapOptions["BASTEXTUREID"] = 0;
            }
            addImageToWindow "WND_CREATE_MAP" ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrCreateMapOptions["BASTEXTUREID"]]].bitmap) 210 74 1
            $pictureBox.Refresh();
        }
        "BTN_CREATEMAP_WADD01"
        {
            MAP_changeMapsizeBy "WIDTH" 16 $True
        }
        "BTN_CREATEMAP_WADD02"
        {
            MAP_changeMapsizeBy "WIDTH" 2 $True
        }
        "BTN_CREATEMAP_WIDTH"
        {
        }
        "BTN_CREATEMAP_WSUB01"
        {
            MAP_changeMapsizeBy "WIDTH" -2 $True
        }
        "BTN_CREATEMAP_WSUB02"
        {
            MAP_changeMapsizeBy "WIDTH" -16 $True
        }
        "BTN_CREATEMAP_HADD01"
        {
            MAP_changeMapsizeBy "HEIGHT" 16 $True
        }
        "BTN_CREATEMAP_HADD02"
        {
            MAP_changeMapsizeBy "HEIGHT" 2 $True
        }
        "BTN_CREATEMAP_HEIGHT"
        {
        }
        "BTN_CREATEMAP_HSUB01"
        {
            MAP_changeMapsizeBy "HEIGHT" -2 $True
        }
        "BTN_CREATEMAP_HSUB02"
        {
            MAP_changeMapsizeBy "HEIGHT" -16 $True
        }
        "BTN_CREATE_MAP_CONTINUE"
        {
            # Creating map...
            showWindow "WND_PLEASE_WAIT"
            $global:strGameState = "EDIT_MAP";
            initMapArray

            MAP_createMapImage
            showWindow "WND_INTERFACE_EDITOR"

            $objForm.Refresh();
        }
        "BTN_CREATE_MAP_LOAD"
        {
            openMapFile
            if($global:strMapFile -ne "")
            {
                showWindow "WND_PLEASE_WAIT"
                $global:strGameState = "EDIT_MAP";
                loadMap $global:strMapFile
                showWindow "WND_INTERFACE_EDITOR"
            }
            else
            {
                Write-Host "No map selected"
            }
        }
        "BTN_SINGLEPLAYER_SETUP_MAP"
        {
            openMapFile
            if($global:strMapFile -ne "")
            {
                $global:arrWindows["WND_SINGLEPLAYER_SETUP"].btn.Remove("BTN_SINGLEPLAYER_SETUP_MAP")
                $filename = Split-Path $global:strMapFile -leaf
                addButtonToWindow "WND_SINGLEPLAYER_SETUP" "BTN_SINGLEPLAYER_SETUP_MAP" "Gray" 338 20 90 12 $True $filename 6 6 "Gold" $False

                # header load map
                loadMapHeader $global:strMapFile

                # Playercount
                addColoredArea "WND_SINGLEPLAYER_SETUP" 90 46 100 26 "CLR_WINDOW_BACK"
                [string]$playerCount = getPlayerCount
                addText "WND_SINGLEPLAYER_SETUP" $playerCount 90 46 "Gold" $False

                # Author
                addColoredArea "WND_SINGLEPLAYER_SETUP" 90 76 100 26 "CLR_WINDOW_BACK"
                addText "WND_SINGLEPLAYER_SETUP" $global:arrMap["AUTHOR"] 90 76 "Gold" $False

                # Size
                addColoredArea "WND_SINGLEPLAYER_SETUP" 90 106 100 26 "CLR_WINDOW_BACK"
                addText "WND_SINGLEPLAYER_SETUP" ($global:arrMap["WIDTH"] + " x " + $global:arrMap["HEIGHT"]) 90 106 "Gold" $False

                # preview
                addImageToWindow "WND_SINGLEPLAYER_SETUP" $global:arrMap.preview_wnd 90 136 2
                
                # remove all buttons
                $global:arrWindows["WND_SINGLEPLAYER_SETUP"].btn.Remove(("BTN_SINGLEPLAYER_SETUP_P1"))
                $global:arrWindows["WND_SINGLEPLAYER_SETUP"].btn.Remove(("BTN_SINGLEPLAYER_SETUP_P2"))
                $global:arrWindows["WND_SINGLEPLAYER_SETUP"].btn.Remove(("BTN_SINGLEPLAYER_SETUP_P3"))
                $global:arrWindows["WND_SINGLEPLAYER_SETUP"].btn.Remove(("BTN_SINGLEPLAYER_SETUP_P4"))
                addColoredArea "WND_SINGLEPLAYER_SETUP"  200 46 170 110 "CLR_WINDOW_BACK"

                # this is where the player array is filled
                # playername (0)
                # income_gold (1)
                # income_wood (2)
                # income_food (3)
                # income_people (4)
                # playertype (index) (5)
                # amount_gold (6)
                # amount_wood (7)
                # amount_food (8)
                # amount_people (9)
                for($p = 1; $p -le 4; $p++)
                {
                    $global:arrPlayerInfo[$p] = @{}

                    $global:arrPlayerInfo[$p][0] = ("Player " + $p) # name
                    $global:arrPlayerInfo[$p][1] = 0
                    $global:arrPlayerInfo[$p][2] = 0
                    $global:arrPlayerInfo[$p][3] = 0
                    $global:arrPlayerInfo[$p][4] = 0
                    $global:arrPlayerInfo[$p][5] = 0
                    $global:arrPlayerInfo[$p][6] = 250
                    $global:arrPlayerInfo[$p][7] = 250
                    $global:arrPlayerInfo[$p][8] = 50
                    $global:arrPlayerInfo[$p][9] = 5
                }

                for($p = 1; $p -le $playerCount; $p++)
                {
                    addText "WND_SINGLEPLAYER_SETUP" ("Player #" + $p + ":") 200 (16 + $p * 30) "Gold" $False
                    addColoredArea "WND_SINGLEPLAYER_SETUP"  200 (24 + $p * 30) 66 10 ("CLR_PLAYER_" + $p + "1")
                    $global:arrPlayerInfo[$p][5] = 3

                    addButtonToWindow "WND_SINGLEPLAYER_SETUP" ("BTN_SINGLEPLAYER_SETUP_P" + $p) "Gray" 100 20 270 (16 + $p * 30) $False ($global:arrPlayertypeIndexString[($global:arrPlayerInfo[$p][5])]) 6 6 "Gold" $False
                }

                $objForm.Refresh();
            }  
        }
        "BTN_SINGLEPLAYER_SETUP_P1"
        {
            handleSingleplayerPlayerButton 1
        }
        "BTN_SINGLEPLAYER_SETUP_P2"
        {
            handleSingleplayerPlayerButton 2
        }
        "BTN_SINGLEPLAYER_SETUP_P3"
        {
            handleSingleplayerPlayerButton 3
        }
        "BTN_SINGLEPLAYER_SETUP_P4"
        {
            handleSingleplayerPlayerButton 4
        }
        "BTN_SWITCH_TOPMOST"
        {
            $global:arrWindows["WND_GAME_OPTIONS"].btn.Remove("BTN_SWITCH_TOPMOST")
            $global:arrSettings["TOPMOST"] = !$global:arrSettings["TOPMOST"];
            $objForm.Topmost = $global:arrSettings["TOPMOST"];
            addSwitchButtonToWindow "WND_GAME_OPTIONS" "BTN_SWITCH_TOPMOST" $global:arrSettings["TOPMOST"] 60 20 240 12 $True $False
        }
        "BTN_GAME_OPTIONS_FACE_SUB"
        {
            if(([int]($global:arrSettings["PLAYER_FACE"])) -eq 0)
            {
                ([int]($global:arrSettings["PLAYER_FACE"])) = ([int]($global:arrSettingsInternal["PLAYER_FACE_MAX"]))
            }
            else
            {
                ([int]($global:arrSettings["PLAYER_FACE"])) = ([int]($global:arrSettings["PLAYER_FACE"])) - 1
            }

            Write-Host "Face: " $global:arrSettings["PLAYER_FACE"]

            addImageToWindow "WND_GAME_OPTIONS" ($global:arrTextures[(nameToId "FACE_" $global:arrSettings["PLAYER_FACE"])].bitmap) 270 84 1
            $objForm.Refresh();
        }
        "BTN_GAME_OPTIONS_FACE_ADD"
        {
            if(([int]($global:arrSettings["PLAYER_FACE"])) -eq ([int]($global:arrSettingsInternal["PLAYER_FACE_MAX"])))
            {
                ([int]($global:arrSettings["PLAYER_FACE"])) = 0
            }
            else
            {
                ([int]($global:arrSettings["PLAYER_FACE"])) = ([int]($global:arrSettings["PLAYER_FACE"])) + 1
            }
            
            Write-Host "Face: " $global:arrSettings["PLAYER_FACE"]

            addImageToWindow "WND_GAME_OPTIONS" ($global:arrTextures[(nameToId "FACE_" $global:arrSettings["PLAYER_FACE"])].bitmap) 270 84 1
            $objForm.Refresh();
        }
        "BTN_WND_GAME_OPTIONS_VOLUMEMUSIC"
        {
            $newX = [math]::floor($iPosX / 20)
            $global:arrWindows["WND_GAME_OPTIONS"].btn.Remove("BTN_WND_GAME_OPTIONS_VOLUMEMUSIC")
            addCountButtonToWindow "WND_GAME_OPTIONS" "BTN_WND_GAME_OPTIONS_VOLUMEMUSIC" 20 20 240 36 5 ($newX + 1) $False 0
            
            Write-Host "Setting music volume..."
            $global:arrSettings["VOLUMEMUSIC"] = $newX * 0.025;
            if([int]$global:arrSettingsInternal["SONGS"] -gt 0){ playSongs }
        }
        "BTN_WND_GAME_OPTIONS_VOLUMEEFFECTS"
        {
            $newX = [math]::floor($iPosX / 20)
            $global:arrWindows["WND_GAME_OPTIONS"].btn.Remove("BTN_WND_GAME_OPTIONS_VOLUMEEFFECTS")
            addCountButtonToWindow "WND_GAME_OPTIONS" "BTN_WND_GAME_OPTIONS_VOLUMEEFFECTS" 20 20 240 60 5 ($newX + 1) $False 0
            
            $global:arrSettings["VOLUMEEFFECTS"] = $newX * 0.025;
        }
        "BTN_WND_GAME_OPTIONS_SCROLLSPEED"
        {
            $newX = [math]::floor($iPosX / 20)

            $global:arrWindows["WND_GAME_OPTIONS"].btn.Remove("BTN_WND_GAME_OPTIONS_SCROLLSPEED")
            $global:arrSettings["SCROLLSPEED"] = $newX + 1;
            addCountButtonToWindow "WND_GAME_OPTIONS" "BTN_WND_GAME_OPTIONS_SCROLLSPEED" 20 20 240 108 5 ($global:arrSettings["SCROLLSPEED"]) $False 1
        }
        "BTN_EDITOR_QUIT"
        {
            showWindow "WND_QUIT_EDITOR"
        }
        "BTN_EDITOR_QUIT_YES"
        {
            $global:strGameState = "MAIN_MENU"
            $global:arrWindows.WindowCurrent = "WND_ESC_MAIN"
            $objForm.Refresh();
        }
        "BTN_EDITOR_QUIT_NO"
        {
            showWindow "WND_ESC_EDITOR"
            $objForm.Refresh();
        }
        "BTN_SINGLEPLAYER_QUIT"
        {
            showWindow "WND_QUIT_SINGLEPLAYER"
        }
        "BTN_SINGLEPLAYER_QUIT_YES"
        {
            $global:strGameState = "MAIN_MENU"
            $global:arrWindows.WindowCurrent = "WND_ESC_MAIN"
            $objForm.Refresh();
        }
        "BTN_SINGLEPLAYER_BACK"
        {
            $global:strGameState = "SINGLEPLAYER_INGAME"
            showWindow "WND_SINGLEPLAYER_MENU"
            $objForm.Refresh();
        }
        "BTN_SINGLEPLAYER_QUIT_NO"
        {
            showWindow "WND_ESC_SINGLEPLAYER"
            $objForm.Refresh();
        }
        "BTN_EDITOR_SAVEIMAGE"
        {
            showWindow "WND_PLEASE_WAIT"
            $objForm.Refresh();
            try
            {
                Write-Host "Path: " ($PSScriptRoot + ".\MAP\" + ($global:arrMap["MAPNAME"]) + ".png")
                $global:objWorld.Save(($PSScriptRoot + ".\MAP\" + ($global:arrMap["MAPNAME"]) + ".png"))
            }
            catch 
            {
                $ErrorMessage = $_.Exception.Message
                Write-Host "Error: $ErrorMessage"
            }
            Write-Host "Image has been saved!"
            showWindow "WND_ESC_EDITOR"
            $objForm.Refresh();
        }
        "BTN_EDITOR_SAVEMAP"
        {
            showWindow "WND_PLEASE_WAIT"
            Write-Host "Building MMAP..."
            buildMMAP
            Write-Host "Saving Map..."
            saveMap ""
            showWindow "WND_ESC_EDITOR"
        }
        # TODO cleanup BTN_IFE
        "BTN_IFE_EDIT_LAYER01"
        {
            if($global:arrCreateMapOptions["EDIT_MODE"] -eq 1)
            {
                return;
            }
        
            $global:arrCreateMapOptions["EDIT_MODE"] = 1;
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER02_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER03_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_PLAYER_SELECT")
            #$global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER02_PREV")
            #$global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER02_NEXT")
            
            buildButton "GRAY" 20 20 10 12 $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_01"].bitmap) 12 14 1
            
            buildButton "GRAY" 20 20 34 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_02"].bitmap) 36 14 1
            
            buildButton "GRAY" 20 20 58 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_03"].bitmap) 60 14 1
        
            buildButton "GRAY" 20 20 82 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_DIRECTION"].bitmap) 84 14 1
        
            buildButton "GRAY" 20 20 106 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_PLAYER"].bitmap) 108 14 1
            
            buildButton "GRAY" 20 20 130 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_SETTINGS"].bitmap) 132 14 1
            
            addColoredArea "WND_INTERFACE_EDITOR" 16 36 120 220 "CLR_WINDOW_BACK"
            
            addButtonToWindow "WND_INTERFACE_EDITOR" "BTN_IFE_EDIT_LAYER01_SELECT" "Transparent" 120 160 16 36 $False "" 8 4 "Gold" $False
            
            
            $max_tex_id = $arrBaseTextureIDToKey.Length
            for($i = 0; $i -lt 6; $i++)
            {
                for($j = 0; $j -lt 8; $j++)
                {
                    $tex_id = ($global:arrCreateMapOptions["IDX_LAYER01"] + ($i * 8) + $j)
                    
                    if($tex_id -lt $max_tex_id)
                    {
                        buildButton "GRAY"  20 20 (16 + $i * 20) (36 + $j * 20) $False
                        addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrBaseTextureIDToKey[$tex_id]].bitmap) (18 + $i * 20) (38 + $j * 20) 1
                    }
                }
            }
            
            # initiales markieren
            $old_x = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER01"] / 8)
            $old_y = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER01"] - ($old_x * 8))
            buildButton "RED"  20 20 (16 + $old_x * 20) (36 + $old_y * 20) $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER01"]]].bitmap) (19 + $old_x * 20) (39 + $old_y * 20) 1
            
            $pictureBox.Refresh();
        }
        "BTN_IFE_EDIT_LAYER01_SELECT"
        {
            $texID = [math]::floor($iPosX / 20) * 8 + [math]::floor($iPosY / 20)
            $max_tex_id = $arrBaseTextureIDToKey.Length
            $texID += $global:arrCreateMapOptions["IDX_LAYER01"];
            
            if($texID -lt $max_tex_id -and $texID -ne $global:arrCreateMapOptions["SELECT_LAYER01"])
            {
                # alte markierung übermalen
                $old_x = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER01"] / 8)
                $old_y = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER01"] - ($old_x * 8))
                buildButton "GRAY"  20 20 (16 + $old_x * 20) (36 + $old_y * 20) $False
                addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrBaseTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER01"]]].bitmap) (18 + $old_x * 20) (38 + $old_y * 20) 1
            
                # neue markierung malen
                $tmp_i = [math]::floor($iPosX / 20)
                $tmp_j = [math]::floor($iPosY / 20)
                buildButton "RED"  20 20 (16 + $tmp_i * 20) (36 + $tmp_j * 20) $True
                addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrBaseTextureIDToKey[$texID]].bitmap) (19 + $tmp_i * 20) (39 + $tmp_j * 20) 1
                
                $global:arrCreateMapOptions["SELECT_LAYER01"] = $texID;
                $pictureBox.Refresh();
            }
            
            Write-Host "TextureID: $texID"
        }
        "BTN_IFE_EDIT_LAYER02"
        {
            if($global:arrCreateMapOptions["EDIT_MODE"] -eq 2)
            {
                return;
            }
        
            $global:arrCreateMapOptions["EDIT_MODE"] = 2;
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER01_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER03_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_PLAYER_SELECT")
            #$global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER01_PREV")
            #$global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER01_NEXT")
            
            buildButton "GRAY" 20 20 10 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_01"].bitmap) 12 14 1
            
            buildButton "GRAY" 20 20 34 12 $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_02"].bitmap) 36 14 1
            
            buildButton "GRAY" 20 20 58 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_03"].bitmap) 60 14 1
        
            buildButton "GRAY" 20 20 82 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_DIRECTION"].bitmap) 84 14 1
        
            buildButton "GRAY" 20 20 106 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_PLAYER"].bitmap) 108 14 1
            
            buildButton "GRAY" 20 20 130 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_SETTINGS"].bitmap) 132 14 1
        
            addColoredArea "WND_INTERFACE_EDITOR" 16 36 120 220 "CLR_WINDOW_BACK"
            
            addButtonToWindow "WND_INTERFACE_EDITOR" "BTN_IFE_EDIT_LAYER02_SELECT" "Transparent" 120 160 16 36 $False "" 8 4 "Gold" $False
   
            $max_tex_id = $arrOverlayTextureIDToKey.Length
            for($i = 0; $i -lt 6; $i++)
            {
                for($j = 0; $j -lt 8; $j++)
                {
                    $tex_id = ($global:arrCreateMapOptions["IDX_LAYER02"] + ($i * 8) + $j)
                    
                    if($tex_id -lt $max_tex_id)
                    {
                        buildButton "GRAY"  20 20 (16 + $i * 20) (36 + $j * 20) $False
                        addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrOverlayTextureIDToKey[$tex_id]].bitmap) (18 + $i * 20) (38 + $j * 20) 1
                    }
                }
            }
            
            # initiales markieren
            $old_x = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER02"] / 8)
            $old_y = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER02"] - ($old_x * 8))
            buildButton "RED"  20 20 (16 + $old_x * 20) (36 + $old_y * 20) $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER02"]]].bitmap) (19 + $old_x * 20) (39 + $old_y * 20) 1
            
            $pictureBox.Refresh();
        }
        "BTN_IFE_EDIT_LAYER02_SELECT"
        {
            $texID = [math]::floor($iPosX / 20) * 8 + [math]::floor($iPosY / 20)
            $max_tex_id = $arrOverlayTextureIDToKey.Length
            $texID += $global:arrCreateMapOptions["IDX_LAYER02"];
            
            if($texID -lt $max_tex_id -and $texID -ne $global:arrCreateMapOptions["SELECT_LAYER02"])
            {
                # alte markierung übermalen
                $old_x = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER02"] / 8)
                $old_y = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER02"] - ($old_x * 8))
                buildButton "GRAY"  20 20 (16 + $old_x * 20) (36 + $old_y * 20) $False
                addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER02"]]].bitmap) (18 + $old_x * 20) (38 + $old_y * 20) 1
            
                # neue markierung malen
                $tmp_i = [math]::floor($iPosX / 20)
                $tmp_j = [math]::floor($iPosY / 20)
                buildButton "RED"  20 20 (16 + $tmp_i * 20) (36 + $tmp_j * 20) $True
                addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrOverlayTextureIDToKey[$texID]].bitmap) (19 + $tmp_i * 20) (39 + $tmp_j * 20) 1
                
                $global:arrCreateMapOptions["SELECT_LAYER02"] = $texID;
                $pictureBox.Refresh();
            }
            Write-Host "TextureID(Layer2): $texID"
        }
        "BTN_IFE_EDIT_LAYER03"
        {
            if($global:arrCreateMapOptions["EDIT_MODE"] -eq 3)
            {
                return;
            }

            $global:arrCreateMapOptions["EDIT_MODE"] = 3;
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER01_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER02_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_PLAYER_SELECT")
            
            buildButton "GRAY" 20 20 10 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_01"].bitmap) 12 14 1
            
            buildButton "GRAY" 20 20 34 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_02"].bitmap) 36 14 1
            
            buildButton "GRAY" 20 20 58 12 $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_03"].bitmap) 60 14 1
        
            buildButton "GRAY" 20 20 82 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_DIRECTION"].bitmap) 84 14 1
        
            buildButton "GRAY" 20 20 106 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_PLAYER"].bitmap) 108 14 1
            
            buildButton "GRAY" 20 20 130 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_SETTINGS"].bitmap) 132 14 1
        
            addButtonToWindow "WND_INTERFACE_EDITOR" "BTN_IFE_EDIT_LAYER03_SELECT" "Transparent" 120 160 16 36 $False "" 8 4 "Gold" $False

            addColoredArea "WND_INTERFACE_EDITOR" 16 36 120 220 "CLR_WINDOW_BACK"

            $max_tex_id = $arrObjectTextureIDToKey.Length
            for($i = 0; $i -lt 6; $i++)
            {
                for($j = 0; $j -lt 8; $j++)
                {
                    $tex_id = ($global:arrCreateMapOptions["IDX_LAYER03"] + ($i * 8) + $j)
                    
                    if($tex_id -lt $max_tex_id)
                    {
                        buildButton "GRAY"  20 20 (16 + $i * 20) (36 + $j * 20) $False
                        addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrObjectTextureIDToKey[$tex_id]].bitmap) (18 + $i * 20) (38 + $j * 20) 1
                    }
                }
            }
            
            # initiales markieren
            $old_x = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER03"] / 8)
            $old_y = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER03"] - ($old_x * 8))
            buildButton "RED"  20 20 (16 + $old_x * 20) (36 + $old_y * 20) $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrObjectTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER03"]]].bitmap) (19 + $old_x * 20) (39 + $old_y * 20) 1
            
            $pictureBox.Refresh();
        }
        "BTN_IFE_EDIT_LAYER03_SELECT"
        {
            $texID = [math]::floor($iPosX / 20) * 8 + [math]::floor($iPosY / 20)
            $max_tex_id = $arrObjectTextureIDToKey.Length
            $texID += $global:arrCreateMapOptions["IDX_LAYER03"];
            
            if($texID -lt $max_tex_id -and $texID -ne $global:arrCreateMapOptions["SELECT_LAYER03"])
            {
                # alte markierung übermalen
                $old_x = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER03"] / 8)
                $old_y = [math]::floor($global:arrCreateMapOptions["SELECT_LAYER03"] - ($old_x * 8))
                buildButton "GRAY"  20 20 (16 + $old_x * 20) (36 + $old_y * 20) $False
                addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrObjectTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER03"]]].bitmap) (18 + $old_x * 20) (38 + $old_y * 20) 1
            
                # neue markierung malen
                $tmp_i = [math]::floor($iPosX / 20)
                $tmp_j = [math]::floor($iPosY / 20)
                buildButton "RED"  20 20 (16 + $tmp_i * 20) (36 + $tmp_j * 20) $True
                addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrObjectTextureIDToKey[$texID]].bitmap) (19 + $tmp_i * 20) (39 + $tmp_j * 20) 1
                
                $global:arrCreateMapOptions["SELECT_LAYER03"] = $texID;
                $pictureBox.Refresh();
            }
            Write-Host "TextureID(Layer3): $texID"
        }
        "BTN_IFE_EDIT_DIRECTIONS"
        {
            $global:arrCreateMapOptions["EDIT_MODE"] = 4;
            
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER01_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER02_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER03_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_PLAYER_SELECT")

            buildButton "GRAY" 20 20 10 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_01"].bitmap) 12 14 1
            
            buildButton "GRAY" 20 20 34 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_02"].bitmap) 36 14 1
            
            buildButton "GRAY" 20 20 58 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_03"].bitmap) 60 14 1
        
            buildButton "GRAY" 20 20 82 12 $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_DIRECTION"].bitmap) 84 14 1
        
            buildButton "GRAY" 20 20 106 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_PLAYER"].bitmap) 108 14 1
            
            buildButton "GRAY" 20 20 130 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_SETTINGS"].bitmap) 132 14 1
        
            addColoredArea "WND_INTERFACE_EDITOR" 16 36 120 220 "CLR_WINDOW_BACK"
        
            $pictureBox.Refresh();
        }
        "BTN_IFE_EDIT_PLAYER"
        {
            $global:arrCreateMapOptions["EDIT_MODE"] = 5;

            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER01_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER02_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER03_SELECT")
            
            buildButton "GRAY" 20 20 10 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_01"].bitmap) 12 14 1
            
            buildButton "GRAY" 20 20 34 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_02"].bitmap) 36 14 1
            
            buildButton "GRAY" 20 20 58 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_03"].bitmap) 60 14 1
        
            buildButton "GRAY" 20 20 82 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_DIRECTION"].bitmap) 84 14 1
        
            buildButton "GRAY" 20 20 106 12 $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_PLAYER"].bitmap) 108 14 1
            
            buildButton "GRAY" 20 20 130 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_SETTINGS"].bitmap) 132 14 1
        
            addButtonToWindow "WND_INTERFACE_EDITOR" "BTN_IFE_EDIT_PLAYER_SELECT" "Transparent" 20 100 16 36 $False "" 8 4 "Gold" $False

            addColoredArea "WND_INTERFACE_EDITOR" 16 36 120 220 "CLR_WINDOW_BACK"


            $max_tex_id = $arrObjectTextureIDToKey.Length
            for($i = 0; $i -lt 5; $i++)
            {
                buildButton "GRAY"  20 20 16 (36 + $i * 20) $False
                addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrPlayerIconsIDToKey[$i]].bitmap) 18 (38 + $i * 20) 1
            }
            
            buildButton "RED"  20 20 16 (36 + 20 * $global:arrCreateMapOptions["SELECT_PLAYER"]) $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrPlayerIconsIDToKey[$global:arrCreateMapOptions["SELECT_PLAYER"]]].bitmap) 19 (39 + 20 * $global:arrCreateMapOptions["SELECT_PLAYER"]) 1


            $pictureBox.Refresh();
        }
        "BTN_IFE_EDIT_PLAYER_SELECT"
        {
            $playerID = [math]::floor($iPosY / 20)

            # redraw old selection
            buildButton "GRAY"  20 20 16 (36 + $global:arrCreateMapOptions["SELECT_PLAYER"] * 20) $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrPlayerIconsIDToKey[$global:arrCreateMapOptions["SELECT_PLAYER"]]].bitmap) 18 (38 + $global:arrCreateMapOptions["SELECT_PLAYER"] * 20) 1

            $global:arrCreateMapOptions["SELECT_PLAYER"] = $playerID

            # redraw new selection
            buildButton "RED"  20 20 16 (36 + 20 * $global:arrCreateMapOptions["SELECT_PLAYER"]) $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrTextures[$arrPlayerIconsIDToKey[$global:arrCreateMapOptions["SELECT_PLAYER"]]].bitmap) 19 (39 + 20 * $global:arrCreateMapOptions["SELECT_PLAYER"]) 1

            Write-Host "Player with ID $playerID selected"

        }
        "BTN_IFE_EDIT_LAYERSETTINGS"
        {
            $global:arrCreateMapOptions["EDIT_MODE"] = 6;

            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER01_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER02_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_LAYER03_SELECT")
            $global:arrWindows["WND_INTERFACE_EDITOR"].btn.Remove("BTN_IFE_EDIT_PLAYER_SELECT")
            
            buildButton "GRAY" 20 20 10 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_01"].bitmap) 12 14 1
            
            buildButton "GRAY" 20 20 34 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_02"].bitmap) 36 14 1
            
            buildButton "GRAY" 20 20 58 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_03"].bitmap) 60 14 1
        
            buildButton "GRAY" 20 20 82 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_DIRECTION"].bitmap) 84 14 1
        
            buildButton "GRAY" 20 20 106 12 $False
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_PLAYER"].bitmap) 108 14 1
            
            buildButton "GRAY" 20 20 130 12 $True
            addImageToWindow "WND_INTERFACE_EDITOR" ($global:arrIcons["ICON_LAYER_SETTINGS"].bitmap) 132 14 1
        
            addColoredArea "WND_INTERFACE_EDITOR" 16 36 120 220 "CLR_WINDOW_BACK"
        
            $pictureBox.Refresh();
        }
        "BTN_BUILDINGS_01"
        {
            $global:arrCreateMapOptions["CLICK_MODE"] = 1;
            $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1

            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_BUILDING_02_SELECT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT_AMOUNT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT_PRODUCTION")
            $global:arrSettingsInternal["RECRUIT_ARMY"] = $False
            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT" "Gray" 136 20 12 34 $False "Economy Buildings" -1 -1 "Gold" $False
            addColoredArea "WND_SINGLEPLAYER_MENU" 10 54 140 180 "CLR_WINDOW_BACK"

            Write-Host "After Redraw"

            buildButton "GRAY" 20 20 10 12 $True
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_BUILDING_01"].bitmap) 12 14 1

            buildButton "GRAY" 20 20 34 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_BUILDING_02"].bitmap) 36 14 1

            buildButton "GRAY" 20 20 58 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_WARES"].bitmap) 60 14 1

            buildButton "GRAY" 20 20 82 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_ARMIES"].bitmap) 84 14 1

            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_BUILDING_01_SELECT" "Transparent" 120 90 10 58 $False "" 8 4 "Gold" $False

            $offset_text_id = [int]($global:arrSettingsInternal["BUILDINGS_MIN"])
            $max_tex_id = [int]($global:arrSettingsInternal["BUILDINGS_CIVILS"])

            $offset_text_id = [int]($global:arrSettingsInternal["BUILDINGS_MIN"])
            $max_tex_id = $offset_text_id + [int]($global:arrSettingsInternal["BUILDINGS_CIVILS"])

            for($i = 0; $i -lt 4; $i++)
            {
                for($j = 0; $j -lt 3; $j++)
                {
                    $tex_id = (($i * 3) + $j) + $offset_text_id
                    
                    Write-Host "TexID is: $tex_id"

                    if($tex_id -lt $max_tex_id)
                    {
                        Write-Host "TexID is: $tex_id"
                        buildButton "GRAY"  20 20 (10 + $i * 20 + $i * 18) (58 + $j * 20 + $j * 6) $False
                        addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrBuilding[$arrBuildingIDToKey[$tex_id]][0]) (11 + $i * 20 + $i * 18) (59 + $j * 20 + $j * 6) 1
                    }
                }
            }

            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT2")
            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT2" "Gray" 136 20 12 134 $False "" -1 -1 "Gold" $False

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_GOLDCOIN"].bitmap) 10 158 1

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_WOOD"].bitmap) 10 176 1

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_FOOD"].bitmap) 10 194 1

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_PEOPLE"].bitmap) 10 212 1
        }
        "BTN_BUILDING_01_SELECT"
        {
            $texID = -1

            $ColID = [math]::floor($iPosX / 38)
            $RowID = [math]::floor($iPosY / 26)

            if($iPosX -gt ($ColID * 20 + $ColID * 18) -and $iPosX -lt (20 + $ColID * 20 + $ColID * 18))
            {
                if($iPosY -gt ($RowID * 20 + $RowID * 6) -and $iPosY -lt (20 + $RowID * 20 + $RowID * 6))
                {
                    $texID = $ColID * 3 + $RowID + $global:arrSettingsInternal["BUILDINGS_MIN"]
                }
            }

            if($RowID -ge 3) {return;}

            if($texID -eq -1 -or $texID -gt $global:arrSettingsInternal["BUILDINGS_CIVILS"])
            {
                return;
            }

            # select new building
            buildButton "GRAY"  20 20 (10 + $ColID * 20 + $ColID * 18) (58 + $RowID * 20 + $RowID * 6) $True
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrBuilding[$arrBuildingIDToKey[$texID]][0]) (11 + $ColID * 20 + $ColID * 18) (59 + $RowID * 20 + $RowID * 6) 1

            if(([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"])) -gt 0)
            {
                $prevColID = [math]::floor(($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"]) / 3)
                $prevRowID = ($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"]) - 3 *  $prevColID

                $val0 = $global:arrSettingsInternal["BUILDINGS_SELECTED"]
                $val1 = ($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"])
                $val2 = (($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"]) / 3)

                Write-Host "Vals: $val0 $val1 $val2"

                Write-Host "Prev: $prevColID $prevRowID"

                buildButton "GRAY"  20 20 (10 + $prevColID * 20 + $prevColID * 18) (58 + $prevRowID * 20 + $prevRowID * 6) $False
                addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrBuilding[$arrBuildingIDToKey[$global:arrSettingsInternal["BUILDINGS_SELECTED"]]][0]) (11 + $prevColID * 20 + $prevColID * 18) (59 + $prevRowID * 20 + $prevRowID * 6) 1
            }

            if($texID -eq ([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"])))
            {
                $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1
                $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT2")
                addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT2" "Gray" 136 20 12 134 $False "" -1 -1 "Gold" $False

                addColoredArea "WND_SINGLEPLAYER_MENU" 30 162 120 62 "CLR_WINDOW_BACK"
            }
            else
            {
                $global:arrSettingsInternal["BUILDINGS_SELECTED"] = $texID
                $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT2")
                addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT2" "Gray" 136 20 12 134 $False ($global:arrBuilding[$arrBuildingIDToKey[$texID]].Name) -1 -1 "Gold" $False

                addColoredArea "WND_SINGLEPLAYER_MENU" 30 162 120 62 "CLR_WINDOW_BACK"

                if(([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].gold_cost)) -ne "")
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].gold_cost)) 30 162 "Red" $False
                }
                else
                {
                    addText "WND_SINGLEPLAYER_MENU" "-" 30 162 "Red" $False
                }

                if(([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].wood_cost)) -ne "")
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].wood_cost)) 30 180 "Red" $False
                }
                else
                {
                    addText "WND_SINGLEPLAYER_MENU" "-" 30 180 "Red" $False
                }

                if(([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].food_cost)) -ne "")
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].food_cost)) 30 198 "Red" $False
                }
                else
                {
                    addText "WND_SINGLEPLAYER_MENU" "-" 30 198 "Red" $False
                }

                if(([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].production_cost)) -ne "")
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].production_cost)) 30 216 "Red" $False
                }
                else
                {
                    addText "WND_SINGLEPLAYER_MENU" "-" 30 216 "Red" $False
                }

                if(($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionType) -eq 1)
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 198 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 216 "Green" $False
                }
                elseif(($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionType) -eq 2)
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 198 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 216 "Green" $False
                }
                elseif(($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionType) -eq 3)
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 198 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 216 "Green" $False
                }
                elseif(($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionType) -eq 4)
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 216 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 198 "Green" $False
                }
                elseif(($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionType) -eq 5)
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 198 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 216 "Green" $False
                }
                else
                {
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 198 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 216 "Green" $False
                }

            }

            Write-Host "TextureID: $texID"
        }
        "BTN_BUILDINGS_02"
        {
            $global:arrCreateMapOptions["CLICK_MODE"] = 2;
            $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1

            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_BUILDING_01_SELECT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT_AMOUNT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT_PRODUCTION")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_TILEINFO_RECRUIT")
            $global:arrSettingsInternal["RECRUIT_ARMY"] = $False
            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT" "Gray" 136 20 12 34 $False "Military Buildings" -1 -1 "Gold" $False
            addColoredArea "WND_SINGLEPLAYER_MENU" 10 54 140 180 "CLR_WINDOW_BACK"

            buildButton "GRAY" 20 20 10 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_BUILDING_01"].bitmap) 12 14 1

            buildButton "GRAY" 20 20 34 12 $True
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_BUILDING_02"].bitmap) 36 14 1

            buildButton "GRAY" 20 20 58 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_WARES"].bitmap) 60 14 1

            buildButton "GRAY" 20 20 82 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_ARMIES"].bitmap) 84 14 1

            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_BUILDING_02_SELECT" "Transparent" 120 90 10 58 $False "" 8 4 "Gold" $False

            $offset_text_id = [int]($global:arrSettingsInternal["BUILDINGS_MIN"]) + [int]($global:arrSettingsInternal["BUILDINGS_CIVILS"])
            $max_tex_id = $offset_text_id + [int]($global:arrSettingsInternal["BUILDINGS_MILITARY"])

            Write-Host "Max Tex ID2 $max_tex_id $offset_text_id"
            for($i = 0; $i -lt 4; $i++)
            {
                for($j = 0; $j -lt 3; $j++)
                {
                    $tex_id = (($i * 3) + $j) + $offset_text_id
                    
                    Write-Host "TexID is: $tex_id " ($max_tex_id - $offset_text_id)

                    if($tex_id -lt $max_tex_id)
                    {
                        Write-Host "TexID is: $tex_id"
                        buildButton "GRAY"  20 20 (10 + $i * 20 + $i * 18) (58 + $j * 20 + $j * 6) $False
                        addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrBuilding[$arrBuildingIDToKey[$tex_id]][0]) (11 + $i * 20 + $i * 18) (59 + $j * 20 + $j * 6) 1
                    }
                }
            }

            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT2")
            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT2" "Gray" 136 20 12 134 $False "" -1 -1 "Gold" $False

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_GOLDCOIN"].bitmap) 10 158 1

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_WOOD"].bitmap) 10 176 1

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_FOOD"].bitmap) 10 194 1

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_PEOPLE"].bitmap) 10 212 1
        }
        "BTN_BUILDING_02_SELECT"
        {
            $texID = -1

            $ColID = [math]::floor($iPosX / 38)
            $RowID = [math]::floor($iPosY / 26)
            if($iPosX -gt ($ColID * 20 + $ColID * 18) -and $iPosX -lt (20 + $ColID * 20 + $ColID * 18))
            {
                if($iPosY -gt ($RowID * 20 + $RowID * 6) -and $iPosY -lt (20 + $RowID * 20 + $RowID * 6))
                {
                    $texID = $ColID * 3 + $RowID + ([int]($global:arrSettingsInternal["BUILDINGS_MIN"])) + ([int]($global:arrSettingsInternal["BUILDINGS_CIVILS"]))
                }
            }

            if($RowID -ge 3) {return;}

            if($texID -eq -1 -or $texID -gt (([int]($global:arrSettingsInternal["BUILDINGS_CIVILS"])) + ([int]($global:arrSettingsInternal["BUILDINGS_MILITARY"]))))
            {
                return;
            }

            Write-Host "TexID: " $texID

            # select new building
            buildButton "GRAY"  20 20 (10 + $ColID * 20 + $ColID * 18) (58 + $RowID * 20 + $RowID * 6) $True
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrBuilding[$arrBuildingIDToKey[$texID]][0]) (11 + $ColID * 20 + $ColID * 18) (59 + $RowID * 20 + $RowID * 6) 1

            if(([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"])) -gt 0)
            {
                $prevColID = [math]::floor(($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"] - $global:arrSettingsInternal["BUILDINGS_CIVILS"]) / 3)
                $prevRowID = ($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"] - $global:arrSettingsInternal["BUILDINGS_CIVILS"]) - 3 *  $prevColID

                $val0 = $global:arrSettingsInternal["BUILDINGS_SELECTED"]
                $val1 = ($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"])
                $val2 = (($global:arrSettingsInternal["BUILDINGS_SELECTED"] - $global:arrSettingsInternal["BUILDINGS_MIN"]) / 3)

                Write-Host "Vals: $val0 $val1 $val2"

                Write-Host "Prev: $prevColID $prevRowID"

                buildButton "GRAY"  20 20 (10 + $prevColID * 20 + $prevColID * 18) (58 + $prevRowID * 20 + $prevRowID * 6) $False
                addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrBuilding[$arrBuildingIDToKey[$global:arrSettingsInternal["BUILDINGS_SELECTED"]]][0]) (11 + $prevColID * 20 + $prevColID * 18) (59 + $prevRowID * 20 + $prevRowID * 6) 1
            }

            if($texID -eq ([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"])))
            {
                $global:arrSettingsInternal["BUILDINGS_SELECTED"] = -1
                $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT2")
                addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT2" "Gray" 136 20 12 134 $False "" -1 -1 "Gold" $False

                addColoredArea "WND_SINGLEPLAYER_MENU" 30 162 120 62 "CLR_WINDOW_BACK"
            }
            else
            {
                $global:arrSettingsInternal["BUILDINGS_SELECTED"] = $texID
                $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT2")
                addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT2" "Gray" 136 20 12 134 $False ($global:arrBuilding[$arrBuildingIDToKey[$texID]].Name) -1 -1 "Gold" $False

                addColoredArea "WND_SINGLEPLAYER_MENU" 30 162 120 62 "CLR_WINDOW_BACK"

                if(([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].gold_cost)) -ne "")
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].gold_cost)) 30 162 "Red" $False
                }
                else
                {
                    addText "WND_SINGLEPLAYER_MENU" "-" 30 162 "Red" $False
                }

                if(([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].wood_cost)) -ne "")
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].wood_cost)) 30 180 "Red" $False
                }
                else
                {
                    addText "WND_SINGLEPLAYER_MENU" "-" 30 180 "Red" $False
                }

                if(([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].food_cost)) -ne "")
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].food_cost)) 30 198 "Red" $False
                }
                else
                {
                    addText "WND_SINGLEPLAYER_MENU" "-" 30 198 "Red" $False
                }

                if(([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].production_cost)) -ne "")
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].production_cost)) 30 216 "Red" $False
                }
                else
                {
                    addText "WND_SINGLEPLAYER_MENU" "-" 30 216 "Red" $False
                }

                if(($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionType) -eq 1)
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 198 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 216 "Green" $False
                }
                elseif(($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionType) -eq 2)
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 198 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 216 "Green" $False
                }
                elseif(($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionType) -eq 3)
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 198 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 216 "Green" $False
                }
                elseif(($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionType) -eq 4)
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 216 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 180 "Green" $Falsef
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 198 "Green" $False
                }
                elseif(($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionType) -eq 5)
                {
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 198 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" ([string]($global:arrBuilding[$arrBuildingIDToKey[$texID]].productionAmount)) 60 216 "Green" $False
                }
                else
                {
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 162 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 180 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 198 "Green" $False
                    addText "WND_SINGLEPLAYER_MENU" "-" 60 216 "Green" $False
                }
            }

            $objForm.Refresh()
        }
        "BTN_WARES"
        {
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_BUILDING_01_SELECT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_BUILDING_02_SELECT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT2")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT_AMOUNT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT_PRODUCTION")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_TILEINFO_RECRUIT")
            $global:arrSettingsInternal["RECRUIT_ARMY"] = $False
            addColoredArea "WND_SINGLEPLAYER_MENU" 10 54 140 180 "CLR_WINDOW_BACK"

            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT" "Gray" 136 20 12 34 $False "Wares Overview" -1 -1 "Gold" $False
            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT_AMOUNT" "Gray" 50 20 46 54 $False "Amount" -1 -1 "Gold" $False
            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT_PRODUCTION" "Gray" 50 20 96 54 $False "Prod." -1 -1 "Gold" $False
            
            buildButton "GRAY" 20 20 10 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_BUILDING_01"].bitmap) 12 14 1

            buildButton "GRAY" 20 20 34 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_BUILDING_02"].bitmap) 36 14 1

            buildButton "GRAY" 20 20 58 12 $True
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_WARES"].bitmap) 60 14 1

            buildButton "GRAY" 20 20 82 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_ARMIES"].bitmap) 84 14 1

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_GOLDCOIN"].bitmap) 10 76 1
            addColoredArea "WND_SINGLEPLAYER_MENU" 30 76 8 16 "CLR_PLAYER_11"
            addText "WND_SINGLEPLAYER_MENU" ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][6]) 50 80 "Gold" $False
            addText "WND_SINGLEPLAYER_MENU" ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][1]) 100 80 "Gold" $False

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_WOOD"].bitmap) 10 94 1
            addColoredArea "WND_SINGLEPLAYER_MENU" 30 94 8 16 "CLR_PLAYER_21"
            addText "WND_SINGLEPLAYER_MENU" ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][7]) 50 98 "Gold" $False
            addText "WND_SINGLEPLAYER_MENU" ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][2]) 100 98 "Gold" $False

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_FOOD"].bitmap) 10 112 1
            addColoredArea "WND_SINGLEPLAYER_MENU" 30 112 8 16 "CLR_PLAYER_31"
            addText "WND_SINGLEPLAYER_MENU" ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][8]) 50 116 "Gold" $False
            addText "WND_SINGLEPLAYER_MENU" ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][3]) 100 116 "Gold" $False

            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_PEOPLE"].bitmap) 10 130 1
            addColoredArea "WND_SINGLEPLAYER_MENU" 30 130 8 16 "CLR_PLAYER_41"
            addText "WND_SINGLEPLAYER_MENU" ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][9]) 50 134 "Gold" $False
            addText "WND_SINGLEPLAYER_MENU" ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][4]) 100 134 "Gold" $False
        }
        "BTN_ARMY"
        {
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_BUILDING_01_SELECT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_BUILDING_02_SELECT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT2")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT_AMOUNT")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_DUMMY_TEXT_PRODUCTION")
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_TILEINFO_RECRUIT")
            $global:arrSettingsInternal["RECRUIT_ARMY"] = $False
            addColoredArea "WND_SINGLEPLAYER_MENU" 10 54 140 180 "CLR_WINDOW_BACK"

            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_DUMMY_TEXT" "Gray" 136 20 12 34 $False "Army Management" -1 -1 "Gold" $False
            
            buildButton "GRAY" 20 20 10 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_BUILDING_01"].bitmap) 12 14 1

            buildButton "GRAY" 20 20 34 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_BUILDING_02"].bitmap) 36 14 1

            buildButton "GRAY" 20 20 58 12 $False
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_WARES"].bitmap) 60 14 1

            buildButton "GRAY" 20 20 82 12 $True
            addImageToWindow "WND_SINGLEPLAYER_MENU" ($global:arrIcons["ICON_ARMIES"].bitmap) 84 14 1

            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_TILEINFO_RECRUIT" "Green" 136 20 12 214 $False "New Army" -1 -1 "Gold" $False
        }
        "BTN_TILEINFO_RECRUIT"
        {
            $global:arrSettingsInternal["RECRUIT_ARMY"] = !$global:arrSettingsInternal["RECRUIT_ARMY"]
            $global:arrWindows["WND_SINGLEPLAYER_MENU"].btn.Remove("BTN_TILEINFO_RECRUIT")
            addButtonToWindow "WND_SINGLEPLAYER_MENU" "BTN_TILEINFO_RECRUIT" "Green" 136 20 12 214 ($global:arrSettingsInternal["RECRUIT_ARMY"]) "New Army" -1 -1 "Gold" $False
        }
        "BTN_COMBAT_RESULTS_CLOSE"
        {
            $global:strGameState = "SINGLEPLAYER_INGAME"
            showWindow "WND_SINGLEPLAYER_MENU"
        }
        "BTN_TILEINFO_QUIT"
        {
            $global:strGameState = "SINGLEPLAYER_INGAME"
            showWindow "WND_SINGLEPLAYER_MENU"
        }
        "BTN_TILEINFO_BURN_BUILDING"
        {
            BLD_DestroyBuilding ($global:arrPlayerInfo.currentSelection)
            $global:strGameState = "SINGLEPLAYER_INGAME"
            showWindow "WND_SINGLEPLAYER_MENU"
        }
        "BTN_END_TURN"
        {
            handleEndTurnPlayer
            showWindow "WND_NEXT_PLAYER"
        }
        "BTN_NEXT_PLAYER_OK"
        {
            showWindow "WND_SINGLEPLAYER_MENU"
            handleButtonKlick "BTN_WARES"
        }
        "BTN_TILEINFO_SWITCH_ARMY"
        {
            fillTileInfoWindow "ARMY"
        }
        "BTN_TILEINFO_SWITCH_BUILDING"
        {
            fillTileInfoWindow "BUILDING"
        }
        "BTN_TILEINFO_SWITCH_TERRAIN"
        {
            fillTileInfoWindow "TERRAIN"
        }
        "BTN_TILEINFO_ADDUNIT_0"
        {
            ARMY_BuyUnits ($global:arrPlayerInfo.selectedTile.armyID) 0
        }
        "BTN_TILEINFO_ADDUNIT_1"
        {
            ARMY_BuyUnits ($global:arrPlayerInfo.selectedTile.armyID) 1
        }
        "BTN_TILEINFO_ADDUNIT_2"
        {
            ARMY_BuyUnits ($global:arrPlayerInfo.selectedTile.armyID) 2
        }
        default
        {
            Write-Host "Button $strButtonID was clicked but has no function?"
        }
    }
}

function  centerOnPosition($iPosX, $iPosY)
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

function WND_CombatResultsHeader($combatData)
{
    try {
        $global:arrWindows[$strType].btn.Remove("BTN_COMBATRESULT_ARMY1")
        $global:arrWindows[$strType].btn.Remove("BTN_COMBATRESULT_ARMY2")
    } catch{}

    buildButton "GRAY" 20 20 12 12 $True
    addColoredArea $strType 15 15 16 16 ("CLR_PLAYER_" + $combatData[0] + "1")
    addButtonToWindow $strType "BTN_COMBATRESULT_ARMY1" "Gray" 136 20 32 12 $False $combatData[1] -1 -1 "Gold" $False
    addButtonToWindow $strType "BTN_COMBATRESULT_VS1" "Transparent" 24 20 168 12 $False "vs" -1 -1 "Gold" $False
    addButtonToWindow $strType "BTN_COMBATRESULT_ARMY2" "Gray" 136 20 192 12 $False $combatData[3] -1 -1 "Gold" $False
    buildButton "GRAY" 20 20 328 12 $True
    addColoredArea $strType 331 15 16 16 ("CLR_PLAYER_" + $combatData[2] + "1")
}

function WND_CombatResultsHeaderInfo($combatData)
{
    $percentHP = ($combatData[4] / $global:arrSettingsInternal["ARMY_DEFAULT_HP"])
    $clr_HP = getColorForPercent $percentHP

    addBarToWindow $strType 96 20 12 32 ("Health: " + $combatData[4] + "/" + $global:arrSettingsInternal["ARMY_DEFAULT_HP"]) $percentHP $clr_HP.color

    addColoredArea $strType 110 34 60 20 "CLR_WINDOW_BACK"
    addImageToWindow $strType ($global:arrIcons["ICON_SWORD"].bitmap) 110 34 1
    addImageToWindow $strType ($global:arrIcons["ICON_BOW"].bitmap) 130 34 1
    addImageToWindow $strType ($global:arrIcons["ICON_HORSE"].bitmap) 150 34 1

    for($i = 0; $i -lt 3; $i++)
    {
        if($combatData[(5 + $i)] -eq 1)
        {
            addImageToWindow $strType ($global:arrIcons["ICON_OK_SMALL"].bitmap) (116 + $i * 20) 42 1
        }
        else
        {
            addImageToWindow $strType ($global:arrIcons["ICON_NOTOK_SMALL"].bitmap) (116 + $i * 20) 42 1
        }
    }

    addColoredArea $strType 194 34 60 20 "CLR_WINDOW_BACK"
    addImageToWindow $strType ($global:arrIcons["ICON_SWORD"].bitmap) 194 34 1
    addImageToWindow $strType ($global:arrIcons["ICON_BOW"].bitmap) 214 34 1
    addImageToWindow $strType ($global:arrIcons["ICON_HORSE"].bitmap) 234 34 1

    for($i = 0; $i -lt 3; $i++)
    {
        if($combatData[(9 + $i)] -eq 1)
        {
            addImageToWindow $strType ($global:arrIcons["ICON_OK_SMALL"].bitmap) (200 + $i * 20) 42 1
        }
        else
        {
            addImageToWindow $strType ($global:arrIcons["ICON_NOTOK_SMALL"].bitmap) (200 + $i * 20) 42 1
        }
    }

    $percentHP = ($combatData[8] / $global:arrSettingsInternal["ARMY_DEFAULT_HP"])
    $clr_HP = getColorForPercent $percentHP
    addBarToWindow $strType 96 20 252 32 ("Health: " + $combatData[8] + "/" + $global:arrSettingsInternal["ARMY_DEFAULT_HP"]) $percentHP $clr_HP.color
}

function WND_CombatResultsLines($combatData)
{
    $offset = 0
    $max = $combatData.fights.Count

    if($combatData.fights.Count -gt 7)
    {
        $offset = ($combatData.fights.Count - 7)
        $max = 7
    }

    for($i = 0; $i -lt $max; $i++)
    {
        WND_CombatResultLine ($combatData.fights[($i + $offset)]) $i
    }
}

function WND_CombatResultLine($combatLine, $iID)
{
    $arrArmyIDToName = "ICON_SWORD", "ICON_BOW", "ICON_HORSE"

    $percentHP = ($combatLine[0] / $global:arrSettingsInternal["ARMY_DEFAULT_HP"])
    $clr_HP = getColorForPercent $percentHP
    addBarToWindow $strType 96 20 12 (62 + $i * 22) ("HP: " + $combatLine[0] + "/" + $global:arrSettingsInternal["ARMY_DEFAULT_HP"]) $percentHP ($clr_HP.color)

    if($combatLine[2] -eq 1)
    {
        addButtonToWindow $strType "BTN_COMBATRESULT_RESULT1" "Green" 40 20 108 (62 + $i * 22) $False "Won" -1 -1 "Gold" $False
    }
    else
    {
        addButtonToWindow $strType "BTN_COMBATRESULT_RESULT1" "Red" 40 20 108 (62 + $i * 22) $False "Lost" -1 -1 "Gold" $False
    }

    addColoredArea $strType 150 (66 + $i * 22) 16 16 "CLR_WINDOW_BACK"
    addImageToWindow $strType ($global:arrIcons[$arrArmyIDToName[$combatLine[1]]].bitmap) 150 (66 + $i * 22) 1

    addImageToWindow $strType ($global:arrIcons["ICON_SWORDS_CROSSED"].bitmap) 172 (66 + $i * 22) 1

    addColoredArea $strType 194 (66 + $i * 22) 16 16 "CLR_WINDOW_BACK"
    addImageToWindow $strType ($global:arrIcons[$arrArmyIDToName[$combatLine[4]]].bitmap) 194 (66 + $i * 22) 1 1

    if($combatLine[5] -eq 1)
    {
        addButtonToWindow $strType "BTN_COMBATRESULT_RESULT2" "Green" 40 20 212 (62 + $i * 22) $False "Won" -1 -1 "Gold" $False
    }
    else
    {
        addButtonToWindow $strType "BTN_COMBATRESULT_RESULT2" "Red" 40 20 212 (62 + $i * 22) $False "Lost" -1 -1 "Gold" $False
    }

    try {$global:arrWindows[$strType].btn.Remove("BTN_COMBATRESULT_RESULT1")} catch{}
    try {$global:arrWindows[$strType].btn.Remove("BTN_COMBATRESULT_RESULT2")} catch{}

    $percentHP = ($combatLine[3] / $global:arrSettingsInternal["ARMY_DEFAULT_HP"])
    $clr_HP = getColorForPercent $percentHP
    addBarToWindow $strType 96 20 252 (62 + $i * 22) ("HP: " + $combatLine[3] + "/" + $global:arrSettingsInternal["ARMY_DEFAULT_HP"]) $percentHP ($clr_HP.color)
}

function WND_CombatResultsEndResults($combatData)
{

    if($combatData[12])
    {
        addButtonToWindow $strType "BTN_COMBATRESULT_ENDRESULT1" "Green" 96 20 12 216 $False "Victory" -1 -1 "Gold" $False
    }
    else
    {
        addButtonToWindow $strType "BTN_COMBATRESULT_ENDRESULT1" "Red" 96 20 12 216 $False "Defeat" -1 -1 "Gold" $False
    }

    if($combatData[13])
    {
        addButtonToWindow $strType "BTN_COMBATRESULT_ENDRESULT2" "Green" 96 20 252 216 $False "Victory" -1 -1 "Gold" $False
    }
    else
    {
        addButtonToWindow $strType "BTN_COMBATRESULT_ENDRESULT2" "Red" 96 20 252 216 $False "Defeat" -1 -1 "Gold" $False
    }

    try {
        $global:arrWindows[$strType].btn.Remove("BTN_COMBATRESULT_ENDRESULT1")
        $global:arrWindows[$strType].btn.Remove("BTN_COMBATRESULT_ENDRESULT2")
    } catch{}

}

function showWindow($strType, $data1)
{
    Write-Host "showWindow($strType)"

    # if a new window is shown (or the same again) disable any inputboxes
    $global:arrWindows.InputCurrent = ""

    switch($strType)
    {
        "WND_TEST"
        {
            buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType

            #addInputToWindow($strWindow, $strName, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $strAlign, $iMaxLength)

            addInputToWindow $strType "INP_TEST_1" 136 20 12 14 "Test" "LEFT" 12

            #addInputToWindow

            addButtonToWindow $strType "BTN_GAME_OPTIONS_BACK" "Gray" 136 20 112 176 $False "Back" -1 -1 "Gold" $False
        }
        "WND_COMBAT_RESULTS"
        {
            buildWindow 360 248 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 248) / 2) $strType

            WND_CombatResultsHeader $data1

            WND_CombatResultsHeaderInfo $data1

            WND_CombatResultsLines $data1

            WND_CombatResultsEndResults $data1

            # end
            addButtonToWindow $strType "BTN_COMBAT_RESULTS_CLOSE" "Gray" 136 20 112 216 $False "Close" -1 -1 "Gold" $False
        }
        "WND_INIT_WAIT_CLICK"
        {
            buildWindow 160 40 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 40) / 2) $strType
            addButtonToWindow $strType "BTN_DUMMY_TEXT" "Transparent" 140 20 10 10 $False "Click to Start" -1 -1 "Gold" $False
        }
        "WND_ESC_MAIN"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
            addButtonToWindow $strType "BTN_SINGLEPLAYER" "Gray" 136 20 12 14 $False "Singleplayer" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_MULTIPLAYER" "Gray" 136 20 12 40 $False "Multiplayer" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_EDITOR" "Gray" 136 20 12 66 $False "Editor" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_OPTIONS" "Gray" 136 20 12 92 $False "Options" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_CREDITS" "Gray" 136 20 12 118 $False "Credits" -1 -1 "Gold" $False
            
            addText $strType ("v" + $global:VersionInfo[0] + "." + $global:VersionInfo[1] + "." + $global:VersionInfo[2] + " - " + $global:VersionInfo[3]) 12 148 "Gold" $False

            addButtonToWindow $strType "BTN_QUIT" "Red" 136 20 12 166 $False "Quit" -1 -1 "Gold" $False
        }
        "WND_QUIT_MAIN"
        {
            buildWindow 160 100 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 100) / 2) $strType
            addText $strType "Really quit?" 12 12 "Gold" $False
            addButtonToWindow $strType "BTN_QUIT_YES" "Red" 60 20 12 56 $False "Yes" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_QUIT_NO" "Green" 60 20 88 56 $False "No" -1 -1 "Gold" $False
        }
        "WND_CREDITS"
        {
            buildWindow 310 200 (($DrawingSizeX - 310) / 2) (($DrawingSizeY - 200) / 2) $strType
            addText $strType "Written by:" 10 10 "Gold" $False
            addText $strType "Spikeone" 10 22 "Gold" $False
            addText $strType "Story by:" 10 40 "Gold" $False
            addText $strType "-" 10 52 "Gold" $False
            addText $strType "Graphics by:" 10 70 "Gold" $False
            addText $strType "Andre Mari Coppola" 10 82 "Gold" $False
            addText $strType "Music By:" 10 100 "Gold" $False
            addText $strType "Ted" 10 112 "Gold" $False
            addButtonToWindow $strType "BTN_CREDITS_BACK" "Gray" 136 20 87 156 $False "Back" -1 -1 "Gold" $False
        }
        "WND_GAME_OPTIONS"
        {
            buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType
            addText $strType "Topmost:" 12 20 "Gold" $False
            addSwitchButtonToWindow $strType "BTN_SWITCH_TOPMOST" ($global:arrSettings["TOPMOST"]) 60 20 240 12 $True $False
            
            addText $strType "Volume Music (0 = off):" 12 44 "Gold" $False
            addCountButtonToWindow $strType "BTN_WND_GAME_OPTIONS_VOLUMEMUSIC" 20 20 240 36 5 ($global:arrSettings["VOLUMEMUSIC"] / 0.025 + 1) $False 0
            
            addText $strType "Volume Effects (0 = off):" 12 68 "Gold" $False
            addCountButtonToWindow $strType "BTN_WND_GAME_OPTIONS_VOLUMEEFFECTS" 20 20 240 60 5 ($global:arrSettings["VOLUMEEFFECTS"] / 0.025 + 1) $False 0
            
            addText $strType "Player face:" 12 92 "Gold" $False
            addButtonToWindow $strType "BTN_GAME_OPTIONS_FACE_SUB" "Gray" 20 20 240 82 $False "" 48 4 "Gold" $False
            addButtonToWindow $strType "BTN_GAME_OPTIONS_FACE_ADD" "Gray" 20 20 300 82 $False "" 48 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_ARROW_GOLD_LEFT"].bitmap) 242 84 1
            addImageToWindow $strType ($global:arrIcons["ICON_ARROW_GOLD_RIGHT"].bitmap) 302 84 1

            addImageToWindow $strType ($global:arrTextures[(nameToId "FACE_" $global:arrSettings["PLAYER_FACE"])].bitmap) 270 84 1

            addText $strType "Scrolled Tiles:" 12 116 "Gold" $False
            addCountButtonToWindow $strType "BTN_WND_GAME_OPTIONS_SCROLLSPEED" 20 20 240 108 5 ($global:arrSettings["SCROLLSPEED"]) $False 1


            addButtonToWindow $strType "BTN_GAME_OPTIONS_BACK" "Gray" 136 20 112 176 $False "Back" -1 -1 "Gold" $False
        }
        "WND_RTFM"
        {
            buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType

            addText $strType "        ________________"   100 20  "Gold" $False 
            addText $strType "       /                /)" 100 28  "Gold" $False
            addText $strType "   ___/_____ ___ __  __/ )" 100 36  "Gold" $False
            addText $strType "  | _ \_   _| __|  \/  | )" 100 44  "Gold" $False
            addText $strType "  |   / | | | _|| |\/| |/"  100 52  "Gold" $False
            addText $strType "  |_|_\ |_| |_| |_| /|_|"   100 60  "Gold" $False
            addText $strType "  /                /  /"    100 68  "Gold" $False
            addText $strType " /                /  /"     100 76  "Gold" $False
            addText $strType "/_______________ /  /"      100 84  "Gold" $False
            addText $strType ")_______________)  /"       100 92  "Gold" $False
            addText $strType ")_______________) /"        100 100 "Gold" $False
            addText $strType ")_______________)/"         100 108 "Gold" $False

            addButtonToWindow $strType "BTN_BACK_TO_SINGLEPLAYER" "Gray" 136 20 112 176 $False "Back" -1 -1 "Gold" $False
        }
        "WND_ERROR_NOLOCALPLAYER"
        {
            buildWindow 160 100 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 100) / 2) $strType
            addText $strType "Missing local player!" 10 10 "Gold" $False
            addText $strType "Can't start game..." 10 22 "Gold" $False
            addButtonToWindow $strType "BTN_ERROR_OK_SINGLEPLAYER_SETUP" "Gray" 136 20 12 56 $False "Ok" -1 -1 "Gold" $False
        }
        "WND_ERROR_HASOPENSLOTS"
        {
            buildWindow 160 100 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 100) / 2) $strType
            addText $strType "Still open slots!" 10 10 "Gold" $False
            addText $strType "Can't start game..." 10 22 "Gold" $False
            addButtonToWindow $strType "BTN_ERROR_OK_SINGLEPLAYER_SETUP" "Gray" 136 20 12 56 $False "Ok" -1 -1 "Gold" $False
        }
        "WND_ERROR_NOTIMPLEMENTED_SINGLEPLAYER"
        {
            buildWindow 160 100 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 100) / 2) $strType
            addText $strType "Sorry! Not" 10 10 "Gold" $False
            addText $strType "implemented..." 10 22 "Gold" $False
            addButtonToWindow $strType "BTN_BACK_TO_SINGLEPLAYER" "Gray" 136 20 12 56 $False "Back" -1 -1 "Gold" $False
        }
        "WND_ERROR_NOTIMPLEMENTED_MULTIPLAYER"
        {
            buildWindow 160 100 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 100) / 2) $strType
            addText $strType "Sorry! Not" 10 10 "Gold" $False
            addText $strType "implemented..." 10 22 "Gold" $False
            addButtonToWindow $strType "BTN_BACK_TO_MAINMENU" "Gray" 136 20 12 56 $False "Back" -1 -1 "Gold" $False
        }
        "WND_PLEASE_WAIT"
        {
            buildWindow 160 40 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 40) / 2) $strType
            addText $strType "Please wait!" 38 10 "Gold" $False
            addText $strType "Working..." 38 22 "Gold" $False
        }
        "WND_SINGLEPLAYER_SETUP"
        {
            buildWindow 440 230 (($DrawingSizeX - 440) / 2) (($DrawingSizeY - 230) / 2) $strType
            addText $strType "Map:" 12 16 "Gold" $False
            addButtonToWindow $strType "BTN_SINGLEPLAYER_SETUP_MAP" "Gray" 338 20 90 12 $False "Open Map..." 6 6 "Gold" $False
            
            addText $strType "Players:" 12 46 "Gold" $False
            
            addText $strType "Author:" 12 76 "Gold" $False
            
            addText $strType "Size:" 12 106 "Gold" $False

            addText $strType "Preview:" 12 136 "Gold" $False

            addButtonToWindow $strType "BTN_BACK_TO_SINGLEPLAYER" "Red" 136 20 12 198 $False "Back" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_SINGLEPLAYER_SETUP_START" "Green" 136 20 292 198 $False "Start" -1 -1 "Gold" $False

            $global:arrSettingsInternal["PLAYERTYPE_MAX"] = 3;
        }
        "WND_SINGLEPLAYER_TYPESELECTION"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
            addButtonToWindow $strType "BTN_CAMPAIGN" "Gray" 136 20 12 14 $True "Campaign" -1 -1 "Gray" $False
            addButtonToWindow $strType "BTN_FREEPLAY" "Gray" 136 20 12 40 $False "Freeplay" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_TUTORIAL" "Gray" 136 20 12 66 $False "Tutorial" -1 -1 "Gold" $False
            
            addButtonToWindow $strType "BTN_BACK_TO_MAINMENU" "Red" 136 20 12 166 $False "Back" -1 -1 "Gold" $False
        }
        "WND_CREATE_MAP"
        {
            buildWindow 310 200 (($DrawingSizeX - 310) / 2) (($DrawingSizeY - 200) / 2) $strType
            
            $global:arrCreateMapOptions["WIDTH"] = 32;
            $global:arrCreateMapOptions["HEIGHT"] = 32;

            addText $strType "Width:" 12 15 "Gold" $False
            addButtonToWindow $strType "BTN_CREATEMAP_WADD01" "Gray" 30 20 140 12 $False "+16" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_CREATEMAP_WADD02" "Gray" 30 20 170 12 $False "+ 2" -1 -1 "Gold" $False
            try {$global:arrWindows[$strType].btn.Remove("BTN_CREATEMAP_WIDTH")} catch{}
            addButtonToWindow $strType "BTN_CREATEMAP_WIDTH" "Red"   40 20 200 12 $False ([string]($global:arrCreateMapOptions["WIDTH"])) -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_CREATEMAP_WSUB01" "Gray" 30 20 240 12 $False "- 2" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_CREATEMAP_WSUB02" "Gray" 30 20 270 12 $False "-16" -1 -1 "Gold" $False
            
            addText $strType "Height:" 12 45 "Gold" $False
            addButtonToWindow $strType "BTN_CREATEMAP_HADD01" "Gray" 30 20 140 42 $False "+16" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_CREATEMAP_HADD02" "Gray" 30 20 170 42 $False "+ 2" -1 -1 "Gold" $False
            try {$global:arrWindows[$strType].btn.Remove("BTN_CREATEMAP_HEIGHT")} catch{}
            addButtonToWindow $strType "BTN_CREATEMAP_HEIGHT" "Red"  40 20 200 42 $False ([string]($global:arrCreateMapOptions["HEIGHT"])) -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_CREATEMAP_HSUB01" "Gray" 30 20 240 42 $False "- 2" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_CREATEMAP_HSUB02" "Gray" 30 20 270 42 $False "-16" -1 -1 "Gold" $False
            
            addText $strType "Basetexture:" 12 75 "Gold" $False

            addButtonToWindow $strType "BTN_CREATEMAP_TEXTURE_PREV" "Gray" 30 20 170 72 $False "" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_CREATEMAP_TEXTURE_NEXT" "Gray" 30 20 240 72 $False "" -1 -1 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_ARROW_GOLD_LEFT"].bitmap) 177 74 1
            addImageToWindow $strType ($global:arrIcons["ICON_ARROW_GOLD_RIGHT"].bitmap) 247 74 1
            
            addImageToWindow $strType ($global:arrTextures[$arrBaseTextureIDToKey[0]].bitmap) 210 74 1
            
            addButtonToWindow $strType "BTN_CREATE_MAP_CANCEL" "Red" 88 20 12 166 $False "Cancel" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_CREATE_MAP_LOAD" "Gray" 88 20 111 166 $False "Load..." -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_CREATE_MAP_CONTINUE" "Green" 88 20 210 166 $False "Continue" -1 -1 "Gold" $False
        }
        "WND_ESC_EDITOR"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
            addButtonToWindow $strType "BTN_EDITOR_SAVEMAP" "Gray" 136 20 12 14 $False "Save map" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_EDITOR_SAVEIMAGE" "Gray" 136 20 12 40 $False "Save image" -1 -1 "Gold" $False

            addInputToWindow $strType "INP_EDIT_MAPNAME" 136 20 12 66 $global:arrMap["MAPNAME"] "LEFT" 0

            addInputToWindow $strType "INP_EDIT_AUTHOR" 136 20 12 92 $global:arrMap["AUTHOR"] "LEFT" 0

            addButtonToWindow $strType "BTN_EDITOR_QUIT" "Red" 136 20 12 166 $False "Quit" -1 -1 "Gold" $False
        }
        "WND_TILEINFO"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType

            addButtonToWindow $strType "BTN_TILEINFO_QUIT" "Red" 136 20 12 238 $False "Close" -1 -1 "Gold" $False

            # show info dependent on selection
            if($global:arrPlayerInfo.selectedTile.x -lt 0 -and $global:arrPlayerInfo.selectedTile.y -lt 0) {return;}

            try {$global:arrWindows[$strType].btn.Remove("BTN_TILEINFO_TEXT_01")} catch{}
            addButtonToWindow $strType "BTN_TILEINFO_TEXT_01" "Gray" 136 20 12 12 $False ("Position: " + $global:arrPlayerInfo.selectedTile.x + "|" + $global:arrPlayerInfo.selectedTile.y) -1 -1 "Gold" $False

            # remove buttons
            try {$global:arrWindows[$strType].btn.Remove("BTN_TILEINFO_SWITCH_ARMY")} catch{}
            addColoredArea $strType 12 182 136 20 "CLR_WINDOW_BACK"

            try {$global:arrWindows[$strType].btn.Remove("BTN_TILEINFO_SWITCH_BUILDING")} catch{}
            addColoredArea $strType 12 210 136 20 "CLR_WINDOW_BACK"

            try {$global:arrWindows[$strType].btn.Remove("BTN_TILEINFO_SWITCH_TERRAIN")} catch{}
            addColoredArea $strType 12 210 136 20 "CLR_WINDOW_BACK"

            # check if add army buttons
            if($global:arrPlayerInfo.selectedTile.armyID -ne -1){
                $global:arrPlayerInfo.selectedTile.mode = "ARMY"
            }

            # show terain info or building info - there can only be either
            if($global:arrPlayerInfo.selectedTile.buildingID -ne -1 -and $global:arrPlayerInfo.selectedTile.armyID -eq -1){
                $global:arrPlayerInfo.selectedTile.mode = "BUILDING"
            }

            if($global:arrPlayerInfo.selectedTile.objectID -ne -1 -and $global:arrPlayerInfo.selectedTile.armyID -eq -1){
                $global:arrPlayerInfo.selectedTile.mode = "TERRAIN"
            }

            fillTileInfoWindow ($global:arrPlayerInfo.selectedTile.mode)
        }
        "WND_ESC_SINGLEPLAYER"
        {
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType

            addButtonToWindow $strType "BTN_SINGLEPLAYER_SAVE" "Gray" 136 20 12 14 $True "Save" -1 -1 "Gray" $False
            addButtonToWindow $strType "BTN_SINGLEPLAYER_LOAD" "Gray" 136 20 12 40 $True "Load" -1 -1 "Gray" $False
            addButtonToWindow $strType "BTN_SINGLEPLAYER_SURRENDER" "Gray" 136 20 12 66 $True "Surrender" -1 -1 "Gray" $False

            addButtonToWindow $strType "BTN_SINGLEPLAYER_BACK" "Green" 136 20 12 140 $False "Back" -1 -1 "Gold" $False

            addButtonToWindow $strType "BTN_SINGLEPLAYER_QUIT" "Red" 136 20 12 166 $False "Quit" -1 -1 "Gold" $False
        }
        "WND_QUIT_SINGLEPLAYER"
        {
            buildWindow 160 100 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 100) / 2) $strType
            addText $strType "Really quit?" 12 12 "Gold" $False
            addButtonToWindow $strType "BTN_SINGLEPLAYER_QUIT_YES" "Red" 60 20 12 56 $False "Yes" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_SINGLEPLAYER_QUIT_NO" "Green" 60 20 88 56 $False "No" -1 -1 "Gold" $False
        }
        "WND_QUIT_EDITOR"
        {
            buildWindow 160 100 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 100) / 2) $strType
            addText $strType "Really quit?" 12 12 "Gold" $False
            addButtonToWindow $strType "BTN_EDITOR_QUIT_YES" "Red" 60 20 12 56 $False "Yes" -1 -1 "Gold" $False
            addButtonToWindow $strType "BTN_EDITOR_QUIT_NO" "Green" 60 20 88 56 $False "No" -1 -1 "Gold" $False
        }
        "WND_INTERFACE_EDITOR"
        {
            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
            addButtonToWindow $strType "BTN_IFE_EDIT_LAYER01" "Gray" 20 20 10 12 $False "" 8 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_LAYER_01"].bitmap) 12 14 1
            
            addButtonToWindow $strType "BTN_IFE_EDIT_LAYER02" "Gray" 20 20 34 12 $False "" 8 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_LAYER_02"].bitmap) 36 14 1
            
            addButtonToWindow $strType "BTN_IFE_EDIT_LAYER03" "Gray" 20 20 58 12 $False "" 8 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_LAYER_03"].bitmap) 60 14 1
        
            addButtonToWindow $strType "BTN_IFE_EDIT_DIRECTIONS" "Gray" 20 20 82 12 $False "" 8 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_LAYER_DIRECTION"].bitmap) 84 14 1
        
            addButtonToWindow $strType "BTN_IFE_EDIT_PLAYER" "Gray" 20 20 106 12 $False "" 8 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_LAYER_PLAYER"].bitmap) 108 14 1
            
            addButtonToWindow $strType "BTN_IFE_EDIT_LAYERSETTINGS" "Gray" 20 20 130 12 $False "" 8 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_LAYER_SETTINGS"].bitmap) 132 14 1
        }

        "WND_SINGLEPLAYER_MENU"
        {

            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType
            addButtonToWindow $strType "BTN_BUILDINGS_01" "Gray" 20 20 10 12 $False "" 8 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_BUILDING_01"].bitmap) 12 14 1

            addButtonToWindow $strType "BTN_BUILDINGS_02" "Gray" 20 20 34 12 $False "" 8 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_BUILDING_02"].bitmap) 36 14 1

            addButtonToWindow $strType "BTN_WARES" "Gray" 20 20 58 12 $False "" 8 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_WARES"].bitmap) 60 14 1

            addButtonToWindow $strType "BTN_ARMY" "Gray" 20 20 82 12 $False "" 8 4 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_ARMIES"].bitmap) 84 14 1
            
            addButtonToWindow $strType "BTN_DUMMY_TEXT" "Gray" 136 20 12 34 $False "---" -1 -1 "Gold" $False

            addButtonToWindow $strType "BTN_END_TURN" "Gray" 64 20 84 238 $False "" -1 -1 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_HOURGLAS"].bitmap) 96 240 1
            addImageToWindow $strType ($global:arrIcons["ICON_ARROW_GOLD_RIGHT"].bitmap) 110 240 1
            addImageToWindow $strType ($global:arrIcons["ICON_ARROW_GOLD_RIGHT"].bitmap) 124 240 1

            addButtonToWindow $strType "BTN_NEXT_UNIT" "Gray" 64 20 12 238 $False "" -1 -1 "Gold" $False
            addImageToWindow $strType ($global:arrIcons["ICON_ARROW_GOLD_RIGHT"].bitmap) 16 240 1
            addImageToWindow $strType ($global:arrIcons["ICON_ARMY"].bitmap) 36 240 1
            addImageToWindow $strType ($global:arrIcons["ICON_ARROW_GOLD_LEFT"].bitmap) 56 240 1
        }
        "WND_NEXT_PLAYER"
        {
            try {$global:arrWindows[$strType].btn.Remove("BTN_WND_NEXT_PLAYER_DUMMY02")} catch{}
            addColoredArea "WND_NEXT_PLAYER" 10 160 140 20 "CLR_WINDOW_BACK"

            buildWindow 160 270 ($DrawingSizeX - 160) 0 $strType

            addButtonToWindow "WND_NEXT_PLAYER" "BTN_WND_NEXT_PLAYER_DUMMY01" "Transparent" 140 20 10 20 $False "Next Player:" -1 -1 "Gold" $False

            buildButton "GRAY" 60 100 50 50 $iPosY $True
            addColoredArea $strType 54 54 52 92 ("CLR_PLAYER_" + [string]($global:arrPlayerInfo.currentplayer) + "1")

            addButtonToWindow "WND_NEXT_PLAYER" "BTN_WND_NEXT_PLAYER_DUMMY02" "Transparent" 140 20 10 160 $False ($global:arrPlayerInfo[($global:arrPlayerInfo.currentplayer)][0]) -1 -1 "Gold" $False

            addButtonToWindow $strType "BTN_NEXT_PLAYER_OK" "Green" 136 20 12 238 $False "Continue" -1 -1 "Gold" $False
        }
        default
        {
            Write-Host "Unknown window $strType"
        }
    }
    $pictureBox.Refresh();
}

function fillTileInfoWindow ($strMode)
{
    Write-Host "fillTileInfoWindow ($strMode)"
    $global:arrPlayerInfo.selectedTile.mode = $strMode

    # clear everything that needs to be cleaned...
    addColoredArea "WND_TILEINFO" 12 52 136 182 "CLR_WINDOW_BACK"

    try {$global:arrWindows["WND_TILEINFO"].btn.Remove("BTN_TILEINFO_TEXT_02")} catch{}
    try {$global:arrWindows["WND_TILEINFO"].btn.Remove("BTN_TILEINFO_BURN_BUILDING")} catch{}

    try {$global:arrWindows["WND_TILEINFO"].btn.Remove("BTN_TILEINFO_SWITCH_ARMY")} catch{}
    try {$global:arrWindows["WND_TILEINFO"].btn.Remove("BTN_TILEINFO_SWITCH_BUILDING")} catch{}
    try {$global:arrWindows["WND_TILEINFO"].btn.Remove("BTN_TILEINFO_SWITCH_TERRAIN")} catch{}

    # check if add army buttons
    if($global:arrPlayerInfo.selectedTile.armyID -ne -1 -and $strMode -eq "ARMY"){
        addButtonToWindow "WND_TILEINFO" "BTN_TILEINFO_SWITCH_ARMY" "Gray" 64 20 12 214 $True "Army" -1 -1 "Gold" $False
    }
    elseif($global:arrPlayerInfo.selectedTile.armyID -ne -1) {
        addButtonToWindow "WND_TILEINFO" "BTN_TILEINFO_SWITCH_ARMY" "Gray" 64 20 12 214 $False "Army" -1 -1 "Gold" $False
    }

    # show terain info or building info - there can only be either
    if($global:arrPlayerInfo.selectedTile.buildingID -ne -1 -and $strMode -eq "BUILDING"){
        addButtonToWindow "WND_TILEINFO" "BTN_TILEINFO_SWITCH_BUILDING" "Gray" 64 20 84 214 $True "Building" -1 -1 "Gold" $False
    } elseif($global:arrPlayerInfo.selectedTile.buildingID -ne -1) {
        addButtonToWindow "WND_TILEINFO" "BTN_TILEINFO_SWITCH_BUILDING" "Gray" 64 20 84 214 $False "Building" -1 -1 "Gold" $False
    }

    if($global:arrPlayerInfo.selectedTile.objectID -ne -1 -and $strMode -eq "TERRAIN"){
        addButtonToWindow "WND_TILEINFO" "BTN_TILEINFO_SWITCH_TERRAIN" "Gray" 64 20 84 214 $True "Terrain" -1 -1 "Gold" $False
    } elseif($global:arrPlayerInfo.selectedTile.objectID -ne -1) {
        addButtonToWindow "WND_TILEINFO" "BTN_TILEINFO_SWITCH_TERRAIN" "Gray" 64 20 84 214 $False "Terrain" -1 -1 "Gold" $False
    }

    if($strMode -ne "ARMY")
    {
        ARMY_resetOverlay ($global:arrPlayerInfo.selectedTile.x) ($global:arrPlayerInfo.selectedTile.y)
    }

    switch($strMode)
    {
        "ARMY"
        {
            $localArmy = $global:arrPlayerInfo.selectedTile.armyID
            $localPlr = $global:arrPlayerInfo.currentplayer

            $owner = $global:arrArmies[$localArmy][2]
            $leader = $global:arrArmies[$localArmy][3]

            # name title
            addButtonToWindow "WND_TILEINFO" "BTN_TILEINFO_TEXT_02" "Gray" 136 20 12 32 $False ($leader) -1 -1 "Gold" $False

            if($owner -ne $localPlr) {return;}

            ARMY_DrawTileinfoButtons $localArmy

            $posX = $global:arrPlayerInfo.selectedTile.x
            $posY = $global:arrPlayerInfo.selectedTile.y

            $global:arrPlayerInfo.selectedTileArmyActions[0] = ARMY_GetPossibleAction $posX $posY 0 $posX ($posY - 1)
            ARMY_SetOverlayForAction ($global:arrPlayerInfo.selectedTileArmyActions[0]) $posX ($posY - 1)

            $global:arrPlayerInfo.selectedTileArmyActions[1] = ARMY_GetPossibleAction $posX $posY 1 ($posX + 1)  $posY
            ARMY_SetOverlayForAction ($global:arrPlayerInfo.selectedTileArmyActions[1]) ($posX + 1)  $posY

            $global:arrPlayerInfo.selectedTileArmyActions[2] = ARMY_GetPossibleAction $posX $posY 2 $posX  ($posY + 1)
            ARMY_SetOverlayForAction ($global:arrPlayerInfo.selectedTileArmyActions[2]) $posX  ($posY + 1)

            $global:arrPlayerInfo.selectedTileArmyActions[3] = ARMY_GetPossibleAction $posX $posY 3 ($posX - 1) $posY
            ARMY_SetOverlayForAction ($global:arrPlayerInfo.selectedTileArmyActions[3]) ($posX - 1) $posY
        }
        "BUILDING"
        {
            $localBld = $global:arrPlayerInfo.selectedTile.buildingID

            $owner = $global:arrBuildings[$localBld][2]
            $type = $global:arrBuildings[$localBld][3]
            $name = $arrBuilding[$global:arrBuildingIDToKey[$type]].name

            $hp_max = $arrBuilding[$global:arrBuildingIDToKey[$type]].hitpoints
            $hp_act = $global:arrBuildings[$localBld][6]

            $state = $global:arrBuildings[$localBld][4]
            $percent = ($global:arrBuildings[$localBld][5] * 100)

            # name title
            addButtonToWindow "WND_TILEINFO" "BTN_TILEINFO_TEXT_02" "Gray" 136 20 12 32 $False ($name) -1 -1 "Gold" $False

            # health percent
            $percent_HP = ($hp_act / $hp_max)
            $clr_HP = getColorForPercent $percent_HP
            addBarToWindow "WND_TILEINFO" 136 20 12 52 (([string]($hp_act)) + "/" + ([string]($hp_max))) $percent_HP $clr_HP.color

            # buildstate
            if(([int]($state)) -eq 0)
            {
                $strStateText = ([string]($percent)) + " %"
                addBarToWindow "WND_TILEINFO" 136 20 12 72 $strStateText $global:arrBuildings[$localBld][5] ($global:arrColors["CLR_BUILDING"].color)
            } 

            # draw building
            addImageToWindow "WND_TILEINFO" $arrBuilding[$global:arrBuildingIDToKey[$type]][($owner * 2)] 48 92 4

            # destroy icon
            if($owner -eq $global:arrPlayerInfo.currentPlayer)
            {
                addButtonToWindow "WND_TILEINFO" "BTN_TILEINFO_BURN_BUILDING" "Red" 20 20 12 136 $False "" -1 -1 "Gold" $False
                addImageToWindow "WND_TILEINFO" ($global:arrIcons["ICON_BOMB"].bitmap) 14 138 1
            }

            playSFX ("SND_" + $global:arrBuildingIDToKey[$type])
        }
        "TERRAIN"
        {
            $localObject = $global:arrPlayerInfo.selectedTile.objectID

            addButtonToWindow "WND_TILEINFO" "BTN_TILEINFO_TEXT_02" "Gray" 136 20 12 32 $False "Object" -1 -1 "Gold" $False

            addImageToWindow "WND_TILEINFO" $global:arrTextures[$arrObjectTextureIDToKey[$localObject]].bitmap 48 92 4

            playSFX "SND_OBJ_GENERIC"
        }
        default
        {
            Write-Host "Unknown tileinfo mode: $strMode"
        }
    }

    $pictureBox.Refresh();
}

function ARMY_BuyUnits($iArmyID, $iOffset)
{
    Write-Host "ARMY_BuyUnits($iArmyID, $iOffset)"

    $owner = $global:arrArmies[$iArmyID][2]

    $price = ($global:arrSettingsInternal["ARMY_UNIT_COSTS"][$iOffset])

    updatePlayerStat $owner 6 (-1 * $price)

    updatePlayerStat $owner 9 (-1 * $global:arrSettingsInternal["ARMY_DEFAULT_PEOPLE"])

    ARMY_updateUnits $iArmyID $iOffset 1

    # update tileinfo if open
    if($global:arrWindows.WindowCurrent -eq "WND_TILEINFO")
    {
        ARMY_DrawTileinfoButtons $iArmyID
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
}

function ARMY_updateUnits($iArmyID, $iOffset, $iValue)
{
    Write-Host "ARMY_updateUnits($iArmyID, $iOffset)"

    if($iValue -gt 0)
    {
        $global:arrArmies[$iArmyID][(7 + $iOffset)] = 1
    }
    else
    {
        $global:arrArmies[$iArmyID][(7 + $iOffset)] = 0
    }
}

function ARMY_DrawTileinfoButtons($iArmyID)
{
    try {$global:arrWindows["WND_TILEINFO"].btn.Remove("BTN_TILEINFO_ADDUNIT_0")} catch{}
    try {$global:arrWindows["WND_TILEINFO"].btn.Remove("BTN_TILEINFO_ADDUNIT_1")} catch{}
    try {$global:arrWindows["WND_TILEINFO"].btn.Remove("BTN_TILEINFO_ADDUNIT_2")} catch{}

    addColoredArea "WND_TILEINFO" 12 98 136 20 "CLR_WINDOW_BACK"
    addColoredArea "WND_TILEINFO" 12 122 136 20 "CLR_WINDOW_BACK"
    addColoredArea "WND_TILEINFO" 12 146 136 20 "CLR_WINDOW_BACK"

    $owner = $global:arrArmies[$iArmyID][2]

    $hp = $global:arrArmies[$iArmyID][6]
    $max_hp = $global:arrSettingsInternal["ARMY_DEFAULT_HP"]

    $percentHP = ($hp / $max_hp)
    $clr_HP = getColorForPercent $percentHP
    addBarToWindow "WND_TILEINFO" 136 20 12 52 ("Health: " + $hp + "/" + $max_hp) $percentHP $clr_HP.color


    $movept = $global:arrArmies[$iArmyID][5]
    $max_movept = $global:arrSettingsInternal["ARMY_DEFAULT_MP"]

    $percentMP = ($movept / $max_movept)
    $clr_MP = getColorForPercent $percentMP

    addBarToWindow "WND_TILEINFO" 136 20 12 72 (" Range: " + $movept + "/" + $max_movept) $percentMP $clr_MP.color

    # draw info about current
    addImageToWindow "WND_TILEINFO" ($global:arrIcons["ICON_SWORD"].bitmap) 12 98 1

    addImageToWindow "WND_TILEINFO" ($global:arrIcons["ICON_BOW"].bitmap) 12 122 1

    addImageToWindow "WND_TILEINFO" ($global:arrIcons["ICON_HORSE"].bitmap) 12 146 1

    for($i = 0; $i -lt 3; $i++)
    {
        if($global:arrArmies[$iArmyID][(7 + $i)] -eq 1)
        {
            addImageToWindow "WND_TILEINFO" ($global:arrIcons["ICON_OK_SMALL"].bitmap) 20 (106 + $i * 24) 1
            addText "WND_TILEINFO" "Full" 34 (98 + $i * 24 + 7) "Green" $False
        }
        else
        {
            addImageToWindow "WND_TILEINFO" ($global:arrIcons["ICON_NOTOK_SMALL"].bitmap) 20 (106 + $i * 24) 1

            $hasInRange = hasBuildingInRange 2 (9 + $i) ($global:arrArmies[$iArmyID][0]) ($global:arrArmies[$iArmyID][1]) $owner

            if($hasInRange)
            {
                $hasGold = checkIfPlayerHasWares $owner 6 ($global:arrSettingsInternal["ARMY_UNIT_COSTS"][$i])
                $hasPeople = checkIfPlayerHasWares $owner 9 ($global:arrSettingsInternal["ARMY_UNIT_COSTS"][$i])

                if($hasGold -and $hasPeople)
                {
                    addButtonToWindow "WND_TILEINFO" ("BTN_TILEINFO_ADDUNIT_" + $i) "Green" 116 20 32 (98 + $i * 24) $False ("Add (" + $global:arrSettingsInternal["ARMY_UNIT_COSTS"][$i] + " Gold)") -1 -1 "Gold" $False
                }
                else
                {
                    if(!$hasGold)
                    {
                        addText "WND_TILEINFO" ("Need Gold: " + $global:arrSettingsInternal["ARMY_UNIT_COSTS"][$i]) 34 (98 + $i * 24 + 7) "Red" $False
                    }
                    else
                    {
                        addText "WND_TILEINFO" ("Need People: 5") 34 (98 + $i * 24 + 7) "Red" $False
                    }
                }
            }
            else
            {
                addText "WND_TILEINFO" "Out of Range:" 34 (98 + $i * 24 + 7) "Red" $False
                addImageToWindow "WND_TILEINFO" $arrBuilding[$global:arrBuildingIDToKey[(9 + $i)]][($owner * 2)] 128 (98 + $i * 24) 1
            }
        }
    }

    $pictureBox.Refresh()
}

function addCountButtonToWindow($strWindow, $strName, $iSizeX, $iSizeY, $iPosX, $iPosY, $iCount, $iActive, $doOutline, $iOffset)
{
    if(!$global:arrWindows[$strWindow].btn)
    {
        # window has no buttons, create array and button
        $global:arrWindows[$strWindow].btn = @{}
        $global:arrWindows[$strWindow].btn[$strName] = @{}
    }
    elseif(!$global:arrWindows[$strWindow].btn[$strName])
    {
        # new button
        $global:arrWindows[$strWindow].btn[$strName] = @{}
    }
    else
    {
        # nothing new
        return;
    }

    $global:arrWindows[$strWindow].btn[$strName].size_x = ($iSizeX * $iCount);
    $global:arrWindows[$strWindow].btn[$strName].size_y = $iSizeY;
    $global:arrWindows[$strWindow].btn[$strName].loc_x  = $iPosX;
    $global:arrWindows[$strWindow].btn[$strName].loc_y  = $iPosY;
    
    # buttons bekommen keine eigene grafik, sie werden lediglich geführt für die klicks
    if($iSizeX -lt 0 -or $iSizeY -lt 0)
    {
        Write-Host "ERROR: addButtonToWindow Size less than 0"
        return;
    }
    
    if((($iSizeX * $iCount) + $iPosX) -ge ($global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Width) -or ($iSizeY + $iPosY) -ge ($global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Height))
    {
        Write-Host "ERROR: addButtonToWindow button larger than window"
        return;
    }
    
    if($iActive -gt $iCount -or $iActive -lt 0)
    {
        Write-Host "ERROR: Active index out of range (Active: $iActive Count: $iCount)"
        return;
    }
    
    for($i = 0; $i -lt $iCount; $i++)
    {
        if($i -eq [int]($iActive - 1))
        {
            buildButton "GRAY" $iSizeX $iSizeY ($iPosX + $i * $iSizeX) $iPosY $True
        }
        else
        {
            buildButton "GRAY" $iSizeX $iSizeY ($iPosX + $i * $iSizeX) $iPosY $False
        }

        addText $strWindow ([string]($i + $iOffset)) ($iPosX + 6 + $i * $iSizeX) ($iPosY + 1 + ($iSizeY - 12) / 2) "Gold" $doOutline
    }
    
    $objForm.Refresh();
}

function addSwitchButtonToWindow($strWindow, $strName, $isActive, $iSizeX, $iSizeY, $iPosX, $iPosY, $showZeroOne, $doOutline)
{
    Write-Host "$strName $strBtnColor"
    if(!$global:arrWindows[$strWindow].btn)
    {
        Write-Host "No buttons"
        $global:arrWindows[$strWindow].btn = @{}
        $global:arrWindows[$strWindow].btn[$strName] = @{}
    }
    elseif(!$global:arrWindows[$strWindow].btn[$strName])
    {
        Write-Host "Buttons but new one"
        $global:arrWindows[$strWindow].btn[$strName] = @{}
    }
    else
    {
        Write-Host "Buttons"
        return;
    }
    
    $global:arrWindows[$strWindow].btn[$strName].size_x = $iSizeX;
    $global:arrWindows[$strWindow].btn[$strName].size_y = $iSizeY;
    $global:arrWindows[$strWindow].btn[$strName].loc_x  = $iPosX;
    $global:arrWindows[$strWindow].btn[$strName].loc_y  = $iPosY;
    
    # buttons bekommen keine eigene grafik, sie werden lediglich geführt für die klicks
    if($iSizeX -lt 0 -or $iSizeY -lt 0)
    {
        Write-Host "ERROR: addButtonToWindow Size less than 0"
        return;
    }
    
    if(($iSizeX + $iPosX) -ge ($global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Width) -or ($iSizeY + $iPosY) -ge ($global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Height))
    {
        Write-Host "ERROR: addButtonToWindow button larger than window"
        return;
    }
    
    if(!$isActive)
    {
        buildButton "RED" $iSizeX $iSizeY $iPosX $iPosY $False
        buildButton "GRAY" ($iSizeX / 2 - 2) ($iSizeY - 4) ($iPosX + $iSizeX - ($iSizeX / 2)) ($iPosY + 2) $False
    }
    else
    {
        buildButton "GREEN" $iSizeX $iSizeY $iPosX $iPosY $False
        buildButton "GRAY" ($iSizeX / 2 - 2) ($iSizeY - 4) ($iPosX + 2) ($iPosY + 2) $False
    }
    
    if($showZeroOne)
    {
        if(!$isActive)
        {
            addText $global:arrWindows.WindowCurrent "0" ($iPosX - 4 + $iSizeX / 4) ($iPosY + 1 + ($iSizeY - 12) / 2) "Gold" $doOutline
        }
        else
        {
            addText $global:arrWindows.WindowCurrent "1" ($iPosX - 4 + 3 * $iSizeX / 4) ($iPosY + 1 + ($iSizeY - 12) / 2) "Gold" $doOutline
        }
        
    }
    
    $objForm.Refresh();
}

function addImageToWindow($strWindow, $objImage, $iPosX, $iPosy, $scale)
{
    Write-Host "addImageToWindow: Adding image to window"

    Write-Host "Window: " $strWindow
    
    $size_x_w = $global:arrWindows[$strWindow].wnd.Width;
    $size_y_w = $global:arrWindows[$strWindow].wnd.Height;
    
    $size_x_i = $objImage.Width;
    $size_y_i = $objImage.Height;
    
    if($scale -le 0)
    {
        Write-Host "addImageToWindow: Invalid scale"
        Write-Host "$scale"
        return;
    }

    if($size_x_w -lt ($size_x_i + $iPosX))
    {
        Write-Host "addImageToWindow: Image outside of window (x)"
        Write-Host "$iPosX $iPosy"
        return;
    }
    
    if($size_y_w -lt ($size_y_i + $iPosy))
    {
        Write-Host "addImageToWindow: Image outside of window (y)"
        Write-Host "$iPosX $iPosy"
        return;
    }

    $rect_src = New-Object System.Drawing.Rectangle(0, 0, $size_x_i, $size_y_i)
    $rect_dst = New-Object System.Drawing.Rectangle($iPosX, $iPosy, ($size_x_i * $scale), ($size_y_i * $scale))
    
    $objImage.MakeTransparent($global:arrColors["CLR_MAGENTA"].color);

    $global:arrWindows[$strWindow].graphics.DrawImage($objImage, $rect_dst, $rect_src, [System.Drawing.GraphicsUnit]::Pixel);
}

function handleSingleplayerPlayerButton($iID)
{
    Write-Host "handleSingleplayerPlayerButton($iID)"

    if($iID -gt (getPlayerCount)) {return}

    # we can actually switch
    Write-Host "switch $iID"

    Write-Host "Max: " $global:arrSettingsInternal["PLAYERTYPE_MAX"]

    $global:arrPlayerInfo[$iID][5] = ($global:arrPlayerInfo[$iID][5] + 1)

    $btnColor = "Gray"

    if($global:arrPlayerInfo[$iID][5] -gt $global:arrSettingsInternal["PLAYERTYPE_MAX"])
    {
        $global:arrPlayerInfo[$iID][5] = 0
        $btnColor = "Red"
    }

    $global:arrWindows["WND_SINGLEPLAYER_SETUP"].btn.Remove(("BTN_SINGLEPLAYER_SETUP_P" + $iID))
    addButtonToWindow "WND_SINGLEPLAYER_SETUP" ("BTN_SINGLEPLAYER_SETUP_P" + $iID) $btnColor 100 20 270 (46 + (($iID - 1) * 30)) $False ($global:arrPlayertypeIndexString[($global:arrPlayerInfo[$iID][5])]) 6 6 "Gold" $False

}

function addColoredArea($strWindow, $iPosX, $iPosY, $iSizeX, $iSizeY, $color)
{
    Write-Host "addColoredArea($strWindow, $iPosX, $iPosY, $iSizeX, $iSizeY, $color)"
    
    $size_x_w = $global:arrWindows[$strWindow].wnd.Width;
    $size_y_w = $global:arrWindows[$strWindow].wnd.Height;
    
    $size_x_i = $objImage.Width;
    $size_y_i = $objImage.Height;
    
    if($size_x_w -lt ($size_x_i + $iPosX))
    {
        Write-Host "addColoredArea: Image outside of window (x)"
        Write-Host "$iPosX $iPosy"
        return;
    }
    
    if($size_y_w -lt ($size_y_i + $iPosy))
    {
        Write-Host "addColoredArea: Image outside of window (y)"
        Write-Host "$iPosX $iPosy"
        return;
    }

    $global:arrWindows[$strWindow].graphics.FillRectangle($global:arrColors[$color].brush, $iPosX, $iPosY, $iSizeX, $iSizeY)
}

function buildButton($strBtnColor, $iSizeX, $iSizeY, $iPosX, $iPosY, $isPressed)
{
    # well, first of all just fill the button area
    $tmp_grd = [System.Drawing.Graphics]::FromImage($global:arrWindows[$global:arrWindows.WindowCurrent].wnd);
    $tmp_grd.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $tmp_grd.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    
    # fill background
    $tmp_grd.FillRectangle($global:arrColors[("CLR_BTN_" + $strBtnColor + "2")].brush, ($iPosX + 2), ($iPosY + 2), ($iSizeX - 4), ($iSizeY - 4))

    # set colors depending on state
    $clr1 = $global:arrColors[("CLR_BTN_" + $strBtnColor + "1")]
    if($isPressed) { $clr1 = $global:arrColors["CLR_BLACK"] }

    $clr2 = $global:arrColors["CLR_BLACK"]
    if($isPressed) { $clr2 = $global:arrColors[("CLR_BTN_" + $strBtnColor + "1")]}

    # upper side
    $tmp_grd.FillRectangle($clr1.brush, $iPosX, $iPosY, $iSizeX, 2)

    # left side
    $tmp_grd.FillRectangle($clr1.brush, $iPosX, $iPosY, 2, $iSizeY)

    # lower side
    $tmp_grd.FillRectangle($clr2.brush, ($iPosX + 2), ($iPosY + $iSizeY - 2), ($iSizeX - 2), 2)

    # right side
    $tmp_grd.FillRectangle($clr2.brush, ($iPosX + $iSizeX - 2), ($iPosY + 2), 2, ($iSizeY - 4))

    # special lower left
    $tmp_grd.FillRectangle($clr2.brush, ($iPosX + 1),($iPosy + $iSizeY - 1), 1, 1)

    # special top right
    $tmp_grd.FillRectangle($clr2.brush, ($iPosX + $iSizeX - 1),($iPosY + 1), 1, 1)
}

function addBarToWindow($strWindow, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $fPercent, $clrBar)
{
    buildButton "GRAY" $iSizeX $iSizeY $iPosX $iPosY $True
    
    $iTextX = [int](($iSizeX - ($strText.Length * 7)) / 2)
    $iTextY = [int](($iSizeY - 7) / 2)

    $length = [math]::floor((([int]($iSizeX)) - 8) * $fPercent)

    if($length -lt 1) {$length = 1}

    Write-Host "Length: $length $fPercent"

    $rect = New-Object System.Drawing.Rectangle((4 + $iPosX), (4 + $iPosY), ($length), ($iSizeY - 8))
    $tmp_grd = [System.Drawing.Graphics]::FromImage($global:arrWindows[$strWindow].wnd);

    $brush = New-Object System.Drawing.SolidBrush($clrBar)
    $tmp_grd.FillRectangle($brush, $rect)
    
    addText $strWindow $strText ($iPosX + $iTextX) ($iPosY + $iTextY) "Gold" $False
    $objForm.Refresh();
}

function buildInput($strWindow, $strName, $isActive)
{
    # well, first of all just fill the button area
    $tmp_grd = [System.Drawing.Graphics]::FromImage($global:arrWindows[$strWindow].wnd);
    $tmp_grd.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $tmp_grd.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    
    $iSizeX = $global:arrWindows[$strWindow].inp[$strName].size_x
    $iSizeY = $global:arrWindows[$strWindow].inp[$strName].size_y
    $iPosX = $global:arrWindows[$strWindow].inp[$strName].loc_x
    $iPosY = $global:arrWindows[$strWindow].inp[$strName].loc_y
    $strText = $global:arrWindows[$strWindow].inp[$strName].text
    $strAlign = $global:arrWindows[$strWindow].inp[$strName].align
    $iMaxLength = $global:arrWindows[$strWindow].inp[$strName].length


    if($isActive)
    {
        $tmp_grd.FillRectangle($global:arrColors["CLR_GOLD_3"].brush, $iPosX, $iPosY, $iSizeX, $iSizeY)
        $tmp_grd.FillRectangle($global:arrColors["CLR_BLACK"].brush, ($iPosX + 1), ($iPosY + 1), ($iSizeX -2), ($iSizeY - 2))
    }
    else
    {
        $tmp_grd.FillRectangle($global:arrColors["CLR_BLACK"].brush, $iPosX, $iPosY, $iSizeX, $iSizeY)
    }

    $iTextX = 2

    if($strAlign.ToUpper() -eq "CENTER")
    {
        $iTextX = [int](($iSizeX - 4 - 7 * $strText.Length) / 2)
    }
    elseif($strAlign.ToUpper() -eq "RIGHT")
    {
        $iTextX = [int]($iSizeX - 4 - 7 * $strText.Length)
    }

    $iTextY = [int](($iSizeY - 7) / 2)

    addText $strWindow $strText ($iPosX + $iTextX) ($iPosY + $iTextY) "Gold" $False
    $objForm.Refresh();
}

function addInputToWindow($strWindow, $strName, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $strAlign, $iMaxLength, $isPressed)
{
    Write-Host "addInputToWindow($strWindow, $strName, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $strAlign, $iMaxLength)"

    if(!$global:arrWindows[$strWindow].inp)
    {
        Write-Host "No inputs"
        $global:arrWindows[$strWindow].inp = @{}
        $global:arrWindows[$strWindow].inp[$strName] = @{}
    }
    elseif(!$global:arrWindows[$strWindow].inp[$strName])
    {
        Write-Host "Inputs but new one"
        $global:arrWindows[$strWindow].inp[$strName] = @{}
    }
    else
    {
        Write-Host "Inputs"
        return;
    }
    
    $global:arrWindows[$strWindow].inp[$strName].size_x = $iSizeX;
    $global:arrWindows[$strWindow].inp[$strName].size_y = $iSizeY;
    $global:arrWindows[$strWindow].inp[$strName].loc_x  = $iPosX;
    $global:arrWindows[$strWindow].inp[$strName].loc_y  = $iPosY;
    $global:arrWindows[$strWindow].inp[$strName].text   = $strText;
    $global:arrWindows[$strWindow].inp[$strName].align  = $strAlign;
    $global:arrWindows[$strWindow].inp[$strName].length = $iMaxLength;
    
    # buttons bekommen keine eigene grafik, sie werden lediglich geführt für die klicks
    if($iSizeX -lt 0 -or $iSizeY -lt 0)
    {
        Write-Host "ERROR: addInputToWindow Size less than 0"
        return;
    }
    
    if(($iSizeX + $iPosX) -ge ($global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Width) -or ($iSizeY + $iPosY) -ge ($global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Height))
    {
        Write-Host "ERROR: addInputToWindow button larger than window"
        return;
    }
    
    # maxlength by inputbox
    if($iMaxLength -le 0)
    {
        $global:arrWindows[$strWindow].inp[$strName].length = ([int](($iSizeX - 4) / 7))
    }

    buildInput $strWindow $strName $False

    $objForm.Refresh();
}

function addButtonToWindow($strWindow, $strName, $strBtnColor, $iSizeX, $iSizeY, $iPosX, $iPosY, $isPressed, $strText, $iTextX, $iTextY, $strColor, $doOutline)
{
    Write-Host "$strName $strBtnColor"

    if(!$global:arrWindows[$strWindow].btn)
    {
        Write-Host "No buttons"
        $global:arrWindows[$strWindow].btn = @{}
        $global:arrWindows[$strWindow].btn[$strName] = @{}
    }
    elseif(!$global:arrWindows[$strWindow].btn[$strName])
    {
        Write-Host "Buttons but new one"
        $global:arrWindows[$strWindow].btn[$strName] = @{}
    }
    else
    {
        Write-Host "Buttons"
        return;
    }
    
    $global:arrWindows[$strWindow].btn[$strName].size_x = $iSizeX;
    $global:arrWindows[$strWindow].btn[$strName].size_y = $iSizeY;
    $global:arrWindows[$strWindow].btn[$strName].loc_x  = $iPosX;
    $global:arrWindows[$strWindow].btn[$strName].loc_y  = $iPosY;
    
    # buttons bekommen keine eigene grafik, sie werden lediglich geführt für die klicks
    if($iSizeX -lt 0 -or $iSizeY -lt 0)
    {
        Write-Host "ERROR: addButtonToWindow Size less than 0"
        return;
    }
    
    if(($iSizeX + $iPosX) -ge ($global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Width) -or ($iSizeY + $iPosY) -ge ($global:arrWindows[$global:arrWindows.WindowCurrent].wnd.Height))
    {
        Write-Host "ERROR: addButtonToWindow button larger than window"
        return;
    }
    
    if(($strText.Length * 7) -ge $iSizeX)
    {
        $l = ($strText.Length * 7)
        Write-Host "ERROR: Button Text too long ($l > $iSizeX)"
    }
 
    if($strBtnColor -ne "Transparent")
    {
        buildButton ($strBtnColor.ToUpper()) $iSizeX $iSizeY $iPosX $iPosY $isPressed
    }

    if([int]$iTextX -lt 0)
    {
        $iTextX = [int](($iSizeX - ($strText.Length * 7)) / 2)
    }

    if([int]$iTextY -lt 0)
    {
        $iTextY = [int](($iSizeY - 7) / 2)
    }

    addText $global:arrWindows.WindowCurrent $strText ($iPosX + $iTextX) ($iPosY + $iTextY) $strColor $doOutline
    $objForm.Refresh();
}

#region FUNCTION ADDTEXT
function addText($strWindow, $strText, $iPosX, $iPosY, $strColor, $doOutline)
{
    $strText = ([string]$strText)

    if ($strText -eq "")
    {
        return;
    }

    $strText = $strText.ToUpper();

    $sizeX      = 0;
    for($i = 0; $i -lt ($strText.Length); $i++)
    {
        $tempChar = $strText.Substring($i, 1);
        if($arrFont[$tempChar])
        {
            $sizeX = $sizeX + $arrFont[$tempChar].Width;
        }
        else
        {
            $sizeX = $sizeX + $arrFont["?"].Width;
        }
    }
    $sizeY      = 9;
    $tmp_img    = New-Object System.Drawing.Bitmap($sizeX, $sizeY);

    $offset_x = 0;
    
    # monospace font, no need to recreate this rect all the time
    $rect_src = New-Object System.Drawing.Rectangle(0, 0, ($arrFont["?"].Width), ($arrFont["?"].Height))

    for($i = 0; $i -lt ($strText.Length); $i++)
    {
        $tempChar = $strText.Substring($i, 1);

        # char not in array? use '?'
        if(!$arrFont[$tempChar])
        {
            $tempChar = "?"
        }

        $rect_dst = New-Object System.Drawing.Rectangle(($iPosX + $offset_x), $iPosy, ($arrFont[$tempChar].Width), $sizeY)

        setCharColor $tempChar $strColor $doOutline

        $global:arrWindows[$strWindow].graphics.DrawImage($arrFont[$tempChar], $rect_dst, $rect_src, [System.Drawing.GraphicsUnit]::Pixel);

        $offset_x = $offset_x + $arrFont[$tempChar].Width
    }
}
#endregion

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
    
    $global:arrWindows.WindowOpen = $True;
    $global:arrWindows.WindowCurrent = $strWindow;
    
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

    $objForm.Refresh();
}
#endregion

#region FUNCTION SCALEGAME
function scaleGame($scaleUp)
{
    $currentFactor = ($objForm.Size.Width - 16)  / ($DrawingSizeX)
    $newFactor = 1
    
    if($currentFactor -ge 3) {$newFactor = 3}
    elseif($currentFactor -le 1) {$newFactor = 1}
    else 
    {
        if($scaleUp) {$newFactor = [math]::Ceiling($currentFactor)}
        else {$newFactor = [math]::Floor($currentFactor)}
    }
    
    $pictureBox.Size = New-Object System.Drawing.Size(($newFactor * $DrawingSizeX), ($newFactor * $DrawingSizeY))
    $objForm.size = New-Object System.Drawing.Size(($newFactor * $DrawingSizeX + 16), ($newFactor * $DrawingSizeY + 38))
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

    $fac_x = ($objForm.Size.Width - 16)  / ($DrawingSizeX)
    $fac_y = ($objForm.Size.Height - 38) / ($DrawingSizeY)

    $rect = New-Object System.Drawing.Rectangle(0, 0, $pictureBox.Size.Width, $pictureBox.Size.Height)
    
    if($global:strGameState -eq "EDIT_MAP" -or $global:strGameState -eq "EDIT_MAP_ESCAPE" -or $global:strGameState -eq "SINGLEPLAYER_INGAME" -or $global:strGameState -eq "SINGLEPLAYER_TILEINFO" -or $global:strGameState -eq "SINGLEPLAYER_ESCAPE")
    {
        $offset_x = $global:arrCreateMapOptions["EDITOR_CHUNK_X"] * $global:arrSettingsInternal["TILESIZE"];
        $offset_y = $global:arrCreateMapOptions["EDITOR_CHUNK_Y"] * $global:arrSettingsInternal["TILESIZE"];
        
        $offset_curx = ($global:arrCreateMapOptions["SELECTED_X"] - $global:arrCreateMapOptions["EDITOR_CHUNK_X"]) * ($fac_x * $global:arrSettingsInternal["TILESIZE"]);
        $offset_cury = ($global:arrCreateMapOptions["SELECTED_Y"] - $global:arrCreateMapOptions["EDITOR_CHUNK_Y"]) * ($fac_y * $global:arrSettingsInternal["TILESIZE"]);
        
        $EventArgs.Graphics.DrawImage($global:objWorldBackground, $rect, 0, 0, $DrawingSizeX, $DrawingSizeY, [System.Drawing.GraphicsUnit]::Pixel)

        $EventArgs.Graphics.DrawImage($global:objWorld, $rect, ($offset_x), ($offset_y), $DrawingSizeX, $DrawingSizeY, [System.Drawing.GraphicsUnit]::Pixel)

        $rect_cur = New-Object System.Drawing.Rectangle($offset_curx, $offset_cury, ($fac_x * $global:arrSettingsInternal["TILESIZE"]), ($fac_y * $global:arrSettingsInternal["TILESIZE"]))
        
        if($global:arrCreateMapOptions["SHOW_PREVIEW"])
        {
            if($global:arrCreateMapOptions["EDIT_MODE"] -eq 1)
            {
                $EventArgs.Graphics.DrawImage(($global:arrTextures[$arrBaseTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER01"]]].bitmap), $rect_cur, 0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"], [System.Drawing.GraphicsUnit]::Pixel)
            }
            elseif($global:arrCreateMapOptions["EDIT_MODE"] -eq 2)
            {
                $EventArgs.Graphics.DrawImage(($global:arrTextures[$arrOverlayTextureIDToKey[$global:arrCreateMapOptions["SELECT_LAYER02"]]].bitmap), $rect_cur, 0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"], [System.Drawing.GraphicsUnit]::Pixel)
            }
            elseif($global:arrCreateMapOptions["EDIT_MODE"] -eq 3)
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

                    if([int]$global:arrSettingsInternal["BUILDINGS_SELECTED"] -ne -1)
                    {
                        $global:arrSettingsInternal["HOOVER_CANBUILD"] = checkIfBuildingPossible ([int]($global:arrSettingsInternal["BUILDINGS_SELECTED"])) ([int]($global:arrSettingsInternal["HOOVER_X"] - 2)) ([int]($global:arrSettingsInternal["HOOVER_Y"] - 2)) ($global:arrPlayerInfo.currentPlayer)
                    }
                    else
                    {
                        $global:arrSettingsInternal["HOOVER_CANBUILD"] = $False
                    }

                    if([int]$global:arrSettingsInternal["RECRUIT_ARMY"])
                    {
                        $global:arrSettingsInternal["HOOVER_CANRECRUIT"] = checkIfRecruitingPossible ([int]($global:arrSettingsInternal["HOOVER_X"] - 2)) ([int]($global:arrSettingsInternal["HOOVER_Y"] - 2)) ($global:arrPlayerInfo.currentPlayer)
                    }
                    else
                    {
                        $global:arrSettingsInternal["HOOVER_CANRECRUIT"] = $False
                    }
                }
                elseif($hovering_X -lt 2 -or $hovering_Y -lt 2 -or $hovering_X -ge ([int]$arrCreateMapOptions["WIDTH"] + 2) -or $hovering_Y -ge ([int]$arrCreateMapOptions["HEIGHT"] + 2))
                {
                    $global:arrSettingsInternal["HOOVER_CANBUILD"] = $False
                    $global:arrSettingsInternal["HOOVER_CANRECRUIT"] = $False
                    $global:arrSettingsInternal["HOOVER_X"] = -1
                    $global:arrSettingsInternal["HOOVER_Y"] = -1
                }

                if($global:arrSettingsInternal["HOOVER_CANBUILD"] -or ($global:arrSettingsInternal["HOOVER_CANRECRUIT"] -and $global:arrSettingsInternal["RECRUIT_ARMY"]))
                {
                    $EventArgs.Graphics.DrawImage($global:arrInterface["SELECTION_TILE_VALID"].bitmap, $rect_cur, 0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"], [System.Drawing.GraphicsUnit]::Pixel)
                }
                else
                {
                    $EventArgs.Graphics.DrawImage($global:arrInterface["SELECTION_TILE_INVALID"].bitmap, $rect_cur, 0, 0, $global:arrSettingsInternal["TILESIZE"], $global:arrSettingsInternal["TILESIZE"], [System.Drawing.GraphicsUnit]::Pixel)
                }
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
    showWindow "WND_INIT_WAIT_CLICK"
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

    $pictureBox.Size = New-Object System.Drawing.Size(($factor * $DrawingSizeX), ($factor * $DrawingSizeY))
    $objForm.size = New-Object System.Drawing.Size(($factor * $DrawingSizeX + 16), ($factor * $DrawingSizeY + 38))
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