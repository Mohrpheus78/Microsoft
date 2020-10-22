# ****************************************************
# D. Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
# Install Windows Fileserver for FSLogix or Citrx UPM
# ****************************************************

<#
    .SYNOPSIS
        This script installs File Server Roles, creates folders and shares for FSLogix containers or Citrix UPM and defines quotas on a newly installed fileserver.
		
    .Description
	The script changes the CD/DVD drive letter, so that drive letter D: is free for the new data drive. If a data drive is already present the script will use it.
	The script will install all neccessary File Server roles, create the shares and defines the quotas. You can choose between FSLogix or Citrix UPM.
		
    .EXAMPLE
	DVD drive: For the new CD/DVD drive letter always use drive and colon, e.g. 'E:'
	Folders: If you want the FSLogix profiles to be places in the folder "D:\FSLogix" type D:\FSLogix without quotation marks as target folder, subfolders "Profiles" and "Office365" are created automatically
		 If you want the Citrix UPM profiles to be placed in "D:\Citrix\UPM" type D:\Citrix without quotation marks as target folder, subfolder "UPM" is created automatically
	Quotas: Define FSLogix quotas in GB, e.g. 10 or 20
		Define UPM quota in MB, e.g. 200

    .NOTES
	Unfortunately after installing the FS-Resource-Manager roles, the server needs a reboot, otherwise the Posh cmldlet doesn't work.
#>


