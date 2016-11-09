﻿[CmdletBinding(SupportsShouldProcess = $true,
                ConfirmImpact = 'Medium')]
Param(
    # The $cfg hashtable from a single config file
    [object]$Cfg,

    # Array of paths for tests to run against this config file
    [object]$TestFiles,

    # Pass through the user's preference to fix differences or not
    [switch]$Remediate
)

ForEach ($Test in $TestFiles) {
    Write-Verbose "Processing test file $Test"

    # Use RegEx to strip everything but the parent folder's name
    $Scope = (Split-Path $Test -Parent) -replace '^.*\\',''

    If ($Scope -notmatch 'vCenter|Datacenter|Cluster|Host|VM|Network') {
        Write-Warning "Skipping test $(Split-Path $Test -Leaf). Use -Verbose for more details"
        Write-Verbose 'Test files should be in a folder with one of the following names:'
        Write-Verbose 'vCenter / Datacenter / Cluster / Host / VM / Network'
        Write-Verbose 'This helps Vester determine which inventory object(s) to use during the test.'
        # Use continue to skip this test and go to the next loop iteration
        continue
    }

    If ($Scope -eq 'Network' -and (Get-Module VMware.VimAutomation.Vds) -eq $null) {
        Try {
            Import-Module VMware.VimAutomation.Vds -ErrorAction Stop
        } Catch {
            Write-Warning 'Failed to import PowerCLI module "VMware.VimAutomation.Vds"'
            Write-Warning "Skipping network test $(Split-Path $Test -Leaf)"
            # Use continue to skip this test and go to the next loop iteration
            continue
        }
    }

    Describe -Name "$Scope Configuration: $(Split-Path $Test -Leaf)" -Fixture {
        # Pull in $Title/$Desired/$Actual/$Fix from the test file
        . $Test

        # Pump the brakes if the config value is $null
        If ($Desired -eq $null) {
            Write-Verbose "Due to null config value, skipping test $(Split-Path $Test -Leaf)"
            # Use continue to skip this test and go to the next loop iteration
            continue
        } Else {
            $Datacenter = Get-Datacenter -name $cfg.scope.datacenter -Server $cfg.vcenter.vc
            # Use $Scope (parent folder) to get the correct objects to test against
            $InventoryList = switch ($Scope) {
                'vCenter'    {$cfg.vcenter.vc}
                'Datacenter' {$Datacenter}
                'Cluster'    {$Datacenter | Get-Cluster -Name $cfg.scope.cluster}
                'Host'       {$Datacenter | Get-Cluster -Name $cfg.scope.cluster | Get-VMHost -Name $cfg.scope.host}
                'VM'         {$Datacenter | Get-Cluster -Name $cfg.scope.cluster | Get-VM -Name $cfg.scope.vm}
                'Network'    {$Datacenter | Get-VDSwitch -Name $cfg.scope.vds}
                }
        } #If Desired

        ForEach ($Object in $InventoryList) {
            Write-Verbose "Processing $($Object.Name) within test $(Split-Path $Test -Leaf)"

            It -Name "$Scope $($Object.Name) - $Title" -Test {
                Try {
                    Compare-Object -ReferenceObject $Desired -DifferenceObject (& $Actual) | Should BeNullOrEmpty
                } Catch {
                    If ($Remediate) {
                        Write-Warning -Message $_
                        If ($PSCmdlet.ShouldProcess("vCenter '$($cfg.vcenter.vc)' - $Scope '$Object'", "Set '$Title' value to '$Desired'")) {
                            Write-Warning -Message "Remediating $Object"
                            & $Fix
                        }
                    } Else {
                        throw $_
                    }
                } #Try/Catch
            } #It
        } #ForEach Object
    } #Describe
} #ForEach Test
