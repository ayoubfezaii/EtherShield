// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Coffre securise - correction du controle d'acces manquant
/// @notice Meme fonctionnalite que CoffreVulnerable, mais chaque fonction
///         d'administration est protegee par le modificateur `seulProprietaire`
///         (meme principe que le contrat Ownable d'OpenZeppelin).
contract CoffreSecurise {
    address public proprietaire;

    event Depot(address indexed deposant, uint256 montant);
    event ProprietaireChange(address indexed ancien, address indexed nouveau);
    event RetraitTotal(address indexed proprietaire, uint256 montant);

    /// @dev Regle d'acces centralisee : on l'ecrit une seule fois et on l'applique
    ///      a chaque fonction sensible. Cela evite d'oublier un `require` quelque part.
    modifier seulProprietaire() {
        require(msg.sender == proprietaire, "Pas le proprietaire");
        _;
    }

    constructor() {
        proprietaire = msg.sender;
    }

    /// @notice Tout le monde peut alimenter le coffre (fonction volontairement ouverte).
    function deposer() external payable {
        require(msg.value > 0, "Montant nul");
        emit Depot(msg.sender, msg.value);
    }

    /// @notice Change le proprietaire du coffre.
    /// @dev CORRECTION : reservee au proprietaire actuel. On refuse aussi l'adresse
    ///      zero, qui bloquerait definitivement les fonds (plus personne ne pourrait
    ///      appeler retirerTout).
    function changerProprietaire(address nouveau) external seulProprietaire {
        require(nouveau != address(0), "Adresse zero interdite");
        emit ProprietaireChange(proprietaire, nouveau);
        proprietaire = nouveau;
    }

    /// @notice Envoie tout le contenu du coffre au proprietaire.
    function retirerTout() external seulProprietaire {
        uint256 montant = address(this).balance;
        (bool ok, ) = proprietaire.call{value: montant}("");
        require(ok, "Echec envoi");
        emit RetraitTotal(proprietaire, montant);
    }
}
