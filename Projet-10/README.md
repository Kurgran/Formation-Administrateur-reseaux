# P11 — Sécurisation du SI de Forges de l'Ouest (Bureau d'études)

**Description courte** : Conception et planification de la sécurisation complète du réseau d'un bureau d'études industriel, suite à une cyberattaque, en conformité avec les recommandations ANSSI.

**Contexte** : Projet de formation OpenClassrooms — Parcours Administrateur Systèmes, Réseaux et Cybersécurité

**Date** : Mars 2026

---

## Vue d'ensemble

Forges de l'Ouest est une PME française de métallurgie (Angers) dont le bureau d'études (12 collaborateurs, 4 pôles) a subi une attaque informatique. En tant qu'ingénieur cybersécurité externe mandaté, le projet consistait à auditer l'infrastructure existante, identifier les failles critiques, puis concevoir une architecture réseau sécurisée et un plan de déploiement complet — le tout dans un budget de 10 000 € HT.

**Composants principaux :**

- **Cartographie réseau (L1)** : Schéma complet de la nouvelle architecture (7 VLANs + DMZ), réalisé sous draw.io
- **Plan projet avec budget (L2)** : Devis détaillé, arbitrages budgétaires, planning 10 semaines, modalités d'hébergement rack
- **Documentation utilisateur et administrateur (L3)** : Procédures d'administration, guide utilisateur, politique de sécurité

---

## Architecture

### Situation initiale (avant sécurisation)

Le bureau d'études fonctionnait sur un **réseau plat unique** (192.168.100.0/24) sans aucune segmentation. Parmi les failles identifiées :

- Aucune segmentation réseau (mouvement latéral libre)
- OS en fin de support (Windows Server 2012 R2, Debian 8)
- Authentification LDAP en clair (port 389)
- Comptes partagés et comptes fantômes actifs
- Absence de pare-feu moderne, de DMZ, de bastion
- Aucune politique de sauvegarde ni de journalisation centralisée
- Aucune sécurité physique du local technique

### Architecture cible

```
                    ┌─────────────────┐
                    │   INTERNET      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  FortiGate 60F  │  ← NGFW (IPS/IDS, VPN, filtrage applicatif)
                    │  CSPN ANSSI     │
                    └──┬──────┬───┬───┘
                       │      │   │
              ┌────────▼──┐   │   └──────────┐
              │    DMZ     │   │              │
              │ 200.0/28   │   │         ┌────▼──────────┐
              │ Nginx RP   │   │         │  Switch L3    │
              │ Serveur Web│   │         │  802.1Q       │
              └────────────┘   │         └───┬───────────┘
                               │             │
                ┌──────────────▼─────────────┤
                │                            │
    ┌───────────┼───────────┬────────────────┤
    │           │           │                │
┌───▼──┐  ┌────▼──┐  ┌─────▼──┐  ┌──────────▼──┐
│VLAN10│  │VLAN20 │  │VLAN 30 │  │  VLAN 40    │
│Direct│  │Prod.  │  │Études  │  │  Technique  │
└──────┘  └───────┘  └────────┘  └─────────────┘

    VLAN 50 (Serveurs) — AD/DNS, DHCP, Apps, Rsyslog, NAS
    VLAN 60 (ToIP)     — Téléphonie IP
    VLAN 99 (Admin)    — Bastion Apache Guacamole (pas d'accès Internet)
```

**Plan d'adressage :**

| VLAN | Nom | Sous-réseau | Passerelle | Contenu |
|------|-----|-------------|------------|---------|
| 10 | Direction | 192.168.10.0/24 | 192.168.10.1 | 2 postes |
| 20 | Production | 192.168.20.0/24 | 192.168.20.1 | 3 postes |
| 30 | Études | 192.168.30.0/24 | 192.168.30.1 | 3 postes |
| 40 | Technique | 192.168.40.0/24 | 192.168.40.1 | 3 postes |
| 50 | Serveurs | 192.168.50.0/24 | 192.168.50.1 | Serveurs + NAS |
| 60 | ToIP | 192.168.60.0/24 | 192.168.60.1 | Téléphonie IP |
| 99 | Administration | 192.168.99.0/24 | 192.168.99.1 | Bastion + admin |
| DMZ | Zone démilitarisée | 192.168.200.0/28 | 192.168.200.1 | Web, reverse proxy |

---

## Équipements déployés

### Matériel neuf

