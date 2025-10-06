# Formation-Administrateur-reseaux
Administrateur systèmes, réseaux et sécurité


# Projet 2 : Reconstruction GLPI, Gestion de Support ITIL & Sécurisation (Formation ASRS)

## 1. Introduction & Contexte

Ce projet s'inscrit dans le cadre de la formation **Administrateur Systèmes, Réseaux et Sécurité (ASRS)** et simule un scénario d'entreprise réaliste chez "XX".

Suite à une panne critique du serveur GLPI (Gestion Libre de Parc Informatique), outil central de gestion des services informatiques (ITSM), et l'absence de sauvegardes récentes, ma mission a été de :

- Reconstruire un serveur GLPI fonctionnel et sécurisé à partir de zéro.
- Intégrer les processus de support IT en attente.
- Mettre en œuvre les bonnes pratiques ITIL pour la gestion des incidents et des demandes.
- Explorer des solutions d'automatisation (agent d'inventaire).
- Formaliser les processus de support.

Ce projet met en lumière l'importance cruciale des sauvegardes, de la gestion structurée des services IT et de la sécurisation des infrastructures.

---

## 2. Objectifs du Projet

- Installer et configurer un serveur GLPI 10+ sur Debian 12 (Pile LAMP).
- Sécuriser l'installation GLPI et les services sous-jacents (Apache, MariaDB).
- Créer et configurer les utilisateurs, groupes et profils dans GLPI.
- Intégrer un backlog de tickets (incidents et demandes) en appliquant la priorisation ITIL (Impact/Urgence).
- Traiter les tickets de Niveau 2 assignés, en documentant la démarche dans GLPI.
- Rédiger des documents de communication technique et de médiation (format PDF).
- Mettre en place et configurer l'Agent GLPI pour l'inventaire automatisé sur un poste client Windows.
- Concevoir un logigramme décrivant le processus de gestion des tickets pour la formation du support N1.
- Produire les livrables demandés (Dump SQL, PDFs spécifiques, Présentation Agent, Logigramme).

---

## 3. Technologies & Outils Utilisés

