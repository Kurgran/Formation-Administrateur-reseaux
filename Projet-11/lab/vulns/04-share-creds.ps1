<#
.SYNOPSIS
    V06 — Crée un partage SMB lisible par tout utilisateur authentifié, contenant
    un script PowerShell avec des credentials hardcodés.

.DESCRIPTION
    Sur FS01 :
      1. Crée le compte de service 'deploy_svc' (membre des admins locaux WS01)
      2. Crée le dossier C:\Configuration\Windows\Safety\Shell\Remote\Scripts\
      3. Pose admin.ps1 contenant les identifiants en clair de deploy_svc
      4. Partage C:\Configuration en SMB sous le nom 'Configuration', accessible
         à 'Authenticated Users' en lecture

    Reproduit l'erreur classique du script de déploiement automatique posé sur
    un partage "interne" pour permettre à l'équipe IT d'exécuter rapidement des
    tâches d'admin. Tout utilisateur authentifié peut lire le partage,
    récupérer le script, et donc les credentials.

.NOTES
    Vulnérabilité référencée : V06 — Criticité : Critique
#>

[CmdletBinding()]
param(
    [string]$Domain    = 'corp.lab',
    [string]$DCName    = 'DC01',
    [string]$FSName    = 'FS01',
    [string]$WSName    = 'WS01'
)

$ErrorActionPreference = 'Stop'

# 1. Création du compte de service deploy_svc
$svcUser     = 'deploy_svc'
$svcPassword = 'Depl0yP4ssw0rd'
$svcSecure   = ConvertTo-SecureString $svcPassword -AsPlainText -Force

try {
    $existing = Get-ADUser -Identity $svcUser -ErrorAction SilentlyContinue
    if ($existing) {
        Set-ADAccountPassword -Identity $svcUser -NewPassword $svcSecure -Reset
        Set-ADUser -Identity $svcUser -PasswordNeverExpires $true -Enabled $true
        Write-Host "[i] Compte $svcUser déjà existant, mot de passe mis à jour." -ForegroundColor Yellow
    }
    else {
        New-ADUser `
            -Name $svcUser `
            -SamAccountName $svcUser `
            -UserPrincipalName "$svcUser@$Domain" `
            -AccountPassword $svcSecure `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -Description 'Compte de deploiement automatise'
        Write-Host "[+] Compte $svcUser créé." -ForegroundColor Green
    }
}
catch {
    Write-Error "Échec création $svcUser : $_"
    return
}

# 2. Ajout de deploy_svc aux administrateurs locaux WS01
try {
    Invoke-Command -ComputerName $WSName -ScriptBlock {
        param($User, $Domain)
        $member = "$Domain\$User"
        $group = Get-LocalGroup -Name 'Administrators' -ErrorAction SilentlyContinue
        if ($group) {
            $existing = Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*\$User" }
            if (-not $existing) {
                Add-LocalGroupMember -Group 'Administrators' -Member $member
                Write-Host "[+] $member ajouté aux admins locaux de $env:COMPUTERNAME"
            }
            else {
                Write-Host "[i] $member déjà admin local de $env:COMPUTERNAME"
            }
        }
    } -ArgumentList $svcUser, ($Domain.Split('.')[0])
}
catch {
    Write-Warning "Impossible de promouvoir $svcUser admin local sur $WSName : $_"
}

# 3. Création du partage SMB sur FS01 avec script contenant credentials
try {
    Invoke-Command -ComputerName $FSName -ScriptBlock {
        param($SvcUser, $SvcPassword)

        $sharePath  = 'C:\Configuration'
        $scriptDir  = Join-Path $sharePath 'Windows\Safety\Shell\Remote\Scripts'
        $scriptPath = Join-Path $scriptDir 'admin.ps1'

        if (-not (Test-Path $scriptDir)) {
            New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
        }

        # Script avec credentials hardcodés (ce qu'on ne devrait JAMAIS faire)
        $scriptContent = @"
# Script de deploiement IT - executable a distance
# Auteur : equipe IT
# NE PAS MODIFIER SANS ACCORD

`$user = '$SvcUser'
`$pass = '$SvcPassword'
`$cred = New-Object System.Management.Automation.PSCredential(`$user, (ConvertTo-SecureString `$pass -AsPlainText -Force))

# Exemple : redemarrage du service IIS sur le poste cible
Invoke-Command -ComputerName `$args[0] -Credential `$cred -ScriptBlock {
    Restart-Service -Name 'W3SVC' -Force
}
"@

        Set-Content -Path $scriptPath -Value $scriptContent -Force
        Write-Host "[+] Script $scriptPath créé avec credentials hardcodés"

        # Création du partage SMB lisible par les utilisateurs authentifiés
        $share = Get-SmbShare -Name 'Configuration' -ErrorAction SilentlyContinue
        if (-not $share) {
            New-SmbShare `
                -Name 'Configuration' `
                -Path $sharePath `
                -ReadAccess 'Authenticated Users' `
                -Description 'Scripts de configuration IT'
            Write-Host "[+] Partage Configuration créé sur $env:COMPUTERNAME"
        }
        else {
            Write-Host "[i] Partage Configuration déjà présent sur $env:COMPUTERNAME"
        }
    } -ArgumentList $svcUser, $svcPassword
}
catch {
    Write-Error "Échec création partage Configuration sur $FSName : $_"
}

Write-Host "[*] V06 appliquée : credentials de $svcUser exposés sur \\$FSName\Configuration" -ForegroundColor Cyan
