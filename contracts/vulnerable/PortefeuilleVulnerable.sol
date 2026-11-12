// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Portefeuille vulnerable (authentification par tx.origin) - usage pedagogique uniquement
/// @notice NE JAMAIS deployer ce contrat sur un reseau public : il authentifie
///         son proprietaire avec tx.origin (SWC-115).
contract PortefeuilleVulnerable {
    address public proprietaire;

    event Transfert(address indexed destinataire, uint256 montant);

    /// @dev Le portefeuille peut etre alimente des le deploiement.
    constructor() payable {
        proprietaire = msg.sender;
    }

    /// @notice Permet d'alimenter le portefeuille.
    receive() external payable {}

    /// @notice Envoie `montant` wei a `destinataire`. Reserve au proprietaire.
    /// @dev FAILLE : tx.origin designe le compte qui a SIGNE la transaction, tout
    ///      au debut de la chaine d'appels, et non l'appelant direct.
    ///
    ///        Proprietaire --(signe)--> ContratPiege --(appelle)--> Portefeuille
    ///        tx.origin  = Proprietaire   (inchange sur toute la chaine)
    ///        msg.sender = ContratPiege   (appelant direct)
    ///
    ///      Si le proprietaire est amene a interagir avec un contrat malveillant
    ///      (hameconnage), ce contrat peut appeler transferer() : la verification
    ///      ci-dessous passe, car tx.origin est bien le proprietaire.
    function transferer(address payable destinataire, uint256 montant) external {
        require(tx.origin == proprietaire, "Pas le proprietaire");
        (bool ok, ) = destinataire.call{value: montant}("");
        require(ok, "Echec envoi");
        emit Transfert(destinataire, montant);
    }
}
