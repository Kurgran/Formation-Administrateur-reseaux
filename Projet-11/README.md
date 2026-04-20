# Projet 11 — Pentest d'un lab Active Directory

⚠️ **Disclaimer**

 Ce qui suit est un retour d'expérience personnel sur un lab que j'ai monté moi-même, dans un environnement isolé, pour m'entraîner à enchaîner une chaîne d'attaque AD de bout en bout. Aucune des techniques décrites ici ne doit être utilisée contre un système qui ne vous appartient pas ou pour lequel vous n'avez pas d'autorisation écrite. L'intrusion non autorisée dans un SI est punie par l'article 323-1 du Code pénal.


Projet homelab : déploiement d'un lab Active Directory volontairement vulnérable,
puis pentest interne en gray-box jusqu'à la compromission totale du domaine.

Le lab simule ce qu'un attaquant interne peut faire en enchaînant des erreurs de
configuration classiques : mots de passe faibles, credentials qui traînent, absence
de LAPS, pas de tiering, LSASS non protégé. Aucun CVE exotique, aucun 0-day —
uniquement des techniques documentées (user-as-pass, Kerberoasting, Pass-the-Hash,
secretsdump, lsassy).

L'objectif est pédagogique : comprendre chaque étape, savoir quelle misconfig a
permis quoi, et produire les livrables qu'on rendrait en vraie mission (rapport +
plan d'action + restitution).

## Avertissement

Ce dossier contient des scripts et des procédures destinés à être utilisés
**uniquement dans un lab personnel et isolé**. Ne pas reproduire tout ou partie de
ces techniques contre un système que vous ne possédez pas ou pour lequel vous
n'avez pas d'autorisation écrite. L'intrusion non autorisée dans un SI est punie
par la loi (articles 323-1 et suivants du Code pénal français).

## Périmètre du lab

Trois VMs Windows Server 2022, réseau isolé, un domaine Active Directory.

| Machine | IP          | Rôle                  | OS                  |
|---------|-------------|-----------------------|---------------------|
| DC01    | 10.10.11.10 | Contrôleur de domaine | Windows Server 2022 |
| FS01    | 10.10.11.20 | Serveur de fichiers   | Windows Server 2022 |
| WS01    | 10.10.11.30 | Poste de travail      | Windows Server 2022 |

Domaine : `corp.lab`. Machine d'attaque : Kali Linux dans le même VLAN.

## Stack technique

