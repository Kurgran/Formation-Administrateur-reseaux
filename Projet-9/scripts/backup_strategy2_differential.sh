#!/bin/bash


# ===========================
# CONFIGURATION
# ===========================

# Serveur de stockage
BACKUP_SERVER="XXXXX"
BACKUP_USER="rsync_user"

# Répertoire source
SOURCE_MACHINES="/home/simulation/MACHINES"

# Répertoire de destination
DEST_BASE="/home/rsync_user/MACHINES"

# Fichier de log
LOG_DIR="/home/simulation/logs_backup"
LOG_FILE="$LOG_DIR/backup_vm_differential_$(date +%Y%m%d_%H%M%S).log"

# Date
DATE=$(date +%Y%m%d_%H%M%S)
DATE_READABLE=$(date '+%d/%m/%Y %H:%M:%S')

# Période de rétention (nombre de sauvegardes différentielles à conserver)
RETENTION=7

# ===========================
# VÉRIFICATIONS PRÉALABLES
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "SAUVEGARDE DIFFÉRENTIELLE VMs - STRATÉGIE 2" | tee -a "$LOG_FILE"
echo "Date de début : $DATE_READABLE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

mkdir -p "$LOG_DIR"

# Vérifier le répertoire source
if [ ! -d "$SOURCE_MACHINES" ]; then
    echo "❌ ERREUR : Le répertoire $SOURCE_MACHINES n'existe pas !" | tee -a "$LOG_FILE"
    exit 1
fi

# Tester la connexion SSH
if ! ssh -o ConnectTimeout=10 "$BACKUP_USER@$BACKUP_SERVER" exit; then
    echo "❌ ERREUR : Impossible de se connecter au serveur $BACKUP_SERVER" | tee -a "$LOG_FILE"
    exit 1
fi

# ===========================
# RECHERCHE DE LA DERNIÈRE SAUVEGARDE COMPLÈTE
# ===========================

echo "🔍 Recherche de la dernière sauvegarde complète de référence..." | tee -a "$LOG_FILE"

LAST_COMPLETE=$(ssh "$BACKUP_USER@$BACKUP_SERVER" "find '$DEST_BASE/complete' -maxdepth 1 -type d -name 'complete_*' -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-")

if [ -z "$LAST_COMPLETE" ]; then
    echo "❌ ERREUR : Aucune sauvegarde complète trouvée !" | tee -a "$LOG_FILE"
    echo "ℹ️  Veuillez d'abord exécuter une sauvegarde complète." | tee -a "$LOG_FILE"
    exit 1
fi

echo "✅ Dernière sauvegarde complète trouvée : $LAST_COMPLETE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# ===========================
# SAUVEGARDE DIFFÉRENTIELLE
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "DÉBUT DE LA SAUVEGARDE DIFFÉRENTIELLE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Créer le répertoire de destination
DEST_PATH="$DEST_BASE/differential/differential_$DATE"
ssh "$BACKUP_USER@$BACKUP_SERVER" "mkdir -p '$DEST_PATH'"

echo "▶ Sauvegarde différentielle des VMs..." | tee -a "$LOG_FILE"
echo "  Source : $SOURCE_MACHINES/" | tee -a "$LOG_FILE"
echo "  Destination : $BACKUP_USER@$BACKUP_SERVER:$DEST_PATH/" | tee -a "$LOG_FILE"
echo "  Référence (comparaison) : $LAST_COMPLETE/" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Exécuter rsync avec --link-dest pointant vers la dernière complète
rsync -avzh \
    --progress \
    --partial \
    --append-verify \
    --itemize-changes \
    --link-dest="$LAST_COMPLETE" \
    --log-file="$LOG_FILE" \
    "$SOURCE_MACHINES/" \
    "$BACKUP_USER@$BACKUP_SERVER:$DEST_PATH/"

# Vérifier le résultat
if [ $? -eq 0 ]; then
    echo "✅ Sauvegarde différentielle des VMs réussie" | tee -a "$LOG_FILE"
    
    # Afficher l'espace utilisé (seules les différences)
    echo "" | tee -a "$LOG_FILE"
    echo "📊 Espace disque utilisé par cette différentielle :" | tee -a "$LOG_FILE"
    ssh "$BACKUP_USER@$BACKUP_SERVER" "du -sh '$DEST_PATH'" | tee -a "$LOG_FILE"
else
    echo "❌ Erreur lors de la sauvegarde différentielle des VMs" | tee -a "$LOG_FILE"
    exit 1
fi

# ===========================
# NETTOYAGE DES ANCIENNES SAUVEGARDES
# ===========================

echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "NETTOYAGE DES ANCIENNES SAUVEGARDES" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "🧹 Vérification de la période de rétention..." | tee -a "$LOG_FILE"
echo "  Période de rétention : $RETENTION sauvegardes" | tee -a "$LOG_FILE"

# Compter les sauvegardes différentielles
BACKUP_COUNT=$(ssh "$BACKUP_USER@$BACKUP_SERVER" "find '$DEST_BASE/differential' -maxdepth 1 -type d -name 'differential_*' | wc -l")
echo "  Nombre de sauvegardes différentielles actuelles : $BACKUP_COUNT" | tee -a "$LOG_FILE"

if [ "$BACKUP_COUNT" -gt "$RETENTION" ]; then
    TO_DELETE=$((BACKUP_COUNT - RETENTION))
    echo "  ⚠️  $TO_DELETE sauvegarde(s) différentielle(s) à supprimer" | tee -a "$LOG_FILE"
    
    # Lister les plus anciennes
    OLD_BACKUPS=$(ssh "$BACKUP_USER@$BACKUP_SERVER" "find '$DEST_BASE/differential' -maxdepth 1 -type d -name 'differential_*' -printf '%T@ %p\n' | sort -n | head -$TO_DELETE | cut -d' ' -f2-")
    
    # Supprimer
    while IFS= read -r BACKUP_DIR; do
        if [ -n "$BACKUP_DIR" ]; then
            echo "  🗑️  Suppression : $BACKUP_DIR" | tee -a "$LOG_FILE"
            ssh "$BACKUP_USER@$BACKUP_SERVER" "rm -rf '$BACKUP_DIR'"
        fi
    done <<< "$OLD_BACKUPS"
    
    echo "  ✅ Nettoyage terminé" | tee -a "$LOG_FILE"
else
    echo "  ℹ️  Aucun nettoyage nécessaire" | tee -a "$LOG_FILE"
fi

# ===========================
# RÉSUMÉ FINAL
# ===========================

echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "SAUVEGARDE DIFFÉRENTIELLE VMs TERMINÉE" | tee -a "$LOG_FILE"
echo "Date de fin : $(date '+%d/%m/%Y %H:%M:%S')" | tee -a "$LOG_FILE"
echo "Fichier de log : $LOG_FILE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

exit 0
