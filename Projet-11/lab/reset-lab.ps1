<#
.SYNOPSIS
    Réinitialise le lab AD vulnérable à un état propre.

.DESCRIPTION
    Supprime les comptes et credentials injectés par deploy-lab.ps1 :
    - Suppression du compte test, helpdesk01, svc_sql, svc_iis, svc_app,
      deploy_svc, dadmin1, dadmin2
    - Nettoyage du champ description LDAP de helpdesk01
    - Suppression du partage Configuration sur FS01 et du script admin.ps1
    - Réinitialisation des mots de passe administrator locaux

    Utile pour rejouer le pentest après avoir testé une remédiation.

.NOTES
    À exécuter depuis un poste Windows avec les droits Domain Admin sur le lab.
#>

[CmdletBinding()]
param(
    [string]$Domain = 'corp.lab',
    [string]$FSName = 'FS01'
)

$ErrorActionPreference = 'Continue'

Write-Host "[*] Réinitialisation du lab AD ($Domain)" -ForegroundColor Cyan

# Suppression des comptes utilisateurs injectés
$accountsToRemove = @(
    'test', 'helpdesk01',
    'svc_sql', 'svc_iis', 'svc_app',
    'deploy_svc', 'dadmin1', 'dadmin2'
)

foreach ($account in $accountsToRemove) {
    try {
        $user = Get-ADUser -Identity $account -ErrorAction SilentlyContinue
        if ($user) {
            Remove-ADUser -Identity $account -Confirm:$false
            Write-Host "[-] Compte supprimé : $account" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "Impossible de supprimer $account : $_"
    }
}

# Suppression du partage Configuration sur FS01
try {
    Invoke-Command -ComputerName $FSName -ScriptBlock {
        $share = Get-SmbShare -Name 'Configuration' -ErrorAction SilentlyContinue
        if ($share) {
            Remove-SmbShare -Name 'Configuration' -Force
            Write-Host "[-] Partage Configuration supprimé sur $env:COMPUTERNAME"
        }
        $scriptPath = 'C:\Configuration\Windows\Safety\Shell\Remote\Scripts\admin.ps1'
        if (Test-Path $scriptPath) {
            Remove-Item -Path 'C:\Configuration' -Recurse -Force
            Write-Host "[-] Dossier C:\Configuration supprimé"
        }
    } -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Nettoyage du partage : $_"
}

Write-Host "[*] Réinitialisation terminée." -ForegroundColor Cyan
Write-Host "[*] Pensez à réinitialiser manuellement les mots de passe Administrator" -ForegroundColor Cyan
Write-Host "    locaux sur WS01 et FS01 si vous voulez repartir de zéro." -ForegroundColor Cyan
