@{
    # Module manifest for VMware CIS Hardening
    RootModule = 'VMwareCISHardening.psm1'
    ModuleVersion = '1.1.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'VMware Security Team'
    CompanyName = 'VMware Community'
    Copyright = '(c) 2024 VMware Community. All rights reserved.'
    Description = 'PowerShell module for applying CIS hardening to VMware vSphere Virtual Machines'
    
    PowerShellVersion = '5.1'
    
    RequiredModules = @(
        @{ModuleName='VMware.PowerCLI'; ModuleVersion='13.0.0'}
    )
    
    FunctionsToExport = @(
        'Invoke-CISHardening',
        'Test-CISCompliance', 
        'Get-CISComplianceReport',
        'Restore-VMConfiguration',
        'Export-VMConfiguration'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('VMware', 'vSphere', 'Security', 'CIS', 'Hardening', 'Compliance')
            LicenseUri = 'https://github.com/mea37065/vmware-cis-vm/blob/main/LICENSE'
            ProjectUri = 'https://github.com/mea37065/vmware-cis-vm'
            ReleaseNotes = 'Enhanced CIS hardening with compliance reporting and bulk operations'
        }
    }
}