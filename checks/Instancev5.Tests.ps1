# So the v5 files need to be handled differently.
# Ww will start with a BeforeDiscovery which will gather the Instance Information up front
# Gather the instances we know are not contactable

BeforeDiscovery {
    # Gather the instances we know are not contactable
    [string[]]$NotContactable = (Get-PSFConfig -Module dbachecks -Name global.notcontactable).Value
    # Get all the tags in use in this run
    $Tags = Get-CheckInformation -Check $Check -Group Instance -AllChecks $AllChecks -ExcludeCheck $ChecksToExclude
    
    $InstancesToTest = @(Get-Instance).ForEach{
        # just add it to the Not Contactable list
        if ($NotContactable -notcontains $psitem) {
            $Instance = $psitem
            try {
                $InstanceSMO = Connect-DbaInstance  -SqlInstance $Instance -ErrorAction SilentlyContinue -ErrorVariable errorvar
            }
            catch {
                $NotContactable += $Instance
            }
            if ($NotContactable -notcontains $psitem) {
                if ($null -eq $InstanceSMO.version) {
                    $NotContactable += $Instance
                }
                else {
                    # Get the relevant information for the checks in one go to save repeated trips to the instance and set values for Not Contactable tests if required
                    NewGet-AllInstanceInfo -Instance $InstanceSMO -Tags $Tags
                }
            }
        }
    }
    Write-PSFMessage -Message "Instances = $($InstancesToTest.Name)" -Level Verbose
    Set-PSFConfig -Module dbachecks -Name global.notcontactable -Value $NotContactable
}

Describe "Default Trace" -Tag DefaultTrace, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.defaulttrace
    Context "Checking Default Trace on <_.Name>" {
        It "The Default Trace should be enabled on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.DefaultTraceEnabled.ConfigValue   | Should -Be 1 -Because "We expected the Default Trace to be enabled"
        }
    }
}
Describe "OLE Automation Procedures Disabled" -Tag OleAutomationProceduresDisabled, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.oleautomationproceduresdisabled
    Context "Checking OLE Automation Procedures on <_.Name>" {
        It "The OLE Automation Procedures should be disabled on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.OleAutomationProceduresEnabled.ConfigValue   | Should -Be 0 -Because "We expect the OLE Automation Procedures to be disabled"
        }
    }
}

Describe "Remote Access Disabled" -Tag RemoteAccessDisabled, Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.remoteaccessdisabled
    Context "Checking Remote Access on <_.Name>" {
        It "Remote Access should be disabled on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.RemoteAccess.ConfigValue | Should -Be 0 -Because "We expected Remote Access to be disabled"
        }
    }
}

Describe "Cross Database Ownership Chaining" -Tag CrossDBOwnershipChaining, Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.CrossDBOwnershipChaining
    Context "Checking Cross Database Ownership Chaining on <_.Name>" {
        It "Cross Database Ownership Chaining should be disabled on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.CrossDBOwnershipChaining.ConfigValue | Should -Be 0 -Because "We expected the Cross DB Ownership Chaining to be disabled"
        }
    }
}

Describe "Scan For Startup Procedures" -Tag ScanForStartupProceduresDisabled, Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.scanforstartupproceduresdisabled
    Context "Checking Scan For Startup Procedures on <_.Name>" {
        It "Scan For Startup Procedures is set to <_.ConfigValues.scanforstartupproceduresdisabled> on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.ScanForStartupProcedures.ConfigValue -eq 0 | Should -Be $PSItem.ConfigValues.scanforstartupproceduresdisabled -Because "We expected the Cross DB Ownership Chaining to be disabled"
        }
    }
}

Describe "SQL Mail XPs Disabled" -Tag SQLMailXPsDisabled, Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.SQLMailXPsDisabled
    Context "Checking SQL Mail XPs on <_.Name>" {
        It "SQL Mail XPs should be disabled on <_.Name>"  -Skip:($skip -or $psitem.VersionMajor -gt 10) {
            $PSItem.Configuration.SqlMailXPsEnabled.ConfigValue | Should -Be 0 -Because "We expected Sql Mail XPs to be disabled"
        }
    }
}

