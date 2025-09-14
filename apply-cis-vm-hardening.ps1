<#
.SYNOPSIS
  CIS Hardening for vSphere Virtual Machines

.DESCRIPTION
  This PowerShell script applies VMware vSphere VM hardening parameters
  recommended by the Center for Internet Security (CIS).
  Fully compatible with PowerCLI 13+.

.PARAMETER vCenter
  The FQDN or IP of the vCenter Server to connect to.

.PARAMETER VMName
  The name of the Virtual Machine to which CIS hardening parameters should be applied.

.EXAMPLE
  .\apply-cis-vm-hardening.ps1 -vCenter "vcsa.lab.local" -VMName "Test-VM01"

.NOTES
  Author: VMware Security Team
  Version: 1.0.0
  Requirements:
    - VMware PowerCLI 13+ installed
    - Permissions to modify VM advanced settings
    - vCenter Server access
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$vCenter,

    [Parameter(Mandatory = $true)]
    [string]$VMName,
    
    [Parameter(Mandatory = $false)]
    [PSCredential]$Credential,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$Backup,
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "$env:TEMP\vmware-cis-hardening.log"
)

# ============================================
#  VMware vSphere VM CIS Hardening Tool
#  Applies CIS security recommendations
# ============================================

# Configure PowerCLI
Write-Host "Configuring PowerCLI..." -ForegroundColor Cyan
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

# Setup logging
Start-Transcript -Path $LogPath -Append

# Connect to vCenter
Write-Host "Connecting to vCenter: $vCenter ..." -ForegroundColor Cyan
try {
    if ($Credential) {
        Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction Stop
    } else {
        Connect-VIServer -Server $vCenter -ErrorAction Stop
    }
    Write-Host "✅ Connected successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to vCenter: $_"
    Stop-Transcript
    exit 1
}

# Load VM
Write-Host "Loading VM: $VMName ..." -ForegroundColor Cyan
try {
    $vm = Get-VM -Name $VMName -ErrorAction Stop
    Write-Host "✅ VM found: $($vm.Name) (PowerState: $($vm.PowerState))" -ForegroundColor Green
}
catch {
    Write-Error "VM '$VMName' not found: $_"
    Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue
    Stop-Transcript
    exit 1
}

# Backup current configuration if requested
if ($Backup) {
    Write-Host "Creating configuration backup..." -ForegroundColor Cyan
    $backupPath = "$env:TEMP\$($vm.Name)_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $currentConfig = $vm.ExtensionData.Config.ExtraConfig | ConvertTo-Json
    $currentConfig | Out-File -FilePath $backupPath
    Write-Host "✅ Backup saved to: $backupPath" -ForegroundColor Green
}

# Hardening parameters
$hardeningParams = @"
EnableUUID TRUE
isolation.bios.bbs.disable TRUE
isolation.device.connectable.disable TRUE
isolation.device.edit.disable TRUE
isolation.ghi.host.shellAction.disable TRUE
isolation.tools.copy.disable TRUE
isolation.tools.diskShrink.disable TRUE
isolation.tools.diskWiper.disable TRUE
isolation.tools.dispTopoRequest.disable TRUE
isolation.tools.dnd.disable TRUE
isolation.tools.getCreds.disable TRUE
isolation.tools.ghi.autologon.disable TRUE
isolation.tools.ghi.launchmenu.change TRUE
isolation.tools.ghi.protocolhandler.info.disable TRUE
isolation.tools.ghi.trayicon.disable TRUE
isolation.tools.guestDnDVersionSet.disable TRUE
isolation.tools.memSchedFakeSampleStats.disable TRUE
isolation.tools.paste.disable TRUE
isolation.tools.setGUIOptions.enable FALSE
isolation.tools.trashFolderState.disable TRUE
isolation.tools.unity.disable TRUE
isolation.tools.unity.push.update.disable TRUE
isolation.tools.unity.taskbar.disable TRUE
isolation.tools.unity.windowContents.disable TRUE
isolation.tools.unityActive.disable TRUE
isolation.tools.unityInterlockOperation.disable TRUE
isolation.tools.vmxDnDVersionGet.disable TRUE
log.keepOld 10
log.rotateSize 2048000
mks.enable3d FALSE
RemoteDisplay.maxConnections 1
RemoteDisplay.vnc.enabled FALSE
tools.guest.desktop.autolock TRUE
tools.guestlib.enableHostInfo FALSE
tools.setInfo.sizeLimit 1048576
devices.hotplug FALSE
"@ -split "`r?`n"

# Apply parameters via ExtensionData.ReconfigVM
Write-Host "Applying hardening parameters..." -ForegroundColor Cyan
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec

foreach ($line in $hardeningParams) {
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        $cols = $line -split "\s+"
        $key = $cols[0]
        $value = $cols[1]

        $opt = New-Object VMware.Vim.OptionValue
        $opt.Key = $key
        $opt.Value = $value
        $spec.ExtraConfig += $opt

        Write-Host "Applying '$key' = '$value'"
    }
}

# Apply configuration to VM
if ($WhatIf) {
    Write-Host "🔍 WHATIF: Would apply the following settings:" -ForegroundColor Yellow
    foreach ($opt in $spec.ExtraConfig) {
        Write-Host "  $($opt.Key) = $($opt.Value)" -ForegroundColor Yellow
    }
    Write-Host "🔍 WHATIF: No changes were made" -ForegroundColor Yellow
} else {
    try {
        $vm.ExtensionData.ReconfigVM($spec)
        Write-Host "✅ Hardening applied successfully to VM '$VMName'." -ForegroundColor Green
        
        # Verify some key settings
        Write-Host "Verifying applied settings..." -ForegroundColor Cyan
        $updatedVM = Get-VM -Name $VMName
        $verifySettings = @("isolation.tools.copy.disable", "isolation.tools.paste.disable", "EnableUUID")
        foreach ($setting in $verifySettings) {
            $value = ($updatedVM.ExtensionData.Config.ExtraConfig | Where-Object {$_.Key -eq $setting}).Value
            if ($value) {
                Write-Host "✅ $setting = $value" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Error "Failed to apply hardening: $_"
        Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue
        Stop-Transcript
        exit 1
    }
}

# Cleanup
Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue
Stop-Transcript
Write-Host "📝 Log saved to: $LogPath" -ForegroundColor Cyan

# Optional: Disconnect from vCenter
#Disconnect-VIServer -Server $vCenter -Confirm:$false
