#http://www.techotopia.com/index.php/Drawing_Graphics_using_PowerShell_1.0_and_GDI%2B

# load forms (GUI)
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing.Graphics") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles() 
# STA Modus (Single Threading Apartment) - benötigt für OpenFileDialog
[threading.thread]::CurrentThread.SetApartmentState(2)

$global:arrWindows = @{}
$global:windowOpen = $False;
$global:strCurrentWindow = "";

$global:arrSettings = @{}
$global:arrSettings.topmost = $False;

$global:strGameState = "WAIT_INIT_CLICK"

### Arrays ###

$revision       = "0.8.15"
$AppName        = "FourTheWin"
$DrawingSizeX	= 480
$DrawingSizeY	= 270
$global:bitmap  = New-Object System.Drawing.Bitmap($DrawingSizeX, $DrawingSizeY);
$black          = [System.Drawing.Color]::FromArgb(0, 0, 0)
$transparent 	= [System.Drawing.Color]::FromArgb(255, 0, 143)

$color_gold     = [System.Drawing.Color]::FromArgb(255, 255, 0)
$color_gold_1   = [System.Drawing.Color]::FromArgb(255, 219, 23)
$color_gold_2   = [System.Drawing.Color]::FromArgb(255, 191, 51)

$color_blue     = [System.Drawing.Color]::FromArgb(0, 211, 247)
$color_blue_1   = [System.Drawing.Color]::FromArgb(0, 123, 219)
$color_blue_2   = [System.Drawing.Color]::FromArgb(0, 55, 191)

# zoomed?
$global:iSize = 1;

$strPathImageGFX = "..\..\DATA\GFX\IMAG\"

# textures etc.
$strPathToMenuGFX = "..\..\DATA\GFX\MENU\"
$tex_MENU_CORNER        = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\MENU_CORNER.png'          ))));
$tex_MENU_SIDE_VERT     = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\MENU_SIDE_VERT.png'       ))));
$tex_MENU_SIDE_HOR      = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\MENU_SIDE_HOR.png'        ))));
#$tex_MENU_TEX_BACK      = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\TEX_BACK_GREEN_DARK.bmp'  ))));
$tex_MENU_TEX_BACK      = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\TEX_BACK_GREEN_NOISE.bmp'  ))));
$tex_MENU_GRAY_DARK     = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\TEX_GRAY_DARK.bmp'        ))));
$tex_MENU_GRAY_LIGHT    = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\TEX_GRAY_LIGHT.bmp'       ))));
$tex_MENU_RED_DARK      = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\TEX_RED_DARK.bmp'         ))));
$tex_MENU_RED_LIGHT     = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\TEX_RED_LIGHT.bmp'        ))));
$tex_MENU_GREEN_DARK    = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\TEX_GREEN_DARK.bmp'       ))));
$tex_MENU_GREEN_LIGHT   = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToMenuGFX + '.\TEX_GREEN_LIGHT.bmp'      ))));

$strPathToMenuGFX = "..\..\DATA\SOUND\MUSIC\"
$arrSounds = @{}
$arrSounds["MAINTHEME"] = New-Object System.Media.SoundPlayer;
$arrSounds["MAINTHEME"].SoundLocation = ($strPathToMenuGFX + "Medieval.wav");