Describe "Dedicated Administrator Connection" -Tag DAC, Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.dac
    Context "Checking Dedicated Administrator Connection on <_.Name>" {
        It "DAC is set to <_.ConfigValues.dacallowed> on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.RemoteDACConnectionsEnabled.ConfigValue -eq 1 | Should -Be $psitem.ConfigValues.dacallowed -Because 'This is the setting that you have chosen for DAC connections'
        }
    }
}

Describe "OLE Automation" -Tag OLEAutomation, Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.oleautomation
    Context "Checking OLE Automation on <_.Name>" {
        It "OLE Automation is set to <_.ConfigValues.OLEAutomation> on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.OleAutomationProceduresEnabled.ConfigValue -eq 1 | Should -Be $psitem.ConfigValues.OLEAutomation -Because 'OLE Automation can introduce additional security risks'
        }
    }
}
Describe "Ad Hoc Workload Optimization" -Tag AdHocWorkload, Medium, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.AdHocWorkload
    Context "Checking Ad Hoc Workload Optimization on <_.Name>" {
        It "Ad Hoc Workload Optimization is enabled on <_.Name>"  -Skip:($skip -or $psitem.VersionMajor -lt 10) {
            $PSItem.Configuration.OptimizeAdhocWorkloads.ConfigValue -eq 1 | Should -Be 1 -Because "Optimize for ad hoc workloads is a recommended setting"
        }
    }
}

Describe "Ad Hoc Distributed Queries" -Tag AdHocDistributedQueriesEnabled, security, CIS, Medium, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.AdHocDistributedQueriesEnabled
    Context "Checking Ad Hoc Distributed Queries on <_.Name>" {
        It "Ad Hoc Distributed Queries is set to <_.ConfigValues.AdHocDistributedQueriesEnabled> on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.AdHocDistributedQueriesEnabled.ConfigValue -eq 1 | Should -Be $psitem.ConfigValues.AdHocDistributedQueriesEnabled -Because 'This is the setting you have chosen for AdHoc Distributed Queries Enabled'
        }
    }
}
Describe "Default File Path" -Tag DefaultFilePath, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.DefaultFilePath
    Context "Checking Default Data File Path on <_.Name>" {
        It "Default Data File Path should not be on the C Drive on <_.Name>"  -Skip:$skip {
            $PSItem.Settings.DefaultFile.substring(0, 1) | Should -Not -Be "C" -Because 'Default Data file path should not be your C:\ drive'
        }
        It "Default Log File Path should not be on the C Drive on <_.Name>"  -Skip:$skip {
            $PSItem.Settings.DefaultLog.substring(0, 1) | Should -Not -Be "C" -Because 'Default Log file path should not be your C:\ drive'
        }
    }
}

Describe "SA Login Renamed" -Tag SaRenamed, DISA, CIS, Medium, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.SaRenamed
    Context "Checking that sa login has been renamed on <_.Name>" {
        It "sa login has been renamed on <_.Name>" {
            ($PsItem.Logins.Name)  | Should -Not -BeIn 'sa' -Because "Renaming the sa account is a requirement"
        }
    }
}

Describe "SA Login Disabled" -Tag SaDisabled, DISA, CIS, Medium, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.security.sadisabled
    Context "Checking that sa login has been disabled on <_.Name>" {
        It "sa login is disabled on <_.Name>" -Skip:$Skip {
            ($PsItem.Logins | Where-Object ID -eq 1).IsDisabled | Should -Be $true -Because "We expected the original sa login to be disabled"
        }
    }
}

Describe "Login SA cannot exist" -Tag SaExist, CIS, Medium, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.security.saexist
    Context "Checking that a login named sa does not exist on <_.Name>" {
        It "sa login does not exist on <_.Name>" -Skip:$Skip {
            $PsItem.Logins['sa'].Count | Should -Be 0 -Because "We expected no login to exist with the name sa"
        }
    }
}

Describe "Default Backup Compression" -Tag DefaultBackupCompression, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.DefaultBackupCompression
    Context "Checking Default Backup Compression on <_.Name>" {
        It "Default Backup Compression is set to <_.ConfigValues.DefaultBackupCompression> on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.DefaultBackupCompression.ConfigValue -eq 1 | Should -Be $psitem.ConfigValues.DefaultBackupCompression -Because 'This is the setting you have chosen the default backup compression'
        }
    }
}

