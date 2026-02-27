#!/bin/bash


# ===========================
# CONFIGURATION
# ===========================

BACKUP_SERVER="XXXX"
BACKUP_USER="rsync_user"
DEST_BASE="/home/rsync_user/MACHINES"

# Fichier de log
LOG_DIR="/home/simulation/logs_backup"
LOG_FILE="$LOG_DIR/restore_vm_$(date +%Y%m%d_%H%M%S).log"

DATE_READABLE=$(date '+%d/%m/%Y %H:%M:%S')

# ===========================
# INTERFACE UTILISATEUR
# ===========================

echo "========================================"
echo "RESTAURATION DE VM - STRATÉGIE 2"
echo "========================================"
echo ""

mkdir -p "$LOG_DIR"

echo "Début de la restauration : $DATE_READABLE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# ===========================
# LISTER LES SAUVEGARDES DISPONIBLES
# ===========================

echo "🔍 Recherche des sauvegardes disponibles..." | tee -a "$LOG_FILE"

# Récupérer toutes les sauvegardes (complètes et différentielles)
BACKUPS=$(ssh "$BACKUP_USER@$BACKUP_SERVER" "find '$DEST_BASE' -maxdepth 2 -type d \( -name 'complete_*' -o -name 'differential_*' \) -printf '%T@ %p\n' | sort -rn")

if [ -z "$BACKUPS" ]; then
    echo "❌ Aucune sauvegarde de VM trouvée" | tee -a "$LOG_FILE"
    exit 1
fi

# Afficher les sauvegardes
echo "Sauvegardes disponibles :" | tee -a "$LOG_FILE"
echo "$BACKUPS" | nl -w2 -s') ' | while read line; do
    echo "$line" | tee -a "$LOG_FILE"
done

BACKUP_COUNT=$(echo "$BACKUPS" | wc -l)

echo ""
read -p "Sélectionnez la sauvegarde à restaurer (1-$BACKUP_COUNT) : " BACKUP_CHOICE

# Extraire la sauvegarde choisie
SELECTED_BACKUP=$(echo "$BACKUPS" | sed -n "${BACKUP_CHOICE}p" | awk '{print $2}')

if [ -z "$SELECTED_BACKUP" ]; then
    echo "❌ Choix invalide" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Sauvegarde sélectionnée : $SELECTED_BACKUP" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# ===========================
# LISTER LES VMs DANS LA SAUVEGARDE
# ===========================

echo "🔍 Listage des VMs dans la sauvegarde..." | tee -a "$LOG_FILE"

# Récupérer la liste des fichiers VM
VMS=$(ssh "$BACKUP_USER@$BACKUP_SERVER" "find '$SELECTED_BACKUP' -maxdepth 1 -type f -name '*.qcow2' -printf '%f\n' | sort")

if [ -z "$VMS" ]; then
    echo "❌ Aucun fichier VM trouvé dans cette sauvegarde" | tee -a "$LOG_FILE"
    exit 1
fi

# Afficher les VMs
echo "VMs disponibles :" | tee -a "$LOG_FILE"
echo "$VMS" | nl -w2 -s') ' | while read line; do
    echo "$line"
done

VM_COUNT=$(echo "$VMS" | wc -l)

echo ""
read -p "Sélectionnez la VM à restaurer (1-$VM_COUNT, ou 0 pour toutes) : " VM_CHOICE

if [ "$VM_CHOICE" -eq 0 ]; then
    SELECTED_VMS="$VMS"
    echo "Restauration de toutes les VMs" | tee -a "$LOG_FILE"
else
    SELECTED_VMS=$(echo "$VMS" | sed -n "${VM_CHOICE}p")
    if [ -z "$SELECTED_VMS" ]; then
        echo "❌ Choix invalide" | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "VM sélectionnée : $SELECTED_VMS" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"

# ===========================
# SÉLECTION DE LA DESTINATION
# ===========================

DEFAULT_RESTORE_DIR="/home/simulation/MACHINES_RESTORE"

echo "Destination de la restauration :" | tee -a "$LOG_FILE"
echo "Par défaut : $DEFAULT_RESTORE_DIR" | tee -a "$LOG_FILE"
read -p "Appuyer sur Entrée pour accepter, ou saisir un autre chemin : " RESTORE_DIR

if [ -z "$RESTORE_DIR" ]; then
    RESTORE_DIR="$DEFAULT_RESTORE_DIR"
fi

# Créer le répertoire
mkdir -p "$RESTORE_DIR"

echo "Destination : $RESTORE_DIR" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# ===========================
# CONFIRMATION
# ===========================

echo "========================================"
echo "RÉSUMÉ DE LA RESTAURATION"
echo "========================================"
echo "Sauvegarde    : $SELECTED_BACKUP"
echo "VM(s)         : $(echo "$SELECTED_VMS" | wc -l) fichier(s)"
echo "Destination   : $RESTORE_DIR"
echo "========================================"
echo ""

read -p "Confirmer la restauration ? (oui/non) : " CONFIRM

if [ "$CONFIRM" != "oui" ]; then
    echo "❌ Restauration annulée" | tee -a "$LOG_FILE"
    exit 0
fi

# ===========================
# RESTAURATION
# ===========================

echo "" | tee -a "$LOG_FILE"
echo "▶ Restauration en cours..." | tee -a "$LOG_FILE"
echo "  Cette opération peut prendre plusieurs minutes (gros fichiers)..." | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Restaurer chaque VM sélectionnée
while IFS= read -r VM_FILE; do
    if [ -n "$VM_FILE" ]; then
        echo "  📦 Restauration de $VM_FILE..." | tee -a "$LOG_FILE"
        
        rsync -avzh \
            --progress \
            --partial \
            --log-file="$LOG_FILE" \
            "$BACKUP_USER@$BACKUP_SERVER:$SELECTED_BACKUP/$VM_FILE" \
            "$RESTORE_DIR/"
        
        if [ $? -eq 0 ]; then
            echo "  ✅ $VM_FILE restaurée avec succès" | tee -a "$LOG_FILE"
        else
            echo "  ❌ Erreur lors de la restauration de $VM_FILE" | tee -a "$LOG_FILE"
        fi
    fi
done <<< "$SELECTED_VMS"

# ===========================
# RÉSUMÉ FINAL
# ===========================

echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "RESTAURATION DE VM TERMINÉE" | tee -a "$LOG_FILE"
echo "Date de fin : $(date '+%d/%m/%Y %H:%M:%S')" | tee -a "$LOG_FILE"
echo "Répertoire de restauration : $RESTORE_DIR" | tee -a "$LOG_FILE"
echo "Fichier de log : $LOG_FILE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

exit 0
