# Advanced Usage Guide

This guide covers advanced scenarios and best practices for using the VMware CIS VM Hardening Tool in enterprise environments.

## 🏢 Enterprise Deployment Scenarios

### Scenario 1: Large-Scale Production Hardening

```powershell
# 1. Create configuration file for production environment
$productionConfig = @{
    VMs = @(
        @{ Name = "WEB-PROD-01"; vCenter = "vcenter-prod.company.com"; Environment = "Production" }
        @{ Name = "WEB-PROD-02"; vCenter = "vcenter-prod.company.com"; Environment = "Production" }
        @{ Name = "DB-PROD-01"; vCenter = "vcenter-prod.company.com"; Environment = "Production" }
        @{ Name = "APP-PROD-01"; vCenter = "vcenter-prod.company.com"; Environment = "Production" }
    )
    Settings = @{
        Backup = $true
        LogPath = "C:\Logs\CIS-Hardening\production-$(Get-Date -Format 'yyyyMMdd').log"
    }
} | ConvertTo-Json -Depth 3

$productionConfig | Out-File "config\production.json"

# 2. Preview changes first
.\scripts\bulk-config-hardening.ps1 -ConfigPath "config\production.json" -Environment "Production" -WhatIf

# 3. Apply hardening during maintenance window
.\scripts\bulk-config-hardening.ps1 -ConfigPath "config\production.json" -Environment "Production"

# 4. Generate compliance report
.\scripts\compliance-report.ps1 -vCenter "vcenter-prod.company.com" -OutputFormat HTML -OutputPath "C:\Reports\prod-compliance.html"
```

### Scenario 2: Multi-vCenter Environment

```powershell
# Configuration for multiple vCenter servers
$multiVCenterConfig = @{
    VMs = @(
        @{ Name = "VM-Site1-01"; vCenter = "vcenter1.company.com"; Environment = "Production" }
        @{ Name = "VM-Site1-02"; vCenter = "vcenter1.company.com"; Environment = "Production" }
        @{ Name = "VM-Site2-01"; vCenter = "vcenter2.company.com"; Environment = "Production" }
        @{ Name = "VM-Site2-02"; vCenter = "vcenter2.company.com"; Environment = "Production" }
    )
    Settings = @{
        Backup = $true
        LogPath = "C:\Logs\CIS-Hardening\multi-site-$(Get-Date -Format 'yyyyMMdd').log"
    }
} | ConvertTo-Json -Depth 3

$multiVCenterConfig | Out-File "config\multi-site.json"

# Process all sites
.\scripts\bulk-config-hardening.ps1 -ConfigPath "config\multi-site.json" -Environment "Production"
```

### Scenario 3: Development Environment Testing

```powershell
# Safe testing in development
$devConfig = @{
    VMs = @(
        @{ Name = "DEV-WEB-01"; vCenter = "vcenter-dev.company.com"; Environment = "Development" }
        @{ Name = "DEV-DB-01"; vCenter = "vcenter-dev.company.com"; Environment = "Development" }
    )
    Settings = @{
        Backup = $true
        LogPath = "C:\Logs\CIS-Hardening\dev-testing.log"
    }
} | ConvertTo-Json -Depth 3

$devConfig | Out-File "config\development.json"

# Test with WhatIf first
.\scripts\bulk-config-hardening.ps1 -ConfigPath "config\development.json" -Environment "Development" -WhatIf

# Apply to development VMs
.\scripts\bulk-config-hardening.ps1 -ConfigPath "config\development.json" -Environment "Development"
```

## 🔧 Advanced Configuration Options

### Custom Hardening Parameters

Create a custom hardening profile by modifying the script:

```powershell
# Custom hardening parameters for high-security environments
$customHardeningParams = @"
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
log.keepOld 30
log.rotateSize 4096000
mks.enable3d FALSE
RemoteDisplay.maxConnections 1
RemoteDisplay.vnc.enabled FALSE
tools.guest.desktop.autolock TRUE
tools.guestlib.enableHostInfo FALSE
tools.setInfo.sizeLimit 1048576
devices.hotplug FALSE
isolation.monitor.control.disable TRUE
isolation.tools.autoInstall.disable TRUE
isolation.tools.ghi.trayicon.disable TRUE
"@ -split "`r?`n"
```

