# ***************************************************************************************
# D. Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
# Install Windows Fileserver for FSLogix or Citrx UPM
# 04/10/20: Added Dedup, Added ReFS filesystem, install File Server Ressorce Manager only 
# with NTFS volume, added detection of already present NTFS volumes
# ***************************************************************************************

<#
.SYNOPSIS
This script installs File Server Roles, creates folders and shares for FSLogix containers or Citrix UPM and defines quotas on a newly installed fileserver.
Dedup is also activated if you like.
		
.DESCRIPTION
The script changes the CD/DVD drive letter, so that drive letter D: is free for the new data drive. If a data drive is already present the script will use it.
The script will install all neccessary File Server roles, create the shares and defines the quotas. You can choose between FSLogix or Citrix UPM and NTFS or ReFS file system
Data deduplication can also be activated (works great with UPM and FSLogix!)
		
.PARAMETER Platform
-Platform 'FSLogix' or 'CitrixUPM'

.PARAMETER DvdDriveLetter
-DvdDriveLetter 'E:' or any other letter except 'D:'

.PARAMETER FileSystem
-FileSystem 'NTFS' or 'REFS'

.PARAMETER Dedup
-Dedup 'true' or 'false'
	
.EXAMPLE
."Install and configure Fileserver.ps1" -Platform FSLogix -DvdDriveLetter E: -FileSystem NTFS -Dedup true
Folders: If you want the FSLogix profiles to be places in the folder "D:\FSLogix" type D:\FSLogix without quotation marks as target folder, subfolders "Profiles" and "Office365" are created automatically
		 If you want the Citrix UPM profiles to be placed in "D:\Citrix\UPM" type D:\Citrix without quotation marks as target folder, subfolder "UPM" is created automatically
Quotas: Define FSLogix quotas in GB, e.g. 10 or 20
		Define UPM quota in MB, e.g. 200
	
.NOTES
Requirements: Windows Server 2019 with or without data drive (Tested only with Windows Server 2019). Existing data drive can be used, new folders will bre created.
Quotas are only supported on NTFS volumes!
Unfortunately after installing the FS-Resource-Manager roles, the server needs a reboot, otherwise the Posh cmldlet doesn't work.
#>


[CmdletBinding()]

param
    (
        # For use with FSLogix containers or Citrix User Profile Manager
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String]$Platform,

        # New drive letter for DVD drive (Drive D: is required for profiles)
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String]$DvdDriveLetter,
		
		# Filesystem for FSLogix data disk
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String]$FileSystem,
		
		# Data deduplication
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String]$Dedup
    )

# Do you run the script as admin?
# ========================================================================================================================================
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

if ($myWindowsPrincipal.IsInRole($adminRole))
   {
    # OK, runs as admin
	Write-Verbose "OK, script is running with Admin rights" -Verbose
	Write-Output ""
   }

else
   {
    # Script doesn't run as admin, run new process object to execute PowerShell
    Write-Verbose "Error! Script is NOT running with Admin rights!" -Verbose
	BREAK
   }
# ========================================================================================================================================


# Variables (Everyone Group for the SMB share)
# ========================================================================================================================================
$s = 'S-1-1-0'
$sid = [wmi]"Win32_SID.SID='$s'"
# ========================================================================================================================================


# Break if Citrix UPM and ReFS selected together
# ========================================================================================================================================
IF (($FileSystem -eq "REFS") -and ($Platform -eq "CitrixUPM"))
	{
	 Write-Verbose "Error! You cannot choose Citrix UPM together with ReFS file system!" -Verbose
	 BREAK
	}


# Install Windows Rolles and Features
# ========================================================================================================================================
IF (!(Get-WindowsFeature -Name FS-Fileserver).Installed) {
	Write-Verbose "Installing File Services" -Verbose
	Write-Output ""
	Install-WindowsFeature -Name "FS-Fileserver","FS-Data-Deduplication" | Out-Null
	# Only install FSRM if file system is NTFS
	IF ($FileSystem -eq "NTFS")
		{
		 Install-WindowsFeature -Name "FS-Resource-Manager","RSAT-FSRM-Mgmt" | Out-Null
		 Copy-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\File Server Resource Manager.lnk" "$ENV:Public\Desktop"
		}
	Write-Verbose "Server needs to reboot, launch script again after reboot" -Verbose
	Read-Host "Hit any key to restart server"
	Restart-Computer
	}
# ========================================================================================================================================


