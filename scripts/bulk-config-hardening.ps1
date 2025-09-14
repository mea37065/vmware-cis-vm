<#
.SYNOPSIS
  Bulk CIS Hardening using configuration file

.DESCRIPTION
  Applies CIS hardening to multiple VMs based on JSON configuration file.
  Supports different environments and custom settings per VM.

.PARAMETER ConfigPath
  Path to JSON configuration file

.PARAMETER Environment
  Filter VMs by environment (Production, Development, Test)

.PARAMETER WhatIf
  Preview changes without applying them

.EXAMPLE
  .\bulk-config-hardening.ps1 -ConfigPath "config\production.json" -Environment "Production"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Production", "Development", "Test", "All")]
    [string]$Environment = "All",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$Parallel
)

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

$config = Get-Content $ConfigPath | ConvertFrom-Json
$scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "apply-cis-vm-hardening.ps1"

# Filter VMs by environment
$vmsToProcess = if ($Environment -eq "All") {
    $config.VMs
} else {
    $config.VMs | Where-Object { $_.Environment -eq $Environment }
}

Write-Host "Processing $($vmsToProcess.Count) VMs for environment: $Environment" -ForegroundColor Cyan

# Process VMs
$results = @()
foreach ($vm in $vmsToProcess) {
    $params = @{
        vCenter = $vm.vCenter
        VMName = $vm.Name
    }
    
    if ($WhatIf) { $params.WhatIf = $true }
    if ($config.Settings.Backup) { $params.Backup = $true }
    if ($config.Settings.LogPath) { $params.LogPath = $config.Settings.LogPath }
    
    try {
        Write-Host "Processing VM: $($vm.Name)" -ForegroundColor Yellow
        & $scriptPath @params
        $results += [PSCustomObject]@{
            VM = $vm.Name
            vCenter = $vm.vCenter
            Status = "Success"
            Error = $null
        }
    }
    catch {
        Write-Error "Failed to process VM $($vm.Name): $_"
        $results += [PSCustomObject]@{
            VM = $vm.Name
            vCenter = $vm.vCenter
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
}

# Summary report
Write-Host "`n=== SUMMARY REPORT ===" -ForegroundColor Green
$results | Format-Table -AutoSize
$successCount = ($results | Where-Object Status -eq "Success").Count
$failCount = ($results | Where-Object Status -eq "Failed").Count
Write-Host "Successful: $successCount | Failed: $failCount" -ForegroundColor Cyan