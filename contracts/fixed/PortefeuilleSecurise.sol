// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Portefeuille securise - correction de l'authentification par tx.origin
/// @notice Meme fonctionnalite que PortefeuilleVulnerable, mais l'appelant est
///         authentifie avec msg.sender.
contract PortefeuilleSecurise {
    address public proprietaire;

    event Transfert(address indexed destinataire, uint256 montant);

    /// @dev Le portefeuille peut etre alimente des le deploiement.
    constructor() payable {
        proprietaire = msg.sender;
    }

    /// @notice Permet d'alimenter le portefeuille.
    receive() external payable {}

    /// @notice Envoie `montant` wei a `destinataire`. Reserve au proprietaire.
    /// @dev CORRECTION : msg.sender est l'appelant DIRECT de la fonction.
    ///      Si un contrat piege s'intercale entre le proprietaire et le
    ///      portefeuille, msg.sender vaut l'adresse du piege et l'appel est rejete.
    function transferer(address payable destinataire, uint256 montant) external {
        require(msg.sender == proprietaire, "Pas le proprietaire");
        (bool ok, ) = destinataire.call{value: montant}("");
        require(ok, "Echec envoi");
        emit Transfert(destinataire, montant);
    }
}