# CD/DVD drive
# ========================================================================================================================================
if ($DvdDriveLetter -eq "D:")
{
	Write-Verbose "Error! You cannot choose drive $DvdDriveLetter! Drive D: is required for the data disk" -Verbose
	Write-Verbose "Choose another drive letter for your DVD drive and try run script again!" -Verbose
	BREAK
}

$DvdDrv = Get-WmiObject -Class Win32_Volume -Filter "DriveType=5"
if ($DvdDrv -ne $null)
{
	# Get current DVD drive letter
	$CurrentDvdDrvLetter = $DvdDrv | Select-Object -ExpandProperty DriveLetter
	Write-Verbose "Current CD/DVD drive is $CurrentDvdDrvLetter" -Verbose
	Write-Output ""
	
	if (!($CurrentDvdDrvLetter -eq "E:"))
	{
		# Check if new drive letter is in use
		if (!(Test-Path -Path $DvdDriveLetter))
		{
		# Change CD/DVD drive
		$DvdDrv | Set-WmiInstance -Arguments @{DriveLetter="$DvdDriveLetter"} | Out-Null
		Write-Verbose "CD/DVD drive letter changed to $DvdDriveLetter" -Verbose
		Write-Output ""
		}
		else
		{
		 Write-Verbose "Error: Drive $DvdDriveLetter is in use" -Verbose
		 BREAK
		}
	}
}
else
	{
	Write-Verbose "Information: No CD/DVD drive available, no need to change the drive letter!" -Verbose
	Write-Output ""
	}
# ========================================================================================================================================


