# Backup Rsync + SSH — Solution de sauvegarde incrémentale & différentielle

**Description courte** : Mise en place d'une solution de sauvegarde automatisée via rsync over SSH, avec deux stratégies complémentaires (incrémentale et différentielle), sur infrastructure virtualisée Proxmox.

**Contexte homelab** : Déployé sur Proxmox — deux VMs Debian 12 Server en réseau local isolé.

**Date** : Janvier 2026

---

## 📋 Vue d'ensemble

Ce projet R&D répond à un besoin concret de résilience informatique : remplacer une solution de sauvegarde devenue incompatible avec une infrastructure virtualisée. Deux stratégies distinctes ont été testées et implémentées : une sauvegarde incrémentale des contextes métier (données applicatives), et une sauvegarde différentielle des machines virtuelles complètes. L'ensemble est automatisé via crontab et intégralement tracé via des fichiers de log horodatés.

**Composants principaux :**
- **VM Client (simulation)** : Héberge les données sources simulant les contextes métier et les fichiers volumieux représentant des VMs
- **VM Serveur de stockage** : Reçoit toutes les sauvegardes, organisées par contexte et par stratégie
- **Scripts Bash** : 7 scripts couvrant sauvegardes complètes, incrémentales, différentielles et leurs restaurations respectives

---

## 🏗️ Architecture

```
┌─────────────────────────────┐        SSH + rsync         ┌──────────────────────────────┐
│     VM CLIENT (simulation)  │ ─────────────────────────► │   VM SERVEUR DE STOCKAGE     │
│       10.0.50.20            │    Authentification         │       10.0.50.10             │
│                             │    par clé asymétrique      │                              │
│  /home/sysadmin/            │                             │  /home/rsync_user/           │
│  ├── SITE/                  │                             │  ├── SITE/                   │
│  ├── RH/                    │                             │  │   ├── complete/            │
│  ├── TICKETS/               │                             │  │   └── incremental/         │
│  ├── FICHIERS/              │                             │  ├── RH/                     │
│  ├── MAILS/                 │                             │  ├── TICKETS/                │
│  └── VM_IMAGES/             │                             │  ├── FICHIERS/               │
│      (fichiers lourds)      │                             │  ├── MAILS/                  │
│                             │                             │  └── MACHINES/               │
│  /home/sysadmin/logs_backup/│                             │      (sauvegarde différent.) │
└─────────────────────────────┘                             └──────────────────────────────┘
           │                                                           │
           └──────────────── Proxmox Hypervisor ─────────────────────┘
                              (réseau interne isolé)
```

**Cycle de sauvegarde Stratégie 1 (données métier) :**
```
Dimanche  → Sauvegarde COMPLÈTE (référence hebdomadaire)
Lu → Sa   → Sauvegardes INCRÉMENTALES (delta depuis la dernière sauvegarde)
            Chaque incrémentale utilise --link-dest pour les hard links
            Rétention : 7 sauvegardes conservées
```

**Cycle de sauvegarde Stratégie 2 (VMs complètes) :**
```
Dimanche  → Sauvegarde COMPLÈTE (référence)
Lu → Sa   → Sauvegardes DIFFÉRENTIELLES (delta depuis la référence du dimanche)
            La référence est toujours la sauvegarde complète du dimanche
```

**Infrastructure :**
- **Plateforme** : Proxmox VE — 2 VMs Debian 12 Server (minimal, sans GUI)
- **Ressources** : 2 vCPU / 2 Go RAM / 100 Go disque dynamique chacune
- **Réseau** : Réseau interne Proxmox isolé — `10.0.50.0/24`
- **Stockage** : Volumes locaux Proxmox (format qcow2)

---

## ⚙️ Prérequis

**Versions testées :**
- rsync : 3.2.7
- OpenSSH : 9.2p1
- OS : Debian 12 (Bookworm) — installation minimale

**Dépendances :**
```bash
# Sur la VM client
sudo apt update && sudo apt install -y rsync openssh-client

# Sur la VM serveur
sudo apt update && sudo apt install -y rsync openssh-server
```

**Accès réseau requis :**
- Port `22` (SSH) : Communication rsync entre client et serveur

---

## 🚀 Installation

### Étape 1 : Créer l'utilisateur dédié sur le serveur de stockage

```bash
# Sur le serveur (10.0.50.10)
sudo useradd -m -s /bin/bash rsync_user
sudo passwd rsync_user

# Créer l'arborescence de destination
sudo -u rsync_user mkdir -p /home/rsync_user/{SITE,RH,TICKETS,FICHIERS,MAILS}/{complete,incremental}
sudo -u rsync_user mkdir -p /home/rsync_user/MACHINES
```

**Explication** : On crée un compte non-root dédié aux opérations de sauvegarde. Le principe du moindre privilège s'applique ici : rsync n'a besoin que d'accéder à son répertoire de stockage, pas aux ressources système.

### Étape 2 : Configurer l'authentification SSH par clé asymétrique

