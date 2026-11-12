# EtherShield — Rapport de sécurité

Module Blockchain, TEK-UP, ING-4-SSIR

## 1. Objet du rapport

Ce rapport présente trois vulnérabilités classiques des smart contracts Ethereum, reproduites dans un laboratoire local. Pour chacune, il décrit le mécanisme de la faille, sa sévérité, son impact, la correction appliquée et les tests qui en apportent la preuve.

Tout le laboratoire s'exécute sur le réseau local Hardhat, avec des comptes de test. Aucun fonds réel ni réseau public n'est impliqué.

## 2. Synthèse

| # | Vulnérabilité | Référence | Sévérité | Impact démontré | Correction |
|---|---|---|---|---|---|
| 1 | Réentrance | SWC-107 | Critique | Vol de tous les fonds de la banque (5 ETH volés avec 1 ETH de mise) | Patron Checks-Effects-Interactions et verrou anti-réentrance |
| 2 | Contrôle d'accès manquant | SWC-105 / SWC-106 | Critique | Prise de contrôle du contrat et vol des 10 ETH du coffre | Modificateur `seulProprietaire` sur chaque fonction sensible |
| 3 | Authentification par `tx.origin` | SWC-115 | Élevée | Vol des 10 ETH du portefeuille par hameçonnage | Authentification par `msg.sender` |

Échelle de sévérité utilisée :

- **Critique** : perte totale des fonds, exploitable par n'importe qui, sans condition préalable.
- **Élevée** : perte totale des fonds, mais l'attaque exige une action de la victime.

## 3. Vulnérabilité n°1 : réentrance

Fichiers : `contracts/vulnerable/BanqueVulnerable.sol`, `contracts/fixed/BanqueSecurisee.sol`, `contracts/attackers/AttaquantReentrance.sol`, `test/01-reentrance.test.js`.

### 3.1 Description

Quand un contrat envoie des ethers à une adresse avec `call`, et que cette adresse est elle-même un contrat, la fonction `receive()` du destinataire s'exécute. Pendant ce temps, le contrat émetteur est « en pause » au milieu de sa fonction. Le destinataire peut en profiter pour rappeler cette même fonction : c'est la réentrance.

La faille apparaît lorsque le contrat met son état à jour **après** l'appel externe :

```solidity
function retirer() external {
    uint256 montant = soldes[msg.sender];
    require(montant > 0, "Solde nul");                  // 1. vérification

    (bool ok, ) = msg.sender.call{value: montant}("");  // 2. interaction
    require(ok, "Echec envoi");

    soldes[msg.sender] = 0;                             // 3. effet : trop tard
}
```

Pendant l'étape 2, le solde de l'appelant n'est pas encore remis à zéro. Chaque rappel de `retirer()` repasse donc la vérification et déclenche un nouveau paiement.

### 3.2 Scénario d'attaque

1. Alice et Bob déposent 3 ETH et 2 ETH dans la banque.
2. L'attaquant déploie `AttaquantReentrance` et appelle `attaquer()` avec 1 ETH.
3. Le contrat d'attaque dépose 1 ETH, puis appelle `retirer()`.
4. La banque lui envoie 1 ETH, ce qui déclenche son `receive()`.
5. `receive()` rappelle `retirer()`. Le solde enregistré vaut toujours 1 ETH : la banque paie de nouveau.
6. La boucle continue tant que la banque possède au moins 1 ETH.

Résultat mesuré par le test : `retirer()` est rappelée 5 fois, la banque passe de 6 ETH à 0, et l'attaquant repart avec 6 ETH (sa mise plus les 5 ETH des clients).

### 3.3 Sévérité : critique

- **Exploitabilité** : n'importe qui peut lancer l'attaque, en une seule transaction, sans privilège particulier.
- **Impact** : perte de la totalité des fonds du contrat. Les soldes d'Alice et Bob restent affichés dans le contrat, mais il n'y a plus d'ethers pour les honorer.
- **Précédent réel** : l'attaque de The DAO (2016), environ 3,6 millions d'ETH détournés, qui a conduit à la scission entre Ethereum et Ethereum Classic.

### 3.4 Correction

`BanqueSecurisee` combine deux protections.

**Le patron Checks-Effects-Interactions (CEI).** L'état est mis à jour avant l'appel externe :

```solidity
function retirer() external nonReentrant {
    uint256 montant = soldes[msg.sender];
    require(montant > 0, "Solde nul");                  // 1. vérification

    soldes[msg.sender] = 0;                             // 2. effet

    (bool ok, ) = msg.sender.call{value: montant}("");  // 3. interaction
    require(ok, "Echec envoi");
}
```

Si le destinataire rappelle `retirer()`, son solde vaut déjà zéro.

**Un verrou anti-réentrance.** Le modificateur `nonReentrant` refuse tout nouvel appel tant que le précédent n'est pas terminé :