# Create data drive
# ========================================================================================================================================
# Check if data drive D: is present and formated with NTFS (ReFS was selected)
IF (([System.IO.DriveInfo]::GetDrives() | Where-Object {($_.DriveType -eq "Fixed") -and ($_.DriveFormat -eq "NTFS") -and ($_.Name -eq "D:\")}) -and ($FileSystem -eq "REFS"))
	{	
	 Write-Output "Attention! A data drive D: was found! The drive is formatted with NTFS, you choosed ReFS file system. Do you want to format the drive with ReFS? (F) or do you want to keep the drive? (K)"
	 Write-Output ""
	 $Q = Read-Host "( F / K )"
	 IF ($Q -eq 'F')
		{
		 Get-Disk | Where-Object {$_.Partitionstyle -eq "mbr" -or $_.Partitionstyle -eq "gpt" -and $_.Number -eq "1"} | Clear-Disk -RemoveData -Confirm:$false | Out-Null
		 Get-Disk | Where-Object {$_.Partitionstyle -eq "raw" -and $_.Number -eq "1"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem REFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
		}
	}

# If no data drive D: is present 
IF (!([System.IO.DriveInfo]::GetDrives() | Where-Object {($_.DriveType -eq "Fixed") -and ($_.DriveFormat -eq "NTFS") -and ($_.Name -eq "D:\")}))
{
# Convert drive D: to GPT if an existing drive is present (MBR)
IF (Get-Disk | Where-Object {$_.Partitionstyle -eq "mbr" -and $_.Number -eq "1"})
{
	IF ($FileSystem -eq "NTFS")
		{
		 Write-Verbose "Found existing MBR drive! Converting drive D: to GPT, formatting drive D: with NTFS" -Verbose
		 Write-Output ""
		 Set-Disk -Number "1" -PartitionStyle GPT
		 Get-Disk | Where-Object {$_.Partitionstyle -eq "gpt" -and $_.Number -eq "1"} | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
		}
	IF ($FileSystem -eq "REFS")
		{
		 Write-Verbose "Found existing MBR drive! Converting drive D: to GPT, formatting drive D: with ReFS" -Verbose
		 Write-Output ""
		 Set-Disk -Number "1" -PartitionStyle GPT
		 Get-Disk | Where-Object {$_.Partitionstyle -eq "gpt" -and $_.Number -eq "1"} | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem ReFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
		}
}

# Formatting drive D: if an existing GPT drive is present and no partition is available
IF (Get-WmiObject -Class Win32_DiskDrive | Where-Object {$_.Partitions -eq "0"})
{
	IF (Get-Disk | Where-Object {$_.Partitionstyle -eq "gpt" -and $_.Number -eq "1"})
		{
		IF ($FileSystem -eq "NTFS")
			{
			 Write-Verbose "Found existing GPT drive! Formatting drive D: with NTFS" -Verbose
			 Write-Output ""
			 Get-Disk | Where-Object {$_.Partitionstyle -eq "gpt" -and $_.Number -eq "1"} | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
			}
		IF ($FileSystem -eq "REFS")
			{
			 Write-Verbose "Found existing GPT drive! Formatting drive D: with ReFS" -Verbose
			 Write-Output ""
			 Get-Disk | Where-Object {$_.Partitionstyle -eq "gpt" -and $_.Number -eq "1"} | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem REFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
			}
		}
}

# Formatting drive D: if an unitialized drive is present
IF (Get-Disk | Where-Object {$_.Partitionstyle -eq "raw" -and $_.Number -eq "1"})
	{
	IF ($FileSystem -eq "NTFS")
		{	
		 Write-Verbose "Found unitialized drive! Initialize drive D: and formatting with NTFS" -Verbose
		 Write-Output ""
		 Get-Disk | Where-Object {$_.Partitionstyle -eq "raw" -and $_.Number -eq "1"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
		}
	IF ($FileSystem -eq "REFS")
		{	
		 Write-Verbose "Found unitialized drive! Initialize drive D: and formatting with REFS" -Verbose
		 Write-Output ""
		 Get-Disk | Where-Object {$_.Partitionstyle -eq "raw" -and $_.Number -eq "1"} | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem REFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
		}
	}
		
# Formatting drive D: if no drive is present
IF (!([System.IO.DriveInfo]::GetDrives() | Where-Object {$_.DriveType -eq "Fixed" -and $_.Name -eq "D:\"}))
	{	
	IF ($FileSystem -eq "NTFS")
		{
		 IF (!(Get-Disk | Where-Object Partitionstyle -eq "raw"))
			{
			 Write-Verbose "Please attach a new virtual disk drive to the VM, for use as data drive" -Verbose
			 Write-Output ""
			 Read-Host -Prompt "Press enter to continue, after attaching the drive..."
			 Write-Output ""
			 Sleep -s 5
			 Write-Verbose "Initialize drive D: and formatting" -Verbose
			 Write-Output ""
			 Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
			 Write-Verbose "Drive D: is ready" -Verbose
			 Write-Output ""
			}
		}
	IF ($FileSystem -eq "REFS")
		{
		 IF (!(Get-Disk | Where-Object Partitionstyle -eq "raw"))
			{
			 Write-Verbose "Please attach a new virtual disk drive to the VM, for use as data drive" -Verbose
			 Write-Output ""
			 Read-Host -Prompt "Press enter to continue, after attaching the drive..."
			 Write-Output ""
			 Sleep -s 5
			 Write-Verbose "Initialize drive D: and formatting" -Verbose
			 Write-Output ""
			 Get-Disk | Where-Object partitionstyle -eq 'raw' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume -FileSystem REFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
			 Write-Verbose "Drive D: is ready" -Verbose
			 Write-Output ""
			}
		}
	}
}

# ========================================================================================================================================


# FSLogix
# ========================================================================================================================================
IF ($Platform -eq "FSLogix")
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
		New-SMBShare -Name FSLogix$ -Path "$FSLFolder" -FullAccess $sid.accountname -CachingMode None -EA SilentlyContinue
		New-Item -Path "$FSLFolder\Profiles" -ItemType Directory
		icacls "$FSLFolder\Profiles" /inheritance:d
		icacls "$FSLFolder\Profiles" /remove:g "*S-1-5-32-545"
		icacls "$FSLFolder\Profiles" /grant "*S-1-5-11:M"
		New-Item -Path "$FSLFolder\Office365" -ItemType Directory
		icacls "$FSLFolder\Office365" /inheritance:d
		icacls "$FSLFolder\Office365" /remove:g "*S-1-5-32-545"
		icacls "$FSLFolder\Office365" /grant "*S-1-5-11:M"
		) | Out-Null
		Write-Verbose "FSLogix folders and share successfully created with the appropriate rights" -Verbose
		Write-Output ""
	}
	
	# Define FSLogix quotas for File Server Ressource Manager
	IF ($FileSystem -eq "REFS")
		{
		Write-Verbose "Quotas are only supported on NTFS volumes!" -Verbose
		Write-Output ""
		}
	IF (($FileSystem -eq "NTFS") -or ([System.IO.DriveInfo]::GetDrives() | Where-Object {($_.DriveType -eq "Fixed") -and ($_.DriveFormat -eq "NTFS") -and ($_.Name -eq "D:\")}))
		{
		Write-Verbose "Creating quotas for File Server Ressource Manager" -Verbose
		Write-Output ""
		# FSLogix Profile Disks
		$ProfileQuota = Read-Host -Prompt "Define quota for the profile disks in GB and press enter"
		$O365Quota = Read-Host -Prompt "Define quota for the profile disks in GB and press enter"

		$(
		$Action1 = New-FsrmAction -Type Event -EventType Warning -Body "User [Source Io Owner] has exceeded the [Quota Threshold]% quota threshold for the quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB, and [Quota Used MB] MB currently is in use ([Quota Used Percent]% of limit)." -RunLimitInterval 180
		$Action2 = New-FsrmAction -Type Report -ReportTypes QuotaUsage -RunLimitInterval 180
		$Action_array = @($Action1,$Action2)
		$Threshold = New-FsrmQuotaThreshold -Percentage 90 -Action $Action_array
		New-FsrmQuotaTemplate -Name "FSLogix Profile Disks" -Size ([int64]($ProfileQuota) * [int64]1GB) -SoftLimit -Threshold $Threshold
		New-FsrmAutoQuota -Path "$FSLFolder\Profiles" -Template "FSLogix Profile Disks"

		# FSLogix Office 365 Disk
		$Action1 = New-FsrmAction -Type Event -EventType Warning -Body "User [Source Io Owner] has exceeded the [Quota Threshold]% quota threshold for the quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB, and [Quota Used MB] MB currently is in use ([Quota Used Percent]% of limit)." -RunLimitInterval 180
		$Action2 = New-FsrmAction -Type Report -ReportTypes QuotaUsage -RunLimitInterval 180
		$Action_array = @($Action1,$Action2)
		$Threshold = New-FsrmQuotaThreshold -Percentage 90 -Action $Action_array
		New-FsrmQuotaTemplate -Name "FSLogix Office365 Disks" -Size ([int64]($O365Quota) * [int64]1GB) -SoftLimit -Threshold $Threshold
		New-FsrmAutoQuota -Path "$FSLFolder\Office365" -Template "FSLogix Office365 Disks"
		) | Out-Null
		Write-Verbose "Quotas for FSLogix successfully created (Eventlog and report)" -Verbose
		Write-Output ""
		}
}
# ========================================================================================================================================


# Citrix UPM
# ========================================================================================================================================
IF ($Platform -eq "CitrixUPM")
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
		New-SMBShare -Name Citrix$ -Path "$CitrixFolder" -FullAccess $sid.accountname -CachingMode None -EA SilentlyContinue
		New-Item -Path "$CitrixFolder\Profiles" -ItemType Directory
		icacls "$CitrixFolder\Profiles" /inheritance:d
		icacls "$CitrixFolder\Profiles" /remove:g "*S-1-5-32-545"
		icacls "$CitrixFolder\Profiles" /grant "*S-1-5-11:(RD,RC,AD,RA,REA)"
		) | Out-Null
		Write-Verbose "Citrix UPM folder and share successfully created with the appropriate rights" -Verbose
		Write-Output ""
	}
	
	# Define Citrix UPM quotas for File Server Ressource Manager
	Write-Verbose "Creating quotas for File Server Ressource Manager" -Verbose
	Write-Output ""
	# Citrix UPM profiles
	$ProfileQuota = Read-Host -Prompt "Define quota for the UPM profiles in MB and press enter"
	$(
	$Action1 = New-FsrmAction -Type Event -EventType Warning -Body "User [Source Io Owner] has exceeded the [Quota Threshold]% quota threshold for the quota on [Quota Path] on server [Server]. The quota limit is [Quota Limit MB] MB, and [Quota Used MB] MB currently is in use ([Quota Used Percent]% of limit)." -RunLimitInterval 180
	$Action2 = New-FsrmAction -Type Report -ReportTypes QuotaUsage -RunLimitInterval 180
	$Action_array = @($Action1,$Action2)
	$Threshold = New-FsrmQuotaThreshold -Percentage 90 -Action $Action_array
	New-FsrmQuotaTemplate -Name "Citrix UPM profiles" -Size ([int64]($ProfileQuota) * [int64]1024KB) -SoftLimit -Threshold $Threshold
	New-FsrmAutoQuota -Path "$CitrixFolder\Profiles" -Template "Citrix UPM profiles"
	) | Out-Null
	Write-Verbose "Quota for Citrix UPM successfully created (Eventlog and report)" -Verbose
	Write-Output ""
}
# ========================================================================================================================================


# Configure Data deduplication
# ========================================================================================================================================
# Enable deduplication
IF ($Dedup -eq "true")
	{
	 Write-Verbose "Configuring data deduplication" -Verbose
	 Write-Output ""
	 Enable-DedupVolume -Volume D: -UsageType Default | Out-Null
	 New-DedupSchedule -Name ThroughputOptimization -Days Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday -Type Optimization -Start 00:00 -DurationHours 4 | Out-Null
	} 
# ========================================================================================================================================


# End of script
Write-Verbose "End of script!"  -Verbose