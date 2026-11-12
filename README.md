# EtherShield — Laboratoire de sécurité des smart contracts Ethereum

Projet du module Blockchain (TEK-UP, ING-4-SSIR).

EtherShield est un laboratoire pédagogique qui reproduit trois vulnérabilités classiques des smart contracts Solidity. Pour chacune, il fournit le contrat vulnérable, le contrat corrigé et des tests Hardhat qui démontrent la faille puis vérifient que la correction tient.

> **Avertissement.** Les contrats des dossiers `contracts/vulnerable` et `contracts/attackers` sont volontairement dangereux. Ils ne doivent être exécutés que sur le réseau local Hardhat, avec ses comptes de test. Aucun fonds réel ni réseau public n'est utilisé.

## Les trois vulnérabilités

| # | Vulnérabilité | Référence | Sévérité | Contrat vulnérable | Contrat corrigé | Contrat d'attaque |
|---|---|---|---|---|---|---|
| 1 | Réentrance | SWC-107 | Critique | `BanqueVulnerable` | `BanqueSecurisee` | `AttaquantReentrance` |
| 2 | Contrôle d'accès manquant | SWC-105 / SWC-106 | Critique | `CoffreVulnerable` | `CoffreSecurise` | aucun (un simple compte suffit) |
| 3 | Authentification par `tx.origin` | SWC-115 | Élevée | `PortefeuilleVulnerable` | `PortefeuilleSecurise` | `AttaquantPhishing` |

L'explication détaillée de chaque faille (mécanisme, impact, correction) se trouve dans [docs/rapport.md](docs/rapport.md).

## Structure du projet

```
contracts/
  vulnerable/   contrats contenant volontairement une faille
  fixed/        versions corrigées
  attackers/    contrats d'attaque utilisés par les tests
test/
  01-reentrance.test.js
  02-controle-acces.test.js
  03-tx-origin.test.js
docs/
  rapport.md    rapport détaillé
gas-report.txt  rapport de gaz, régénéré à chaque exécution des tests
```

## Prérequis

- Node.js 18 ou plus récent
- npm

## Installation

```bash
npm install
```

## Lancer les tests

Tous les tests :

```bash
npx hardhat test
```

Une seule vulnérabilité :

```bash
npx hardhat test test/01-reentrance.test.js
npx hardhat test test/02-controle-acces.test.js
npx hardhat test test/03-tx-origin.test.js
```

Hardhat compile les contrats, démarre une blockchain locale en mémoire, exécute les tests puis l'arrête. Rien n'est déployé ailleurs.

Résultat attendu : 14 tests réussis.

```
  1 - Reentrance
    BanqueVulnerable
      √ fonctionne normalement pour un client honnete
      √ FAILLE : l'attaquant vide la banque avec une mise de 1 ETH
    BanqueSecurisee
      √ fonctionne normalement pour un client honnete
      √ CORRECTION : la meme attaque echoue et les fonds restent intacts

  2 - Controle d'acces manquant
    CoffreVulnerable
      √ FAILLE : n'importe qui peut se nommer proprietaire puis vider le coffre
    CoffreSecurise
      √ CORRECTION : un inconnu ne peut pas changer le proprietaire
      √ CORRECTION : un inconnu ne peut pas vider le coffre
      √ le proprietaire legitime peut retirer et transmettre la propriete
      √ refuse l'adresse zero comme nouveau proprietaire

  3 - Authentification par tx.origin
    PortefeuilleVulnerable
      √ fonctionne normalement quand le proprietaire appelle directement
      √ refuse un appel direct de l'attaquant
      √ FAILLE : le portefeuille est vide si le proprietaire appelle le contrat piege
    PortefeuilleSecurise
      √ fonctionne normalement quand le proprietaire appelle directement
      √ CORRECTION : le meme hameconnage echoue et les fonds restent intacts

  14 passing
```

## Comment lire les tests

- Un test préfixé `FAILLE` réussit lorsque l'attaque **fonctionne** sur le contrat vulnérable : il prouve que la faille existe.
- Un test préfixé `CORRECTION` réussit lorsque la même attaque **échoue** sur le contrat corrigé.
- Les autres tests vérifient que l'usage légitime continue de fonctionner.

## Analyse du gaz

Le rapport de gaz (`hardhat-gas-reporter`) est activé dans `hardhat.config.js`. Chaque exécution de `npx hardhat test` réécrit le fichier `gas-report.txt` à la racine du projet. Le tableau n'est plus affiché dans le terminal.

Mesures : Solidity 0.8.24, optimiseur désactivé, réseau local Hardhat.

| Vulnérabilité | Opération | Version vulnérable (gaz) | Version corrigée (gaz) | Écart |
|---|---|---:|---:|---:|
| 1. Réentrance | Déploiement de la banque | 414 846 | 466 344 | +51 498 (+12,4 %) |
| | `deposer()` | 45 182 | 45 182 | 0 |
| | `retirer()` | 30 299 | 46 152 | +15 853 (+52,3 %) |
| 2. Contrôle d'accès | Déploiement du coffre | 447 348 | 524 559 | +77 211 (+17,3 %) |
| | `deposer()` | 22 757 | 22 757 | 0 |
| | `changerProprietaire()` | 28 676 | 28 866 | +190 (+0,7 %) |
| | `retirerTout()` | 32 368 | 32 368 | 0 |
| 3. `tx.origin` | Déploiement du portefeuille | 345 024 | 345 024 | 0 |
| | `transferer()` | 35 580 | 35 580 | 0 |

Pourquoi ces écarts :

- **Réentrance : plus cher.** Le verrou anti-réentrance écrit deux fois dans le stockage du contrat à chaque retrait, et l'écriture dans le stockage est l'opération la plus chère de l'EVM. Le contrat contient aussi plus de code, donc son déploiement coûte plus. Le surcoût est justifié : environ 16 000 gaz par retrait, contre le vol de tous les fonds.
- **Contrôle d'accès : presque identique.** La correction ajoute deux vérifications simples (190 gaz) et un peu de code au déploiement. Le surcoût est négligeable par rapport à la perte du contrat.
- **`tx.origin` : identique.** Lire `msg.sender` coûte le même prix que lire `tx.origin`. La correction est gratuite.

Exemple de conversion en ETH, avec la formule du cours `frais = gaz utilisé × (frais de base + pourboire)`, un frais de base de 10 gwei et un pourboire de 2 gwei, pour un retrait sur la banque corrigée (46 152 gaz) :

```
46 152 × (10 + 2) = 553 824 gwei = 0,000553824 ETH
```

Le même retrait sur la banque vulnérable coûte 30 299 × 12 = 363 588 gwei, soit 0,000363588 ETH. La protection coûte donc 0,000190236 ETH de plus par retrait.

L'analyse complète se trouve dans la section « Analyse du gaz » de [docs/rapport.md](docs/rapport.md).

## Environnement technique

- Hardhat 2 avec `@nomicfoundation/hardhat-toolbox` (ethers v6, Mocha, Chai)
- Solidity 0.8.24
