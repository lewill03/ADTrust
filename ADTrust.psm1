function Set-ADTrust {
<#    
.SYNOPSIS    
    Create a trust relationship between 2 AD forests
    
.DESCRIPTION  
    Set up an Active Directory trust between 2 forests. It will :

    Add a conditional forwarder on the DC where the script is run, to the remote DC
    Add a conditional forwarder on the remote DC, to the DC where the script is run
    Create the trust relationship between the 2 domains/forests (you can also choose trust direction, bidirectional, inbound, or outbound)
      
.PARAMETER FQDN  
    FQDN of the remote DC

.PARAMETER IP  
    IP address of the remote DC
       
.PARAMETER Admin  
    Admin account of the remote DC in samAccountName form (i.e. DOMAIN\Administrator)
     
.PARAMETER TrustDirection 
    Trust direction of the trust relationship (Bidirectional, Inbound, Outbound)  
                 
.NOTES    
    Name: ADTrust.ps1  
    Author: lewill03
    DateCreated: 20Jun2024  
	
.LINK
	https://github.com/lewill03/ADTrust
     
.EXAMPLE    
    Set-ADTrust DC2.domain.local 192.168.1.100 DOMAIN\Administrator Bidirectional
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Enter the FQDN of the remote DC.")]
        [string]$FQDN,

        [Parameter(Mandatory = $true, HelpMessage = "Enter the IP address of the remote forest DC.")]
        [string]$IP,

        [Parameter(Mandatory = $true, HelpMessage = "Enter a remote forest admin account with domain in samAccountName form (DOMAIN\user).")]
        [string]$Admin,

        [Parameter(Mandatory = $true, HelpMessage = "Specify trust direction: Bidirectional, Inbound, or Outbound.")]
        [ValidateSet('B', 'I', 'O', 'Bidirectional', 'Inbound', 'Outbound')]
        [string]$TrustDirection
    )

    $DNSName = ($FQDN -split '\.')[1..($FQDN.Length - 1)] -join '.'

    switch ($TrustDirection.ToUpper()) {
    "B" { $TrustDirection = "Bidirectional" }
    "I" { $TrustDirection = "Inbound" }
    "O" { $TrustDirection = "Outbound" }
    }

    # 1. Add a conditional forwarder on this DC to the remote forest
    Write-Host "1. Adding a conditional forwarder on this DC to the remote forest..." -ForegroundColor Cyan

    $existingForwarder = Get-DnsServerZone -Name $DNSName -ErrorAction SilentlyContinue

    if ($existingForwarder) {
        Write-Host "Conditional forwarder for $DNSName already exists. Skipping..." -ForegroundColor Yellow
    } 
    else {
        try {
            Add-DnsServerConditionalForwarderZone -Name $DNSName -MasterServers $IP
            Write-Host "$($DNSName) has been added to conditional forwarders." -ForegroundColor Green
        }
        catch {
            Write-Warning "DNS conditional forwarder failed to add: Error: $($($_.Exception).Message)"
            return
        }
    }

    # 2. Add a conditional forwarder on the remote DC to this forest
    Write-Host "2. Adding a conditional forwarder on the remote DC to this forest" -ForegroundColor Cyan

    Write-Host "Requesting credentials for remote forest admin account..." -ForegroundColor Cyan
    $RemoteCredential = Get-Credential -UserName $Admin -Message "Enter the password for $Admin"

    $localIP = (Test-Connection -ComputerName (hostname) -Count 1 | Select -ExpandProperty IPV4Address).IPAddressToString
    $localRootDomain = (Get-ADForest).RootDomain

    try {
        $session = New-PSSession -ComputerName $FQDN -Credential $RemoteCredential -ErrorAction Stop
        Remove-PSSession $session -ErrorAction SilentlyContinue
        try {
            Invoke-Command -ComputerName $FQDN -Credential $RemoteCredential -ScriptBlock {
                Add-DnsServerConditionalForwarderZone -Name $using:localRootDomain -MasterServers $using:localIP
                Write-Host "Conditional forwarder to this domain has been successfully added on remote DC." -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Failed to add conditional forwarder on remote DC: Error: $($($_.Exception).Message)"
            return
        }
    }
    catch {
        Write-Warning "Failed to authenticate to remote DC: Error: $($($_.Exception).Message)"
        return
    }

    # 3. Create the trust between the 2 forests
    Write-Host "3. Creation of trust relationship between the two forests" -ForegroundColor Cyan

    $createTrust = Read-Host "Proceed with creating trust? [Y/n]"
    if ($createTrust -eq "" -or $createTrust -eq "Y" -or $createTrust -eq "y") {
        Write-Host "Proceeding with Trust Direction: $TrustDirection" -ForegroundColor Yellow

        $remoteContext = New-Object -TypeName "System.DirectoryServices.ActiveDirectory.DirectoryContext" -ArgumentList @("Forest", $DNSName, $RemoteCredential.UserName, $RemoteCredential.GetNetworkCredential().Password)
        $localForest = [System.DirectoryServices.ActiveDirectory.Forest]::getCurrentForest()

        try {
            $remoteForest = [System.DirectoryServices.ActiveDirectory.Forest]::getForest($remoteContext)
            Write-Host "$($remoteForest) exists." -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to retrieve information for forest $($DNSName): Error: $($($_.Exception).Message)"
            return
        }

        try {
            $localForest.CreateTrustRelationship($remoteForest, $TrustDirection)
            Write-Host "$($TrustDirection) trust has been created with forest $($remoteForest)." -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not create $($TrustDirection) trust with forest $($remoteForest): Error: $($($_.Exception).Message)"
            return
        }
    }
    else {
        Write-Host "Trust creation has been skipped." -ForegroundColor Yellow
    }
}
