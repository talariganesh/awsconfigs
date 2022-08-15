<powershell>

echo "Start of user data output"
Set-PSDebug -Trace 1

Start-Transcript -Path "C:\UserData.log" -Append

# Create a file on boot to timestamp the instance launch
$file = $env:SystemRoot + "\Temp\FirstBoot_" + (Get-Date).ToString("yyyy-MM-dd-hh-mm")
New-Item $file -ItemType file

# Example to install Windows Server features (this would enable AD management from this server)
#Install-WindowsFeature -Name ADLDS,GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server

# Change Execution Policy for this process to run the script.
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Install the required packages.
Install-Module -Name AuditPolicyDsc -Force
Install-Module -Name SecurityPolicyDsc -Force
Install-Module -Name NetworkingDsc -Force

# create folder for userdata scripts
$userscripts = "C:\scripts\"
if (Test-Path $userscripts) { 
	Write-Host "Folder Exists" 
	}
else{
	New-Item $userscripts -ItemType Directory
	}
	
# Download and install CIS benchmarks from zscaler github repo
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Cloudneeti/os-harderning-scripts/master/WindowsServer2019/CIS_Benchmark_WindowsServer2019_v100.ps1" -OutFile "$userscripts\CIS_Benchmark_WindowsServer2019_v100.ps1"
Set-Location -Path $userscripts
.\CIS_Benchmark_WindowsServer2019_v100.ps1
Start-DscConfiguration -Path "$userscripts\CIS_Benchmark_WindowsServer2019_v100"  -Force -Verbose -Wait

# Function to check pending reboot.
function Check-PendingReboot {
    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
    try { 
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if (($status -ne $null) -and $status.RebootPending) {
            return $true
        }
    }
    catch { }

    return $false
}

# Change Execution Policy for this process to run the script.
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force

# Install the required packages.
Install-PackageProvider -Name NuGet -Force
Install-Module -Name PSWindowsUpdate -Force

# Import the required module.
Import-Module PSWindowsUpdate

# Look for all updates, download, install and don't reboot yet.
Get-WindowsUpdate -AcceptAll -Download -Install -IgnoreReboot

# Check if a pending reboot is found, notify users if that is the case. If none found just close the session.
$reboot = Check-PendingReboot

if($reboot -eq $true){
   write-host("Pending reboot found. Reboot..")
   cmd /c "msg * "Windows update has finished downloading and needs to reboot to install the required updates. Rebooting in 5 minutes..""
   cmd /c "Shutdown /r /f /t 300"
   Exit
   
}
else {
   write-host("No Pending reboot. Shutting down PowerShell..")
   Exit
}

</powershell>