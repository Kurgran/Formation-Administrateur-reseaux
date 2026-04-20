<#
.SYNOPSIS
    V05 — Crée trois comptes de service kerberoastables avec des mots de passe
    de qualité variable.

.DESCRIPTION
    Trois comptes de service sont créés avec un SPN (Service Principal Name)
    enregistré dans l'AD. La présence d'un SPN sur un compte utilisateur le
    rend kerberoastable : n'importe quel utilisateur authentifié peut
    demander un ticket TGS-REP chiffré avec le hash du mot de passe du
    compte de service.

    Deux des trois comptes utilisent un mot de passe faible et seront cassés
    par hashcat hors-ligne. Le troisième utilise un mot de passe long
    (>25 caractères) qui résiste à un crack raisonnable. C'est exactement
    ce qu'on observe en mission : un parc historique avec des comptes
    "oubliés" mêlés à des comptes correctement gérés.

.NOTES
    Vulnérabilité référencée : V05 — Criticité : Critique
#>

[CmdletBinding()]
param(
    [string]$Domain    = 'corp.lab',
    [string]$DCName    = 'DC01',
    [string]$FSName    = 'FS01',
    [string]$WSName    = 'WS01'
)

$ErrorActionPreference = 'Stop'

# Trois comptes : SPN + mot de passe + niveau de robustesse simulé
$svcAccounts = @(
    @{
        Name         = 'svc_sql'
        Password     = 'azertyuiop'                  # Faible — cassé par dico classique
        SPN          = "MSSQLSvc/sqlserver.$Domain:1433"
        Description  = 'Service SQL Server'
    },
    @{
        Name         = 'svc_iis'
        Password     = 'P4ssw0rd'                    # Faible — cassé par dico + règles
        SPN          = "HTTP/intranet.$Domain"
        Description  = 'Pool applicatif IIS'
    },
    @{
        Name         = 'svc_app'
        Password     = 'X4!Pq2vMzL8NwT3Bd6FjK9HrYa'   # Forte — résistante au crack
        SPN          = "HOST/appserver.$Domain"
        Description  = 'Service applicatif metier'
    }
)

foreach ($svc in $svcAccounts) {
    $username    = $svc.Name
    $passwordTxt = $svc.Password
    $password    = ConvertTo-SecureString $passwordTxt -AsPlainText -Force

    try {
        $existing = Get-ADUser -Identity $username -ErrorAction SilentlyContinue
        if ($existing) {
            Set-ADAccountPassword -Identity $username -NewPassword $password -Reset
            Set-ADUser -Identity $username `
                -ServicePrincipalNames @{Replace=@($svc.SPN)} `
                -Description $svc.Description `
                -Enabled $true
            Write-Host "[i] Compte $username déjà existant, SPN et mot de passe mis à jour." -ForegroundColor Yellow
        }
        else {
            New-ADUser `
                -Name $username `
                -SamAccountName $username `
                -UserPrincipalName "$username@$Domain" `
                -AccountPassword $password `
                -Enabled $true `
                -PasswordNeverExpires $true `
                -ServicePrincipalNames $svc.SPN `
                -Description $svc.Description
            Write-Host "[+] Compte $username créé avec SPN $($svc.SPN)." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Échec création $username : $_"
    }
}

Write-Host "[*] 3 comptes SPN créés. 2 cassables (svc_sql, svc_iis), 1 résistant (svc_app)." -ForegroundColor Cyan
