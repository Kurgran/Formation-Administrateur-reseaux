# Infrastructure IT Entreprise (AD, GLPI, Ansible)

**Description courte** : Infrastructure complète d'entreprise avec Active Directory, gestion de parc GLPI et automatisation Ansible pour un environnement hybride Windows/Linux
**Contexte homelab** : Déployé sur Proxmox (4 VMs dédiées)
**Date** : Février 2026

---

## 📋 Vue d'ensemble

Projet d'infrastructure IT complète simulant la gestion d'un parc de 40+ utilisateurs pour une entreprise fictive de développement de jeux vidéo. L'infrastructure intègre Active Directory pour la gestion centralisée des identités, GLPI pour l'inventaire du parc matériel, et Ansible pour l'automatisation des déploiements et configurations.

Ce projet démontre la capacité à concevoir, déployer et maintenir une infrastructure d'entreprise hybride Windows/Linux en appliquant les bonnes pratiques de sécurité (méthodologie AGDLP, authentification Kerberos, automatisation des tâches récurrentes).

**Composants principaux :**
- **Active Directory (Windows Server 2022)** : Annuaire centralisé, DNS, DHCP, GPO
- **GLPI (Linux Debian)** : Gestion du parc matériel/logiciel, synchronisation LDAP avec AD
- **Ansible** : Automatisation du montage de partages réseau, déploiement d'outils, patch management

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Réseau 192.168.10.0/24                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐        ┌──────────────────┐           │
│  │  Windows Server  │        │  Linux Server    │           │
│  │    (DC-01)       │◄──────►│  (SRV-GLPI)      │           │
│  │                  │  LDAP  │                  │           │
│  │  - AD DS         │        │  - GLPI          │           │
│  │  - DNS           │        │  - Ansible       │           │
│  │  - DHCP          │        │  - Apache        │           │
│  │  - File Server   │        │  - MariaDB       │           │
│  └────────┬─────────┘        └──────────────────┘           │
│           │                                                  │
│           │ Kerberos Auth                                    │
│           │                                                  │
│  ┌────────┴─────────────────────────────────┐               │
│  │                                           │               │
│  ▼                                           ▼               │
│ ┌──────────────┐                   ┌──────────────┐         │
│ │ Client       │                   │ Client       │         │
│ │ Windows 11   │                   │ Linux Ubuntu │         │
│ │              │                   │              │         │
│ │ - Auto mount │                   │ - Auto mount │         │
│ │ - GPO apply  │                   │ - Kerberos   │         │
│ └──────────────┘                   └──────────────┘         │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

**Infrastructure :**
- **Plateforme** : Proxmox VE 8.x
- **VMs déployées** :
  - `DC-01` : Windows Server 2022 (4 vCPU, 8 Go RAM, 100 Go)
  - `SRV-GLPI` : Debian 12 (2 vCPU, 4 Go RAM, 60 Go)
  - `WIN-CLIENT` : Windows 11 Pro (2 vCPU, 4 Go RAM, 60 Go)
  - `LIN-CLIENT` : Ubuntu 24.04 LTS (2 vCPU, 4 Go RAM, 40 Go)
- **Réseau** : VLAN 10 (192.168.10.0/24)
  - DC-01 : 192.168.10.10
  - SRV-GLPI : 192.168.10.20
- **Stockage** : Sauvegarde quotidienne sur NAS (PBS ou NFS)

---

## ⚙️ Prérequis

**Versions testées :**
- Windows Server 2022 Standard (Desktop Experience)
- Debian 12 (Bookworm)
- GLPI 10.0.x
- Ansible 2.15+
- Python 3.11+ (pour Ansible)

**Dépendances système (Linux) :**
```bash
# Sur SRV-GLPI (Debian)
sudo apt update
sudo apt install -y apache2 mariadb-server php php-{mysql,curl,gd,intl,ldap,apcu,xmlrpc,cas,zip,bz2,mbstring,xml}
sudo apt install -y ansible python3-pip krb5-user sssd sssd-tools
```

**Accès réseau requis :**
- **Port 53 (TCP/UDP)** : DNS
- **Port 88 (TCP/UDP)** : Kerberos
- **Port 389 (TCP)** : LDAP
- **Port 445 (TCP)** : SMB/CIFS (partages réseau)
- **Port 3389 (TCP)** : RDP (administration)
- **Port 80/443 (TCP)** : GLPI Web Interface

