﻿#requires -Modules Pester, VMware.VimAutomation.Core

[CmdletBinding(SupportsShouldProcess = $true, 
               ConfirmImpact = 'Medium')]
Param(
    # Optionally fix all config drift that is discovered. Defaults to false (off)
    [switch]$Remediate = $false,

    # Optionally define a different config file to use. Defaults to Vester\Configs\Config.ps1
    [string]$Config = (Split-Path $PSScriptRoot) + '\Configs\Config.ps1'
)

Process {
    # Tests
    Describe -Name 'VM Configuration: Snapshot(s)' -Tag @("vm") -Fixture {
        # Variables
        . $Config
        [int]$snapretention = $cfg.vm.snapretention

        foreach ($VM in (Get-VM -Name $cfg.scope.vm)) 
        {
            It -name "$($VM.name) has no snapshot older than $snapretention day(s)" -test {
                [array]$value = $VM |
                Get-Snapshot |
                Where-Object -FilterScript {
                    $_.Created -lt (Get-Date).AddDays(-$snapretention)
                }
                try 
                {
                    $value | Should BeNullOrEmpty
                }
                catch 
                {
                    if ($Remediate) 
                    {
                        Write-Warning -Message $_
                        if ($PSCmdlet.ShouldProcess("vCenter '$($cfg.vcenter.vc)' - VM '$VM'", "Removing snapshots older than '$snapretention' days"))
                        {
                            Write-Warning -Message "Remediating $VM"
                            Remove-Snapshot -Snapshot $value -ErrorAction Stop -Confirm:$false
                        }
                    }
                    else 
                    {
                        throw $_
                    }
                }
            }
        }
    }
}