### Environment-Specific Settings

```powershell
# Different settings for different environments
function Get-EnvironmentSpecificSettings {
    param([string]$Environment)
    
    switch ($Environment) {
        "Production" {
            return @{
                "log.keepOld" = "30"
                "log.rotateSize" = "4096000"
                "RemoteDisplay.maxConnections" = "1"
                "RemoteDisplay.vnc.enabled" = "FALSE"
            }
        }
        "Development" {
            return @{
                "log.keepOld" = "10"
                "log.rotateSize" = "2048000"
                "RemoteDisplay.maxConnections" = "2"
                "RemoteDisplay.vnc.enabled" = "TRUE"
            }
        }
        "Test" {
            return @{
                "log.keepOld" = "5"
                "log.rotateSize" = "1024000"
                "RemoteDisplay.maxConnections" = "3"
                "RemoteDisplay.vnc.enabled" = "TRUE"
            }
        }
    }
}
```

## 📊 Monitoring and Reporting

### Automated Compliance Monitoring

```powershell
# Daily compliance check script
$monitoringScript = @'
# Daily CIS Compliance Check
$vCenters = @("vcenter1.company.com", "vcenter2.company.com")
$reportPath = "C:\Reports\Daily-Compliance"

if (-not (Test-Path $reportPath)) {
    New-Item -Path $reportPath -ItemType Directory -Force
}

foreach ($vCenter in $vCenters) {
    $timestamp = Get-Date -Format "yyyyMMdd"
    $outputFile = "$reportPath\$($vCenter.Split('.')[0])_compliance_$timestamp.html"
    
    .\scripts\compliance-report.ps1 -vCenter $vCenter -OutputFormat HTML -OutputPath $outputFile
    
    # Send email notification if compliance is below threshold
    $report = Get-Content $outputFile -Raw
    if ($report -match "Average Compliance.*?(\d+\.?\d*)%") {
        $compliance = [double]$matches[1]
        if ($compliance -lt 90) {
            # Send alert email (implement your email logic here)
            Write-Warning "Compliance below threshold for $vCenter : $compliance%"
        }
    }
}
'@

$monitoringScript | Out-File "scripts\daily-compliance-check.ps1"
```

### Integration with SIEM/Monitoring Tools

```powershell
# Export compliance data for SIEM integration
function Export-ComplianceForSIEM {
    param(
        [string]$vCenter,
        [string]$SyslogServer,
        [int]$SyslogPort = 514
    )
    
    # Generate compliance report in JSON format
    $reportPath = "$env:TEMP\compliance_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    .\scripts\compliance-report.ps1 -vCenter $vCenter -OutputFormat JSON -OutputPath $reportPath
    
    # Parse and send to SIEM
    $complianceData = Get-Content $reportPath | ConvertFrom-Json
    
    foreach ($vm in $complianceData) {
        $syslogMessage = @{
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            source = "VMware-CIS-Hardening"
            severity = if ($vm.CompliancePercentage -lt 80) { "HIGH" } else { "INFO" }
            vm_name = $vm.VMName
            vcenter = $vm.vCenter
            compliance_percentage = $vm.CompliancePercentage
            failed_checks = $vm.FailedChecks
        } | ConvertTo-Json -Compress
        
        # Send to syslog server (implement your syslog client here)
        Write-Host "SIEM Log: $syslogMessage"
    }
}
```

## 🔄 Automation and Scheduling

### PowerShell Scheduled Task

```powershell
# Create scheduled task for weekly compliance checks
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Scripts\vmware-cis-vm\scripts\daily-compliance-check.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2AM
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName "VMware CIS Compliance Check" -Action $action -Trigger $trigger -Settings $settings -Description "Weekly VMware CIS compliance monitoring"
```

### Integration with CI/CD Pipeline

