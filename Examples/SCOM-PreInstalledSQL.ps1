#requires -Version 5
# SCOM 2016
$SecurePassword = ConvertTo-SecureString -String "Pass@word1" -AsPlainText -Force
$InstallerServiceAccount = New-Object System.Management.Automation.PSCredential ("domain\!Installer", $SecurePassword)
$SecurePassword = ConvertTo-SecureString -String "Pass@word1" -AsPlainText -Force
$SystemCenter2016OperationsManagerActionAccount = New-Object System.Management.Automation.PSCredential ("domain\!om_saa", $SecurePassword)
$SecurePassword = ConvertTo-SecureString -String "Pass@word1" -AsPlainText -Force
$SystemCenter2016OperationsManagerDASAccount = New-Object System.Management.Automation.PSCredential ("domain\!om_das", $SecurePassword)
$SecurePassword = ConvertTo-SecureString -String "Pass@word1" -AsPlainText -Force
$SystemCenter2016OperationsManagerDataReader = New-Object System.Management.Automation.PSCredential ("domain\!om_dra", $SecurePassword)
$SecurePassword = ConvertTo-SecureString -String "Pass@word1" -AsPlainText -Force
$SystemCenter2016OperationsManagerDataWriter = New-Object System.Management.Automation.PSCredential ("domain\!om_dwa", $SecurePassword)

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName                                            = "*"
            PSDscAllowPlainTextPassword                         = $true
            PSDscAllowDomainUser                                = $true
            SourcePath                                          = "\\SQL01\Software"
            SourceFolder                                        = "\SystemCenter2016\OperationsManager"
            WindowsServerSource                                 = "\WindowsServer2012R2"
            SQLServer2014SystemCLRTypes                         = "\Prerequisites\SQL2014CLR"
            ReportViewer2015Redistributable                     = "\Prerequisites\RV2015"
            InstallerServiceAccount                             = $InstallerServiceAccount
            SystemCenter2016OperationsManagerActionAccount      = $SystemCenter2016OperationsManagerActionAccount
            SystemCenter2016OperationsManagerDASAccount         = $SystemCenter2016OperationsManagerDASAccount
            SystemCenter2016OperationsManagerDataReader         = $SystemCenter2016OperationsManagerDataReader
            SystemCenter2016OperationsManagerDataWriter         = $SystemCenter2016OperationsManagerDataWriter
            SCOMAdmins                                          = "domain\SCOMAdmins"
            ManagementGroupName                                 = "SCOM_domain"
            SystemCenterProductKey                              = ""

            SqlServer                                           = "SQL01.domain.info"
            SqlInstance                                         = "MSSQLSERVER"
            SqlDatabase                                         = "OperationsManager"
            DatabaseSize                                        = 1000
            SqlDWServer                                         = "SQL01.domain.info"
            SqlDWInstance                                       = "MSSQLSERVER"
            SqlDWDatabase                                       = "OperationsManagerDW"
            DwDatabaseSize                                      = 1000
            SystemCenter2016OperationsManagerReportingServer    = "node01.domain.info"
            SystemCenter2016OperationsManagerReportingInstance  = "SQL01.domain.info\MSSQLSERVER"
        }
        @{
            NodeName = "Node01.domain.info"
            Roles = @(
                "System Center 2016 Operations Manager Management Server",
                "System Center 2016 Operations Manager Web Console Server",
                "System Center 2016 Operations Manager Console"
            )
        }
        @{
            NodeName = "Node02.domain.info"
            Roles = @(
                "System Center 2016 Operations Manager Management Server",
                "System Center 2016 Operations Manager Web Console Server",
                "System Center 2016 Operations Manager Console"
            )
        }
    )
}

