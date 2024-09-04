Write-Host "1. Add a conditional forwarder on this DC to the remote forest" -ForegroundColor Cyan

$DNSName = Read-Host -Prompt "Enter the DNS domain of the remote forest"
$DNSIP = Read-Host -Prompt "Enter the remote forest DC IP"
try {
        Add-DnsServerConditionalForwarderZone -Name $DNSName -MasterServers $DNSIP
        Write-Host "$($DNSName) has been added to conditional forwarders "`n"" -ForegroundColor Green
    }
catch {
        Write-Warning "DNS conditional forwarder failed to add:`n`tError: $($($_.Exception).Message)"
        exit
    }


Write-Host "2. Add a conditional forwarder on the remote DC to this forest" -ForegroundColor Cyan

$RemoteAdmin = Read-Host -Prompt "Enter a remote forest account with admin rights (using DOMAIN\Account)"
$RemoteAdminPassword = Read-Host -Prompt "Enter the remote forest admin account's password"

$securePassword = ConvertTo-SecureString $RemoteAdminPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($RemoteAdmin, $securePassword)

$localIP = (Test-Connection -ComputerName (hostname) -Count 1  | Select -ExpandProperty IPV4Address).IPAddressToString
$RemoteFQDN = Read-Host -Prompt "Entrer remote DC FQDN"
$localRootDomain = (Get-ADForest).RootDomain

try {
        $session = New-PSSession -ComputerName $RemoteFQDN -Credential $credential -ErrorAction Stop
        Remove-PSSession $session -ErrorAction SilentlyContinue
        try {
            Invoke-Command -ComputerName $RemoteFQDN -Credential $credential -ScriptBlock {
                Add-DnsServerConditionalForwarderZone -Name $using:localRootDomain -MasterServers $using:localIP
                Write-Host "Conditional forwarder to this domain has been successfully added on remote DC "`n"" -ForegroundColor Green
                }
            }
        catch {
            Write-Warning "Failed to add conditional forwarder on remote DC:`n`tError: $($($_.Exception).Message)"
            exit
        }
        
    }
catch {
        Write-Warning "Failed to authenticate to remote DC:`n`tError: $($($_.Exception).Message)"
        exit
    }


Write-Host "3. Create the trust between the 2 forests" -ForegroundColor Cyan

do {
    $validTrust = Read-Host -Prompt "A trust relashionship will be created to forest $($DNSName), do you wish to continue? [y/n]"
    if ($validTrust -eq "y" -or $validTrust -eq "Y") {
        $validInputTrust = $true
        $remoteForest = $DNSName
    }
    elseif ($validTrust -eq "n" -or $validTrust -eq "N") {
        $validInputTrust = $true
        exit
    }
    else {
        Write-Host "Invalid Input, try again" -ForegroundColor Red
        $validInputTrust = $false
    }
} while (-not $validInputTrust)


do {
    $strTrustDirection = Read-Host "Enter the trust direction: Bidirectional, Inbound, Outbound [B/I/O]"
    if ($strTrustDirection -eq "B" -or $strTrustDirection -eq "b") {
        $TrustDirection = "Bidirectional"
        $validInput = $true
    }
    elseif ($strTrustDirection -eq "I" -or $strTrustDirection -eq "i") {
        $TrustDirection = "Inbound"
        $validInput = $true
    }
    elseif ($strTrustDirection -eq "O" -or $strTrustDirection -eq "o") {
        $TrustDirection = "Outbound"
        $validInput = $true
    }
    else {
        Write-Host "Invalid Input, Try again" -ForegroundColor Red
        $validInput = $false
        continue
    }

    do {
        Write-Host "Selected trust direction: $($TrustDirection)" -ForegroundColor Yellow
        $continue = Read-Host "Proceed? [y/n]"
        if ($continue -eq "y" -or $continue -eq "Y") {
            $confirm = $true
        }
        elseif ($continue -eq "n" -or $continue -eq "N") {
            $confirm = $false
            $validInput = $false
            break
        }
        else {
            Write-Host "Invalid Input, Try again" -ForegroundColor Red
            $confirm = $false
        }
    } while (-not $confirm)

} while (-not $validInput)

Write-Host "Proceeding with Trust Direction: $TrustDirection..." -ForegroundColor Yellow


$remoteContext = New-Object -TypeName "System.DirectoryServices.ActiveDirectory.DirectoryContext" -ArgumentList @("Forest", $remoteForest, $RemoteAdmin, $RemoteAdminPassword)
$localforest=[System.DirectoryServices.ActiveDirectory.Forest]::getCurrentForest()

try {
        $remoteForest = [System.DirectoryServices.ActiveDirectory.Forest]::getForest($remoteContext)
        Write-Host "$($remoteForest) exists" -ForegroundColor Green
    }
catch {
        Write-Warning "Failed to retrieve information for forest $($remoteForest):`n`tError: $($($_.Exception).Message)"
        exit
    }

try {
        $localForest.CreateTrustRelationship($remoteForest,$TrustDirection)
        Write-Host "$($TrustDirection) trust has been created with forest $($remoteForest)"  -ForegroundColor Green
    }
catch {
        Write-Warning "Could not create $($TrustDirection) trust with forest $($remoteForest)`n`tError: $($($_.Exception).Message)"
        exit
    }