---

## 🚀 Installation

### Étape 1 : Déploiement Active Directory (Windows Server)

**1.1 Installation du rôle AD DS**
```powershell
# Installer le rôle Active Directory
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Promouvoir le serveur en contrôleur de domaine
Install-ADDSForest `
    -DomainName "vertex.local" `
    -DomainNetbiosName "VERTEX" `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -InstallDns:$true `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
    -Force:$true
```

**Explication** : Cette commande installe Active Directory Domain Services et crée un nouveau domaine `vertex.local`. L'option `-InstallDns:$true` installe automatiquement le rôle DNS intégré à AD, essentiel pour Kerberos.

**1.2 Configuration DNS**
```powershell
# Vérifier que la zone DNS est créée
Get-DnsServerZone

# Configurer le serveur pour utiliser lui-même comme DNS primaire
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses ("127.0.0.1", "192.168.10.10")
```

**1.3 Installation DHCP (optionnel)**
```powershell
Install-WindowsFeature -Name DHCP -IncludeManagementTools
Add-DhcpServerv4Scope -Name "VLAN10" -StartRange 192.168.10.100 -EndRange 192.168.10.200 -SubnetMask 255.255.255.0
Set-DhcpServerv4OptionValue -ScopeId 192.168.10.0 -DnsServer 192.168.10.10 -Router 192.168.10.1
```

### Étape 2 : Création de la structure organisationnelle

**2.1 Création des OUs (Organizational Units)**
```powershell
# Script PowerShell pour créer la structure OU
$BaseDN = "DC=vertex,DC=local"

# Créer les OUs départements
$Departments = @("Direction", "Developpement", "Graphisme", "Audio", "Testing", "IT")

foreach ($Dept in $Departments) {
    New-ADOrganizationalUnit -Name $Dept -Path $BaseDN -ProtectedFromAccidentalDeletion $true
}

# Créer les sous-OUs pour utilisateurs et groupes
foreach ($Dept in $Departments) {
    New-ADOrganizationalUnit -Name "Users" -Path "OU=$Dept,$BaseDN" -ProtectedFromAccidentalDeletion $true
    New-ADOrganizationalUnit -Name "Groups" -Path "OU=$Dept,$BaseDN" -ProtectedFromAccidentalDeletion $true
}
```

**2.2 Création des utilisateurs (exemple)**
```powershell
# Exemple : créer un utilisateur dans le département Développement
$SecurePassword = ConvertTo-SecureString "TempPass2024!" -AsPlainText -Force

New-ADUser `
    -Name "Jean Martin" `
    -GivenName "Jean" `
    -Surname "Martin" `
    -SamAccountName "jmartin" `
    -UserPrincipalName "jmartin@vertex.local" `
    -Path "OU=Users,OU=Developpement,DC=vertex,DC=local" `
    -AccountPassword $SecurePassword `
    -Enabled $true `
    -ChangePasswordAtLogon $true
```

**2.3 Application de la méthodologie AGDLP**
```powershell
# Créer un groupe GLOBAL pour les développeurs
New-ADGroup `
    -Name "GG_Developpeurs" `
    -GroupScope Global `
    -Path "OU=Groups,OU=Developpement,DC=vertex,DC=local"

# Créer un groupe DOMAIN LOCAL pour l'accès au partage Dev
New-ADGroup `
    -Name "DL_Acces_Partage_Dev" `
    -GroupScope DomainLocal `
    -Path "OU=Groups,OU=Developpement,DC=vertex,DC=local"

# Ajouter l'utilisateur au groupe global
Add-ADGroupMember -Identity "GG_Developpeurs" -Members "jmartin"

# Donner les permissions au groupe domain local
# (À faire via l'interface ou icacls sur le partage réseau)
```

**Points d'attention :**
- **AGDLP** : Toujours suivre Accounts → Global groups → Domain Local groups → Permissions
- **Mots de passe** : Utiliser une politique de complexité forte en production
- **DNS** : S'assurer que le serveur DNS pointe bien sur lui-même (127.0.0.1 ou IP du DC)

### Étape 3 : Configuration des partages réseau

**3.1 Création du partage réseau**
```powershell
# Créer le répertoire de partage
New-Item -Path "D:\Partages\Developpement" -ItemType Directory

# Créer le partage SMB
New-SmbShare -Name "Developpement" -Path "D:\Partages\Developpement" -FullAccess "VERTEX\DL_Acces_Partage_Dev"

