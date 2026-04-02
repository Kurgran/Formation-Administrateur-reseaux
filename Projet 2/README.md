# Formation-Administrateur-reseaux
Administrateur systèmes, réseaux et sécurité


# Projet 2 : Reconstruction GLPI, gestion de support ITIL et sécurisation (Formation ASRS)

## Contexte

Ce projet s'inscrit dans la formation **Administrateur Systèmes, Réseaux et Sécurité (ASRS)**, sur un scénario d'entreprise fictif ("XX"). Suite à une panne critique du serveur GLPI et l'absence de sauvegardes récentes, la mission était de reconstruire l'outil depuis zéro, réintégrer les tickets en attente et sécuriser l'ensemble de l'installation.

Un cas concret qui illustre pourquoi les sauvegardes et la gestion structurée des services IT ne sont pas optionnelles.

---

## Objectifs

- Installer et configurer GLPI 10+ sur Debian 12 (pile LAMP)
- Sécuriser l'installation et les services sous-jacents (Apache, MariaDB)
- Créer utilisateurs, groupes et profils dans GLPI
- Intégrer un backlog de tickets en appliquant la priorisation ITIL (Impact/Urgence)
- Traiter les tickets N2 avec documentation complète dans GLPI
- Rédiger les documents de communication requis (format PDF)
- Mettre en place l'Agent GLPI pour l'inventaire automatisé sur poste Windows
- Concevoir un logigramme de gestion des tickets pour le support N1
- Produire l'ensemble des livrables demandés

---

## Technologies et outils

- **Système** : Debian 12 ("Bookworm"), administration CLI
- **Pile web** : Apache2, MariaDB 10+, PHP 8+ avec extensions requises
- **Application ITSM** : GLPI 10.x
- **Virtualisation** : VMware Workstation Pro (ou VirtualBox)
- **Client de test** : Windows 10/11
- **Agent inventaire** : Agent GLPI natif
- **Base de données** : MariaDB (CLI + mysqldump pour l'export)
- **Réseau** : Accès par pont (Bridged), DHCP, notions IPsec pour le scénario VPN
- **Sécurité** : mysql_secure_installation, Apache sécurisé (DocumentRoot vers `/public`), gestion permissions Linux (`chown`, `chmod`), pare-feu
- **Méthodologie** : ITIL v3/v4 — Service Desk, Incidents, Demandes, Priorisation, Escalade, Base de Connaissances, SACM

---

## Ce qui a été réalisé

### Installation et sécurisation du serveur GLPI

Mise en place d'un Debian 12 stable en CLI, configuration de la pile LAMP (Apache, MariaDB, PHP), installation de GLPI 10.x. Sécurisation post-install : suppression de `install.php`, changement des mots de passe par défaut, configuration Apache avec DocumentRoot pointant vers `/public` (corrige l'avertissement de sécurité GLPI et réduit la surface d'attaque), sécurisation MariaDB via `mysql_secure_installation` avec création d'un utilisateur dédié `glpiuser`.

### Implémentation ITSM/ITIL dans GLPI

Création des utilisateurs et groupes en cohérence avec l'organisation de XX. Saisie de l'ensemble du backlog (incidents et demandes), priorisation ITIL rigoureuse (Impact × Urgence), distinction et assignation claire des tickets N1 et N2. Traitement complet des tickets N2 avec documentation du diagnostic et des étapes de résolution dans les suivis GLPI. Utilisation de la Base de Connaissances pour la procédure "Machine Infectée". Attachement des documents PDF aux tickets concernés pour la traçabilité.

### Cas complexes traités

- **"Logiciel Comptabilité"** : conflit managérial/opérationnel, tickets liés, proposition de médiation axée sur la formation (PDF), communication avec l'utilisateur impacté
- **VPN Partenaire** : rédaction d'une communication technique formelle avec paramètres IPsec (IKEv2, AES-256, SHA-256, PFS) et informations requises du partenaire
- **"Problème Connexion AD"** : diagnostic simulé d'un compte AD verrouillé, résolution documentée dans GLPI
- **"Achat Matériel"** : recherche de références techniques précises (Toshiba N300/Enterprise), formalisation de la demande

### Agent GLPI et inventaire automatisé

Installation et configuration de l'agent sur une VM Windows 10/11. URL cible : `http://<IP>/front/inventory.php` — c'est le point sur lequel on perd le plus de temps à la première installation. Vérification de la remontée inventaire matériel et logiciel dans GLPI. Rédaction d'une présentation synthétisant le rôle, les avantages et la mise en œuvre de l'agent.

### Formalisation des processus

Logigramme (via diagrams.net) décrivant le cycle de vie d'un ticket pour le support N1, avec mise en évidence du processus d'escalade vers le N2, en cohérence avec les principes ITIL.

---

## Livrables

- Dump SQL complet de la base GLPI (`glpidb`) après traitement des tickets
- Quatre PDF : proposition de médiation "Logiciel Comptabilité", email VPN partenaire, demande d'achat matériel, réponse utilisateur impacté
- Présentation PDF sur l'Agent GLPI (rôle, avantages, mise en place, démonstration)
- Logigramme PDF du processus de gestion des tickets ITIL pour le N1
- Procédure PDF "Machine Infectée" intégrée à la Base de Connaissances GLPI

> Les livrables peuvent être placés dans un dossier `/deliverables`. Pour le dump SQL, anonymisation recommandée avant publication publique.

---

## Difficultés rencontrées

**Configuration Apache sécurisée** : comprendre pourquoi l'avertissement GLPI apparaissait et le corriger en ajustant le DocumentRoot vers `/public` a demandé de creuser la structure de GLPI 10 et la configuration d'Apache. Ce n'est pas documenté de façon évidente.

**URL Agent GLPI** : trouver l'URL exacte (`/front/inventory.php`) pour la cible serveur n'est pas évident à la première installation — c'est pourtant ce qui conditionne toute la remontée d'inventaire.

**Connectivité VM** : le mode "Accès par pont" sur un portable qui change de réseau (Wi-Fi/Ethernet) oblige à vérifier et ajuster la carte hôte dans l'hyperviseur, parfois à forcer `sudo systemctl restart networking.service`.

**Documentation des tickets N2** : documenter le diagnostic et les étapes intermédiaires dans les suivis GLPI, pas seulement la solution finale — ça demande une approche plus méthodique que ce qu'on ferait instinctivement.

---

## Auteur

APPERCEL CLEMENT