```yaml
# Azure DevOps Pipeline example
trigger:
  branches:
    include:
    - main
  paths:
    include:
    - infrastructure/vmware/*

stages:
- stage: VMwareCompliance
  displayName: 'VMware CIS Compliance'
  jobs:
  - job: ComplianceCheck
    displayName: 'Run CIS Compliance Check'
    pool:
      vmImage: 'windows-latest'
    steps:
    - task: PowerShell@2
      displayName: 'Install PowerCLI'
      inputs:
        script: |
          Install-Module -Name VMware.PowerCLI -Force -Scope CurrentUser
          
    - task: PowerShell@2
      displayName: 'Run Compliance Report'
      inputs:
        script: |
          .\scripts\compliance-report.ps1 -vCenter "$(VCENTER_SERVER)" -OutputFormat JSON -OutputPath "compliance-report.json"
          
    - task: PublishTestResults@2
      displayName: 'Publish Compliance Results'
      inputs:
        testResultsFormat: 'JUnit'
        testResultsFiles: 'compliance-report.json'
```

## 🛡️ Security Best Practices

### Credential Management

```powershell
# Secure credential storage
$secureCredential = Get-Credential -Message "Enter vCenter credentials"
$secureCredential | Export-Clixml -Path "$env:USERPROFILE\.vmware\vcenter-creds.xml"

# Use stored credentials
$credential = Import-Clixml -Path "$env:USERPROFILE\.vmware\vcenter-creds.xml"
.\apply-cis-vm-hardening.ps1 -vCenter "vcenter.company.com" -VMName "MyVM" -Credential $credential
```

### Audit Trail

```powershell
# Enhanced logging with audit trail
function Write-AuditLog {
    param(
        [string]$Action,
        [string]$VMName,
        [string]$User,
        [string]$Details
    )
    
    $auditEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Action = $Action
        VMName = $VMName
        User = $User
        Details = $Details
        ComputerName = $env:COMPUTERNAME
    } | ConvertTo-Json -Compress
    
    Add-Content -Path "C:\Logs\vmware-cis-audit.log" -Value $auditEntry
}

# Usage in hardening script
Write-AuditLog -Action "CIS_HARDENING_APPLIED" -VMName $VMName -User $env:USERNAME -Details "All CIS parameters applied successfully"
```

## 🔍 Troubleshooting Advanced Scenarios

### Performance Impact Analysis

```powershell
# Monitor performance impact of hardening
function Test-HardeningPerformanceImpact {
    param([string]$VMName, [string]$vCenter)
    
    # Get baseline performance metrics
    $vm = Get-VM -Name $VMName
    $beforeStats = Get-Stat -Entity $vm -Stat "cpu.usage.average","mem.usage.average" -Start (Get-Date).AddHours(-1)
    
    # Apply hardening
    .\apply-cis-vm-hardening.ps1 -vCenter $vCenter -VMName $VMName
    
    # Wait and collect post-hardening metrics
    Start-Sleep -Seconds 300
    $afterStats = Get-Stat -Entity $vm -Stat "cpu.usage.average","mem.usage.average" -Start (Get-Date).AddMinutes(-5)
    
    # Compare metrics
    Write-Host "Performance Impact Analysis for $VMName" -ForegroundColor Cyan
    Write-Host "CPU Usage - Before: $($beforeStats | Where-Object {$_.MetricId -eq 'cpu.usage.average'} | Measure-Object Value -Average | Select-Object -ExpandProperty Average)" -ForegroundColor Yellow
    Write-Host "CPU Usage - After: $($afterStats | Where-Object {$_.MetricId -eq 'cpu.usage.average'} | Measure-Object Value -Average | Select-Object -ExpandProperty Average)" -ForegroundColor Yellow
}
```

### Rollback Procedures

```powershell
# Automated rollback function
function Restore-VMConfiguration {
    param(
        [string]$VMName,
        [string]$vCenter,
        [string]$BackupPath
    )
    
    if (-not (Test-Path $BackupPath)) {
        Write-Error "Backup file not found: $BackupPath"
        return
    }
    
    Connect-VIServer -Server $vCenter
    $vm = Get-VM -Name $VMName
    $backupConfig = Get-Content $BackupPath | ConvertFrom-Json
    
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    
    foreach ($setting in $backupConfig) {
        $opt = New-Object VMware.Vim.OptionValue
        $opt.Key = $setting.Key
        $opt.Value = $setting.Value
        $spec.ExtraConfig += $opt
    }
    
    $vm.ExtensionData.ReconfigVM($spec)
    Write-Host "Configuration restored from backup: $BackupPath" -ForegroundColor Green
}
```

This advanced usage guide provides comprehensive examples for enterprise deployment scenarios, monitoring, automation, and troubleshooting of the VMware CIS VM Hardening Tool.