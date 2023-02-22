# ****************************************************
# D. Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
# Modify MS Teams VDI App
# ****************************************************

<#
    .SYNOPSIS
        Change Teams setting per user
		
    .Description
        Change the MS Teams VDI installer app settings, such as GPU acceleration or fully close Teams app 
		
    .EXAMPLE
	WEM:
	Path: powershell.exe
        Arguments: -executionpolicy bypass -file "C:\Program Files (x86)\SuL\Scripts\Teams User Settings.ps1"  
	    
    .NOTES
	Execute as WEM external task, logonscript or task at logon
	You can add setting 
#>

# Define settings
param(
# Enable or disable GPU acceleration
[boolean]$disableGpu=$True,
# Fully close Teams App
[boolean]$runningOnClose=$False,
# Current web language
[string]$currentWebLanguage="en-US"
)

## Get Teams Configuration and Convert file content from JSON format to PowerShell object
$JSONObject=Get-Content -Raw -Path "$ENV:APPDATA\Microsoft\Teams\desktop-config.json" | ConvertFrom-Json
## Define Cookies and Cookies-journal 
##Some settings eg "Application language" wouldn't work unless these are deleted
$cookiesFile = "$ENV:APPDATA\Microsoft\Teams\Cookies"
$cookiesJournal = "$ENV:APPDATA\Microsoft\Teams\Cookies-journal"

## Delete Cookies and Cookies-journal
if ([System.IO.File]::Exists($cookiesFile)) {
  Remove-Item $cookiesFile -Force
}

if ([System.IO.File]::Exists($cookiesJournal)) {
  Remove-Item $cookiesJournal -Force
}

# Update Object settings
$JSONObject.appPreferenceSettings.disableGpu=$disableGpu
$JSONObject.appPreferenceSettings.runningOnClose=$runningOnClose
$JSONObject.currentWebLanguage=$currentWebLanguage
$NewFileContent=$JSONObject | ConvertTo-Json

# Update configuration in file
$NewFileContent | Set-Content -Path "$ENV:APPDATA\Microsoft\Teams\desktop-config.json" 