```solidity
modifier nonReentrant() {
    require(!verrouille, "Reentrance detectee");
    verrouille = true;
    _;
    verrouille = false;
}
```

Le CEI suffit à corriger cette fonction. Le verrou est une défense en profondeur : il protège aussi contre les oublis lors d'évolutions futures du contrat. En production, on utilise le `ReentrancyGuard` d'OpenZeppelin, qui applique le même principe.

### 3.5 Preuve par les tests

| Test | Ce qu'il démontre |
|---|---|
| `FAILLE : l'attaquant vide la banque avec une mise de 1 ETH` | La banque vulnérable est vidée, 5 réentrées sont comptées, Alice ne peut plus retirer. |
| `CORRECTION : la meme attaque echoue et les fonds restent intacts` | La même attaque est annulée (`Echec envoi`), la banque conserve ses 5 ETH, Alice et Bob retirent normalement. |
| `fonctionne normalement pour un client honnete` (deux versions) | Le dépôt et le retrait légitimes fonctionnent avant comme après correction. |

## 4. Vulnérabilité n°2 : contrôle d'accès manquant

Fichiers : `contracts/vulnerable/CoffreVulnerable.sol`, `contracts/fixed/CoffreSecurise.sol`, `test/02-controle-acces.test.js`.

### 4.1 Description

En Solidity, une fonction `public` ou `external` peut être appelée par n'importe quelle adresse. C'est au développeur de restreindre explicitement les fonctions sensibles. Dans `CoffreVulnerable`, la fonction qui change le propriétaire a été laissée sans aucune vérification :

```solidity
function changerProprietaire(address nouveau) external {
    proprietaire = nouveau;   // aucune vérification de l'appelant
}
```

La fonction `retirerTout()` vérifie bien que l'appelant est le propriétaire. Cette protection est pourtant inutile, puisque n'importe qui peut d'abord devenir propriétaire.

### 4.2 Scénario d'attaque

1. Le propriétaire déploie le coffre et y dépose 10 ETH.
2. L'attaquant appelle `changerProprietaire(sonAdresse)`.
3. L'attaquant, désormais propriétaire, appelle `retirerTout()` et reçoit les 10 ETH.

Aucun contrat d'attaque n'est nécessaire : deux transactions depuis un compte ordinaire suffisent.

### 4.3 Sévérité : critique

- **Exploitabilité** : triviale. Aucune compétence technique particulière, aucune condition préalable.
- **Impact** : perte de la totalité des fonds et perte définitive du contrôle du contrat par son propriétaire légitime.
- **Précédents réels** : les deux incidents du portefeuille multi-signatures Parity (2017), dus à une fonction d'initialisation restée accessible à tous. Le premier a permis le vol d'environ 150 000 ETH, le second a gelé environ 513 000 ETH. Les défauts de contrôle d'accès figurent en tête du classement OWASP Smart Contract Top 10.

### 4.4 Correction

`CoffreSecurise` centralise la règle d'accès dans un modificateur, appliqué à toutes les fonctions d'administration :

```solidity
modifier seulProprietaire() {
    require(msg.sender == proprietaire, "Pas le proprietaire");
    _;
}

function changerProprietaire(address nouveau) external seulProprietaire {
    require(nouveau != address(0), "Adresse zero interdite");
    proprietaire = nouveau;
}

function retirerTout() external seulProprietaire { ... }
```

Le refus de l'adresse zéro évite une erreur de manipulation qui bloquerait les fonds pour toujours. En production, on utilise les contrats `Ownable` ou `AccessControl` d'OpenZeppelin.

Bonne pratique associée : passer en revue chaque fonction `public` ou `external` et se demander qui a le droit de l'appeler.

### 4.5 Preuve par les tests

| Test | Ce qu'il démontre |
|---|---|
| `FAILLE : n'importe qui peut se nommer proprietaire puis vider le coffre` | L'attaquant devient propriétaire, retire les 10 ETH, et l'ancien propriétaire est rejeté. |
| `CORRECTION : un inconnu ne peut pas changer le proprietaire` | L'appel est rejeté, le propriétaire reste inchangé. |
| `CORRECTION : un inconnu ne peut pas vider le coffre` | L'appel est rejeté, les 10 ETH restent dans le coffre. |
| `le proprietaire legitime peut retirer et transmettre la propriete` | Les fonctions d'administration restent utilisables par le propriétaire. |
| `refuse l'adresse zero comme nouveau proprietaire` | La validation de l'adresse fonctionne. |

## 5. Vulnérabilité n°3 : authentification par `tx.origin`

Fichiers : `contracts/vulnerable/PortefeuilleVulnerable.sol`, `contracts/fixed/PortefeuilleSecurise.sol`, `contracts/attackers/AttaquantPhishing.sol`, `test/03-tx-origin.test.js`.

### 5.1 Description

Solidity expose deux variables qui identifient « qui appelle » :

