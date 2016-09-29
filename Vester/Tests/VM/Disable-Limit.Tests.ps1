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
    # CPU Limits 
    Describe -Name 'VM Configuration: CPU Limit' -Tags @("vm") -Fixture {
        # Variables
        . $Config
        [bool]$allowcpulimit    = $cfg.vm.allowcpulimit

        If (-not $allowcpulimit) {
            foreach ($VM in (Get-VM -Name $cfg.scope.vm)) 
            {
                It -name "$($VM.name) has no CPU limits configured" -test {
                    [array]$value = $VM | Get-VMResourceConfiguration
                    try 
                    {
                        $value.CpuLimitMhz  | Should Be -1
                    }
                    catch 
                    {
                        if ($Remediate) 
                        {
                            Write-Warning -Message $_
                            if ($PSCmdlet.ShouldProcess("vCenter '$($cfg.vcenter.vc)' - VM '$VM'", "Disable CPU limit"))
                            {
                                Write-Warning -Message "Remediating $VM"
                                $value | Set-VMResourceConfiguration -CpuLimitMhz $null
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

    # Memory Limits 
    Describe -Name 'VM Configuration: Memory Limit'-Tag @("vm") -Fixture {
        # Variables
        . $Config
        [bool]$allowmemorylimit = $cfg.vm.allowmemorylimit

        If (-not $allowmemorylimit) {
            foreach ($VM in (Get-VM -Name $cfg.scope.vm)) 
            {
                It -name "$($VM.name) has no memory limits configured" -test {
                    [array]$value = $VM | Get-VMResourceConfiguration
                    try 
                    {
                        $value.MemLimitMB  | Should Be -1
                    }
                    catch 
                    {
                        if ($Remediate) 
                        {
                            Write-Warning -Message $_
                            if ($PSCmdlet.ShouldProcess("vCenter '$($cfg.vcenter.vc)' - VM '$VM'", "Disable memory limit"))
                            {
                                Write-Warning -Message "Remediating $VM"

                                $value | Set-VMResourceConfiguration -MemLimitMB $null
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
}
