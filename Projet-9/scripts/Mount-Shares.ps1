<#
.SYNOPSIS
    Script de montage des partages réseau Barzini - Version 4 (AGDLP)

.DESCRIPTION
    Monte les lecteurs réseaux selon les groupes DL (Domain Local).
    La logique de sécurité est entièrement gérée par Active Directory via les ACL.
    
    Architecture :
    - Filtrage pré-montage basé sur l'appartenance aux groupes DL
    - Montage uniquement des partages où l'utilisateur a au moins un accès (RW ou RO)
    - Les permissions effectives sont contrôlées par Windows Server via les ACL NTFS

.NOTES
    Auteur  : Clément 
    Version : 4.0 - Conforme AGDLP, logique de sécurité dans AD
#>

#Requires -Version 5.1

# ============================================
# 1. CONFIGURATION
# ============================================

$SERVER = "\\SRV-AD-01.barzini.ba"
$LOG_PATH = "$env:TEMP\MountShares_v4.log"

# Mapping des partages standards
$SHARE_MAPPINGS = @{
    "Direction"     = @{Letter="Z:"; Name="Direction Generale"}
    "Production"    = @{Letter="P:"; Name="Production"}
    "Developpement" = @{Letter="V:"; Name="Developpement"}
    "Technique"     = @{Letter="T:"; Name="Technique"}
    "Graphisme"     = @{Letter="G:"; Name="Graphisme"}
    "Audio"         = @{Letter="A:"; Name="Audio"}
}

$COMMON_SHARE   = @{Letter="S:"; Share="Commun"; Name="Partage Commun"}
$PERSONAL_DRIVE = "H:"

# ============================================
# 2. FONCTIONS
# ============================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LOG_PATH -Value $logLine -ErrorAction SilentlyContinue
    
    $color = switch ($Level) {
        "ERROR"   { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default   { "Cyan" }
    }
    Write-Host $logLine -ForegroundColor $color
}

function Remove-ExistingDrives {
    Write-Log "Nettoyage des lecteurs existants..." "INFO"
    
    $drives = Get-WmiObject -Class Win32_MappedLogicalDisk -ErrorAction SilentlyContinue
    foreach ($drive in $drives) {
        $id = $drive.DeviceID
        $null = cmd /c "net use $id /delete /yes" 2>&1
    }
}

function Mount-Drive {
    param(
        [string]$Letter,
        [string]$SharePath,
        [string]$Description
    )

    if (Test-Path $Letter) {
        Write-Log "Lecteur $Letter déjà utilisé, ignoré" "WARNING"
        return $false
    }

    $cmdArgs = "use $Letter $SharePath /persistent:yes"
    $proc = Start-Process -FilePath "net.exe" -ArgumentList $cmdArgs -NoNewWindow -Wait -PassThru

    if ($proc.ExitCode -eq 0) {
        Write-Log "Monté : $Description sur $Letter" "SUCCESS"
        return $true
    }
    else {
        Write-Log "Échec montage : $SharePath (accès refusé)" "ERROR"
        return $false
    }
}

function Get-ADGroupsNative {
    try {
        $searcher = [adsisearcher]"(sAMAccountName=$env:USERNAME)"
        $result = $searcher.FindOne()
        
        $groups = @()
        if ($result -ne $null) {
            foreach ($grp in $result.Properties["memberof"]) {
                if ($grp -match "^CN=([^,]+)") {
                    $groups += $matches[1].ToUpper()
                }
            }
        }
        return $groups
    }
    catch {
        Write-Log "Erreur LDAP : $_" "ERROR"
        return @()
    }
}

function Get-AuthorizedShares {
    param([string[]]$UserGroups)
    
    $authorizedShares = @()
    
    # Mapping GG → Partages selon la PSI Barzini
    
    # Direction → accès à tous les partages (RO sauf Direction en RW)
    if ($UserGroups -contains "GG_DIRECTION") {
        $authorizedShares += @("Direction", "Production", "Developpement", "Technique", "Graphisme", "Audio")
    }
    
    # Développement → Dev + Graphisme + Audio (RW sur les 3)
    if ($UserGroups -contains "GG_DEVELOPPEMENT") {
        $authorizedShares += @("Developpement", "Graphisme", "Audio")
    }
    
    # Graphisme → Graphisme uniquement
    if ($UserGroups -contains "GG_GRAPHISME") {
        $authorizedShares += "Graphisme"
    }
    
    # Audio → Audio uniquement
    if ($UserGroups -contains "GG_AUDIO") {
        $authorizedShares += "Audio"
    }
    
    # Production → Production uniquement
    if ($UserGroups -contains "GG_PRODUCTION") {
        $authorizedShares += "Production"
    }
    
    # Technique → Technique + accès RO à tous les autres
    if ($UserGroups -contains "GG_TECHNIQUE") {
        $authorizedShares += @("Technique", "Direction", "Production", "Developpement", "Graphisme", "Audio")
    }
    
    # Dédoublonnage
    return ($authorizedShares | Select-Object -Unique)
}

# ============================================
# 4. ORCHESTRATION
# ============================================

Write-Log "--- Démarrage Script V4 (AGDLP) ---" "INFO"
Write-Log "Utilisateur : $env:USERNAME" "INFO"

# Nettoyage
Remove-ExistingDrives
Start-Sleep -Milliseconds 200

# Récupération des groupes
$userGroups = Get-ADGroupsNative
Write-Log "Groupes détectés : $($userGroups.Count)" "INFO"

# Montage partage commun (universel)
Mount-Drive -Letter $COMMON_SHARE.Letter `
            -SharePath "$SERVER\$($COMMON_SHARE.Share)" `
            -Description $COMMON_SHARE.Name

# Montage des partages standards (avec filtrage GG)
$authorizedShares = Get-AuthorizedShares -UserGroups $userGroups
Write-Log "Partages autorisés : $($authorizedShares -join ', ')" "INFO"

foreach ($shareName in $SHARE_MAPPINGS.Keys) {
    if ($authorizedShares -contains $shareName) {
        $map = $SHARE_MAPPINGS[$shareName]
        Mount-Drive -Letter $map.Letter `
                    -SharePath "$SERVER\$shareName" `
                    -Description $map.Name
    }
    else {
        Write-Log "Ignoré : $shareName (non autorisé)" "INFO"
    }
}

# Dossier personnel
Mount-Drive -Letter $PERSONAL_DRIVE `
            -SharePath "$SERVER\Users\$env:USERNAME" `
            -Description "Espace Personnel"

Write-Log "--- Fin Script V4 ---" "SUCCESS"