Describe "Model Database Growth" -Tag ModelDbGrowth, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.modeldbgrowth
    Context "Testing model database growth setting is not default on <_.Name>" {
        It "Growth settings should not be percent for file <_.Name> on <_.Parent.Parent.Parent.Name>" -Skip:$skip -ForEach $PsItem.Databases['model'].FileGroups.Files  {
            $psitem.GrowthType | Should -Not -Be 'Percent' -Because 'New databases use the model database as a template and percent growth can cause performance problems'
        }
        It "Growth settings should not be 1Mb for file <_.Name> on <_.Parent.Parent.Parent.Name>" -Skip:$skip -ForEach $PsItem.Databases['model'].FileGroups.Files  {
            $psitem.Growth | Should -Not -Be 1024 -Because 'New databases use the model database as a template and growing for each Mb will have a performance impact'
        }
        It "Growth settings should not be percent for file <_.Name> on <_.Parent.Parent.Name>" -Skip:$skip -ForEach @($PsItem.Databases['model'].LogFiles) {
            $psitem.GrowthType | Should -Not -Be 'Percent' -Because 'New databases use the model database as a template and percent growth can cause performance problems'
        }
        It "Growth settings should not be 1Mb for file <_.Name> on <_.Parent.Parent.Name>" -Skip:$skip -ForEach @($PsItem.Databases['model'].LogFiles) {
            $psitem.Growth | Should -Not -Be 1024 -Because 'New databases use the model database as a template and growing for each Mb will have a performance impact'
        }
    }
}

Describe "Error Log Count" -Tag ErrorLogCount, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.ErrorLogCount
    Context "Checking error log count on <_.Name>" {
        It "Error log count should be greater or equal to <_.ConfigValues.errorLogCount> on <_.Name>" -Skip:$skip {
            $psitem.NumberOfLogFiles | Should -BeGreaterOrEqual $psitem.ConfigValues.errorLogCount -Because "We expect to have at least $($psitem.ConfigValues.errorLogCount) number of error log files"
        }
    }
}

Describe "Instance MaxDop" -Tag MaxDopInstance, MaxDop, Medium, Instance -ForEach ($InstancesToTest | Where-Object { $psitem.Name -notin $psitem.ConfigValues.ExcludeInstanceMaxDop }) {
    $skip = Get-DbcConfigValue skip.instance.MaxDopInstance
    Context "Testing Instance MaxDop Value on <_.Name>" {
        #if UseRecommended - check that the CurrentInstanceMaxDop property returned from Test-DbaMaxDop matches the the RecommendedMaxDop property
        It "Instance Level MaxDop setting should be correct on <_.Name>" -Skip:$Skip -ForEach ($Psitem | Where-Object { $psitem.ConfigValues.UseRecommendedMaxDop -eq $true }) {
            $psitem.MaxDopSettings.CurrentInstanceMaxDop | Should -Be $psitem.MaxDopSettings.RecommendedMaxDop  -Because "We expect the MaxDop Setting to be the default recommended value $($psitem.MaxDopSettings.RecommendedMaxDop)"
        }
        #if not UseRecommended - check that the CurrentInstanceMaxDop property returned from Test-DbaMaxDop matches the MaxDopValue parameter
        It "Instance Level MaxDop setting should be correct on <_.Name>" -Skip:$Skip -ForEach($Psitem | Where-Object { $psitem.ConfigValues.UseRecommendedMaxDop -ne $true }) {
            $psitem.MaxDopSettings.CurrentInstanceMaxDop | Should -Be $psitem.ConfigValues.InstanceMaxDop -Because "We expect the MaxDop Setting to be the value you specified $($psitem.ConfigValues.InstanceMaxDop)"
        }
    }
}

Describe "Two Digit Year Cutoff" -Tag TwoDigitYearCutoff, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.TwoDigitYearCutoff
    Context "Testing Two Digit Year Cutoff on <_.Name>" {
        It "Two Digit Year Cutoff is set to <_.ConfigValues.TwoDigitYearCutoff> on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.TwoDigitYearCutoff.ConfigValue | Should -Be $psitem.ConfigValues.TwoDigitYearCutoff -Because 'This is the value that you have chosen for Two Digit Year Cutoff configuration'
        }
    }
}