```bash
# Sur la VM client (10.0.50.20) — générer la paire de clés
ssh-keygen -t ed25519 -C "backup_rsync_key" -f ~/.ssh/backup_key

# Copier la clé publique sur le serveur
ssh-copy-id -i ~/.ssh/backup_key.pub rsync_user@10.0.50.10

# Tester la connexion sans mot de passe
ssh -i ~/.ssh/backup_key rsync_user@10.0.50.10
```

**Points d'attention :**
- Utiliser `ed25519` plutôt que RSA 2048 : plus court, plus sécurisé, recommandé en 2024+
- La clé privée reste sur le client — **ne jamais la copier ailleurs**
- Vérifier les permissions : `chmod 600 ~/.ssh/backup_key`

### Étape 3 : Déployer les scripts de sauvegarde

```bash
# Sur la VM client
git clone https://github.com/<votre-username>/backup-rsync-ssh.git
cd backup-rsync-ssh/scripts
chmod +x *.sh
```

**Adapter les variables de configuration** dans chaque script :
```bash
# Variables à modifier selon votre environnement
BACKUP_SERVER="10.0.50.10"       # IP du serveur de stockage
BACKUP_USER="rsync_user"          # Utilisateur SSH dédié
SSH_KEY="~/.ssh/backup_key"       # Chemin vers la clé privée SSH
RETENTION=7                        # Nombre de sauvegardes à conserver
```

### Étape 4 : Configurer la planification cron

```bash
# Éditer la crontab de l'utilisateur courant
crontab -e
```

```bash
# Contenu de la crontab
# ┌───────────── minute (0-59)
# │ ┌───────────── heure (0-23)
# │ │ ┌───────────── jour du mois (1-31)
# │ │ │ ┌───────────── mois (1-12)
# │ │ │ │ ┌───────────── jour de la semaine (0=dimanche)
# │ │ │ │ │

# Stratégie 1 — Sauvegarde complète (dimanche à 2h00)
0 2 * * 0 /home/sysadmin/scripts/backup_complete_s1.sh >> /home/sysadmin/logs_backup/cron_s1.log 2>&1

# Stratégie 1 — Sauvegarde incrémentale (lundi-samedi à 2h00)
0 2 * * 1-6 /home/sysadmin/scripts/backup_incremental_s1.sh >> /home/sysadmin/logs_backup/cron_s1.log 2>&1

# Stratégie 2 — Sauvegarde complète VMs (dimanche à 3h00)
0 3 * * 0 /home/sysadmin/scripts/backup_complete_s2.sh >> /home/sysadmin/logs_backup/cron_s2.log 2>&1

# Stratégie 2 — Sauvegarde différentielle VMs (lundi-samedi à 3h00)
0 3 * * 1-6 /home/sysadmin/scripts/backup_differential_s2.sh >> /home/sysadmin/logs_backup/cron_s2.log 2>&1
```

---

## 🔧 Configuration

### Options rsync utilisées

**Stratégie 1 — Incrémentale avec hard links (`--link-dest`)**
```bash
rsync -avz --delete \
  --link-dest="/home/rsync_user/SITE/incremental/latest" \
  -e "ssh -i ~/.ssh/backup_key -o StrictHostKeyChecking=no" \
  /home/sysadmin/SITE/ \
  rsync_user@10.0.50.10:/home/rsync_user/SITE/incremental/$(date +%Y%m%d_%H%M%S)/
```

