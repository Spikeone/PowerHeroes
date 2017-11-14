function writeMSG($msg)
{
    #Write-Host $msg
    [System.Windows.Forms.MessageBox]::Show($msg, "")
}