# Configurer les permissions NTFS (important !)
icacls "D:\Partages\Developpement" /grant "VERTEX\DL_Acces_Partage_Dev:(OI)(CI)M"
```

**3.2 Enregistrement des SPNs (Service Principal Names)**
```powershell
# CRUCIAL pour Kerberos : enregistrer les SPNs sur le compte machine du serveur de fichiers
setspn -A CIFS/dc-01.vertex.local DC-01$
setspn -A CIFS/dc-01 DC-01$

# Vérifier l'enregistrement
setspn -L DC-01$
```

**Explication** : Les SPNs permettent à Kerberos d'authentifier le service de partage de fichiers (CIFS). Sans SPNs correctement enregistrés, les clients recevront l'erreur "Server not found in Kerberos database".

### Étape 4 : Déploiement GLPI (Linux)

**4.1 Installation de GLPI**
```bash
# Télécharger GLPI
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/10.0.12/glpi-10.0.12.tgz
tar -xzf glpi-10.0.12.tgz
sudo mv glpi /var/www/html/

# Configurer les permissions
sudo chown -R www-data:www-data /var/www/html/glpi
sudo chmod -R 755 /var/www/html/glpi
```

**4.2 Configuration Apache**
```bash
sudo tee /etc/apache2/sites-available/glpi.conf <<EOF
<VirtualHost *:80>
    ServerName glpi.vertex.local
    DocumentRoot /var/www/html/glpi

    <Directory /var/www/html/glpi>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF

# Activer le site et les modules nécessaires
sudo a2ensite glpi
sudo a2enmod rewrite
sudo systemctl restart apache2
```

**4.3 Configuration de la base de données MariaDB**
```bash
# Sécuriser MariaDB
sudo mysql_secure_installation

# Créer la base GLPI
sudo mysql -u root -p <<EOF
CREATE DATABASE glpi CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY 'SecurePassword123!';
GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost';
FLUSH PRIVILEGES;
EOF
```

**4.4 Configuration LDAP dans GLPI**

Se connecter à GLPI (`http://192.168.10.20/glpi`) et configurer l'authentification LDAP :

- **Serveur** : `192.168.10.10` (DC-01)
- **Port** : `389`
- **BaseDN** : `DC=vertex,DC=local`
- **Filtre de connexion** : `(&(objectClass=user)(objectCategory=person)(sAMAccountName=*))`
- **Compte de liaison** : `cn=glpi-ldap,cn=Users,dc=vertex,dc=local`
- **Mot de passe** : [mot de passe du compte de service]

**Points d'attention :**
- Créer un compte de service dédié dans AD avec des permissions de lecture LDAP uniquement
- Tester la connexion LDAP avant d'activer la synchronisation automatique

### Étape 5 : Déploiement Ansible (automatisation)

**5.1 Installation Ansible**
```bash
# Sur SRV-GLPI
sudo apt install -y ansible python3-pip python3-winrm

# Installer les modules Python pour Windows
pip3 install pywinrm[credssp]
```

**5.2 Configuration de l'inventaire Ansible**
```bash
sudo mkdir -p /etc/ansible
sudo tee /etc/ansible/hosts <<EOF
[windows_clients]
win-client ansible_host=192.168.10.50

[linux_clients]
lin-client ansible_host=192.168.10.51

[windows_clients:vars]
ansible_user=administrator@vertex.local
ansible_password=AdminPass123!
ansible_connection=winrm
ansible_winrm_transport=kerberos
ansible_winrm_server_cert_validation=ignore

[linux_clients:vars]
ansible_user=root
ansible_ssh_private_key_file=/root/.ssh/id_rsa
EOF
```

**5.3 Configuration Kerberos pour Ansible**
```bash
sudo tee /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = VERTEX.LOCAL
    dns_lookup_realm = false
    dns_lookup_kdc = true
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    VERTEX.LOCAL = {
        kdc = 192.168.10.10
        admin_server = 192.168.10.10
    }

[domain_realm]
    .vertex.local = VERTEX.LOCAL
    vertex.local = VERTEX.LOCAL
EOF
```

**Explication** : Cette configuration permet à Ansible d'utiliser Kerberos pour s'authentifier auprès des clients Windows sans stocker de mots de passe en clair.

---

## 🔧 Configuration

### Fichiers de configuration principaux

