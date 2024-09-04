# ADTrust

This Powershell script allows you to set up an Active Directory trust between 2 forests. It will :
- Add a conditional forwarder on the DC where the script is run, to the remote DC
- Add a conditional forwarder on the remote DC, to the DC where the script is run
- Create the trust relationship between the 2 domains/forests (you can also choose trust direction, bidirectional, inbound, or outbound)

# Usage

You can run the script as is in an elevated PowerShell prompt on your DC.
