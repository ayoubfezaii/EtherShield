// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Banque securisee - correction de la faille de reentrance
/// @notice Meme fonctionnalite que BanqueVulnerable, avec deux protections
///         complementaires (defense en profondeur) :
///           1. le patron Checks-Effects-Interactions (CEI) ;
///           2. un verrou anti-reentrance (equivalent du ReentrancyGuard d'OpenZeppelin).
contract BanqueSecurisee {
    // Solde en wei de chaque client de la banque.
    mapping(address => uint256) public soldes;

    // Verrou anti-reentrance : vrai pendant l'execution d'une fonction protegee.
    bool private verrouille;

    event Depot(address indexed client, uint256 montant);
    event Retrait(address indexed client, uint256 montant);

    /// @dev Protection n°2 : interdit de rentrer dans une fonction protegee
    ///      tant que l'appel precedent n'est pas termine.
    modifier nonReentrant() {
        require(!verrouille, "Reentrance detectee");
        verrouille = true;
        _; // corps de la fonction protegee
        verrouille = false;
    }

    /// @notice Depose des ethers sur le compte de l'appelant.
    function deposer() external payable {
        require(msg.value > 0, "Montant nul");
        soldes[msg.sender] += msg.value;
        emit Depot(msg.sender, msg.value);
    }

    /// @notice Retire la totalite du solde de l'appelant.
    /// @dev Protection n°1 : ordre Verification -> Effet -> Interaction (CEI).
    ///      Le solde est remis a zero AVANT l'envoi des ethers. Si le destinataire
    ///      tente de rappeler retirer() pendant le `call`, son solde vaut deja 0
    ///      et la verification echoue.
    function retirer() external nonReentrant {
        // 1) Verification (Checks)
        uint256 montant = soldes[msg.sender];
        require(montant > 0, "Solde nul");

        // 2) Effet (Effects) : l'etat est mis a jour avant tout appel externe.
        soldes[msg.sender] = 0;

        // 3) Interaction (Interactions) : l'appel externe vient en dernier.
        (bool ok, ) = msg.sender.call{value: montant}("");
        require(ok, "Echec envoi");

        emit Retrait(msg.sender, montant);
    }

    /// @notice Total des ethers detenus par la banque (tous clients confondus).
    function soldeTotal() external view returns (uint256) {
        return address(this).balance;
    }
}