# Install Windows Rolles and Features
IF (!(Get-WindowsFeature -Name FS-Fileserver).Installed) {
	Write-Verbose "Installing File Services" -Verbose
	Write-Output ""
	Install-WindowsFeature -Name "FS-Fileserver","FS-Data-Deduplication","FS-Resource-Manager","RSAT-FSRM-Mgmt" | Out-Null
	Copy-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\File Server Resource Manager.lnk" "$ENV:Public\Desktop"
	Write-Verbose "Server needs to reboot, launch script again after reboot" -Verbose
	Read-Host "Hit any key to restart server"
	Restart-Computer
	}
	
	
	# CD/DVD drive
	$DvdDrv = Get-WmiObject -Class Win32_Volume -Filter "DriveType=5"
	if ($DvdDrv -ne $null)
	{
		# Get current DVD drive letter
		$DvdDrvLetter = $DvdDrv | Select-Object -ExpandProperty DriveLetter
		Write-Verbose "Current CD/DVD drive is $DvdDrvLetter" -Verbose
		Write-Output ""
		
		if (!($DvdDrvLetter -eq "E:"))
		{
			# Check if drive D: is in use
			if ($DvdDrvLetter -eq "D:")
				{
				# Define drive letter for CD/DVD drive
				$NewDVDDrive = Read-Host -Prompt "Define a new drive letter for CD/DVD drive, so that FSLogix data drive can be set to drive D: (e.g. E:)"
				Write-Output ""
				}
			 
				# Check if new drive letter is in use
				if (!(Test-Path -Path $NewDVDDrive))
				{
				# Change CD/DVD drive
				$DvdDrv | Set-WmiInstance -Arguments @{DriveLetter="$NewDVDDrive"} | Out-Null
				Write-Verbose "CD/DVD drive letter changed to $NewDVDDrive" -Verbose
				Write-Output ""
				}
				else
				{
				 Write-Verbose "Error: Drive $NewDVDDrive is in use"
				 BREAK
				}
		}
	}
	else
		{
		Write-Verbose "Information: No CD/DVD drive available, no need to change the drive letter!" -Verbose
		Write-Output ""
		}
	
	
	# Create data drive
	#Check if data drive D: is present
	IF (!([System.IO.DriveInfo]::GetDrives() | Where-Object {($_.DriveType -eq "Fixed") -and ($_.DriveFormat -eq "NTFS") -and ($_.Name -eq "D:\")}))
	{
		
	# Convert drive D: to GPT if an existing drive is present (MBR)
	IF (Get-Disk | Where-Object {$_.Partitionstyle -eq "mbr" -and $_.Number -eq "1"})
		{
		 Write-Verbose "Converting drive D: to GPT, formatting drive D:" -Verbose
		 Write-Output ""
		 Set-Disk -Number "1" -PartitionStyle GPT
		 Get-Disk | Where-Object {$_.Partitionstyle -eq "gpt" -and $_.Number -eq "1"} | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
		}
		
	# Formatting drive D: if an existing GPT drive is present
	IF (Get-Disk | Where-Object {$_.Partitionstyle -eq "gpt" -and $_.Number -eq "1"})
		{
		 Write-Verbose "Formatting drive D:" -Verbose
		 Write-Output ""
		 Get-Disk | Where-Object {$_.Partitionstyle -eq "gpt" -and $_.Number -eq "1"} | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
		}
		
	# Formatting drive D: if an unitialized drive is present
	IF (Get-Disk | Where-Object {$_.Partitionstyle -eq "raw" -and $_.Number -eq "1"})
		{
		 Write-Verbose "Initialize drive D: and formatting" -Verbose
		 Write-Output ""
		 Get-Disk | Where-Object {$_.Partitionstyle -eq "raw" -and $_.Number -eq "1"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
		}
		
	# Formatting drive D: if no drive is present
	IF (!([System.IO.DriveInfo]::GetDrives() | Where-Object {$_.DriveType -eq "Fixed" -and $_.Name -eq "D:\"}))
	{
		IF (!(Get-Disk | Where-Object Partitionstyle -eq "raw"))
			{
			 Write-Verbose "Please attach a new virtual disk drive to the VM, for use as data drive" -Verbose
			 Write-Output ""
			 Read-Host -Prompt "Hit any key to continue, after attaching the drive..."
			 Write-Output ""
			 Sleep -s 5
			 Write-Verbose "Initialize drive D: and formatting" -Verbose
			 Write-Output ""
			 Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
			 Write-Verbose "Drive D: is ready" -Verbose
			 Write-Output ""
			}
	}
	}
	
	# FSLogix or Citrix UPM?
	Write-Verbose "Do you want to prepare the server for FSLogix (F) or Citrix UPM (C)?" -Verbose
	Write-Output ""
	$Selection = Read-Host "( F / C )"
	Write-Output ""
	IF ($Selection -eq "F")
	{
	# FSLogix FRXContext
	copy-item "$PSScriptRoot\frxcontext" "${ENV:ProgramFiles(x86)}\FSLogix\frxcontext" -Recurse -Force -EA SilentlyContinue
	Start-Process -FilePath "${ENV:ProgramFiles(x86)}\FSLogix\frxcontext\frxcontext.exe" -ArgumentList "--install" | Out-Null
	Write-Verbose "FSLogix context menu (frxcontext) successfully installed" -Verbose
	Write-Output ""
	
	# Create FSLogix folders
	$FSLFolder = Read-Host -Prompt "Define FSLogix folder for profiles and office containers without quotation marks (e.g. D:\FSLogix), subfolders are created automatically"
	Write-Output ""
	IF (!(Test-Path -Path "$FSLFolder"))
	{
		Write-Verbose "Creating FSLogix folders" -Verbose
		Write-Output ""
		$(
		New-Item -Path "$FSLFolder" -ItemType Directory
		icacls "$FSLFolder" /inheritance:d
		icacls "$FSLFolder" /remove:g "*S-1-1-0"
		New-SMBShare -Name FSLogix$ -Path "$FSLFolder" -FullAccess Everyone -CachingMode None -EA SilentlyContinue
		New-SMBShare -Name FSLogix$ -Path "$FSLFolder" -FullAccess Jeder -CachingMode None -EA SilentlyContinue
		New-Item -Path "$FSLFolder\Profiles" -ItemType Directory
		icacls "$FSLFolder\Profiles" /inheritance:d
		icacls "$FSLFolder\Profiles" /remove:g "*S-1-5-32-545"
		icacls "$FSLFolder\Profiles" /grant "*S-1-5-11:M"
		New-Item -Path "$FSLFolder\Office365" -ItemType Directory
		icacls "$FSLFolder\Office365" /inheritance:d
		icacls "$FSLFolder\Office365" /remove:g "*S-1-5-32-545"
		icacls "$FSLFolder\Office365" /grant "*S-1-5-11:M"
		) | Out-Null
		Write-Verbose "FSLogix folders successfully created" -Verbose
		Write-Output ""
	}
	
	# Define FSLogix quotas for File Server Ressource Manager
	Write-Verbose "Creating quotas for File Server Ressource Manager" -Verbose
	Write-Output ""
	# FSLogix Profile Disks
	$ProfileQuota = Read-Host -Prompt "Define quota for the profile disks in GB"
	$O365Quota = Read-Host -Prompt "Define quota for the profile disks in GB"
	
	$(
	$Action1 = New-FsrmAction -Type Event -EventType Warning -Body "User [Source Io Owner] has exceeded the [Quota Threshold]% quota threshold for the quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB, and [Quota Used MB] MB currently is in use ([Quota Used Percent]% of limit)." -RunLimitInterval 180
	$Action2 = New-FsrmAction -Type Report -ReportTypes QuotaUsage -RunLimitInterval 180
	$Action_array = @($Action1,$Action2)
	$Threshold = New-FsrmQuotaThreshold -Percentage 90 -Action $Action_array
	New-FsrmQuotaTemplate -Name "FSLogix Profile Disks" -Size ([int64]($ProfileQuota) * [int64]1GB) -SoftLimit -Threshold $Threshold
	New-FsrmQuota -Path "$FSLFolder\Profiles" -Template "FSLogix Profile Disks"
	
	# FSLogix Office 365 Disk
	$Action1 = New-FsrmAction -Type Event -EventType Warning -Body "User [Source Io Owner] has exceeded the [Quota Threshold]% quota threshold for the quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB, and [Quota Used MB] MB currently is in use ([Quota Used Percent]% of limit)." -RunLimitInterval 180
	$Action2 = New-FsrmAction -Type Report -ReportTypes QuotaUsage -RunLimitInterval 180
	$Action_array = @($Action1,$Action2)
	$Threshold = New-FsrmQuotaThreshold -Percentage 90 -Action $Action_array
	New-FsrmQuotaTemplate -Name "FSLogix Office365 Disks" -Size ([int64]($O365Quota) * [int64]1GB) -SoftLimit -Threshold $Threshold
	New-FsrmQuota -Path "$FSLFolder\Office365" -Template "FSLogix Office365 Disks"
	) | Out-Null
	Write-Verbose "Quotas for FSLogix successfully created (Eventlog and report)" -Verbose
	Write-Output ""
	}
	
	Else
	{
	# Create Citrix UPM folders
	$CitrixFolder = Read-Host -Prompt "Define Citrix UPM folder for profiles without quotation marks (e.g. D:\Citrix), subfolder UPM gets created automatically"
	Write-Output ""
	IF (!(Test-Path -Path "$CitrixFolder"))
	{
		Write-Verbose "Creating Citrix UPM folder" -Verbose
		Write-Output ""
		$(
		New-Item -Path "$CitrixFolder" -ItemType Directory
		icacls "$CitrixFolder" /inheritance:d
		icacls "$CitrixFolder" /remove:g "*S-1-1-0"
		New-SMBShare -Name FSLogix$ -Path "$CitrixFolder" -FullAccess Everyone -CachingMode None -EA SilentlyContinue
		New-SMBShare -Name FSLogix$ -Path "$CitrixFolder" -FullAccess Jeder -CachingMode None -EA SilentlyContinue
		New-Item -Path "$CitrixFolder\Profiles" -ItemType Directory
		icacls "$CitrixFolder\Profiles" /inheritance:d
		icacls "$CitrixFolder\Profiles" /remove:g "*S-1-5-32-545"
		icacls "$CitrixFolder\Profiles" /grant "*S-1-5-11:(RD,RC,AD,RA,REA)"
		) | Out-Null
		Write-Verbose "Citrix UPM folder successfully created" -Verbose
		Write-Output ""
	}
	
	# Define Citrix UPM quotas for File Server Ressource Manager
	Write-Verbose "Creating quotas for File Server Ressource Manager" -Verbose
	Write-Output ""
	# Citrix UPM profiles
	$ProfileQuota = Read-Host -Prompt "Define quota for the UPM profiles in MB"
	$(
	$Action1 = New-FsrmAction -Type Event -EventType Warning -Body "User [Source Io Owner] has exceeded the [Quota Threshold]% quota threshold for the quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB, and [Quota Used MB] MB currently is in use ([Quota Used Percent]% of limit)." -RunLimitInterval 180
	$Action2 = New-FsrmAction -Type Report -ReportTypes QuotaUsage -RunLimitInterval 180
	$Action_array = @($Action1,$Action2)
	$Threshold = New-FsrmQuotaThreshold -Percentage 90 -Action $Action_array
	New-FsrmQuotaTemplate -Name "Citrix UPM profiles" -Size ([int64]($ProfileQuota) * [int64]1024KB) -SoftLimit -Threshold $Threshold
	New-FsrmQuota -Path "$CitrixFolder\Profiles" -Template "Citrix UPM profiles"
	) | Out-Null
	Write-Verbose "Quota for Citrix UPM successfully created (Eventlog and report)" -Verbose
	Write-Output ""
	}
	
	# End of script
	Write-Verbose "End of script!"  -Verbose
