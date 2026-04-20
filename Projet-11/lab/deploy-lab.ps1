<#
.SYNOPSIS
    Orchestrateur de déploiement du lab AD vulnérable.

.DESCRIPTION
    Ce script suppose que les trois VMs (DC01, FS01, WS01) sont déjà créées
    sous Windows Server 2022, jointes au domaine corp.lab, et accessibles
    depuis le poste d'administration. Il applique les misconfigurations
    volontaires qui constituent la chaîne d'attaque du lab.

    À exécuter depuis un poste Windows avec les droits Domain Admin sur le lab.
    N'EST PAS DESTINÉ À TOURNER EN PRODUCTION.

.NOTES
    Lab strictement isolé. Ne pas exécuter hors d'un environnement dédié.
#>

[CmdletBinding()]
param(
    [string]$Domain    = 'corp.lab',
    [string]$DCName    = 'DC01',
    [string]$FSName    = 'FS01',
    [string]$WSName    = 'WS01'
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "[*] Déploiement du lab AD vulnérable ($Domain)" -ForegroundColor Cyan
Write-Host "[*] Cibles : $DCName, $FSName, $WSName" -ForegroundColor Cyan
Write-Host ""

# Confirmation avant exécution — garde-fou contre les erreurs de destination
$confirm = Read-Host "Confirmez-vous l'exécution sur le domaine '$Domain' ? (tapez OUI)"
if ($confirm -ne 'OUI') {
    Write-Warning "Abandon demandé par l'utilisateur."
    exit 1
}

# Application des misconfigs dans l'ordre
$vulnScripts = @(
    '01-weak-password.ps1',
    '02-ldap-description.ps1',
    '03-kerberoastable.ps1',
    '04-share-creds.ps1',
    '05-da-session.ps1'
)

foreach ($script in $vulnScripts) {
    $path = Join-Path $scriptRoot "vulns\$script"
    if (-not (Test-Path $path)) {
        Write-Warning "Script manquant : $path"
        continue
    }
    Write-Host "[+] Exécution : $script" -ForegroundColor Green
    try {
        & $path -Domain $Domain -DCName $DCName -FSName $FSName -WSName $WSName
    }
    catch {
        Write-Error "Échec sur $script : $_"
    }
    Write-Host ""
}

Write-Host "[*] Déploiement terminé. Le lab est prêt à être pentesté." -ForegroundColor Cyan
Write-Host "[*] Pour réinitialiser : ./reset-lab.ps1" -ForegroundColor Cyan
