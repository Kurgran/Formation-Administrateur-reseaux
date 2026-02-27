#!/bin/bash


# ===========================
# CONFIGURATION
# ===========================

# Serveur de stockage
BACKUP_SERVER="xxxx"
BACKUP_USER="rsync_user"

# Répertoire source (VMs)
SOURCE_MACHINES="/home/simulation/MACHINES"

# Répertoire de destination
DEST_BASE="/home/rsync_user/MACHINES"

# Fichier de log
LOG_DIR="/home/simulation/logs_backup"
LOG_FILE="$LOG_DIR/backup_vm_complete_$(date +%Y%m%d_%H%M%S).log"

# Date
DATE=$(date +%Y%m%d_%H%M%S)
DATE_READABLE=$(date '+%d/%m/%Y %H:%M:%S')

# ===========================
# VÉRIFICATIONS PRÉALABLES
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "SAUVEGARDE COMPLÈTE VMs - STRATÉGIE 2" | tee -a "$LOG_FILE"
echo "Date de début : $DATE_READABLE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

mkdir -p "$LOG_DIR"

# Vérifier le répertoire source
if [ ! -d "$SOURCE_MACHINES" ]; then
    echo "❌ ERREUR : Le répertoire $SOURCE_MACHINES n'existe pas !" | tee -a "$LOG_FILE"
    exit 1
fi

# Compter les VMs
VM_COUNT=$(find "$SOURCE_MACHINES" -maxdepth 1 -type f -name "*.qcow2" | wc -l)
if [ "$VM_COUNT" -eq 0 ]; then
    echo "⚠️  ATTENTION : Aucun fichier VM (.qcow2) trouvé dans $SOURCE_MACHINES" | tee -a "$LOG_FILE"
    exit 1
fi
echo "ℹ️  Nombre de VMs à sauvegarder : $VM_COUNT" | tee -a "$LOG_FILE"

# Tester la connexion SSH
echo "🔍 Test de connexion au serveur de sauvegarde..." | tee -a "$LOG_FILE"
if ! ssh -o ConnectTimeout=10 "$BACKUP_USER@$BACKUP_SERVER" exit; then
    echo "❌ ERREUR : Impossible de se connecter au serveur $BACKUP_SERVER" | tee -a "$LOG_FILE"
    exit 1
fi
echo "✅ Connexion SSH établie avec succès" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# ===========================
# SAUVEGARDE COMPLÈTE DES VMs
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "DÉBUT DE LA SAUVEGARDE COMPLÈTE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Créer le répertoire de destination
DEST_PATH="$DEST_BASE/complete/complete_$DATE"
ssh "$BACKUP_USER@$BACKUP_SERVER" "mkdir -p '$DEST_PATH'"

echo "▶ Sauvegarde de $VM_COUNT machine(s) virtuelle(s)..." | tee -a "$LOG_FILE"
echo "  Source : $SOURCE_MACHINES/" | tee -a "$LOG_FILE"
echo "  Destination : $BACKUP_USER@$BACKUP_SERVER:$DEST_PATH/" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Exécuter rsync
rsync -avzh \
    --progress \
    --partial \
    --itemize-changes \
    --log-file="$LOG_FILE" \
    "$SOURCE_MACHINES/" \
    "$BACKUP_USER@$BACKUP_SERVER:$DEST_PATH/"

# Vérifier le résultat
if [ $? -eq 0 ]; then
    echo "✅ Sauvegarde complète des VMs réussie" | tee -a "$LOG_FILE"
    
    # Afficher l'espace utilisé
    echo "" | tee -a "$LOG_FILE"
    echo "📊 Espace disque utilisé par la sauvegarde :" | tee -a "$LOG_FILE"
    ssh "$BACKUP_USER@$BACKUP_SERVER" "du -sh '$DEST_PATH'" | tee -a "$LOG_FILE"
else
    echo "❌ Erreur lors de la sauvegarde complète des VMs" | tee -a "$LOG_FILE"
    exit 1
fi

# ===========================
# RÉSUMÉ FINAL
# ===========================

echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "SAUVEGARDE COMPLÈTE VMs TERMINÉE" | tee -a "$LOG_FILE"
echo "Date de fin : $(date '+%d/%m/%Y %H:%M:%S')" | tee -a "$LOG_FILE"
echo "Fichier de log : $LOG_FILE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

exit 0