Configuration SCOM
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xCredSSP
    Import-DscResource -Module xSQLServer
    Import-DscResource -Module xSCOM


    # Set role and instance variables
    $Roles = $AllNodes.Roles | Sort-Object -Unique
    foreach($Role in $Roles)
    {
        $Servers = @($AllNodes.Where{$_.Roles | Where-Object {$_ -eq $Role}}.NodeName)
        Set-Variable -Name ($Role.Replace(" ","").Replace(".","") + "s") -Value $Servers
        if($Servers.Count -eq 1)
        {
            Set-Variable -Name ($Role.Replace(" ","").Replace(".","")) -Value $Servers[0]
            if(
                $Role.Contains("Database") -or
                $Role.Contains("Datawarehouse") -or
                $Role.Contains("Reporting") -or
                $Role.Contains("Analysis") -or
                $Role.Contains("Integration")
            )
            {
                $Instance = $AllNodes.Where{$_.NodeName -eq $Servers[0]}.SQLServers.Where{$_.Roles | Where-Object {$_ -eq $Role}}.InstanceName
                Set-Variable -Name ($Role.Replace(" ","").Replace(".","").Replace("Server","Instance")) -Value $Instance
            }
        }
    }

    Node $AllNodes.NodeName
    {

        # Install .NET Framework 3.5 on SQL and Web Console nodes
        if(
            ($SystemCenter2016OperationsManagerDatabaseServer -eq $Node.NodeName) -or
            ($SystemCenter2016OperationsManagerDatawarehouseServer -eq $Node.NodeName) -or
            ($SystemCenter2016OperationsManagerReportingServer -eq $Node.NodeName) -or
            ($SystemCenter2016OperationsManagerWebConsoleServers | Where-Object {$_ -eq $Node.NodeName})
        )
        {
            if($Node.WindowsServerSource)
            {
                $WindowsServerSource = (Join-Path -Path $Node.WindowsServerSource -ChildPath "\sources\sxs")
            }
            else
            {
                $WindowsServerSource = "\WindowsServer2012R2\sources\sxs"
            }

            WindowsFeature "NET-Framework-Core"
            {
                Ensure = "Present"
                Name = "NET-Framework-Core"
                Source = $Node.SourcePath + $WindowsServerSource
            }
        }

        # Install IIS on Web Console Servers
        if($SystemCenter2016OperationsManagerWebConsoleServers | Where-Object {$_ -eq $Node.NodeName})
        {
            WindowsFeature "Web-WebServer"
            {
                Ensure = "Present"
                Name = "Web-WebServer"
            }

            WindowsFeature "Web-Request-Monitor"
            {
                Ensure = "Present"
                Name = "Web-Request-Monitor"
            }

            WindowsFeature "Web-Windows-Auth"
            {
                Ensure = "Present"
                Name = "Web-Windows-Auth"
            }

            WindowsFeature "Web-Asp-Net"
            {
                Ensure = "Present"
                Name = "Web-Asp-Net"
            }

            WindowsFeature "Web-Asp-Net45"
            {
                Ensure = "Present"
                Name = "Web-Asp-Net45"
            }

            WindowsFeature "NET-WCF-HTTP-Activation45"
            {
                Ensure = "Present"
                Name = "NET-WCF-HTTP-Activation45"
            }

            WindowsFeature "Web-Mgmt-Console"
            {
                Ensure = "Present"
                Name = "Web-Mgmt-Console"
            }

            WindowsFeature "Web-Metabase"
            {
                Ensure = "Present"
                Name = "Web-Metabase"
            }
        }

        # Install Report Viewer 2015 on Web Console Servers and Consoles
        if(
            ($SystemCenter2016OperationsManagerWebConsoleServers | Where-Object {$_ -eq $Node.NodeName}) -or
            ($SystemCenter2016OperationsManagerConsoles | Where-Object {$_ -eq $Node.NodeName})
        )
        {
            if($Node.SQLServer2014SystemCLRTypes)
            {
                $SQLServer2014SystemCLRTypes = (Join-Path -Path $Node.SQLServer2014SystemCLRTypes -ChildPath "SQLSysClrTypes.msi")
            }
            else
            {
                $SQLServer2014SystemCLRTypes = "\Prerequisites\SQL2014CLR\SQLSysClrTypes.msi"
            }
            Package "SQLServer2014SystemCLRTypes"
            {
                Ensure = "Present"
                Name = "Microsoft System CLR Types for SQL Server 2014"
                ProductId = ""
                Path = (Join-Path -Path $Node.SourcePath -ChildPath $SQLServer2014SystemCLRTypes)
                Arguments = "ALLUSERS=2"
                PsDscRunAsCredential = $Node.InstallerServiceAccount
            }

            if($Node.ReportViewer2015Redistributable)
            {
                $ReportViewer2015Redistributable = (Join-Path -Path $Node.ReportViewer2015Redistributable -ChildPath "ReportViewer.msi")
            }
            else
            {
                $ReportViewer2015Redistributable = "\Prerequisites\RV2015\ReportViewer.msi"
            }
            Package "ReportViewer2015Redistributable"
            {
                DependsOn = "[Package]SQLServer2014SystemCLRTypes"
                Ensure = "Present"
                Name = "Microsoft Report Viewer 2015 Runtime"
                ProductID = ""
                Path = (Join-Path -Path $Node.SourcePath -ChildPath $ReportViewer2015Redistributable)
                Arguments = "ALLUSERS=2"
                PsDscRunAsCredential = $Node.InstallerServiceAccount
            }
        }

        # Add service accounts to admins on Management Servers
        if($SystemCenter2016OperationsManagerManagementServers | Where-Object {$_ -eq $Node.NodeName})
        {

            If($Node.SystemCenter2016OperationsManagerActionAccount.UserName -eq $Node.SystemCenter2016OperationsManagerDASAccount.UserName)
            {
                Group "Administrators"
                {
                    GroupName = "Administrators"

                    MembersToInclude = @(
                        $Node.SystemCenter2016OperationsManagerDASAccount.UserName
                    )
                    Credential = $Node.InstallerServiceAccount
                    PsDscRunAsCredential = $Node.InstallerServiceAccount
                }
            }
            Else
            {
                Group "Administrators"
                {
                    GroupName = "Administrators"
                    MembersToInclude = @(
                        $Node.SystemCenter2016OperationsManagerActionAccount.UserName,
                        $Node.SystemCenter2016OperationsManagerDASAccount.UserName
                    )
                    Credential = $Node.InstallerServiceAccount
                    PsDscRunAsCredential = $Node.InstallerServiceAccount
                }
            }
        }

        # Install first Management Server
        if ($SystemCenter2016OperationsManagerManagementServers[0] -eq $Node.NodeName)
        {
            # Enable CredSSP - required for ProductKey PS cmdlet
            # Do NOT use if WinRM is set by GPO, will cause boot loop
            <#
            xCredSSP "Server"
            {
                Ensure = "Present"
                Role = "Server"
            }

            xCredSSP "Client"
            {
                Ensure = "Present"
                Role = "Client"
                DelegateComputers = $Node.NodeName
            }

            # Create DependsOn for first Management Server
            $DependsOn = @(
                "[xCredSSP]Server",
                "[xCredSSP]Client",
                "[Group]Administrators"
            )
            #>

            # Assumes SQL is Online
            # Wait for Operations SQL Server
<#
            if ($SystemCenter2016OperationsManagerManagementServers[0] -eq $SystemCenter2016OperationsManagerDatabaseServer)
            {
                $DependsOn += @(("[xSqlServerFirewall]" + $SystemCenter2016OperationsManagerDatabaseServer + $SystemCenter2016OperationsManagerDatabaseInstance))
            }
            else
            {
                WaitForAll "OMDB"
                {
                    NodeName = $SystemCenter2016OperationsManagerDatabaseServer
                    ResourceName = ("[xSqlServerFirewall]" + $SystemCenter2016OperationsManagerDatabaseServer + $SystemCenter2016OperationsManagerDatabaseInstance)
                    Credential = $Node.InstallerServiceAccount
                    RetryCount = 720
                    RetryIntervalSec = 5
                }
                $DependsOn += @("[WaitForAll]OMDB")
            }

            # Wait for Datawarehouse SQL Server, if different from Operations SQL Server
            if (
                ($SystemCenter2016OperationsManagerDatabaseServer -ne $SystemCenter2016OperationsManagerDatawarehouseServer) -or
                ($SystemCenter2016OperationsManagerDatabaseInstance -ne $SystemCenter2016OperationsManagerDatawarehouseInstance)
            )
            {
                if($SystemCenter2016OperationsManagerManagementServers[0] -eq $SystemCenter2016OperationsManagerDatawarehouseServer)
                {
                    $DependsOn += @(("[xSqlServerFirewall]" + $SystemCenter2016OperationsManagerDatawarehouseServer + $SystemCenter2016OperationsManagerDatawarehouseInstance))
                }
                else
                {
                    WaitForAll "OMDW"
                    {
                        NodeName = $SystemCenter2016OperationsManagerDatawarehouseServer
                        ResourceName = ("[xSqlServerFirewall]" + $SystemCenter2016OperationsManagerDatawarehouseServer + $SystemCenter2016OperationsManagerDatawarehouseInstance)
                        Credential = $Node.InstallerServiceAccount
                        RetryCount = 720
                        RetryIntervalSec = 5
                    }
                    $DependsOn += @("[WaitForAll]OMDW")
                }
            }
#>
            # Install first Management Server
            xSCOMManagementServerSetup "OMMS"
            {
                DependsOn = $DependsOn
                Ensure = "Present"
                SourcePath = $Node.SourcePath
                SourceFolder = $Node.SourceFolder
                SetupCredential = $Node.InstallerServiceAccount
                ProductKey = $Node.SystemCenterProductKey
                ManagementGroupName = $Node.ManagementGroupName
                FirstManagementServer = $true
                ActionAccount = $Node.SystemCenter2016OperationsManagerActionAccount
                DASAccount = $Node.SystemCenter2016OperationsManagerDASAccount
                DataReader = $Node.SystemCenter2016OperationsManagerDataReader
                DataWriter = $Node.SystemCenter2016OperationsManagerDataWriter
                SqlServerInstance = ($Node.SQLServer + "\" + $Node.SQLInstance)
                DatabaseName = $Node.SqlDatabase
                DatabaseSize = $Node.DatabaseSize
                DwSqlServerInstance = ($Node.SQLDWServer + "\" + $Node.SQLDWInstance)
                DwDatabaseName = $Node.SqlDWDatabase
                DwDatabaseSize = $Node.DwDatabaseSize

            }
        }

        # Wait for first Management Server on other Management Servers
        # and Reporting and Web Console server, if they are not on a Management Server
        if(
            (
                ($SystemCenter2016OperationsManagerManagementServers | Where-Object {$_ -eq $Node.NodeName}) -and
                ($SystemCenter2016OperationsManagerManagementServers[0] -ne $Node.NodeName)
            ) -or
            (
                ($SystemCenter2016OperationsManagerReportingServer -eq $Node.NodeName) -and
                (!($SystemCenter2016OperationsManagerManagementServers | Where-Object {$_ -eq $Node.NodeName}))
            ) -or
            (
                ($SystemCenter2016OperationsManagerWebConsoleServers | Where-Object {$_ -eq $Node.NodeName}) -and
                (!($SystemCenter2016OperationsManagerManagementServers | Where-Object {$_ -eq $Node.NodeName}))
            )
        )
        {
            WaitForAll "OMMS"
            {
                NodeName = $SystemCenter2016OperationsManagerManagementServers[0]
                ResourceName = "[xSCOMManagementServerSetup]OMMS"
                PsDscRunAsCredential = $Node.InstallerServiceAccount
                RetryCount = 1440
                RetryIntervalSec = 5
            }
        }

        # Install other Management Servers
        if(
            ($SystemCenter2016OperationsManagerManagementServers | Where-Object {$_ -eq $Node.NodeName}) -and
            ($SystemCenter2016OperationsManagerManagementServers[0] -ne $Node.NodeName)
        )
        {
            xSCOMManagementServerSetup "OMMS"
            {
                DependsOn = @(
                    "[Group]Administrators",
                    "[WaitForAll]OMMS"
                )
                Ensure = "Present"
                SourcePath = $Node.SourcePath
                SourceFolder = $Node.SourceFolder
                SetupCredential = $Node.InstallerServiceAccount
                FirstManagementServer = $false
                ActionAccount = $Node.SystemCenter2016OperationsManagerActionAccount
                DASAccount = $Node.SystemCenter2016OperationsManagerDASAccount
                DataReader = $Node.SystemCenter2016OperationsManagerDataReader
                DataWriter = $Node.SystemCenter2016OperationsManagerDataWriter
                SqlServerInstance = ($Node.SQLServer + "\" + $Node.SQLInstance)
                DatabaseName = $Node.SqlDatabase
            }
        }

        # Install Reporting Server
        if($SystemCenter2016OperationsManagerReportingServer -eq $Node.NodeName)
        {
            # If this is a Management Server, depend on itself
            # else wait for the first Management Server
            if ($SystemCenter2016OperationsManagerManagementServers | Where-Object {$_ -eq $Node.NodeName})
            {
                $DependsOn = "[xSCOMManagementServerSetup]OMMS"
            }
            else
            {
                $DependsOn = "[WaitForAll]OMMS"
            }

            xSCOMReportingServerSetup "OMRS"
            {
                DependsOn = $DependsOn
                Ensure = "Present"
                SourcePath = $Node.SourcePath
                SourceFolder = $Node.SourceFolder
                SetupCredential = $Node.InstallerServiceAccount
                ManagementServer = $SystemCenter2016OperationsManagerManagementServers[0]
                SRSInstance = ($SystemCenter2016OperationsManagerReportingServer + "\" + $SystemCenter2016OperationsManagerReportingInstance)
                DataReader = $Node.SystemCenter2016OperationsManagerDataReader
            }
        }

        # Install Web Console Servers
        if($SystemCenter2016OperationsManagerWebConsoleServers | Where-Object {$_ -eq $Node.NodeName})
        {
            $DependsOn = @(
                "[WindowsFeature]NET-Framework-Core",
                "[WindowsFeature]Web-WebServer",
                "[WindowsFeature]Web-Request-Monitor",
                "[WindowsFeature]Web-Windows-Auth",
                "[WindowsFeature]Web-Asp-Net",
                "[WindowsFeature]Web-Asp-Net45",
                "[WindowsFeature]NET-WCF-HTTP-Activation45",
                "[WindowsFeature]Web-Mgmt-Console",
                "[WindowsFeature]Web-Metabase",
                "[Package]SQLServer2014SystemCLRTypes",
                "[Package]ReportViewer2015Redistributable"
            )
            # If this is a Management Server, depend on itself
            # else wait for the first Management Server
            if ($SystemCenter2016OperationsManagerManagementServers | Where-Object {$_ -eq $Node.NodeName})
            {
                $DependsOn += @("[xSCOMManagementServerSetup]OMMS")
            }
            else
            {
                $DependsOn += @("[WaitForAll]OMMS")
            }
            xSCOMWebConsoleServerSetup "OMWC"
            {
                DependsOn = $DependsOn
                Ensure = "Present"
                SourcePath = $Node.SourcePath
                SourceFolder = $Node.SourceFolder
                SetupCredential = $Node.InstallerServiceAccount
                ManagementServer = $SystemCenter2016OperationsManagerManagementServers[0]
            }
        }

        # Install Consoles
        if($SystemCenter2016OperationsManagerConsoles | Where-Object {$_ -eq $Node.NodeName})
        {
            xSCOMConsoleSetup "OMC"
            {
                DependsOn = @(
                    "[Package]SQLServer2014SystemCLRTypes",
                    "[Package]ReportViewer2015Redistributable"
                )
                Ensure = "Present"
                SourcePath = $Node.SourcePath
                SourceFolder = $Node.SourceFolder
                SetupCredential = $Node.InstallerServiceAccount
            }
        }
    }
}

foreach($Node in $ConfigurationData.AllNodes)
{
    if($Node.NodeName -ne "*")
    {
        Start-Process -FilePath "robocopy.exe" -ArgumentList ("`"C:\Program Files\WindowsPowerShell\Modules`" `"\\" + $Node.NodeName + "\c$\Program Files\WindowsPowerShell\Modules`" /e /purge /xf") -NoNewWindow -Wait
    }
}

Write-Host "Creating MOFs" -ForegroundColor Yellow
SCOM -ConfigurationData $ConfigurationData
Write-Host "Running Config" -ForegroundColor Yellow
Start-DscConfiguration -Path .\SCOM -Verbose -Wait -Force
