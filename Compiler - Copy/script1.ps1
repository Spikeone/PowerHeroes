. (".\Script2.ps1")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[System.Windows.Forms.MessageBox]::Show($msg, "Calling Script 2")
writeMSG "Hello World"