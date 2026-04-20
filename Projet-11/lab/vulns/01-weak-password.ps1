<#
.SYNOPSIS
    V03 — Crée un compte utilisateur avec un mot de passe trivial (user-as-pass).

.DESCRIPTION
    Crée le compte 'test' dans l'Active Directory avec le mot de passe 'test'.
    Simule une erreur très courante : un compte de test créé à la va-vite avec
    un mot de passe identique au nom d'utilisateur.

    Ce compte constitue le point d'entrée initial de la chaîne d'attaque.
    Il permet au pentester de passer d'une position non authentifiée à une
    position authentifiée sur le domaine, débloquant la reconnaissance LDAP
    et toutes les étapes suivantes.

.NOTES
    Vulnérabilité référencée : V03 — Criticité : Critique
#>

[CmdletBinding()]
param(
    [string]$Domain    = 'corp.lab',
    [string]$DCName    = 'DC01',
    [string]$FSName    = 'FS01',
    [string]$WSName    = 'WS01'
)

$ErrorActionPreference = 'Stop'

$username = 'test'
$password = ConvertTo-SecureString 'test' -AsPlainText -Force

try {
    $existing = Get-ADUser -Identity $username -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "[i] Compte $username déjà existant, réinitialisation du mot de passe." -ForegroundColor Yellow
        Set-ADAccountPassword -Identity $username -NewPassword $password -Reset
        Set-ADUser -Identity $username -PasswordNeverExpires $true -Enabled $true
    }
    else {
        New-ADUser `
            -Name $username `
            -SamAccountName $username `
            -UserPrincipalName "$username@$Domain" `
            -AccountPassword $password `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -ChangePasswordAtLogon $false
        Write-Host "[+] Compte $username créé avec mot de passe '$username' (user-as-pass)." -ForegroundColor Green
    }
}
catch {
    Write-Error "Échec de la création du compte $username : $_"
}