- **Système d'Exploitation Serveur :** Debian 12 ("Bookworm") - Administration en ligne de commande (CLI).
- **Pile Web :** Apache2, MariaDB 10+, PHP 8+ (avec extensions requises).
- **Application ITSM :** GLPI 10.x.
- **Virtualisation :** VMware Workstation Pro (ou VirtualBox).
- **Client de Test :** Windows 10 / 11.
- **Agent d'Inventaire :** Agent GLPI natif.
- **Base de Données :** MariaDB (administration via CLI, mysqldump pour l'export).
- **Réseau :** Configuration en Accès par Pont (Bridged), DHCP, notions de base IPsec (pour le scénario VPN).
- **Sécurité :** mysql_secure_installation, configuration sécurisée Apache (DocumentRoot vers `/public`), gestion des permissions Linux (`chown`, `chmod`), pare-feu (concepts abordés lors du dépannage SSH).
- **Méthodologie :** ITIL v3/v4 (concepts de Service Desk, Gestion des Incidents, Gestion des Demandes, Priorisation Impact/Urgence, Escalade, Base de Connaissances, SACM).


---

## 4. Fonctionnalités Clés & Implémentations Réalisées

### Installation et Sécurisation du Serveur GLPI

- Mise en place d'un serveur Debian 12 stable en CLI.
- Installation et configuration de la pile LAMP (Apache, MariaDB, PHP).
- Installation de GLPI 10.x.
- Sécurisation post-installation : suppression de `install.php`, changement des mots de passe par défaut, configuration Apache avec DocumentRoot pointant vers `/public` pour corriger l'avertissement GLPI et renforcer la sécurité web.
- Sécurisation de MariaDB via `mysql_secure_installation` et création d'un utilisateur dédié (`glpiuser`) pour l'application.

### Implémentation des Processus ITSM/ITIL dans GLPI

- Création des utilisateurs et groupes reflétant l'organisation de XX.
- Saisie de l'ensemble des tickets (Incidents et Demandes) du backlog.
- Application rigoureuse de la priorisation ITIL (Impact x Urgence).
- Distinction et assignation claire des tickets N1 et N2.
- Traitement complet des tickets N2 avec documentation détaillée via les suivis GLPI (diagnostic, actions, résolution).
- Utilisation de la Base de Connaissances pour la procédure "Machine Infectée".
- Attachement des documents PDF spécifiques directement aux tickets concernés pour la traçabilité.

### Résolution de Cas Complexes

- **Cas "Logiciel Comptabilité" :** Analyse du conflit managérial/opérationnel, création de tickets liés, proposition de médiation axée sur la formation (document PDF), communication adaptée avec l'utilisateur bloqué (email PDF).
- **Cas VPN Partenaire :** Rédaction d'une communication technique formelle incluant les paramètres IPsec standards et sécurisés (IKEv2, AES-256, SHA-256, PFS...) et les informations requises du partenaire.
- **Cas "Problème Connexion AD" :** Diagnostic simulé d'un compte AD verrouillé et résolution documentée dans GLPI.
- **Cas "Achat Matériel" :** Recherche de références techniques précises (Disques Toshiba N300/Enterprise) et formalisation de la demande.

### Mise en Place de l'Agent GLPI

- Installation et configuration de l'agent sur une VM Windows 10/11.
- Configuration correcte de l'URL serveur (`http://<IP>/front/inventory.php`).
- Vérification de la remontée automatique de l'inventaire matériel et logiciel dans GLPI.
- Rédaction d'une présentation synthétisant le rôle, les avantages et la mise en œuvre de l'agent.

### Formalisation des Processus

- Conception d'un logigramme clair (via diagrams.net) décrivant le cycle de vie d'un ticket pour le support N1, mettant en évidence le processus d'escalade vers le N2, conformément aux principes ITIL.

---

## 5. Livrables Produits

- Un dump SQL complet de la base de données GLPI (`glpidb`) après traitement des tickets.
- Quatre documents PDF spécifiques :
  - Proposition de médiation pour le cas "Logiciel Comptabilité".
  - Email technique de contact pour le VPN Partenaire.
  - Demande d'achat matériel formalisée.
  - Réponse personnalisée à l'utilisateur impacté par le cas "Logiciel Comptabilité".
- Une présentation PDF sur l'Agent GLPI (rôle, avantages, mise en place, démonstration).
- Un logigramme PDF décrivant le processus de gestion des tickets ITIL pour le N1.
- Une procédure PDF de réponse à incident "Machine Infectée" (intégrée à la Base de Connaissances GLPI).

> **Note :**  
> Les livrables PDF et SQL peuvent être structurés dans un dossier `/deliverables` dans le dépôt.  
> Pour le dump SQL, l'anonymisation des données est recommandée avant publication publique.

---

## 6. Challenges Rencontrés et Solutions Apportées

- **Configuration Apache Sécurisée :** Comprendre et corriger l'avertissement GLPI en ajustant le DocumentRoot vers le dossier `/public` et en configurant les règles de réécriture a nécessité une analyse précise de la structure de GLPI 10 et de la configuration d'Apache.
- **Configuration Agent GLPI :** Trouver l'URL exacte (`/front/inventory.php`) pour la cible serveur a été un point clé pour assurer la communication entre l'agent et le serveur.
- **Connectivité Réseau VM :** La gestion du mode "Accès par pont" sur un portable changeant de connexion (Wi-Fi/Ethernet) a nécessité de vérifier et d'ajuster la carte hôte associée au pont dans l'hyperviseur et parfois de forcer le renouvellement DHCP (`sudo systemctl restart networking.service`).
- **Traitement des Tickets N2 :** Aller au-delà de la simple solution en documentant le diagnostic et les étapes intermédiaires via les suivis GLPI a demandé une approche plus méthodique.

---

## 7. Apprentissages et Compétences Développées

- **Administration Système Linux (Debian) :** Installation, configuration de base, gestion des services (`systemctl`), gestion des paquets (`apt`), permissions (`chmod`, `chown`), configuration réseau (`ip a`, `/etc/network/interfaces`), utilisation CLI.
- **Administration Web (LAMP) :** Installation et configuration d'Apache2 (VirtualHosts, modules), PHP et ses extensions.
- **Administration Base de Données (MariaDB) :** Installation, sécurisation (`mysql_secure_installation`), création base/utilisateur, gestion privilèges (`GRANT`), sauvegarde/export (`mysqldump`).
- **Configuration et Utilisation GLPI :** Installation, sécurisation, gestion utilisateurs/groupes/profils, création/traitement tickets, utilisation base de connaissances, configuration inventaire natif.
- **Méthodologie ITSM/ITIL :** Application pratique des concepts d'Incident, Demande, Priorisation (Impact/Urgence), Escalade, Base de Connaissances, Gestion des Actifs (via agent).
- **Notions Réseau & Sécurité :** Configuration VPN IPsec (concepts P1/P2), sécurisation serveur web/BDD, procédure réponse à incident malware, isolement réseau, principe du moindre privilège.
- **Compétences Transverses :** Diagnostic technique, résolution de problèmes, documentation (procédures, emails techniques), communication, gestion de conflit simple, suivi de projet.

Ce projet constitue une base solide pour aborder des problématiques plus complexes en administration système et réseau, et renforce la compréhension des processus opérationnels indispensables en cybersécurité.

---

## 8. Auteur

APPERCEL CLEMENT