$strPathToFontGFX = "..\..\DATA\GFX\FONT\"
$arrFont = @{}
$arrFont["!"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '1.bmp'  ))));
$arrFont[""""] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '2.bmp'  ))));
$arrFont["#"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '3.bmp'  ))));
#$arrFont["$"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '4.bmp'  ))));
$arrFont["%"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '5.bmp'  ))));
$arrFont["&"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '6.bmp'  ))));
$arrFont["'"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '7.bmp'  ))));
$arrFont["("] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '8.bmp'  ))));
$arrFont[")"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '9.bmp'  ))));
$arrFont["*"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '10.bmp'  ))));
$arrFont["+"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '11.bmp'  ))));
$arrFont[","] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '12.bmp'  ))));
$arrFont["-"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '13.bmp'  ))));
$arrFont["."] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '14.bmp'  ))));
$arrFont["/"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '15.bmp'  ))));
$arrFont["0"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '16.bmp'  ))));
$arrFont["1"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '17.bmp'  ))));
$arrFont["2"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '18.bmp'  ))));
$arrFont["3"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '19.bmp'  ))));
$arrFont["4"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '20.bmp'  ))));
$arrFont["5"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '21.bmp'  ))));
$arrFont["6"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '22.bmp'  ))));
$arrFont["7"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '23.bmp'  ))));
$arrFont["8"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '24.bmp'  ))));
$arrFont["9"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '25.bmp'  ))));
$arrFont[":"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '26.bmp'  ))));
$arrFont[";"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '27.bmp'  ))));
$arrFont["<"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '28.bmp'  ))));
$arrFont["="] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '29.bmp'  ))));
$arrFont[">"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '30.bmp'  ))));
$arrFont["?"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '31.bmp'  ))));
$arrFont["@"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '32.bmp'  ))));
$arrFont["A"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '33.bmp'  ))));
$arrFont["B"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '34.bmp'  ))));
$arrFont["C"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '35.bmp'  ))));
$arrFont["D"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '36.bmp'  ))));
$arrFont["E"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '37.bmp'  ))));
$arrFont["F"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '38.bmp'  ))));
$arrFont["G"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '39.bmp'  ))));
$arrFont["H"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '40.bmp'  ))));
$arrFont["I"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '41.bmp'  ))));
$arrFont["J"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '42.bmp'  ))));
$arrFont["K"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '43.bmp'  ))));
$arrFont["L"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '44.bmp'  ))));
$arrFont["M"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '45.bmp'  ))));
$arrFont["N"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '46.bmp'  ))));
$arrFont["O"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '47.bmp'  ))));
$arrFont["P"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '48.bmp'  ))));
$arrFont["Q"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '49.bmp'  ))));
$arrFont["R"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '50.bmp'  ))));
$arrFont["S"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '51.bmp'  ))));
$arrFont["T"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '52.bmp'  ))));
$arrFont["U"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '53.bmp'  ))));
$arrFont["V"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '54.bmp'  ))));
$arrFont["W"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '55.bmp'  ))));
$arrFont["X"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '56.bmp'  ))));
$arrFont["Y"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '57.bmp'  ))));
$arrFont["Z"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '58.bmp'  ))));
$arrFont["\"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '58.bmp'  ))));
$arrFont["^"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '58.bmp'  ))));
$arrFont["_"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '58.bmp'  ))));
#$arrFont["(C)"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '58.bmp'  ))));
$arrFont["Ä"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '58.bmp'  ))));
$arrFont["Ö"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '58.bmp'  ))));
$arrFont["Ü"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '58.bmp'  ))));
$arrFont["ß"] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '58.bmp'  ))));
$arrFont[" "] = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathToFontGFX + '67.bmp'  ))));

# Create the form
$objForm = New-Object System.Windows.Forms.Form 
$objForm.minimumSize = New-Object System.Drawing.Size(($DrawingSizeX + 16), ($DrawingSizeY + 36)) 
$objForm.maximumSize = New-Object System.Drawing.Size(($DrawingSizeX + 16), ($DrawingSizeY + 36)) 
$objForm.MaximizeBox = $False;
$objForm.MinimizeBox = $False;
$objForm.Topmost = $global:arrSettings.topmost; 
#https://i-msdn.sec.s-msft.com/dynimg/IC24340.jpeg
#$objForm.BackColor = "SlateGray"

$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.SizeMode = 4
$pictureBox.Size = New-Object System.Drawing.Size($DrawingSizeX	, $DrawingSizeY)
$objForm.controls.add($pictureBox)
$objForm.AutoSize = $False
$pictureBox.Add_Click({onMouseClick "Picturebox"})
$objForm.Add_Shown({$objForm.Activate()})
$objForm.Add_Click({})
$pictureBox.Add_Paint({onRedraw $this $_})
$objForm.Add_KeyDown({onKeyPress $this $_})
$objForm.Add_Click({onMouseClick "Form"})

##
## onKeyPress
##

function onKeyPress($sender, $EventArgs)
{
    $keyCode = $EventArgs.KeyCode
    
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
        "Escape"
        {
            #showWindow "WND_ESC_MAIN"
        }
        "C"
        {
            showSplash
        }
        "T"
        {
            Write-Host "Testfunction!"
            #$global:arrWindows["WND_ESC_MAIN"].btn.Remove("BTN_SINGLEPLAYER")
            #addButtonToWindow "WND_ESC_MAIN" "BTN_SINGLEPLAYER_KRAM" "Gray" 136 20 12 24 "Singlekram" 8 4 "Gold" $False
            
        }
        default     {Write-Host "Unhandled keypress, code '$keyCode'"}
    }
}

function onMouseClick($strNameSender)
{
    $relX = [System.Windows.Forms.Cursor]::Position.X - $objForm.Location.X - 8 # 8 = left border
    $relY = [System.Windows.Forms.Cursor]::Position.Y - $objForm.Location.Y - 30 # 30 = upper border
    
    $relX = $relX / [math]::pow(2, ($global:iSize -1 ))
    $relY = $relY / [math]::pow(2, ($global:iSize -1 ))
    
    switch($strNameSender)
    {
        "Picturebox"
        {
            handleClickPicturebox $relX $relY
        }
        default
        {
            Write-Host "unhandled click at $relX $relY"
        }
    }
}

function handleClickPicturebox($posX, $posY)
{
    if($global:strGameState -eq "WAIT_INIT_CLICK")
    {
        showWindow "WND_ESC_MAIN"
        $global:strGameState = "MAIN_MENU"
    }
    elseif($global:windowOpen)
    {
        handleClickWindow $posX $posY
    }
    else
    {
        Write-Host "unhandled click at $relX $relY (in handleClickPicturebox)"
    }
}

function handleClickWindow($posX, $posY)
{
    # relative to window click
    if($global:windowOpen -and !$global:arrWindows[$global:strCurrentWindow].btn)
    {
        Write-Host "Active window but no buttons?"
        return;
    }
    
    if($posX -lt $global:arrWindows[$global:strCurrentWindow].loc_x -or $posX -gt ($global:arrWindows[$global:strCurrentWindow].loc_x + $global:arrWindows[$global:strCurrentWindow].wnd.Width))
    {
        return;
    }
    
    if($posY -lt $global:arrWindows[$global:strCurrentWindow].loc_y -or $posY -gt ($global:arrWindows[$global:strCurrentWindow].loc_y + $global:arrWindows[$global:strCurrentWindow].wnd.Height))
    {
        return;
    }
    
    $relX = $posX -  $global:arrWindows[$global:strCurrentWindow].loc_x
    $relY = $posY -  $global:arrWindows[$global:strCurrentWindow].loc_y
    
    $keys    = $global:arrWindows[$global:strCurrentWindow].btn.Keys
    
    Try
    {
        foreach($key in $keys)
        {
            if(!$global:arrWindows[$global:strCurrentWindow].btn)
            {
                return;
            }
            
            if(($global:arrWindows[$global:strCurrentWindow].btn[$key].loc_x -lt $relX) -and ($global:arrWindows[$global:strCurrentWindow].btn[$key].loc_x + $global:arrWindows[$global:strCurrentWindow].btn[$key].size_x -gt $relX))
            {
                if(($global:arrWindows[$global:strCurrentWindow].btn[$key].loc_y -lt $relY) -and ($global:arrWindows[$global:strCurrentWindow].btn[$key].loc_y + $global:arrWindows[$global:strCurrentWindow].btn[$key].size_y -gt $relY))
                {
                    handleButtonKlick $key
                }
            }
        }
    }
    Catch [system.exception]
    {
        Write-Host "Warning: Maybe a click has not properly been registered!"
    }
}

function handleButtonKlick($strButtonID)
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
            showWindow "WND_ESC_MAIN"
        }
        "BTN_CREDITS_BACK"
        {
            showWindow "WND_ESC_MAIN"
        }
        "BTN_SINGLEPLAYER"
        {
            showWindow "WND_ERROR_NOTIMPLEMENTED"
        }
        "BTN_MULTIPLAYER"
        {
            showWindow "WND_ERROR_NOTIMPLEMENTED"
        }
        "BTN_ERROR_NOTIMPLEMENTED_BACK"
        {
            showWindow "WND_ESC_MAIN"
        }
        "BTN_SWITCH_TOPMOST"
        {
            $global:arrWindows["WND_GAME_OPTIONS"].btn.Remove("BTN_SWITCH_TOPMOST")
            $global:arrSettings.topmost = !$global:arrSettings.topmost;
            $objForm.Topmost = $global:arrSettings.topmost;
            addSwitchButtonToWindow "WND_GAME_OPTIONS" "BTN_SWITCH_TOPMOST" $global:arrSettings.topmost 60 20 240 12 $True $False
        }
        default
        {
            Write-Host "Button $strButtonID was clicked but has no function?"
        }
    }
}

function showWindow($strType)
{
    switch($strType)
    {
        "WND_ESC_MAIN"
        {
            Write-Host "Building window: $strType"
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
            addButtonToWindow "WND_ESC_MAIN" "BTN_SINGLEPLAYER" "Gray" 136 20 12 24 "Singleplayer" 8 4 "Gold" $False
            addButtonToWindow "WND_ESC_MAIN" "BTN_MULTIPLAYER" "Gray" 136 20 12 50 "Multiplayer" 12 4 "Gold" $False
            addButtonToWindow "WND_ESC_MAIN" "BTN_OPTIONS" "Gray" 136 20 12 76 "Options" 33 4 "Gold" $False
            addButtonToWindow "WND_ESC_MAIN" "BTN_CREDITS" "Gray" 136 20 12 102 "Credits" 35 4 "Gold" $False
            addButtonToWindow "WND_ESC_MAIN" "BTN_QUIT" "Red" 136 20 12 156 "Quit" 48 4 "Gold" $False
            $pictureBox.Refresh();
        }
        "WND_QUIT_MAIN"
        {
            Write-Host "Building window: $strType"
            buildWindow 160 100 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 100) / 2) $strType
            addText $global:arrWindows[$strType].wnd "Really quit?" 12 12 "Gold" $False
            addButtonToWindow "WND_QUIT_MAIN" "BTN_QUIT_YES" "Red" 60 20 12 56 "Yes" 8 4 "Gold" $False
            addButtonToWindow "WND_QUIT_MAIN" "BTN_QUIT_NO" "Green" 60 20 88 56 "No" 8 4 "Gold" $False
            $pictureBox.Refresh();
        }
        "WND_CREDITS"
        {
            Write-Host "Building window: $strType"
            buildWindow 160 200 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 200) / 2) $strType
            addText $global:arrWindows[$strType].wnd "Written by:" 10 10 "Gold" $False
            addText $global:arrWindows[$strType].wnd "Spikeone" 10 22 "Gold" $False
            addText $global:arrWindows[$strType].wnd "Story by:" 10 40 "Gold" $False
            addText $global:arrWindows[$strType].wnd "-" 10 52 "Gold" $False
            addText $global:arrWindows[$strType].wnd "Graphics by:" 10 70 "Gold" $False
            addText $global:arrWindows[$strType].wnd "-" 10 82 "Gold" $False
            addButtonToWindow $strType "BTN_CREDITS_BACK" "Gray" 136 20 12 156 "Back" 48 4 "Gold" $False
        }
        "WND_GAME_OPTIONS"
        {
            Write-Host "Building window: $strType"
            buildWindow 360 220 (($DrawingSizeX - 360) / 2) (($DrawingSizeY - 220) / 2) $strType
            addText $global:arrWindows[$strType].wnd "Topmost:" 12 12 "Gold" $False
            addSwitchButtonToWindow $strType "BTN_SWITCH_TOPMOST" $False 60 20 240 12 $True $False
            addButtonToWindow $strType "BTN_GAME_OPTIONS_BACK" "Gray" 136 20 112 176 "Back" 48 4 "Gold" $False
        }
        "WND_ERROR_NOTIMPLEMENTED"
        {
            buildWindow 160 100 (($DrawingSizeX - 160) / 2) (($DrawingSizeY - 100) / 2) $strType
            addText $global:arrWindows[$strType].wnd "Sorry! Not" 10 10 "Gold" $False
            addText $global:arrWindows[$strType].wnd "implemented..." 10 22 "Gold" $False
            addButtonToWindow $strType "BTN_ERROR_NOTIMPLEMENTED_BACK" "Gray" 136 20 12 56 "Back" 48 4 "Gold" $False
        }
        default
        {
            Write-Host "Unknown window $strType"
        }
    }
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
    
    if(($iSizeX + $iPosX) -ge ($global:arrWindows[$global:strCurrentWindow].wnd.Width) -or ($iSizeY + $iPosY) -ge ($global:arrWindows[$global:strCurrentWindow].wnd.Height))
    {
        Write-Host "ERROR: addButtonToWindow button larger than window"
        return;
    }
    
    if(!$isActive)
    {
        buildButton "Red" $iSizeX $iSizeY $iPosX $iPosY
        buildButton "Gray" ($iSizeX / 2 - 2) ($iSizeY - 4) ($iPosX + $iSizeX - ($iSizeX / 2)) ($iPosY + 2)
    }
    else
    {
        buildButton "Green" $iSizeX $iSizeY $iPosX $iPosY
        buildButton "Gray" ($iSizeX / 2 - 2) ($iSizeY - 4) ($iPosX + 2) ($iPosY + 2)
    }
    
    if($showZeroOne)
    {
        if(!$isActive)
        {
            addText $global:arrWindows[$global:strCurrentWindow].wnd "0" ($iPosX - 4 + $iSizeX / 4) ($iPosY + 1 + ($iSizeY - 12) / 2) "Gold" $doOutline
        }
        else
        {
            addText $global:arrWindows[$global:strCurrentWindow].wnd "1" ($iPosX - 4 + 3 * $iSizeX / 4) ($iPosY + 1 + ($iSizeY - 12) / 2) "Gold" $doOutline
        }
        
    }
    
    $objForm.Refresh();
}

function buildButton($strBtnColor, $iSizeX, $iSizeY, $iPosX, $iPosY)
{
    # well, first of all just fill the button area
    for($i = 0; $i -lt $iSizeX; $i++)
    {
        for($j = 0; $j -lt $iSizeY; $j++)
        {
            $posx = $i - [math]::floor($i / 64) * 64;
            $posy = $j - [math]::floor($j / 64) * 64;
            
            switch($strBtnColor)
            {
                "Red"
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($i + $iPosX), ($j + $iPosY), $tex_MENU_RED_DARK.GetPixel($posx, $posy));
                }
                "Green"
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($i + $iPosX), ($j + $iPosY), $tex_MENU_GREEN_DARK.GetPixel($posx, $posy));
                }
                default
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($i + $iPosX), ($j + $iPosY), $tex_MENU_GRAY_DARK.GetPixel($posx, $posy));
                }
            }
        }
    }
    
    # and special effects...
    # $i = y
    for($i = 0; $i -lt 2; $i++)
    {
        for($j = $i; $j -lt $iSizeX; $j++)
        {            
            $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($iPosX + $j), ($iPosY + $iSizeY - $i), "Black");
        }
        
    }
    
    # $i = x
    for($i = ($iSizeX - 2); $i -lt $iSizeX; $i++)
    {
        for($j = (0 + $iSizeX - $i - 1); $j -lt $iSizeY; $j++)
        {   
            $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($i + $iPosX), ($j + $iPosY), "Black");
        }
    }
    
    # and special effects...
    # $i = y
    for($i = 0; $i -lt 2; $i++)
    {
        for($j = $i; $j -lt ($iSizeX - $i); $j++)
        {   
            $posx = $i - [math]::floor($i / 64) * 64;
            $posy = $j - [math]::floor($j / 64) * 64;
            
            switch($strBtnColor)
            {
                "Red"
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($iPosX + $j), ($iPosY + $i), $tex_MENU_RED_LIGHT.GetPixel($posx, $posy));
                }
                "Green"
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($iPosX + $j), ($iPosY + $i), $tex_MENU_GREEN_LIGHT.GetPixel($posx, $posy));
                }
                default
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($iPosX + $j), ($iPosY + $i), $tex_MENU_GRAY_LIGHT.GetPixel($posx, $posy));
                }
            }
        }
    }
    
    # $i = x
    for($i = 0; $i -lt 2; $i++)
    {
        for($j = 0; $j -lt ($iSizeY - $i); $j++)
        {   
            $posx = $i - [math]::floor($i / 64) * 64;
            $posy = $j - [math]::floor($j / 64) * 64;
            
            switch($strBtnColor)
            {
                "Red"
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($i + $iPosX), ($j + $iPosY), $tex_MENU_RED_LIGHT.GetPixel($posx, $posy));
                }
                "Green"
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($i + $iPosX), ($j + $iPosY), $tex_MENU_GREEN_LIGHT.GetPixel($posx, $posy));
                }
                default
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($i + $iPosX), ($j + $iPosY), $tex_MENU_GRAY_LIGHT.GetPixel($posx, $posy));
                }
            }
            
            
        }
    }
}

function addButtonToWindow($strWindow, $strName, $strBtnColor, $iSizeX, $iSizeY, $iPosX, $iPosY, $strText, $iTextX, $iTextY, $strColor, $doOutline)
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
    
    if(($iSizeX + $iPosX) -ge ($global:arrWindows[$global:strCurrentWindow].wnd.Width) -or ($iSizeY + $iPosY) -ge ($global:arrWindows[$global:strCurrentWindow].wnd.Height))
    {
        Write-Host "ERROR: addButtonToWindow button larger than window"
        return;
    }
    
    if(($strText.Length * 12) -ge $iSizeX)
    {
        $l = ($strText.Length * 12)
        Write-Host "ERROR: Button Text too long ($l > $iSizeX)"
    }
    
    # well, first of all just fill the button area
    for($i = 0; $i -lt $iSizeX; $i++)
    {
        for($j = 0; $j -lt $iSizeY; $j++)
        {
            $posx = $i - [math]::floor($i / 64) * 64;
            $posy = $j - [math]::floor($j / 64) * 64;
            
            switch($strBtnColor)
            {
                "Red"
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($i + $iPosX), ($j + $iPosY), $tex_MENU_RED_DARK.GetPixel($posx, $posy));
                }
                "Green"
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($i + $iPosX), ($j + $iPosY), $tex_MENU_GREEN_DARK.GetPixel($posx, $posy));
                }
                default
                {
                    $global:arrWindows[$global:strCurrentWindow].wnd.SetPixel(($i + $iPosX), ($j + $iPosY), $tex_MENU_GRAY_DARK.GetPixel($posx, $posy));
                }
            }
        }
    }
    
    buildButton $strBtnColor $iSizeX $iSizeY $iPosX $iPosY 
    addText $global:arrWindows[$global:strCurrentWindow].wnd $strText ($iPosX + $iTextX) ($iPosY + $iTextY) $strColor $doOutline
    $objForm.Refresh();
}

function addText($objTarget, $strText, $iPosX, $iPosY, $strColor, $doOutline)
{
    $strText = $strText.ToUpper();
    #Write-Host "Adding text"
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
    $sizeY      = 12;
    #$tmp_rec    = New-Object System.Drawing.Rectangle(0, 0, $sizeX, $sizeY)
    #$tmp_img    = $global:bitmap.Clone($tmp_rec, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $tmp_img    = New-Object System.Drawing.Bitmap($sizeX, $sizeY);
    
    Write-Host "$strText $iPosX $iPosY"
    
    $offset_x = 0;
    
    for($i = 0; $i -lt ($strText.Length); $i++)
    {
        $tempChar = $strText.Substring($i, 1);
        
        if($arrFont[$tempChar])
        {
            # valid char
            for($j = 0; $j -lt ($arrFont[$tempChar].Width); $j++)
            {
                for($k = 0; $k -lt 12; $k++)
                {
                    # mal sehen ob es hier noch das font gibt
                    if($j -lt $arrFont[$tempChar].Width -and $k -lt $arrFont[$tempChar].Height)
                    {
                        $tmp_img.SetPixel(($j + $offset_x), $k, $arrFont[$tempChar].GetPixel($j, $k))
                    }
                    else
                    {
                        $tmp_img.SetPixel(($j + $offset_x), $k, $transparent);
                    }
                }
            }
            
            $offset_x = $offset_x + $arrFont[$tempChar].Width;
        }
        else
        {
            # invalid char
            $tempChar = "?";
            for($j = 0; $j -lt ($arrFont[$tempChar].Width); $j++)
            {
                for($k = 0; $k -lt 12; $k++)
                {
                    # mal sehen ob es hier noch das font gibt
                    if($j -lt $arrFont[$tempChar].Width -and $k -lt $arrFont[$tempChar].Height)
                    {
                        $tmp_img.SetPixel(($j + $offset_x), $k, $arrFont[$tempChar].GetPixel($j, $k))
                    }
                    else
                    {
                        $tmp_img.SetPixel(($j + $offset_x), $k, $transparent);
                    }
                }
            }
            
            $offset_x = $offset_x + $arrFont[$tempChar].Width;
        }
    }
    
    for($i = 0; $i -lt $sizeX; $i++)
    {
        for($j = 0; $j -lt $sizeY; $j++)
        {
            if($tmp_img.GetPixel($i, $j) -ne $transparent -and (($tmp_img.GetPixel($i, $j) -ne $black) -or ($doOutline -and $tmp_img.GetPixel($i, $j) -eq $black)))
            {
                switch($strColor)
                {
                    "Gold"
                    {
                        $pixel = $tmp_img.GetPixel($i, $j);
                        
                        if($pixel -eq $color_blue)
                        {
                            $objTarget.SetPixel(($i + $iPosX), ($j + $iPosY), $color_gold)
                        }
                        elseif($pixel -eq $color_blue_1)
                        {
                            $objTarget.SetPixel(($i + $iPosX), ($j + $iPosY), $color_gold_1)
                        }
                        elseif($pixel -eq $color_blue_2)
                        {
                            $objTarget.SetPixel(($i + $iPosX), ($j + $iPosY), $color_gold_1)
                        }
                        else
                        {
                            $objTarget.SetPixel(($i + $iPosX), ($j + $iPosY), $tmp_img.GetPixel($i, $j))
                        }
                    }
                    default
                    {
                        $objTarget.SetPixel(($i + $iPosX), ($j + $iPosY), $tmp_img.GetPixel($i, $j))
                    }
                }
            }
        }
    }
    
}

function buildWindow($iSizeX, $iSizeY, $iPosX, $iPosY, $strWindow)
{
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
    
    Write-Host "Building window $strWindow"
    
    #$global:windowOpen = !$global:windowOpen;
    $global:windowOpen = $True;
    $global:strCurrentWindow = $strWindow;
    
    if(!$global:windowOpen)
    {
        Write-Host "Window is hidden now"
        $objForm.Refresh();
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
    
    # lets first create a outline
    for($i = 0; $i -lt $iSizeX; $i++)
    {
        $tmp_wnd.SetPixel($i, 0, "Black")
        $tmp_wnd.SetPixel($i, ($iSizeY - 1), "Black")
    }
    
    for($i = 0; $i -lt $iSizeY; $i++)
    {
        $tmp_wnd.SetPixel(0, $i, "Black")
        $tmp_wnd.SetPixel(($iSizeX - 1), $i, "Black")
    }
    
    # draw back
    $offset_x_l     = 1 + 6;
    $offset_x_r     = $iSizeX - 1 - 6;
    
    $offset_y_l     = 1 + 6;
    $offset_y_r     = $iSizeY - 1 - 6;
    
    for($i = ($offset_x_l); $i -lt ($offset_x_r); $i++)
    {
        for($j = ($offset_y_l); $j -lt ($offset_y_r); $j++)
        {
            $posx = $i - [math]::floor($i / 64) * 64;
            $posy = $j - [math]::floor($j / 64) * 64;
            
            $tmp_wnd.SetPixel($i, $j, $tex_MENU_TEX_BACK.GetPixel($posx, $posy));
        }
    }
    
    # draw sides (vert)
    $offset_x       = 1 + 8;
    $offsetmax_x    = $iSizeX - 1 - 8;
    $offset_y       = $iSizey - 1 - 6;
    #$offsetmax_y    = 1 + 6;
    for($i = $offset_x; $i -lt $offsetmax_x; $i++)
    {
        for($j = 0; $j -lt 6; $j++)
        {
            $posx = $i - [math]::floor($i / 14) * 14;
            # top
            $tmp_wnd.SetPixel($i, ($j + 1), $tex_MENU_SIDE_VERT.GetPixel($posx, (5 - $j)));
            # bottom
            $tmp_wnd.SetPixel($i, ($j + $offset_y), $tex_MENU_SIDE_VERT.GetPixel($posx, $j));
        }
    }
    
    # draw sides (hor)
    $offset_x       = 1;
    $offset_y       = 1 + 6;
    $offsetmax_y    = $iSizeY - 1 - 6;
    #$offsetmax_y    = 1 + 6;
    for($i = 0; $i -lt 6; $i++)
    {
        for($j = $offset_y; $j -lt $offsetmax_y; $j++)
        {
            $posy = $j - [math]::floor($j / 14) * 14;
            # left
            $tmp_wnd.SetPixel(($i + $offset_x), $j, $tex_MENU_SIDE_HOR.GetPixel($i, $posy));
            # right
            $tmp_wnd.SetPixel(($iSizeX - $offset_x - $i - 1), $j, $tex_MENU_SIDE_HOR.GetPixel($i, $posy));
        }
    }
    
    # draw corners
    $offset_x = 1;
    $offset_y = 1;
    for($i = 0; $i -lt 8; $i++)
    {
        for($j = 0; $j -lt 8; $j++)
        {
            $tmp_wnd.SetPixel(($offset_x + $i), ($offset_y + $j), $tex_MENU_CORNER.GetPixel($i, $j));
        }
    }
    
    $offset_x = 1;
    $offset_y = $iSizeY - 1 - 8;
    for($i = 0; $i -lt 8; $i++)
    {
        for($j = 0; $j -lt 8; $j++)
        {
            $tmp_wnd.SetPixel(($offset_x + $i), ($offset_y + $j), $tex_MENU_CORNER.GetPixel($i, $j));
        }
    }
    
    $offset_x = $iSizeX - 1 - 8;
    $offset_y = 1;
    for($i = 0; $i -lt 8; $i++)
    {
        for($j = 0; $j -lt 8; $j++)
        {
            $tmp_wnd.SetPixel(($offset_x + $i), ($offset_y + $j), $tex_MENU_CORNER.GetPixel($i, $j));
        }
    }
    
    $offset_x = $iSizeX - 1 - 8;
    $offset_y = $iSizeY - 1 - 8;
    for($i = 0; $i -lt 8; $i++)
    {
        for($j = 0; $j -lt 8; $j++)
        {
            $tmp_wnd.SetPixel(($offset_x + $i), ($offset_y + $j), $tex_MENU_CORNER.GetPixel($i, $j));
        }
    }
    
    Write-Host "Adding arrays for window $strWindow"
    
    $global:arrWindows[$strWindow] = @{}
    #$global:arrWindows[$strWindow].btn = @{}
    $global:arrWindows[$strWindow].wnd = $tmp_wnd;
    $global:arrWindows[$strWindow].loc_x = $iPosX;
    $global:arrWindows[$strWindow].loc_y = $iPosY;
    $objForm.Refresh();
    #addSpriteAt $tmp_wnd $iPosX $iPosY
}

function scaleGame($scaleUp)
{
    if($scaleUp)
    {
        if($global:iSize -lt 3)
        {
            $pictureBox.Scale(2.0);
            $global:iSize+=1;
            $objForm.minimumSize = New-Object System.Drawing.Size(([math]::pow(2, ($global:iSize -1 )) * $DrawingSizeX + 16), ([math]::pow(2, ($global:iSize -1 )) * $DrawingSizeY + 36)) 
            $objForm.maximumSize = New-Object System.Drawing.Size(([math]::pow(2, ($global:iSize -1 )) * $DrawingSizeX + 16), ([math]::pow(2, ($global:iSize -1 )) * $DrawingSizeY + 36)) 
        }
    }
    else
    {
        if($global:iSize -gt 1)
        {
            $pictureBox.Scale(0.5);
            $global:iSize-=1;
            $objForm.minimumSize = New-Object System.Drawing.Size(([math]::pow(2, ($global:iSize -1 )) * $DrawingSizeX + 16), ([math]::pow(2, ($global:iSize -1 )) * $DrawingSizeY + 36)) 
            $objForm.maximumSize = New-Object System.Drawing.Size(([math]::pow(2, ($global:iSize -1 )) * $DrawingSizeX + 16), ([math]::pow(2, ($global:iSize -1 )) * $DrawingSizeY + 36)) 
        }
    }
}

function onRedraw($Sender, $EventArgs)
{
    $EventArgs.Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor

	$rect = New-Object System.Drawing.Rectangle(0, 0, $pictureBox.Size.Width, $pictureBox.Size.Height)
    $EventArgs.Graphics.DrawImage($global:bitmap, $rect, 0, 0, $global:bitmap.Width, $global:bitmap.Height, [System.Drawing.GraphicsUnit]::Pixel)
    
    #$EventArgs.Graphics.DrawImage($bitmap, $rect, 0, 0, $bitmap.Width, $bitmap.Height, [System.Drawing.GraphicsUnit]::Pixel)
    if($global:windowOpen)
    {
        # Position des rects anpassen, fenster soll sich gleichermaßen verschieben
        $rect_wnd = New-Object System.Drawing.Rectangle(([math]::pow(2, ($global:iSize -1 )) * $global:arrWindows[$global:strCurrentWindow].loc_x), ([math]::pow(2, ($global:iSize -1 )) * $global:arrWindows[$global:strCurrentWindow].loc_y), ([math]::pow(2, ($global:iSize -1 )) * $global:arrWindows[$global:strCurrentWindow].wnd.Size.Width), ([math]::pow(2, ($global:iSize -1 )) * $global:arrWindows[$global:strCurrentWindow].wnd.Size.Height))
        #Write-Host "$rect_wnd"
        # und das fenster korrekt skaliert darstellen
        # links und oben fehlen iwie 1 pixel... oder der wird nicht skaliert? es ist komisch
        $EventArgs.Graphics.DrawImage($global:arrWindows[$global:strCurrentWindow].wnd, $rect_wnd, 0, 0, $global:arrWindows[$global:strCurrentWindow].wnd.Width, $global:arrWindows[$global:strCurrentWindow].wnd.Height, [System.Drawing.GraphicsUnit]::Pixel)
    }

}   

function showSplash()
{
    $global:bitmap = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathImageGFX + 'SCREEN_BACK_02.png'))));
    $pictureBox.Refresh();
}

function addSpriteAt($bmp, $x, $y)
{
    Write-Host "adding sprite"
    
	$img_x = $bmp.Size.Width;
	$img_y = $bmp.Size.Height;

	for($i = 0; $i -lt $img_x; $i++)
	{
		for($j = 0; $j -lt $img_y; $j++)
		{
			$color = $bmp.GetPixel($i, $j)
			if($color -ne $transparent)
			{
				$global:bitmap.SetPixel(($x + $i), ($y + $j), $color)
			}
		}
	}
    
    $pictureBox.Refresh();
}

function initGame()
{
    Write-Host "Init game"
    #$arrSounds["MAINTHEME"].PlayLooping();
    $global:bitmap = New-Object System.Drawing.Bitmap([System.Drawing.Image]::Fromfile((get-item ($strPathImageGFX + 'SCREEN_BACK_02.png'))));
}

initGame
$objForm.Refresh();

###Window Settings###
#$objForm.Topmost = $True
[void] $objForm.ShowDialog()