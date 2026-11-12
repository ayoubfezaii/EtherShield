// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Coffre vulnerable (controle d'acces manquant) - usage pedagogique uniquement
/// @notice NE JAMAIS deployer ce contrat sur un reseau public : une fonction
///         d'administration est laissee ouverte a tout le monde (SWC-105 / SWC-106).
contract CoffreVulnerable {
    // Seul le proprietaire est cense pouvoir vider le coffre.
    address public proprietaire;

    event Depot(address indexed deposant, uint256 montant);
    event ProprietaireChange(address indexed ancien, address indexed nouveau);
    event RetraitTotal(address indexed proprietaire, uint256 montant);

    constructor() {
        proprietaire = msg.sender;
    }

    /// @notice Tout le monde peut alimenter le coffre.
    function deposer() external payable {
        require(msg.value > 0, "Montant nul");
        emit Depot(msg.sender, msg.value);
    }

    /// @notice Change le proprietaire du coffre.
    /// @dev FAILLE : aucune verification de l'appelant ! En Solidity, une fonction
    ///      `external` ou `public` est appelable par N'IMPORTE QUELLE adresse tant
    ///      qu'on ne le restreint pas explicitement. Ici, n'importe qui peut donc
    ///      se nommer proprietaire.
    function changerProprietaire(address nouveau) external {
        emit ProprietaireChange(proprietaire, nouveau);
        proprietaire = nouveau;
    }

    /// @notice Envoie tout le contenu du coffre au proprietaire.
    /// @dev Cette fonction est correctement protegee... mais la protection ne vaut
    ///      rien, puisque l'attaquant peut d'abord devenir proprietaire via
    ///      changerProprietaire(). Le controle d'acces doit couvrir TOUTES les
    ///      fonctions sensibles, pas seulement la derniere de la chaine.
    function retirerTout() external {
        require(msg.sender == proprietaire, "Pas le proprietaire");
        uint256 montant = address(this).balance;
        (bool ok, ) = proprietaire.call{value: montant}("");
        require(ok, "Echec envoi");
        emit RetraitTotal(proprietaire, montant);
    }
}
