#!/bin/bash


# ===========================
# CONFIGURATION
# ===========================

# Serveur de stockage
BACKUP_SERVER="XXXX"
BACKUP_USER="rsync_user"

# Répertoires sources (sur la VM simulation)
SOURCE_SITE="/home/simulation/SITE"
SOURCE_RH="/home/simulation/RH"
SOURCE_TICKETS="/home/simulation/TICKETS"
SOURCE_FICHIERS="/home/simulation/FICHIERS"
SOURCE_MAILS="/home/simulation/MAILS"

# Répertoires de destination (sur le serveur de stockage)
DEST_BASE="/home/rsync_user"

# Fichier de log
LOG_DIR="/home/simulation/logs_backup"
LOG_FILE="$LOG_DIR/backup_complete_$(date +%Y%m%d_%H%M%S).log"

# Date et heure
DATE=$(date +%Y%m%d_%H%M%S)
DATE_READABLE=$(date '+%d/%m/%Y %H:%M:%S')

# ===========================
# VÉRIFICATIONS PRÉALABLES
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "SAUVEGARDE COMPLÈTE - STRATÉGIE 1" | tee -a "$LOG_FILE"
echo "Date de début : $DATE_READABLE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Créer le répertoire de logs s'il n'existe pas
mkdir -p "$LOG_DIR"

# Vérifier que les répertoires sources existent
for SRC in "$SOURCE_SITE" "$SOURCE_RH" "$SOURCE_TICKETS" "$SOURCE_FICHIERS" "$SOURCE_MAILS"; do
    if [ ! -d "$SRC" ]; then
        echo "❌ ERREUR : Le répertoire source $SRC n'existe pas !" | tee -a "$LOG_FILE"
        exit 1
    fi
done

# Tester la connexion SSH au serveur
echo "🔍 Test de connexion au serveur de sauvegarde..." | tee -a "$LOG_FILE"
if ! ssh -o ConnectTimeout=10 "$BACKUP_USER@$BACKUP_SERVER" exit; then
    echo "❌ ERREUR : Impossible de se connecter au serveur $BACKUP_SERVER" | tee -a "$LOG_FILE"
    exit 1
fi
echo "✅ Connexion SSH établie avec succès" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# ===========================
# FONCTION DE SAUVEGARDE
# ===========================

backup_complete() {
    local CONTEXT_NAME=$1      # Nom du contexte (ex: SITE, RH)
    local SOURCE_DIR=$2        # Répertoire source
    local DEST_SUBDIR=$3       # Sous-répertoire de destination (ex: SITE/complete)
    
    echo "▶ Sauvegarde complète de $CONTEXT_NAME..." | tee -a "$LOG_FILE"
    echo "  Source : $SOURCE_DIR" | tee -a "$LOG_FILE"
    echo "  Destination : $BACKUP_USER@$BACKUP_SERVER:$DEST_SUBDIR/" | tee -a "$LOG_FILE"
    
    # Créer le répertoire de destination sur le serveur distant
    ssh "$BACKUP_USER@$BACKUP_SERVER" "mkdir -p '$DEST_BASE/$DEST_SUBDIR/complete_$DATE'"
    
    # Exécuter rsync avec les options adaptées
    rsync -avzh \
        --delete \
        --itemize-changes \
        --log-file="$LOG_FILE" \
        "$SOURCE_DIR/" \
        "$BACKUP_USER@$BACKUP_SERVER:$DEST_BASE/$DEST_SUBDIR/complete_$DATE/"
    
    # Vérifier le code de retour de rsync
    if [ $? -eq 0 ]; then
        echo "✅ $CONTEXT_NAME : Sauvegarde complète réussie" | tee -a "$LOG_FILE"
    else
        echo "❌ $CONTEXT_NAME : Erreur lors de la sauvegarde complète" | tee -a "$LOG_FILE"
    fi
    echo "" | tee -a "$LOG_FILE"
}

# ===========================
# EXÉCUTION DES SAUVEGARDES
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "DÉBUT DES SAUVEGARDES COMPLÈTES" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Sauvegarder chaque contexte
backup_complete "SITE" "$SOURCE_SITE" "SITE/complete"
backup_complete "RH" "$SOURCE_RH" "RH/complete"
backup_complete "TICKETS" "$SOURCE_TICKETS" "TICKETS/complete"
backup_complete "FICHIERS" "$SOURCE_FICHIERS" "FICHIERS/complete"
backup_complete "MAILS" "$SOURCE_MAILS" "MAILS/complete"

# ===========================
# RÉSUMÉ FINAL
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "SAUVEGARDE COMPLÈTE TERMINÉE" | tee -a "$LOG_FILE"
echo "Date de fin : $(date '+%d/%m/%Y %H:%M:%S')" | tee -a "$LOG_FILE"
echo "Fichier de log : $LOG_FILE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

exit 0
