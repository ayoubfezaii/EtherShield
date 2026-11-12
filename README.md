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

## Environnement technique

- Hardhat 2 avec `@nomicfoundation/hardhat-toolbox` (ethers v6, Mocha, Chai)
- Solidity 0.8.24
