#!/bin/bash
# ============================================
# Script : mount_v4.1.sh
# Version : 4.1 (AGDLP + Filtrage pré-montage)
# Auteur : Clément 
# Description : Monte uniquement les partages où l'utilisateur a au moins un accès (RW ou RO)
# ============================================

# --- 1. CONFIGURATION ---
SERVER="srv-ad-01.barzini.ba"
MOUNT_BASE="/mnt/barzini"
LOG_FILE="/var/log/mount_barzini.log"

# Options de montage Kerberos
MOUNT_OPTIONS="sec=krb5,vers=3.0,cruid=$(id -u),uid=$(id -u),gid=$(id -g),file_mode=0755,dir_mode=0755"

# Liste des partages standards
STANDARD_SHARES=("Direction" "Production" "Developpement" "Technique" "Graphisme" "Audio")

# ============================================
# 2. FONCTIONS
# ============================================

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "SUCCESS") echo -e "\033[0;32m[OK] $message\033[0m" ;;
        "ERROR")   echo -e "\033[0;31m[KO] $message\033[0m" ;;
        "WARNING") echo -e "\033[1;33m[WARN] $message\033[0m" ;;
        *)         echo -e "\033[0;34m[INFO] $message\033[0m" ;;
    esac

    echo "[$timestamp] [$(whoami)] [$level] $message" | sudo tee -a "$LOG_FILE" >/dev/null 2>&1
}

cleanup_mounts() {
    log_message "INFO" "Nettoyage de l'environnement..."
    
    if [ -d "$MOUNT_BASE" ]; then
        grep "$MOUNT_BASE" /proc/mounts | awk '{print $2}' | sort -r | while read -r mp; do
            log_message "WARNING" "Démontage forcé : $mp"
            sudo umount -f -l "$mp" 2>/dev/null
        done
    fi
    
    log_message "INFO" "Suppression des dossiers résiduels..."
    sudo rm -rf "${MOUNT_BASE:?}"/*
}

mount_share() {
    local share_name="$1"
    local local_folder="$2"
    local mount_point="${MOUNT_BASE}/${local_folder}"
    
    sudo mkdir -p "$mount_point"

    if grep -q "$mount_point" /proc/mounts; then
        log_message "WARNING" "Déjà monté : $local_folder"
        return
    fi

    log_message "INFO" "Montage : $share_name -> $local_folder"
    
    sudo mount -t cifs "//${SERVER}/${share_name}" "$mount_point" -o "$MOUNT_OPTIONS,rw" 2>/dev/null

    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Monté : $local_folder"
    else
        log_message "ERROR" "Échec : $share_name (accès refusé)"
        sudo rmdir "$mount_point" 2>/dev/null
    fi
}

has_access_to_share() {
    local share_name="$1"
    local share_lower=$(echo "$share_name" | tr '[:upper:]' '[:lower:]')
    
    # Vérifier si l'utilisateur a un DL_*_RW ou DL_*_RO pour ce partage
    if [[ "$USER_GROUPS" == *"dl_${share_lower}_rw"* ]] || [[ "$USER_GROUPS" == *"dl_${share_lower}_ro"* ]]; then
        return 0  # true
    else
        return 1  # false
    fi
}

# ============================================
# 3. LOGIQUE PRINCIPALE
# ============================================

main() {
    echo "--- MONTAGE BARZINI v4.1 (AGDLP + Filtrage) ---"
    
    # Vérification Kerberos
    if ! klist -s; then
        log_message "ERROR" "Pas de ticket Kerberos. Exécutez : kinit"
        exit 1
    fi

    cleanup_mounts
    sudo mkdir -p "$MOUNT_BASE"

    # Récupérer les groupes de l'utilisateur (en minuscules pour la comparaison)
    USER_GROUPS=$(id -Gn | tr '[:upper:]' '[:lower:]')
    log_message "INFO" "Groupes utilisateur : $USER_GROUPS"

    # 1. Partages universels (toujours montés)
    mount_share "Commun" "Commun"
    mount_share "Users/$(whoami)" "Personnel"

    # 2. Partages standards (filtrage basé sur les DL)
    for share in "${STANDARD_SHARES[@]}"; do
        if has_access_to_share "$share"; then
            mount_share "$share" "$share"
        else
            log_message "INFO" "Ignoré : $share (aucun accès DL)"
        fi
    done

    echo "--- FIN MONTAGE v4.1 ---"
    log_message "INFO" "Montages actifs :"
    mount | grep "$MOUNT_BASE" | awk '{print "  - " $3}'
}

main
