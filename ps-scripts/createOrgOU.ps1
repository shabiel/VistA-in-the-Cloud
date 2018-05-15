Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$adPass,
    [Parameter(Mandatory=$True,Position=2)]
    [string]$org
)

$adPassSecure = $adPass | ConvertTo-SecureString -AsPlainText -Force
$adUser = "VITCAdmin"
$adCredential = New-Object System.Management.Automation.PSCredential($adUser, $adPassSecure)

$S = New-PSSession -ComputerName "VITC-C-DC1"
Import-Module -PSsession $S -Name ActiveDirectory

New-ADOrganizationalUnit -name $org -Path "OU=VITC-Machines,DC=osehravic,DC=onmicrosoft,DC=com" -Credential $adCredential
New-ADOrganizationalUnit -name "Computers" -Path "OU=$org,OU=VITC-Machines,DC=osehravic,DC=onmicrosoft,DC=com" -Credential $adCredential
New-ADOrganizationalUnit -name "Security Groups" -Path "OU=$org,OU=VITC-Machines,DC=osehravic,DC=onmicrosoft,DC=com" -Credential $adCredential
New-ADOrganizationalUnit -name "Users" -Path "OU=$org,OU=VITC-Machines,DC=osehravic,DC=onmicrosoft,DC=com" -Credential $adCredential