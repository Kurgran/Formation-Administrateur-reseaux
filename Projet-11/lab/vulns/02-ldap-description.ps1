<#
.SYNOPSIS
    V04 — Stocke un mot de passe en clair dans le champ description LDAP.

.DESCRIPTION
    Crée un compte 'helpdesk01' avec un mot de passe puis stocke ce mot de passe
    en clair dans l'attribut 'description' de l'objet LDAP.

    Ce champ est lisible par tout utilisateur authentifié du domaine. C'est une
    erreur classique : un admin qui communique un mot de passe temporaire à un
    collaborateur l'écrit dans la description "pour s'en souvenir", et oublie
    de le retirer.

.NOTES
    Vulnérabilité référencée : V04 — Criticité : Critique
#>

[CmdletBinding()]
param(
    [string]$Domain    = 'corp.lab',
    [string]$DCName    = 'DC01',
    [string]$FSName    = 'FS01',
    [string]$WSName    = 'WS01'
)

$ErrorActionPreference = 'Stop'

$username     = 'helpdesk01'
$passwordText = 'Helpdesk2026!'
$password     = ConvertTo-SecureString $passwordText -AsPlainText -Force
$description  = "Compte temporaire - Mot de passe '$passwordText'"

try {
    $existing = Get-ADUser -Identity $username -ErrorAction SilentlyContinue
    if ($existing) {
        Set-ADAccountPassword -Identity $username -NewPassword $password -Reset
        Set-ADUser -Identity $username -Description $description -Enabled $true
        Write-Host "[i] Compte $username déjà existant, description et mot de passe mis à jour." -ForegroundColor Yellow
    }
    else {
        New-ADUser `
            -Name $username `
            -SamAccountName $username `
            -UserPrincipalName "$username@$Domain" `
            -AccountPassword $password `
            -Description $description `
            -Enabled $true `
            -PasswordNeverExpires $true
        Write-Host "[+] Compte $username créé avec MDP dans description LDAP." -ForegroundColor Green
    }

    # Ajout au groupe IT Support (crée le groupe s'il n'existe pas)
    $group = Get-ADGroup -Filter "Name -eq 'IT Support'" -ErrorAction SilentlyContinue
    if (-not $group) {
        New-ADGroup -Name 'IT Support' -GroupScope Global -GroupCategory Security
    }
    Add-ADGroupMember -Identity 'IT Support' -Members $username -ErrorAction SilentlyContinue
}
catch {
    Write-Error "Échec de la création de $username : $_"
}
