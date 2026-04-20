<#
.SYNOPSIS
    V08 + V09 — Crée deux comptes Domain Admin et prépare une session DA active
    sur un serveur membre (FS01).

.DESCRIPTION
    Cette étape combine plusieurs misconfigs critiques :

    V08 — Réutilisation du mot de passe Administrator local
          Force le même mot de passe Administrator local sur WS01 et FS01.
          C'est une dérive très courante quand il n'y a pas de LAPS : l'image
          de déploiement embarque un mot de passe partagé, et personne ne le
          rotate.

    V09 — Session Domain Admin sur serveur membre
          Crée deux comptes 'dadmin1' et 'dadmin2' membres du groupe Domain
          Admins, puis prépare une connexion RDP vers FS01 sous l'identité de
          dadmin1. Une fois l'utilisateur connecté, son hash NTLM reste en
          mémoire dans LSASS jusqu'au prochain redémarrage du serveur.

    L'automatisation de la connexion RDP n'est pas faite ici : la mise en
    place d'une session interactive doit rester un acte manuel pour préserver
    la fidélité au scénario réel. Une instruction claire est affichée à la
    fin du script.

.NOTES
    Vulnérabilités référencées : V08 + V09 — Criticité : Critique
#>

[CmdletBinding()]
param(
    [string]$Domain    = 'corp.lab',
    [string]$DCName    = 'DC01',
    [string]$FSName    = 'FS01',
    [string]$WSName    = 'WS01'
)

$ErrorActionPreference = 'Stop'

# Mot de passe Administrator local partagé (V08)
$localAdminPassword = 'L0c4lAdmin2026!'
$localAdminSecure   = ConvertTo-SecureString $localAdminPassword -AsPlainText -Force

# Comptes Domain Admin dadmin1 et dadmin2 (V09)
$daAccounts = @(
    @{ Name = 'dadmin1'; Password = 'D4rkAdm1n2026!'; Description = 'Administrateur de domaine' },
    @{ Name = 'dadmin2'; Password = 'Adm2nW0rkPass!'; Description = 'Administrateur de domaine secondaire' }
)

# 1. Création des comptes Domain Admin
foreach ($da in $daAccounts) {
    $username = $da.Name
    $password = ConvertTo-SecureString $da.Password -AsPlainText -Force

    try {
        $existing = Get-ADUser -Identity $username -ErrorAction SilentlyContinue
        if ($existing) {
            Set-ADAccountPassword -Identity $username -NewPassword $password -Reset
            Set-ADUser -Identity $username -Description $da.Description -Enabled $true
            Write-Host "[i] Compte $username déjà existant, mot de passe mis à jour." -ForegroundColor Yellow
        }
        else {
            New-ADUser `
                -Name $username `
                -SamAccountName $username `
                -UserPrincipalName "$username@$Domain" `
                -AccountPassword $password `
                -Enabled $true `
                -PasswordNeverExpires $true `
                -Description $da.Description
            Write-Host "[+] Compte $username créé." -ForegroundColor Green
        }

        # Ajout au groupe Domain Admins
        $isMember = Get-ADGroupMember -Identity 'Domain Admins' |
            Where-Object { $_.SamAccountName -eq $username }
        if (-not $isMember) {
            Add-ADGroupMember -Identity 'Domain Admins' -Members $username
            Write-Host "[+] $username ajouté à Domain Admins." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Échec création/promotion $username : $_"
    }
}

# 2. Réinitialisation des mots de passe Administrator locaux WS01 et FS01 (V08)
foreach ($computer in @($WSName, $FSName)) {
    try {
        Invoke-Command -ComputerName $computer -ScriptBlock {
            param($Pwd)
            $admin = Get-LocalUser -Name 'Administrator' -ErrorAction SilentlyContinue
            if ($admin) {
                $admin | Set-LocalUser -Password $Pwd
                Write-Host "[+] Mot de passe Administrator local réinitialisé sur $env:COMPUTERNAME"
            }
        } -ArgumentList $localAdminSecure
    }
    catch {
        Write-Warning "Impossible de réinitialiser Administrator local sur $computer : $_"
    }
}

# 3. Instructions manuelles pour V09
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " ÉTAPE MANUELLE — V09 : ouvrir une session DA sur $FSName" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Sur le poste d'admin, ouvrir une session RDP vers $FSName"
Write-Host "   mstsc /v:$FSName"
Write-Host ""
Write-Host "2. S'authentifier avec le compte $Domain\dadmin1"
Write-Host "   Mot de passe : D4rkAdm1n2026!"
Write-Host ""
Write-Host "3. Une fois la session ouverte, fermer la fenêtre RDP SANS se"
Write-Host "   déconnecter proprement (cliquer sur la croix). La session"
Write-Host "   reste ainsi active sur $FSName et le hash NTLM de dadmin1"
Write-Host "   sera présent dans LSASS jusqu'au prochain reboot."
Write-Host ""
Write-Host "4. Vérifier la session active depuis le poste d'admin :"
Write-Host "   query user /server:$FSName"
Write-Host ""
