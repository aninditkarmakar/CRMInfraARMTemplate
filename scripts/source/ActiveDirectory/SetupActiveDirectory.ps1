configuration CreateADPDC 
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    Import-DscResource -ModuleName xActiveDirectory,xDisk,cDisk, xNetworking, PSDesiredStateConfiguration, xAdcsDeployment
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)

    Node localhost
    {
		Script script1
		{
      	    SetScript =  { 
				Set-DnsServerDiagnostics -All $true
                Write-Verbose -Verbose "Enabling DNS client diagnostics" 
            }
            GetScript =  { @{} }
            TestScript = { $false}
			DependsOn = "[WindowsFeature]DNS"
        }
	
		WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"		
        }

		WindowsFeature DnsTools
		{
			Ensure = "Present"
            Name = "RSAT-DNS-Server"
		}

        xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
			DependsOn = "[WindowsFeature]DNS"
        }

        xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        cDiskNoRestart ADDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
			DependsOn= "[cDiskNoRestart]ADDataDisk"
        }  

		WindowsFeature ADAdminCenter 
        { 
            Ensure = "Present" 
            Name = "RSAT-AD-AdminCenter"
			DependsOn = "[WindowsFeature]ADDSInstall"
        }
		
		WindowsFeature ADDSTools 
        { 
            Ensure = "Present" 
            Name = "RSAT-ADDS-Tools"
			DependsOn = "[WindowsFeature]ADDSInstall"
        }  

        xADDomain FirstDS 
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
			DependsOn = "[WindowsFeature]ADDSInstall"
        }

        WindowsFeature ADCS-Cert-Authority
        {
                Ensure = 'Present'
                Name = 'ADCS-Cert-Authority'
                DependsOn = "[xADDomain]FirstDS"
        }

        WindowsFeature ADCS-Web-Enrollment
        {
            Ensure = 'Present'
            Name = 'ADCS-Web-Enrollment'
            DependsOn = "[xADDomain]FirstDS"
        }

        WindowsFeature ADFS
        {
            Ensure = "Present"
            Name = "ADFS-Federation"
            DependsOn = "[WindowsFeature]ADCS-Cert-Authority"
        }

        xADCSCertificationAuthority ADCS
        {
            Ensure = 'Present'
            Credential = $DomainCreds
            CAType = 'EnterpriseRootCA'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority'              
        }

        xADCSWebEnrollment CertSrv
        {
            IsSingleInstance = 'Yes'
            Ensure = 'Present'
            Credential = $DomainCreds
            DependsOn = '[xADCSCertificationAuthority]ADCS'
        }

        LocalConfigurationManager 
        {
            ConfigurationMode = 'ApplyAndAutoCorrect'
            RebootNodeIfNeeded = $true
        }
   }
}