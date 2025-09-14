# VMware CIS Hardening PowerShell Module

# Import required modules
if (-not (Get-Module VMware.PowerCLI -ListAvailable)) {
    Write-Warning "VMware PowerCLI is required. Install with: Install-Module VMware.PowerCLI"
}

# Module variables
$script:CISRequirements = @{
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

function Invoke-CISHardening {
    <#
    .SYNOPSIS
        Applies CIS hardening to VMware VMs
    
    .DESCRIPTION
        Applies Center for Internet Security (CIS) hardening parameters to VMware vSphere Virtual Machines
    
    .PARAMETER vCenter
        vCenter Server FQDN or IP address
    
    .PARAMETER VMName
        Name of the Virtual Machine to harden
    
    .PARAMETER Credential
        PSCredential object for vCenter authentication
    
    .PARAMETER WhatIf
        Preview changes without applying them
    
    .PARAMETER Backup
        Create configuration backup before applying changes
    
    .EXAMPLE
        Invoke-CISHardening -vCenter "vcenter.lab.local" -VMName "WebServer01"
    
    .EXAMPLE
        Invoke-CISHardening -vCenter "vcenter.lab.local" -VMName "WebServer01" -WhatIf -Backup
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$vCenter,
        
        [Parameter(Mandatory = $true)]
        [string]$VMName,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [switch]$Backup
    )
    
    try {
        # Connect to vCenter
        Write-Verbose "Connecting to vCenter: $vCenter"
        if ($Credential) {
            $connection = Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction Stop
        } else {
            $connection = Connect-VIServer -Server $vCenter -ErrorAction Stop
        }
        
        # Get VM
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        Write-Verbose "Found VM: $($vm.Name)"
        
        # Backup if requested
        if ($Backup) {
            Export-VMConfiguration -VM $vm -BackupPath "$env:TEMP\$($vm.Name)_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        }
        
        # Apply hardening
        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
        
        foreach ($requirement in $script:CISRequirements.GetEnumerator()) {
            if ($PSCmdlet.ShouldProcess($vm.Name, "Apply $($requirement.Key) = $($requirement.Value)")) {
                $opt = New-Object VMware.Vim.OptionValue
                $opt.Key = $requirement.Key
                $opt.Value = $requirement.Value
                $spec.ExtraConfig += $opt
                Write-Verbose "Applied: $($requirement.Key) = $($requirement.Value)"
            }
        }
        
        if (-not $WhatIfPreference) {
            $vm.ExtensionData.ReconfigVM($spec)
            Write-Output "✅ CIS hardening applied successfully to VM '$VMName'"
        }
        
    }
    catch {
        Write-Error "Failed to apply CIS hardening: $_"
    }
    finally {
        if ($connection) {
            Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

function Test-CISCompliance {
    <#
    .SYNOPSIS
        Tests VM compliance against CIS benchmarks
    
    .DESCRIPTION
        Checks current VM configuration against CIS security requirements
    
    .PARAMETER vCenter
        vCenter Server FQDN or IP address
    
    .PARAMETER VMName
        Name of the Virtual Machine to check
    
    .PARAMETER Credential
        PSCredential object for vCenter authentication
    
    .EXAMPLE
        Test-CISCompliance -vCenter "vcenter.lab.local" -VMName "WebServer01"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$vCenter,
        
        [Parameter(Mandatory = $true)]
        [string]$VMName,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )
    
    try {
        # Connect to vCenter
        if ($Credential) {
            $connection = Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction Stop
        } else {
            $connection = Connect-VIServer -Server $vCenter -ErrorAction Stop
        }
        
        # Get VM
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        
        # Check compliance
        $complianceResults = @()
        $passedChecks = 0
        
        foreach ($requirement in $script:CISRequirements.GetEnumerator()) {
            $currentValue = ($vm.ExtensionData.Config.ExtraConfig | Where-Object {$_.Key -eq $requirement.Key}).Value
            $isCompliant = $currentValue -eq $requirement.Value
            
            if ($isCompliant) { $passedChecks++ }
            
            $complianceResults += [PSCustomObject]@{
                Setting = $requirement.Key
                RequiredValue = $requirement.Value
                CurrentValue = $currentValue ?? "Not Set"
                Compliant = $isCompliant
            }
        }
        
        $compliancePercentage = [math]::Round(($passedChecks / $script:CISRequirements.Count) * 100, 2)
        
        return [PSCustomObject]@{
            VMName = $VMName
            vCenter = $vCenter
            CompliancePercentage = $compliancePercentage
            PassedChecks = $passedChecks
            TotalChecks = $script:CISRequirements.Count
            Details = $complianceResults
        }
    }
    catch {
        Write-Error "Failed to check compliance: $_"
    }
    finally {
        if ($connection) {
            Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

function Get-CISComplianceReport {
    <#
    .SYNOPSIS
        Generates CIS compliance report
    
    .DESCRIPTION
        Creates detailed compliance report in various formats
    
    .PARAMETER vCenter
        vCenter Server FQDN or IP address
    
    .PARAMETER VMName
        Name of specific VM (optional, checks all VMs if not specified)
    
    .PARAMETER OutputFormat
        Report format (HTML, JSON, CSV)
    
    .PARAMETER OutputPath
        Path to save the report
    
    .EXAMPLE
        Get-CISComplianceReport -vCenter "vcenter.lab.local" -OutputFormat HTML -OutputPath "C:\Reports\compliance.html"
    #>
    
    [CmdletBinding()]
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
    
    # Implementation would call the compliance-report.ps1 script
    $scriptPath = Join-Path $PSScriptRoot "scripts\compliance-report.ps1"
    
    $params = @{
        vCenter = $vCenter
        OutputFormat = $OutputFormat
    }
    
    if ($VMName) { $params.VMName = $VMName }
    if ($OutputPath) { $params.OutputPath = $OutputPath }
    if ($Credential) { $params.Credential = $Credential }
    
    & $scriptPath @params
}

function Export-VMConfiguration {
    <#
    .SYNOPSIS
        Exports VM configuration for backup
    
    .DESCRIPTION
        Creates backup of VM advanced configuration settings
    
    .PARAMETER VM
        VM object to backup
    
    .PARAMETER BackupPath
        Path to save backup file
    
    .EXAMPLE
        $vm = Get-VM "WebServer01"
        Export-VMConfiguration -VM $vm -BackupPath "C:\Backups\webserver01_backup.json"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]$VM,
        
        [Parameter(Mandatory = $true)]
        [string]$BackupPath
    )
    
    try {
        $config = $VM.ExtensionData.Config.ExtraConfig | Select-Object Key, Value
        $config | ConvertTo-Json -Depth 2 | Out-File -FilePath $BackupPath -Encoding UTF8
        Write-Output "✅ Configuration backup saved to: $BackupPath"
    }
    catch {
        Write-Error "Failed to export VM configuration: $_"
    }
}

function Restore-VMConfiguration {
    <#
    .SYNOPSIS
        Restores VM configuration from backup
    
    .DESCRIPTION
        Restores VM advanced configuration from backup file
    
    .PARAMETER vCenter
        vCenter Server FQDN or IP address
    
    .PARAMETER VMName
        Name of the Virtual Machine
    
    .PARAMETER BackupPath
        Path to backup file
    
    .PARAMETER Credential
        PSCredential object for vCenter authentication
    
    .EXAMPLE
        Restore-VMConfiguration -vCenter "vcenter.lab.local" -VMName "WebServer01" -BackupPath "C:\Backups\webserver01_backup.json"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$vCenter,
        
        [Parameter(Mandatory = $true)]
        [string]$VMName,
        
        [Parameter(Mandatory = $true)]
        [string]$BackupPath,
        
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credential
    )
    
    try {
        if (-not (Test-Path $BackupPath)) {
            throw "Backup file not found: $BackupPath"
        }
        
        # Connect to vCenter
        if ($Credential) {
            $connection = Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction Stop
        } else {
            $connection = Connect-VIServer -Server $vCenter -ErrorAction Stop
        }
        
        # Get VM and backup config
        $vm = Get-VM -Name $VMName -ErrorAction Stop
        $backupConfig = Get-Content $BackupPath | ConvertFrom-Json
        
        # Apply backup configuration
        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
        
        foreach ($setting in $backupConfig) {
            $opt = New-Object VMware.Vim.OptionValue
            $opt.Key = $setting.Key
            $opt.Value = $setting.Value
            $spec.ExtraConfig += $opt
        }
        
        $vm.ExtensionData.ReconfigVM($spec)
        Write-Output "✅ Configuration restored from backup: $BackupPath"
    }
    catch {
        Write-Error "Failed to restore VM configuration: $_"
    }
    finally {
        if ($connection) {
            Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Invoke-CISHardening',
    'Test-CISCompliance',
    'Get-CISComplianceReport', 
    'Export-VMConfiguration',
    'Restore-VMConfiguration'
)