| Variable | Signification |
|---|---|
| `msg.sender` | L'appelant direct de la fonction (un compte ou un contrat). |
| `tx.origin` | Le compte qui a signé la transaction, au tout début de la chaîne d'appels. |

Lors d'un appel direct, les deux sont identiques. Elles diffèrent dès qu'un contrat intermédiaire s'intercale :

```
Propriétaire ──signe──> Contrat piège ──appelle──> Portefeuille

vu depuis le Portefeuille :
  tx.origin  = Propriétaire
  msg.sender = Contrat piège
```

`PortefeuilleVulnerable` authentifie son propriétaire avec `tx.origin` :

```solidity
function transferer(address payable destinataire, uint256 montant) external {
    require(tx.origin == proprietaire, "Pas le proprietaire");
    ...
}
```

Tout contrat avec lequel le propriétaire interagit peut donc agir en son nom auprès du portefeuille.

### 5.2 Scénario d'attaque

1. Le propriétaire détient 10 ETH dans son portefeuille.
2. L'attaquant déploie `AttaquantPhishing`, qui expose une fonction d'apparence anodine, `reclamerRecompense()`.
3. Par hameçonnage (faux site, faux airdrop), il amène le propriétaire à appeler cette fonction.
4. Le contrat piège appelle `transferer(attaquant, totalité du solde)` sur le portefeuille.
5. Le portefeuille vérifie `tx.origin` : c'est bien le propriétaire. Les 10 ETH partent chez l'attaquant.

### 5.3 Sévérité : élevée

- **Exploitabilité** : l'attaque exige que la victime signe une transaction vers le contrat piège. Cette condition la rend moins directe que les deux précédentes, d'où une sévérité élevée plutôt que critique. L'hameçonnage reste toutefois l'un des vecteurs d'attaque les plus courants de l'écosystème.
- **Impact** : perte de la totalité des fonds du portefeuille en une seule transaction.

### 5.4 Correction

`PortefeuilleSecurise` remplace `tx.origin` par `msg.sender` :

```solidity
require(msg.sender == proprietaire, "Pas le proprietaire");
```

Dans le scénario d'attaque, `msg.sender` vaut l'adresse du contrat piège : l'appel est rejeté.

Règle générale : ne jamais utiliser `tx.origin` pour une décision d'autorisation.

### 5.5 Preuve par les tests

| Test | Ce qu'il démontre |
|---|---|
| `refuse un appel direct de l'attaquant` | La vérification par `tx.origin` semble fonctionner en appel direct, ce qui rend la faille trompeuse. |
| `FAILLE : le portefeuille est vide si le proprietaire appelle le contrat piege` | Les 10 ETH passent du portefeuille à l'attaquant. |
| `CORRECTION : le meme hameconnage echoue et les fonds restent intacts` | Le même appel est rejeté, les 10 ETH restent dans le portefeuille. |
| `fonctionne normalement quand le proprietaire appelle directement` (deux versions) | L'usage légitime fonctionne avant comme après correction. |

## 6. Exécution des tests

Prérequis : Node.js 18 ou plus récent.

```bash
npm install
npx hardhat test
```

Pour ne lancer qu'une vulnérabilité :

```bash
npx hardhat test test/01-reentrance.test.js
npx hardhat test test/02-controle-acces.test.js
npx hardhat test test/03-tx-origin.test.js
```

Résultat obtenu : 14 tests réussis sur 14.

| Fichier de test | Tests |
|---|---|
| `01-reentrance.test.js` | 4 |
| `02-controle-acces.test.js` | 5 |
| `03-tx-origin.test.js` | 5 |

Convention de nommage : un test `FAILLE` réussit quand l'attaque fonctionne sur le contrat vulnérable, un test `CORRECTION` réussit quand la même attaque échoue sur le contrat corrigé.

## 7. Recommandations générales

1. Appliquer systématiquement l'ordre Checks-Effects-Interactions dans toute fonction qui effectue un appel externe.
2. Protéger chaque fonction sensible par un contrôle d'accès explicite, et auditer la visibilité de toutes les fonctions.
3. Authentifier avec `msg.sender`, jamais avec `tx.origin`.
4. S'appuyer sur des bibliothèques auditées (OpenZeppelin : `ReentrancyGuard`, `Ownable`, `AccessControl`) plutôt que de réécrire ces mécanismes.
5. Écrire des tests d'attaque en plus des tests fonctionnels, et compléter par des outils d'analyse statique comme Slither.

## 8. Références

- SWC Registry : SWC-105, SWC-106, SWC-107, SWC-115 — https://swcregistry.io
- OWASP Smart Contract Top 10 — https://owasp.org/www-project-smart-contract-top-10/
- Documentation Solidity, « Security Considerations » — https://docs.soliditylang.org/en/latest/security-considerations.html
- OpenZeppelin Contracts — https://docs.openzeppelin.com/contracts