**Playbook Ansible : Montage automatique des partages réseau (Windows)**  
`/etc/ansible/playbooks/mount-network-drives.yml`

```yaml
---
- name: Montage automatique des partages réseau sur clients Windows
  hosts: windows_clients
  gather_facts: no
  tasks:
    - name: Créer une tâche planifiée pour monter les lecteurs réseau
      win_scheduled_task:
        name: "Mount Network Drives"
        description: "Monte les partages réseau en fonction du groupe AD de l'utilisateur"
        actions:
          - path: powershell.exe
            arguments: >-
              -ExecutionPolicy Bypass
              -File "C:\Scripts\Mount-Drives.ps1"
        triggers:
          - type: logon
        username: SYSTEM
        logon_type: interactive_token  # CRUCIAL : utilise le token de l'utilisateur connecté
        run_level: highest
        state: present
        enabled: yes

    - name: Déployer le script PowerShell de montage
      win_copy:
        src: files/Mount-Drives.ps1
        dest: C:\Scripts\Mount-Drives.ps1
```

**Script PowerShell : Montage des lecteurs réseau**  
`/etc/ansible/playbooks/files/Mount-Drives.ps1`

```powershell
# Script de montage automatique des partages réseau
# Basé sur l'appartenance aux groupes AD de l'utilisateur

param()

# Fonction de logging
function Write-Log {
    param([string]$Message)
    $LogPath = "C:\Scripts\Logs\mount-drives.log"
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogPath -Append
}

Write-Log "Script de montage des partages démarré"

# Vérifier si l'utilisateur est un compte de domaine
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if ($CurrentUser -notlike "VERTEX\*") {
    Write-Log "Utilisateur local détecté ($CurrentUser), pas de montage"
    exit 0
}

Write-Log "Utilisateur domaine détecté : $CurrentUser"

# Fonction pour monter un lecteur réseau
function Mount-NetworkDrive {
    param(
        [string]$DriveLetter,
        [string]$SharePath,
        [string]$Label
    )
    
    try {
        # Vérifier si le lecteur est déjà monté
        if (Test-Path "${DriveLetter}:") {
            Write-Log "Lecteur ${DriveLetter}: déjà monté, démontage..."
            net use "${DriveLetter}:" /delete /yes 2>&1 | Out-Null
        }
        
        # Monter le lecteur
        $null = New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $SharePath -Persist -Scope Global -ErrorAction Stop
        Write-Log "Lecteur ${DriveLetter}: ($Label) monté avec succès : $SharePath"
        return $true
    }
    catch {
        Write-Log "ERREUR lors du montage de ${DriveLetter}: - $($_.Exception.Message)"
        return $false
    }
}

# Récupérer les groupes AD de l'utilisateur
try {
    $UserGroups = ([ADSISEARCHER]"(samAccountName=$($env:USERNAME))").FindOne().Properties.memberof
}
catch {
    Write-Log "ERREUR : Impossible de récupérer les groupes AD - $($_.Exception.Message)"
    exit 1
}

# Montage selon les groupes
if ($UserGroups -match "GG_Developpeurs") {
    Mount-NetworkDrive -DriveLetter "D" -SharePath "\\dc-01.vertex.local\Developpement" -Label "Développement"
    Mount-NetworkDrive -DriveLetter "P" -SharePath "\\dc-01.vertex.local\Projets" -Label "Projets"
}

if ($UserGroups -match "GG_Direction") {
    Mount-NetworkDrive -DriveLetter "R" -SharePath "\\dc-01.vertex.local\Direction" -Label "Direction"
}

# Montage du lecteur commun pour tous
Mount-NetworkDrive -DriveLetter "C" -SharePath "\\dc-01.vertex.local\Commun" -Label "Commun"

Write-Log "Script de montage terminé"
```

**Points d'attention critiques :**
- **`logon_type: interactive_token`** : ESSENTIEL pour que le script s'exécute avec le token Kerberos de l'utilisateur réel et non en SYSTEM
- **Gestion des conflits de lettres** : Démonter le lecteur existant avant de remonter
- **Logs détaillés** : Facilite le debug en cas de problème

### Variables d'environnement