| Équipement | Prix HT | Justification |
|------------|---------|---------------|
| FortiGate 60F (NGFW) | 1 200 € | Pare-feu certifié ANSSI (CSPN), IPS/IDS, VPN |
| FortiGuard UTP 3 ans | 1 500 € | Signatures IPS/IDS, AV réseau, filtrage web, contrôle applicatif |
| Switch L3 manageable 24 ports | 350 € | Segmentation 7 VLANs, trunk 802.1Q, SNMP v3 |
| Serveur rack 1U reconditionné (Xeon, 64 Go RAM) | 2 500 € | Héberge 4 VMs (bastion, reverse proxy, logs, backup) |
| Onduleur rack 1U — 750 VA | 500 € | Continuité de service |
| NAS 2 baies + 2×4 To RAID 1 | 650 € | Politique sauvegarde 3-2-1 (ANSSI R36, R37) |
| Disque externe USB chiffré 4 To | 120 € | Backup hors site, rotation hebdomadaire |
| Kit sécurité physique (RFID + caméra + sonde) | 900 € | Défense en profondeur |
| Infrastructure (jarretières, guide-câbles, kit rack, testeur) | 390 € | Câblage et maintenabilité |
| Extension garantie + upgrade RAM serveur | 500 € | Fiabilité long terme |

### Logiciels open source (gratuits)

| Logiciel | Rôle |
|----------|------|
| Apache Guacamole | Bastion d'administration avec rupture protocolaire (ANSSI R9) |
| Nginx | Reverse proxy en DMZ (ANSSI R11, R12) |
| Rsyslog | Journalisation centralisée (ANSSI R67) |

### Budget total

| | Montant |
|---|---------|
| **Total général** | **8 610 € HT** |
| Budget restant (marge imprévus) | 1 390 € HT |
| **Taux d'utilisation** | **86,1 %** |

---

## Mesures de sécurisation

### Réseau et accès

| # | Mesure | Réf. ANSSI | Description |
|---|--------|------------|-------------|
| 1 | Segmentation en 7 VLANs | R7, R8, R15- | Isolation des flux par pôle métier et par fonction |
| 2 | Pare-feu FortiGate 60F | R1, R2, R3 | IPS/IDS intégré, filtrage applicatif, VPN natif |
| 3 | DMZ dédiée | R11, R12 | Isolation serveur web et reverse proxy |
| 4 | Reverse proxy Nginx | R11, R12 | Plus aucun accès direct aux serveurs depuis Internet |
| 5 | Bastion Apache Guacamole (VLAN 99) | R7, R8, R9 | Rupture protocolaire, sessions enregistrées, pas d'accès Internet |
| 6 | VPN SSL/TLS + IPsec | R16, R17, R18 | Accès distants chiffrés, fin du RDP exposé |

### Systèmes et identités

| # | Mesure | Réf. ANSSI | Description |
|---|--------|------------|-------------|
| 7 | Migration LDAPS (port 636) | R22, R23 | Chiffrement flux authentification AD |
| 8 | Mise à jour OS | R34, R35 | Windows Server 2022, Debian 12 (correctifs actifs) |
| 9 | Comptes nominatifs + nettoyage AD | R56, R57, R58 | Suppression comptes partagés et fantômes, MdP 12 car. min |

### Résilience et supervision

| # | Mesure | Réf. ANSSI | Description |
|---|--------|------------|-------------|
| 10 | Journalisation centralisée Rsyslog | R67 | Collecte logs tous équipements, corrélation événements |
| 11 | Politique sauvegarde 3-2-1 | R36, R37 | NAS RAID 1 + disque externe chiffré hors site |
| 12 | Sécurité physique local technique | Défense en profondeur | Badge RFID Mifare, caméra IP, sonde environnementale |

---

## Modalités d'hébergement

Baie de brassage existante : armoire standard 13U, 4U disponibles.

| Unité | Équipement | Statut |
|-------|-----------|--------|
| U1 | Panneau de brassage 24 ports | Existant |
| U2 | Panneau guide-câbles 1U | **NOUVEAU** |
| U3 | Switch Arista (existant) | Existant |
| U4 | Switch Arista (existant) | Existant |
| U5 | Switch Arista (existant) | Existant |
| U6 | Switch L3 manageable 24 ports | **NOUVEAU** |
| U7 | FortiGate 60F + kit rack-mount | **NOUVEAU*** |
| U8–U9 | Serveur rack 1U (64 Go RAM) | **NOUVEAU** |
| U10+ | Onduleur rack 1U — 750 VA | **NOUVEAU** |

*\*Remplacement de l'ancien routeur/FW — même emplacement.*

Bilan : 5U → 10U occupés, 3U libres pour évolutions futures.

---

## Planification

Projet en 4 phases sur 10 semaines ouvrées :

