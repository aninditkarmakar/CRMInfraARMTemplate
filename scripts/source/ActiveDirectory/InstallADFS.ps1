#
# Windows PowerShell script for AD FS Deployment
#

Import-Module ADFS

# Get the credential used for the federation service account
$serviceAccountCredential = Get-Credential -Message "Enter the credential for the Federation Service Account."
$domainName = "test.internal"
$computerFQDN = "$env:COMPUTERNAME.$domainName".ToLower()
$cert = dir Cert:\LocalMachine\My | Where-Object { $_.Subject -like "CN=$computerFQDN" }

Install-AdfsFarm `
-CertificateThumbprint:$cert.Thumbprint `
-FederationServiceDisplayName:"Test Organization" `
-FederationServiceName:$computerFQDN `
-ServiceAccountCredential:$serviceAccountCredential