| Option | Rôle |
|---|---|
| `-a` | Mode archive : préserve permissions, timestamps, liens symboliques, owner |
| `-v` | Verbose : affiche les fichiers transférés (pour les logs) |
| `-z` | Compression des données en transit |
| `--delete` | Supprime sur la destination les fichiers supprimés à la source |
| `--link-dest` | Crée des hard links vers les fichiers inchangés (économie d'espace majeure) |
| `-e "ssh -i ..."` | Spécifie la commande SSH avec la clé dédiée |

**Stratégie 2 — Différentielle (référence fixe du dimanche)**
```bash
rsync -avz --delete \
  --link-dest="/home/rsync_user/MACHINES/complete_reference" \
  -e "ssh -i ~/.ssh/backup_key" \
  /home/sysadmin/VM_IMAGES/ \
  rsync_user@10.0.50.10:/home/rsync_user/MACHINES/differential/$(date +%Y%m%d_%H%M%S)/
```

### Variables d'environnement des scripts

| Variable | Valeur exemple | Description |
|---|---|---|
| `BACKUP_SERVER` | `10.0.50.10` | IP du serveur de stockage |
| `BACKUP_USER` | `rsync_user` | Utilisateur SSH dédié |
| `SSH_KEY` | `~/.ssh/backup_key` | Clé privée pour l'authentification |
| `LOG_DIR` | `/home/sysadmin/logs_backup` | Répertoire des fichiers de log |
| `RETENTION` | `7` | Nombre de sauvegardes incrémentales à conserver |
| `DATE` | `$(date +%Y%m%d_%H%M%S)` | Horodatage pour nommage des répertoires |

---

## 📊 Utilisation

### Lancer une sauvegarde manuellement

```bash
# Sauvegarde complète Stratégie 1 (données métier)
bash /home/sysadmin/scripts/backup_complete_s1.sh

# Sauvegarde incrémentale Stratégie 1
bash /home/sysadmin/scripts/backup_incremental_s1.sh

# Sauvegarde différentielle Stratégie 2 (VMs)
bash /home/sysadmin/scripts/backup_differential_s2.sh
```

### Consulter les logs

```bash
# Derniers logs de sauvegarde incrémentale
ls -lt /home/sysadmin/logs_backup/ | head -10

# Lire un fichier de log spécifique
cat /home/sysadmin/logs_backup/backup_incremental_20260115_020001.log

# Suivre les logs en temps réel lors d'une sauvegarde
tail -f /home/sysadmin/logs_backup/cron_s1.log
```

### Lancer une restauration

```bash
# Restauration incrémentale — choisir la version à restaurer
bash /home/sysadmin/scripts/restore_incremental_s1.sh 20260115_020001

# Restauration différentielle VM
bash /home/sysadmin/scripts/restore_differential_s2.sh 20260115_030001
```

### Vérifier l'espace disque économisé par les hard links

```bash
# Sur le serveur de stockage
du -sh /home/rsync_user/SITE/incremental/*/
df -h /home/rsync_user/
```

---

## 🐛 Troubleshooting

### Erreur : `Permission denied (publickey)`
**Cause** : La clé publique n'est pas correctement déployée sur le serveur, ou les permissions du répertoire `.ssh` sont incorrectes.
**Solution** :
```bash
# Vérifier les permissions sur le serveur
chmod 700 /home/rsync_user/.ssh
chmod 600 /home/rsync_user/.ssh/authorized_keys

# Re-déployer la clé publique
ssh-copy-id -i ~/.ssh/backup_key.pub rsync_user@10.0.50.10
```

### Erreur : `rsync: command not found`
**Cause** : rsync non installé sur l'une des deux machines.
**Solution** :
```bash
sudo apt install -y rsync
which rsync   # Doit retourner /usr/bin/rsync
```

### Erreur : `ssh: Could not resolve hostname`
**Cause** : Problème DNS ou résolution de nom sur le réseau interne Proxmox.
**Solution** :
```bash
# Utiliser l'IP directement plutôt que le hostname
# Ou ajouter une entrée dans /etc/hosts
echo "10.0.50.10  backup-server" | sudo tee -a /etc/hosts
```

### La rétention ne s'applique pas (accumulation de sauvegardes)
**Cause** : La fonction de suppression dans le script ne compte pas correctement les sauvegardes.
**Solution** :
```bash
# Vérifier le nombre de répertoires présents
ls /home/rsync_user/SITE/incremental/ | wc -l

# Tester la logique de suppression manuellement
ls -t /home/rsync_user/SITE/incremental/ | tail -n +8
```

### Logs et debug

```bash
# Lancer rsync en mode verbose + dry-run (simulation sans modification)
rsync -avz --dry-run --stats \
  -e "ssh -i ~/.ssh/backup_key" \
  /home/sysadmin/SITE/ \
  rsync_user@10.0.50.10:/home/rsync_user/SITE/complete/

# Codes de retour rsync courants
# 0 = Succès
# 23 = Transfert partiel (certains fichiers ignorés)
# 24 = Fichiers disparus pendant le transfert (normal si fichiers temporaires)
echo "Code de retour : $?"
```

---

## 📝 Notes

**Points d'amélioration possibles :**
- Notifications par email en cas d'échec de sauvegarde (msmtp ou ssmtp)
- Monitoring de l'espace disque avec alerte seuil (script dédié ou intégration Zabbix/Wazuh)
- Chiffrement GPG des sauvegardes avant transfert (conformité données sensibles)
- Sauvegarde déportée vers NAS ou stockage distant (offsite backup)
- Tests de restauration automatiques périodiques avec vérification d'intégrité (sha256sum)
- Rotation et compression des fichiers de log (logrotate)

**Ressources utiles :**
- [Documentation officielle rsync](https://rsync.samba.org/documentation.html)
- [Man page rsync](https://linux.die.net/man/1/rsync)
- [IT-Connect — Sauvegarde incrémentale vs différentielle](https://www.it-connect.fr)

**Homelab context :**
- Infrastructure Proxmox — réseau interne isolé (pas de routage externe nécessaire)
- SSH configuré en écoute sur le port 22 standard dans cet environnement de lab (recommandation prod : port non standard + fail2ban)
- Scripts testés sur Debian 12 — compatibles Ubuntu 22.04+

---

## 📄 Licence

MIT — Libre utilisation, modification et redistribution avec attribution.

<<<<<<< Updated upstream
=======
---


**Projet réalisé dans le cadre de ma reconversion cybersécurité — Formation Admin Sys/Réseau/Cyber**  
>>>>>>> Stashed changes