| Phase | Semaines | Durée | Ressources clés |
|-------|----------|-------|-----------------|
| 1. Étude de la solution | S1 – S2 | 2 semaines | Ingénieur cybersécurité, Chef de projet |
| 2. Déploiement | S3 – S6 | 4 semaines | Admin. systèmes, Technicien |
| 3. Tests et validation | S7 – S8 | 2 semaines | Ingénieur, Admin. systèmes |
| 4. Support et documentation | S9 – S10 | 2 semaines | Ingénieur, Admin. systèmes |

**Ressources mobilisées :** 36 jours-homme (main-d'œuvre interne, aucun coût facturé).

---

## Livrables

| Livrable | Format | Description |
|----------|--------|-------------|
| L1 — Cartographie réseau | .drawio → PDF | Schéma logique complet avant/après sécurisation |
| L2 — Plan projet | .docx → PDF | Contexte, failles, devis, RH, hébergement, planning |
| L3 — Documentation | .docx → PDF | Guide utilisateur + guide administrateur |

---

## Choix architecturaux notables

**FortiGate 60F vs pfSense :** dans le contexte d'une entreprise industrielle manipulant des plans techniques et des données de production sensibles, le FortiGate offre un support constructeur professionnel, des signatures IPS/IDS mises à jour automatiquement, et une certification ANSSI (CSPN). La licence UTP est indispensable — sans elle, le FortiGate n'est qu'un pare-feu stateful basique.

**Rsyslog en VLAN 50 (pas en DMZ) :** choix délibéré pour réduire la surface d'attaque de la DMZ. Le serveur de logs contient des informations sensibles sur l'ensemble du SI — le placer en DMZ l'exposerait inutilement. Les flux de logs transitent par le FortiGate qui les filtre.

**NAS physique vs VM de backup :** une VM de sauvegarde hébergée sur le même hyperviseur que les données à protéger constitue un point de défaillance unique. Le NAS physique dédié garantit la résilience même en cas de compromission de l'hyperviseur.

**Serveur reconditionné :** l'économie d'environ 1 500 € par rapport au neuf est compensée par l'extension de garantie 3 ans et l'upgrade RAM à 64 Go. Performances largement suffisantes pour 4 VMs légères.

---

## Difficultés rencontrées

### Cohérence inter-livrables
**Problème** : des modifications apportées à la cartographie (L1) n'étaient pas systématiquement répercutées dans le plan projet (L2) et la documentation (L3).
**Solution** : adoption du principe "L1 est la source de vérité" — toute modification architecturale part de la cartographie et se propage ensuite aux deux autres documents.

### Contrainte des 4U rack
**Problème** : intégrer tous les nouveaux équipements dans seulement 4 unités de rack disponibles.
**Solution** : remplacement de l'ancien routeur/FW par le FortiGate (même emplacement = 0U supplémentaire), ce qui libère les 4U pour le guide-câbles, le switch L3, le serveur et l'onduleur. Le NAS sort du rack (étagère dédiée).

### Arbitrage budget
**Problème** : trouver l'équilibre entre sécurité maximale et budget contraint à 10 000 € HT.
**Solution** : utilisation de logiciels open source (Guacamole, Nginx, Rsyslog) pour les services applicatifs, serveur reconditionné, et marge de ~14% conservée pour les imprévus.

---

## Notes

**Points d'amélioration possibles :**

- Déploiement d'un SIEM (Wazuh) pour la corrélation avancée des logs, à envisager quand le budget le permet
- Mise en place de NAC (Network Access Control) pour le contrôle d'accès au réseau physique
- Automatisation des tests de restauration de sauvegarde
- Déploiement d'un EDR sur les postes utilisateurs

**Ressources utiles :**

- [ANSSI — Recommandations relatives à l'administration sécurisée des SI (2023)](https://www.ssi.gouv.fr/guide/recommandations-relatives-a-ladministration-securisee-des-systemes-dinformation/)
- [ANSSI — Guides de bonnes pratiques](https://www.ssi.gouv.fr/entreprise/bonnes-pratiques/)
- [Fortinet — Documentation FortiGate 60F](https://docs.fortinet.com/)
- [Apache Guacamole — Documentation officielle](https://guacamole.apache.org/doc/)

**Références ANSSI utilisées dans le projet :**

R1, R2, R3, R7, R8, R9, R11, R12, R15-, R16, R17, R18, R22, R23, R34, R35, R36, R37, R56, R57, R58, R67

---

## Licence

Ce projet est un exercice de formation. Les documents et schémas sont partagés à titre pédagogique.

---

**Projet réalisé dans le cadre de ma reconversion en cybersécurité — Formation OpenClassrooms Administrateur Systèmes, Réseaux et Cybersécurité**

Portfolio complet : *[https://appercel-clement.netlify.app/posts/assr10/]*