- Proxmox VE pour la virtualisation
- Windows Server 2022 (ISO d'évaluation)
- Kali Linux 2025 sur la machine d'attaque
- Outils : nmap, crackmapexec, impacket (secretsdump, GetUserSPNs, psexec),
  ldapdomaindump, hashcat, lsassy, smbclient

## Structure du dossier

```
Projet-11/
├── README.md
├── lab/
│   ├── deploy-lab.ps1          # Script de déploiement des 3 VMs (bootstrap AD + misconfigs)
│   ├── vulns/
│   │   ├── 01-weak-password.ps1         # Crée le compte test:test
│   │   ├── 02-ldap-description.ps1      # Injecte MDP dans description LDAP helpdesk01
│   │   ├── 03-kerberoastable.ps1        # Crée les comptes SPN avec MDP faibles
│   │   ├── 04-share-creds.ps1           # Pose admin.ps1 avec creds sur FS01
│   │   └── 05-da-session.ps1            # Instructions pour forcer une session DA sur FS01
│   └── reset-lab.ps1           # Remet le lab dans l'état initial
├── pentest/
│   ├── 01-recon.md             # Phase 1 : énumération
│   ├── 02-initial-access.md    # Phase 2 : user-as-pass
│   ├── 03-auth-recon.md        # Phase 3 : reco authentifiée + Kerberoasting
│   ├── 04-lateral.md           # Phase 4 : mouvement latéral + Pass-the-Hash
│   └── 05-da.md                # Phase 5 : compromission DC
└── wordlists/
    └── seed-users.txt          # Liste de base pour l'énumération Kerberos
```

## Chaîne d'attaque résumée

```
test:test                      → accès domaine authentifié
→ ldapdump                     → MDP clair dans description LDAP (helpdesk01)
→ GetUserSPNs + hashcat        → 2 comptes SPN cassés (svc_sql, svc_iis)
→ partage Configuration FS01   → creds hardcodés dans admin.ps1 (deploy_svc)
→ deploy_svc admin local WS01
→ secretsdump WS01             → hash Administrator local
→ Pass-the-Hash FS01           → admin local FS01 (pas de LAPS)
→ lsassy FS01                  → hash NTLM dadmin1 (Domain Admin)
→ psexec DC01 avec hash        → NT AUTHORITY\SYSTEM sur le DC
```

Cinq phases. Onze vulnérabilités identifiées, dont six critiques. Corriger n'importe
laquelle des critiques aurait cassé la chaîne.

## Reproduire le lab

### Prérequis

- Un hyperviseur Proxmox (ou VMware, ou Hyper-V avec adaptation mineure)
- Au moins 24 Go de RAM disponibles pour les trois VMs
- Un VLAN ou un réseau isolé (pas d'exposition internet, pas de route vers le LAN prod)

### Déploiement

```bash
# Adapter les variables dans lab/deploy-lab.ps1 (IPs, nom de domaine, mots de passe)
# Puis lancer le déploiement depuis un poste Windows avec les droits nécessaires
pwsh ./lab/deploy-lab.ps1
```

Le script monte DC01, promeut le domaine, joint FS01 et WS01, puis applique les
misconfigs volontaires. Compter 45 minutes de bout en bout selon le matériel.

### Reset du lab

```bash
pwsh ./lab/reset-lab.ps1
```

Supprime les comptes et credentials injectés, réinitialise les ACLs du partage,
reforce les policies propres. Utile pour rejouer le pentest après avoir testé une
remédiation.

## Vulnérabilités présentes (par ordre de criticité)

| ID  | Vulnérabilité                                         | Criticité |
|-----|-------------------------------------------------------|-----------|
| V03 | Mot de passe trivial (user-as-pass `test:test`)       | Critique  |
| V04 | Mot de passe stocké dans la description LDAP          | Critique  |
| V05 | Kerberoasting — mots de passe faibles sur comptes SPN | Critique  |
| V06 | Credentials hardcodés dans un script d'administration | Critique  |
| V08 | Réutilisation du mot de passe administrateur local    | Critique  |
| V09 | Session Domain Admin sur serveur membre               | Critique  |
| V01 | SMB signing non obligatoire (FS01, WS01)              | Élevée    |
| V07 | Expiration des mots de passe désactivée               | Élevée    |
| V11 | LSASS non protégé (no Credential Guard / RunAsPPL)    | Élevée    |
| V02 | Énumération Kerberos possible sans authentification   | Moyen     |
| V10 | Credentials par défaut (vagrant:vagrant dans LSA)     | Moyen     |

## Remédiations principales

Court terme — sept recommandations priorisées :

- R01 — Politique de mot de passe robuste (longueur 14+, complexité, expiration, pas d'user-as-pass, gMSA pour les comptes SPN)
- R02 — Suppression immédiate des credentials exposés (attribut `description`, scripts, partages)
- R03 — Déploiement Microsoft LAPS sur tout le parc
- R04 — Credential Guard + LSA Protection (RunAsPPL)
- R05 — SMB signing obligatoire
- R06 — Politique de verrouillage de compte
- R07 — Suppression des comptes et credentials par défaut

Long terme — quatre chantiers :

- Modèle de tiering Microsoft (Tier 0 / 1 / 2)
- Déploiement SIEM pour supervision et détection
- Durcissement AD global (désactivation NTLM, audit avancé, revue SPN, PingCastle)
- Formation et sensibilisation des administrateurs

## Prochaines étapes

- Rejouer le pentest après application de chaque remédiation individuelle pour mesurer laquelle casse la chaîne et à quelle étape.
- Ajouter une phase DCSync pour compléter la démonstration de contrôle total.
- Intégrer un SIEM (Wazuh) dans le lab pour confronter les événements générés à ce qu'une équipe de détection verrait passer.

## Ressources

- [HackNDo — Pass the Hash](https://beta.hackndo.com/pass-the-hash/)
- [HackNDo — Kerberoasting](https://beta.hackndo.com/kerberoasting/)
- [Microsoft — Securing Active Directory](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/best-practices-for-securing-active-directory)
- [ANSSI — Points de contrôle Active Directory](https://cyber.gouv.fr/publications/points-de-controle-active-directory)
- [PingCastle](https://www.pingcastle.com/)

## Licence

MIT — les scripts de déploiement du lab et les notes de pentest sont fournis à des
fins pédagogiques uniquement.
