Configure Filesserver

You can use this script to create the profile folders, shares and quotas for your FSLogix or Citrix UPM profiles. The script also takes care of the permissions.
If you don't have a data drive the script will detect this and ask you to attach a new drive. The CDRom drive letter will be changed, so that the data drive gets the letter D:
If you choose FSLogix frxcontext will be installed, so you can mount the VHDX profile disks on your fileserver. 
You can select NTFS or ReFS filesystem. ReFS may be better for FSLogix if you use concurrent access but the quotas aren't supported on ReFS partitions. If you don't use concurrent user access with FSLogix you don't have advantages using ReFS file system.
Data deduplication can also be activated in the data volume, both Citrix UPM and FSLogix containers work great with data dedup. 