| Variable | Valeur | Description |
|----------|--------|-------------|
| `ANSIBLE_HOST_KEY_CHECKING` | `False` | Désactive la vérification des clés SSH (dev uniquement) |
| `KRB5_CONFIG` | `/etc/krb5.conf` | Chemin vers la config Kerberos |
| `GLPI_DB_HOST` | `localhost` | Hôte de la base de données GLPI |
| `GLPI_DB_NAME` | `glpi` | Nom de la base de données GLPI |
| `GLPI_DB_USER` | `glpi_user` | Utilisateur DB GLPI |

---

## 📊 Utilisation

### Accès

- **Active Directory** : RDP sur `192.168.10.10` (administrator@vertex.local)
- **GLPI Interface Web** : `http://192.168.10.20/glpi`
  - Login par défaut (première installation) : `glpi` / `glpi`
  - Après config LDAP : utilisateurs du domaine AD

### Commandes utiles

**Active Directory (PowerShell)**
```powershell
# Vérifier le statut du contrôleur de domaine
Get-ADDomainController

# Lister tous les utilisateurs
Get-ADUser -Filter * | Select-Object Name, SamAccountName, Enabled

# Forcer la réplication AD
repadmin /syncall /AdeP

# Vérifier les SPNs d'un compte
setspn -L DC-01$

# Consulter les événements Kerberos
Get-WinEvent -LogName Security | Where-Object {$_.Id -eq 4768 -or $_.Id -eq 4769} | Select-Object -First 10
```

**GLPI (Linux)**
```bash
# Vérifier le statut d'Apache
sudo systemctl status apache2

# Consulter les logs GLPI
sudo tail -f /var/www/html/glpi/files/_log/php-errors.log

# Tester la connexion LDAP manuellement
ldapsearch -x -H ldap://192.168.10.10 -D "cn=glpi-ldap,cn=Users,dc=vertex,dc=local" -W -b "dc=vertex,dc=local" "(objectClass=user)"
```

**Ansible**
```bash
# Tester la connectivité aux clients Windows
ansible windows_clients -m win_ping

# Tester la connectivité aux clients Linux
ansible linux_clients -m ping

# Exécuter le playbook de montage de partages
ansible-playbook /etc/ansible/playbooks/mount-network-drives.yml

# Mode verbose pour debug
ansible-playbook /etc/ansible/playbooks/mount-network-drives.yml -vvv
```

### Cas d'usage

**Ajouter un nouveau utilisateur et lui donner accès au partage Développement**
```powershell
# 1. Créer l'utilisateur dans AD
$SecurePassword = ConvertTo-SecureString "TempPass2024!" -AsPlainText -Force
New-ADUser -Name "Sophie Durand" -SamAccountName "sdurand" -UserPrincipalName "sdurand@vertex.local" -Path "OU=Users,OU=Developpement,DC=vertex,DC=local" -AccountPassword $SecurePassword -Enabled $true

# 2. Ajouter l'utilisateur au groupe GG_Developpeurs
Add-ADGroupMember -Identity "GG_Developpeurs" -Members "sdurand"

# 3. Le montage automatique se fera lors de la prochaine connexion (via tâche planifiée)
```

**Déployer un patch de sécurité sur tous les clients Windows**
```bash
# Créer un playbook pour les mises à jour Windows
ansible-playbook /etc/ansible/playbooks/windows-updates.yml
```

---

## 🐛 Troubleshooting

### Erreur : "Server not found in Kerberos database"

**Cause** : Les SPNs (Service Principal Names) ne sont pas enregistrés dans Active Directory pour le service de partage de fichiers.

**Solution** :
```powershell
# Sur le contrôleur de domaine, enregistrer les SPNs
setspn -A CIFS/dc-01.vertex.local DC-01$
setspn -A CIFS/dc-01 DC-01$

# Vérifier l'enregistrement
setspn -L DC-01$

# Forcer la réplication AD pour propager les changements
repadmin /syncall /AdeP
```

### Erreur : Les partages réseau ne se montant pas automatiquement

**Cause** : La tâche planifiée Windows s'exécute en contexte SYSTEM au lieu d'utiliser le token de l'utilisateur connecté.

**Solution** :
```powershell
# Vérifier le type de logon de la tâche planifiée
Get-ScheduledTask -TaskName "Mount Network Drives" | Select-Object -ExpandProperty Principal

# Si LogonType n'est pas "InteractiveToken", recréer la tâche
Unregister-ScheduledTask -TaskName "Mount Network Drives" -Confirm:$false

# Créer avec le bon logon type via Ansible ou manuellement :
# - Ouvrir Task Scheduler
# - Créer une tâche qui se déclenche "At log on"
# - Dans Security options : "Run only when user is logged on"
# - Cocher "Run with highest privileges"
```

