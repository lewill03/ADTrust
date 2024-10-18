# ADTrust

This Powershell cmdlet allows you to set up an Active Directory trust between 2 forests. It will :
- Add a conditional forwarder on the DC where the script is run, to the remote DC
- Add a conditional forwarder on the remote DC, to the DC where the script is run
- Create the trust relationship between the 2 domains/forests (you can also choose trust direction, bidirectional, inbound, or outbound)

# Importing module

In an elevated PowerShell prompt, on your DC:
```
Import-Module .\ADTrust.psm1
```

# Usage
```
Set-ADTrust <DC-FQDN> <DC-IP> <Admin(samAccountName)> <TrustDirection>
```

# Examples
```
Set-ADTrust DC1.domain.local 192.168.1.100 DOMAIN\administrator Bidirectional
```
