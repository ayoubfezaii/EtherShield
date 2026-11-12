// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Banque vulnerable (reentrance) - usage pedagogique uniquement
/// @notice NE JAMAIS deployer ce contrat sur un reseau public : il contient
///         volontairement une faille de reentrance (SWC-107).
contract BanqueVulnerable {
    // Solde en wei de chaque client de la banque.
    mapping(address => uint256) public soldes;

    event Depot(address indexed client, uint256 montant);
    event Retrait(address indexed client, uint256 montant);

    /// @notice Depose des ethers sur le compte de l'appelant.
    function deposer() external payable {
        require(msg.value > 0, "Montant nul");
        soldes[msg.sender] += msg.value;
        emit Depot(msg.sender, msg.value);
    }

    /// @notice Retire la totalite du solde de l'appelant.
    /// @dev FAILLE : l'ordre des operations est Verification -> Interaction -> Effet.
    ///      L'envoi d'ethers (interaction externe) a lieu AVANT la remise a zero
    ///      du solde. Si msg.sender est un contrat, sa fonction receive() reprend
    ///      la main pendant le `call` et peut rappeler retirer() : le solde n'etant
    ///      pas encore remis a zero, la verification passe a nouveau et la banque
    ///      paie une deuxieme fois, puis une troisieme, etc.
    function retirer() external {
        // 1) Verification : le client a-t-il un solde ?
        uint256 montant = soldes[msg.sender];
        require(montant > 0, "Solde nul");

        // 2) Interaction : envoi des ethers. `call` transmet tout le gaz restant,
        //    ce qui laisse au destinataire de quoi executer du code arbitraire.
        (bool ok, ) = msg.sender.call{value: montant}("");
        require(ok, "Echec envoi");

        // 3) Effet : mise a jour de l'etat... TROP TARD.
        //    Pendant l'etape 2, soldes[msg.sender] valait encore `montant`.
        soldes[msg.sender] = 0;
        emit Retrait(msg.sender, montant);
    }

    /// @notice Total des ethers detenus par la banque (tous clients confondus).
    function soldeTotal() external view returns (uint256) {
        return address(this).balance;
    }
}