### Erreur : GLPI ne synchronise pas les utilisateurs LDAP

**Cause** : Le compte de service GLPI n'a pas les permissions de lecture sur les OUs Active Directory.

**Solution** :
```powershell
# Sur le contrôleur de domaine, donner les permissions de lecture LDAP au compte glpi-ldap
# Via PowerShell (nécessite le module ActiveDirectory)

$Account = "VERTEX\glpi-ldap"
$OUs = @(
    "OU=Direction,DC=vertex,DC=local",
    "OU=Developpement,DC=vertex,DC=local",
    "OU=Graphisme,DC=vertex,DC=local"
    # ... autres OUs
)

foreach ($OU in $OUs) {
    $ACL = Get-Acl -Path "AD:$OU"
    $Rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        (New-Object System.Security.Principal.NTAccount($Account)),
        [System.DirectoryServices.ActiveDirectoryRights]::GenericRead,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $ACL.AddAccessRule($Rule)
    Set-Acl -Path "AD:$OU" -AclObject $ACL
}
```

### Erreur : Ansible ne peut pas se connecter aux clients Windows

**Cause** : WinRM n'est pas configuré ou Kerberos ne fonctionne pas correctement.

**Solution** :
```bash
# Sur le serveur Ansible, vérifier la configuration Kerberos
klist  # Doit afficher un ticket valide

# Si pas de ticket, obtenir un ticket Kerberos
kinit administrator@VERTEX.LOCAL

# Vérifier à nouveau
klist

# Tester la connexion WinRM manuellement
ansible windows_clients -m win_ping -vvv

# Si échec, vérifier WinRM sur le client Windows (en PowerShell sur le client)
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Service\Auth\Kerberos -Value $true
Restart-Service WinRM
```

### Logs et debug

**Active Directory**
```powershell
# Logs Kerberos (Event ID 4768 = TGT request, 4769 = Service ticket request)
Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4768 or EventID=4769)]]" | Select-Object -First 20 | Format-Table TimeCreated, Message -AutoSize

# Logs de réplication AD
repadmin /showrepl
```

**GLPI**
```bash
# Logs Apache
sudo tail -f /var/log/apache2/glpi_error.log

# Logs applicatifs GLPI
sudo tail -f /var/www/html/glpi/files/_log/php-errors.log

# Logs de synchronisation LDAP (via interface web)
# Configuration > Authentification > Annuaire LDAP > [Nom de l'annuaire] > Tester la connexion
```

**Ansible**
```bash
# Mode debug complet
export ANSIBLE_DEBUG=1
ansible-playbook playbook.yml -vvvv

# Logs de Kerberos côté client
sudo tail -f /var/log/krb5libs.log  # Si configuré
```

---

## 📝 Notes

**Points d'amélioration possibles :**
- Déployer un second contrôleur de domaine (DC-02) pour la haute disponibilité
- Implémenter la segmentation VLAN (VLAN management, VLAN utilisateurs, DMZ pour GLPI)
- Intégrer un SIEM (Wazuh, Splunk) pour le monitoring des logs AD et détection d'anomalies
- Automatiser la sauvegarde des GPO et de la configuration AD via scripts
- Créer des playbooks Ansible pour le patch management automatisé (Windows Update + apt upgrade)

**Ressources utiles :**
- [Documentation Microsoft AD DS](https://learn.microsoft.com/windows-server/identity/ad-ds/)
- [GLPI Documentation](https://glpi-install.readthedocs.io/)
- [Ansible Windows Guide](https://docs.ansible.com/ansible/latest/os_guide/windows_usage.html)
- [Kerberos MIT Documentation](https://web.mit.edu/kerberos/krb5-latest/doc/)
- [AGDLP Best Practices](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/implementing-least-privilege-administrative-models)

**Homelab context :**
- Ce projet s'intègre dans un environnement Proxmox plus large avec pfSense (routage/firewall) et NAS Synology (stockage)
- Les VMs sont sauvegardées quotidiennement via Proxmox Backup Server
- À terme : segmentation réseau avec VLANs dédiés pour chaque service (Management, Production, DMZ)

---

## 📄 Licence

Projet personnel à but pédagogique - Libre de réutilisation et modification

---

