<#
.SYNOPSIS
  CIS Compliance Report Generator

.DESCRIPTION
  Generates detailed compliance report for VMware VMs against CIS benchmarks.
  Checks current configuration and identifies non-compliant settings.

.PARAMETER vCenter
  vCenter Server FQDN or IP address

.PARAMETER VMName
  VM name to check (optional, checks all VMs if not specified)

.PARAMETER OutputFormat
  Report output format (HTML, JSON, CSV)

.PARAMETER OutputPath
  Path to save the report

.EXAMPLE
  .\compliance-report.ps1 -vCenter "vcenter.lab.local" -OutputFormat HTML -OutputPath "C:\Reports\compliance.html"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$vCenter,
    
    [Parameter(Mandatory = $false)]
    [string]$VMName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("HTML", "JSON", "CSV")]
    [string]$OutputFormat = "HTML",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [PSCredential]$Credential
)

# CIS Benchmark requirements
$cisRequirements = @{
    "EnableUUID" = "TRUE"
    "isolation.tools.copy.disable" = "TRUE"
    "isolation.tools.paste.disable" = "TRUE"
    "isolation.tools.dnd.disable" = "TRUE"
    "isolation.device.connectable.disable" = "TRUE"
    "isolation.device.edit.disable" = "TRUE"
    "RemoteDisplay.vnc.enabled" = "FALSE"
    "RemoteDisplay.maxConnections" = "1"
    "log.keepOld" = "10"
    "log.rotateSize" = "2048000"
    "devices.hotplug" = "FALSE"
    "isolation.tools.unity.disable" = "TRUE"
    "isolation.tools.getCreds.disable" = "TRUE"
    "tools.guestlib.enableHostInfo" = "FALSE"
}

# Connect to vCenter
Write-Host "Connecting to vCenter: $vCenter" -ForegroundColor Cyan
try {
    if ($Credential) {
        Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction Stop
    } else {
        Connect-VIServer -Server $vCenter -ErrorAction Stop
    }
} catch {
    Write-Error "Failed to connect to vCenter: $_"
    exit 1
}

# Get VMs to check
$vmsToCheck = if ($VMName) {
    Get-VM -Name $VMName -ErrorAction SilentlyContinue
} else {
    Get-VM
}

if (-not $vmsToCheck) {
    Write-Error "No VMs found to check"
    exit 1
}

Write-Host "Checking $($vmsToCheck.Count) VMs for CIS compliance..." -ForegroundColor Cyan

# Check compliance
$complianceResults = @()
foreach ($vm in $vmsToCheck) {
    Write-Host "Checking VM: $($vm.Name)" -ForegroundColor Yellow
    
    $vmCompliance = [PSCustomObject]@{
        VMName = $vm.Name
        PowerState = $vm.PowerState
        vCenter = $vCenter
        CheckDate = Get-Date
        TotalChecks = $cisRequirements.Count
        PassedChecks = 0
        FailedChecks = 0
        CompliancePercentage = 0
        Details = @()
    }
    
    foreach ($requirement in $cisRequirements.GetEnumerator()) {
        $currentValue = ($vm.ExtensionData.Config.ExtraConfig | Where-Object {$_.Key -eq $requirement.Key}).Value
        $isCompliant = $currentValue -eq $requirement.Value
        
        if ($isCompliant) {
            $vmCompliance.PassedChecks++
        } else {
            $vmCompliance.FailedChecks++
        }
        
        $vmCompliance.Details += [PSCustomObject]@{
            Setting = $requirement.Key
            RequiredValue = $requirement.Value
            CurrentValue = $currentValue ?? "Not Set"
            Compliant = $isCompliant
            Severity = if ($requirement.Key -match "isolation|RemoteDisplay") { "High" } else { "Medium" }
        }
    }
    
    $vmCompliance.CompliancePercentage = [math]::Round(($vmCompliance.PassedChecks / $vmCompliance.TotalChecks) * 100, 2)
    $complianceResults += $vmCompliance
}

# Generate report
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
if (-not $OutputPath) {
    $OutputPath = "$env:TEMP\CIS_Compliance_Report_$timestamp.$($OutputFormat.ToLower())"
}

switch ($OutputFormat) {
    "JSON" {
        $complianceResults | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutputPath -Encoding UTF8
    }
    "CSV" {
        $flatResults = @()
        foreach ($result in $complianceResults) {
            foreach ($detail in $result.Details) {
                $flatResults += [PSCustomObject]@{
                    VMName = $result.VMName
                    PowerState = $result.PowerState
                    CompliancePercentage = $result.CompliancePercentage
                    Setting = $detail.Setting
                    RequiredValue = $detail.RequiredValue
                    CurrentValue = $detail.CurrentValue
                    Compliant = $detail.Compliant
                    Severity = $detail.Severity
                }
            }
        }
        $flatResults | Export-Csv -Path $OutputPath -NoTypeInformation
    }
    "HTML" {
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>CIS Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .summary { background-color: #ecf0f1; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .vm-section { margin: 20px 0; border: 1px solid #bdc3c7; border-radius: 5px; }
        .vm-header { background-color: #3498db; color: white; padding: 10px; }
        .compliant { color: #27ae60; font-weight: bold; }
        .non-compliant { color: #e74c3c; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #bdc3c7; padding: 8px; text-align: left; }
        th { background-color: #34495e; color: white; }
        .high-severity { background-color: #ffebee; }
        .medium-severity { background-color: #fff3e0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ CIS Compliance Report</h1>
        <p>Generated: $(Get-Date)</p>
        <p>vCenter: $vCenter</p>
    </div>
    
    <div class="summary">
        <h2>📊 Summary</h2>
        <p><strong>Total VMs Checked:</strong> $($complianceResults.Count)</p>
        <p><strong>Average Compliance:</strong> $([math]::Round(($complianceResults | Measure-Object CompliancePercentage -Average).Average, 2))%</p>
    </div>
"@

        foreach ($result in $complianceResults) {
            $statusClass = if ($result.CompliancePercentage -ge 80) { "compliant" } else { "non-compliant" }
            $html += @"
    <div class="vm-section">
        <div class="vm-header">
            <h3>🖥️ $($result.VMName) - <span class="$statusClass">$($result.CompliancePercentage)% Compliant</span></h3>
            <p>Power State: $($result.PowerState) | Passed: $($result.PassedChecks) | Failed: $($result.FailedChecks)</p>
        </div>
        <table>
            <tr><th>Setting</th><th>Required</th><th>Current</th><th>Status</th><th>Severity</th></tr>
"@
            foreach ($detail in $result.Details) {
                $statusIcon = if ($detail.Compliant) { "✅" } else { "❌" }
                $severityClass = if ($detail.Severity -eq "High") { "high-severity" } else { "medium-severity" }
                $html += "<tr class='$severityClass'><td>$($detail.Setting)</td><td>$($detail.RequiredValue)</td><td>$($detail.CurrentValue)</td><td>$statusIcon</td><td>$($detail.Severity)</td></tr>"
            }
            $html += "</table></div>"
        }
        
        $html += "</body></html>"
        $html | Out-File -FilePath $OutputPath -Encoding UTF8
    }
}

# Display summary
Write-Host "`n=== COMPLIANCE SUMMARY ===" -ForegroundColor Green
$complianceResults | Select-Object VMName, PowerState, CompliancePercentage, PassedChecks, FailedChecks | Format-Table -AutoSize

Write-Host "📄 Report saved to: $OutputPath" -ForegroundColor Cyan

# Cleanup
Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue