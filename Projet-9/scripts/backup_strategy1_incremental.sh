#!/bin/bash



# ===========================
# CONFIGURATION
# ===========================

# Serveur de stockage
BACKUP_SERVER="XXXXXXX"
BACKUP_USER="rsync_user"

# Répertoires sources
SOURCE_SITE="/home/simulation/SITE"
SOURCE_RH="/home/simulation/RH"
SOURCE_TICKETS="/home/simulation/TICKETS"
SOURCE_FICHIERS="/home/simulation/FICHIERS"
SOURCE_MAILS="/home/simulation/MAILS"

# Répertoires de destination
DEST_BASE="/home/rsync_user"

# Fichier de log
LOG_DIR="/home/simulation/logs_backup"
LOG_FILE="$LOG_DIR/backup_incremental_$(date +%Y%m%d_%H%M%S).log"

# Date et heure
DATE=$(date +%Y%m%d_%H%M%S)
DATE_READABLE=$(date '+%d/%m/%Y %H:%M:%S')

# Période de rétention (nombre de sauvegardes à conserver)
RETENTION=7

# ===========================
# VÉRIFICATIONS PRÉALABLES
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "SAUVEGARDE INCRÉMENTALE - STRATÉGIE 1" | tee -a "$LOG_FILE"
echo "Date de début : $DATE_READABLE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Créer le répertoire de logs
mkdir -p "$LOG_DIR"

# Vérifier les répertoires sources
for SRC in "$SOURCE_SITE" "$SOURCE_RH" "$SOURCE_TICKETS" "$SOURCE_FICHIERS" "$SOURCE_MAILS"; do
    if [ ! -d "$SRC" ]; then
        echo "❌ ERREUR : Le répertoire source $SRC n'existe pas !" | tee -a "$LOG_FILE"
        exit 1
    fi
done

# Tester la connexion SSH
echo "🔍 Test de connexion au serveur de sauvegarde..." | tee -a "$LOG_FILE"
if ! ssh -o ConnectTimeout=10 "$BACKUP_USER@$BACKUP_SERVER" exit; then
    echo "❌ ERREUR : Impossible de se connecter au serveur $BACKUP_SERVER" | tee -a "$LOG_FILE"
    exit 1
fi
echo "✅ Connexion SSH établie avec succès" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# ===========================
# FONCTION DE SAUVEGARDE INCRÉMENTALE
# ===========================

backup_incremental() {
    local CONTEXT_NAME=$1
    local SOURCE_DIR=$2
    local DEST_SUBDIR=$3
    
    echo "▶ Sauvegarde incrémentale de $CONTEXT_NAME..." | tee -a "$LOG_FILE"
    echo "  Source : $SOURCE_DIR" | tee -a "$LOG_FILE"
    
    # Trouver la dernière sauvegarde (complète ou incrémentale) pour --link-dest
    echo "  🔍 Recherche de la dernière sauvegarde de référence..." | tee -a "$LOG_FILE"
    
    # ================================================================
    # CORRECTION : Tri par nom de répertoire (alphabétique décroissant)
    # au lieu du mtime du filesystem (%T@).
    #
    # Pourquoi : Les noms suivent le format complete_YYYYMMDD_HHMMSS
    # ou incremental_YYYYMMDD_HHMMSS. Le tri alphabétique inverse
    # donne automatiquement le plus récent en premier, car YYYYMMDD
    # est naturellement triable.
    #
    # Avec l'ancien tri par mtime (%T@), le répertoire de la complète
    # avait souvent un mtime plus récent (modifié par des opérations
    # ultérieures), ce qui faisait toujours pointer --link-dest vers
    # la complète → comportement différentiel au lieu d'incrémental.
    # ================================================================
    LAST_BACKUP=$(ssh "$BACKUP_USER@$BACKUP_SERVER" \
        "find '$DEST_BASE/$DEST_SUBDIR' -maxdepth 2 -type d \
        \( -name 'complete_*' -o -name 'incremental_*' \) \
        | sort -r | head -1")
    
    if [ -z "$LAST_BACKUP" ]; then
        echo "  ⚠️  ATTENTION : Aucune sauvegarde de référence trouvée !" | tee -a "$LOG_FILE"
        echo "  ℹ️  Veuillez d'abord exécuter une sauvegarde complète." | tee -a "$LOG_FILE"
        echo "  ⏭️  Passage au contexte suivant..." | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
        return 1
    fi
    
    echo "  ✅ Dernière sauvegarde trouvée : $LAST_BACKUP" | tee -a "$LOG_FILE"
    
    # Créer le répertoire de destination pour l'incrémentale
    DEST_PATH="$DEST_BASE/$DEST_SUBDIR/incremental_$DATE"
    ssh "$BACKUP_USER@$BACKUP_SERVER" "mkdir -p '$DEST_PATH'"
    
    echo "  Destination : $BACKUP_USER@$BACKUP_SERVER:$DEST_PATH" | tee -a "$LOG_FILE"
    echo "  Référence (--link-dest) : $LAST_BACKUP" | tee -a "$LOG_FILE"
    
    # Exécuter rsync avec --link-dest
    rsync -avzh \
        --delete \
        --itemize-changes \
        --link-dest="$LAST_BACKUP" \
        --log-file="$LOG_FILE" \
        "$SOURCE_DIR/" \
        "$BACKUP_USER@$BACKUP_SERVER:$DEST_PATH/"
    
    if [ $? -eq 0 ]; then
        echo "✅ $CONTEXT_NAME : Sauvegarde incrémentale réussie" | tee -a "$LOG_FILE"
    else
        echo "❌ $CONTEXT_NAME : Erreur lors de la sauvegarde incrémentale" | tee -a "$LOG_FILE"
    fi
    echo "" | tee -a "$LOG_FILE"
}

# ===========================
# FONCTION DE NETTOYAGE (RÉTENTION)
# ===========================

cleanup_old_backups() {
    local CONTEXT_NAME=$1
    local DEST_SUBDIR=$2
    
    echo "🧹 Nettoyage des anciennes sauvegardes de $CONTEXT_NAME..." | tee -a "$LOG_FILE"
    echo "  Période de rétention : $RETENTION sauvegardes" | tee -a "$LOG_FILE"
    
    # Compter le nombre de sauvegardes incrémentales existantes
    BACKUP_COUNT=$(ssh "$BACKUP_USER@$BACKUP_SERVER" "find '$DEST_BASE/$DEST_SUBDIR' -maxdepth 2 -type d -name 'incremental_*' | wc -l")
    
    echo "  Nombre de sauvegardes incrémentales actuelles : $BACKUP_COUNT" | tee -a "$LOG_FILE"
    
    if [ "$BACKUP_COUNT" -gt "$RETENTION" ]; then
        # Calculer combien de sauvegardes à supprimer
        TO_DELETE=$((BACKUP_COUNT - RETENTION))
        echo "  ⚠️  $TO_DELETE sauvegarde(s) à supprimer" | tee -a "$LOG_FILE"
        
        # ================================================================
        # CORRECTION COHÉRENTE : Tri par nom (alphabétique croissant)
        # pour identifier les plus anciennes sauvegardes à supprimer.
        # Le tri croissant (sort) place les plus anciennes en premier.
        # ================================================================
        OLD_BACKUPS=$(ssh "$BACKUP_USER@$BACKUP_SERVER" \
            "find '$DEST_BASE/$DEST_SUBDIR' -maxdepth 2 -type d \
            -name 'incremental_*' | sort | head -$TO_DELETE")
        
        # Supprimer chaque sauvegarde obsolète
        while IFS= read -r BACKUP_DIR; do
            if [ -n "$BACKUP_DIR" ]; then
                echo "  🗑️  Suppression : $BACKUP_DIR" | tee -a "$LOG_FILE"
                ssh "$BACKUP_USER@$BACKUP_SERVER" "rm -rf '$BACKUP_DIR'"
            fi
        done <<< "$OLD_BACKUPS"
        
        echo "  ✅ Nettoyage terminé pour $CONTEXT_NAME" | tee -a "$LOG_FILE"
    else
        echo "  ℹ️  Aucun nettoyage nécessaire (nombre de sauvegardes < rétention)" | tee -a "$LOG_FILE"
    fi
    echo "" | tee -a "$LOG_FILE"
}

# ===========================
# EXÉCUTION DES SAUVEGARDES
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "DÉBUT DES SAUVEGARDES INCRÉMENTALES" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Sauvegarder chaque contexte
backup_incremental "SITE" "$SOURCE_SITE" "SITE"
backup_incremental "RH" "$SOURCE_RH" "RH"
backup_incremental "TICKETS" "$SOURCE_TICKETS" "TICKETS"
backup_incremental "FICHIERS" "$SOURCE_FICHIERS" "FICHIERS"
backup_incremental "MAILS" "$SOURCE_MAILS" "MAILS"

# ===========================
# NETTOYAGE DES ANCIENNES SAUVEGARDES
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "NETTOYAGE DES ANCIENNES SAUVEGARDES" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

cleanup_old_backups "SITE" "SITE"
cleanup_old_backups "RH" "RH"
cleanup_old_backups "TICKETS" "TICKETS"
cleanup_old_backups "FICHIERS" "FICHIERS"
cleanup_old_backups "MAILS" "MAILS"

# ===========================
# RÉSUMÉ FINAL
# ===========================

echo "========================================" | tee -a "$LOG_FILE"
echo "SAUVEGARDE INCRÉMENTALE TERMINÉE" | tee -a "$LOG_FILE"
echo "Date de fin : $(date '+%d/%m/%Y %H:%M:%S')" | tee -a "$LOG_FILE"
echo "Fichier de log : $LOG_FILE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

exit 0