require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.24",

  // Rapport de gaz (plugin hardhat-gas-reporter, inclus dans hardhat-toolbox).
  // A chaque `npx hardhat test`, il mesure le gaz consomme par chaque fonction
  // appelee et par chaque deploiement de contrat.
  gasReporter: {
    enabled: true,
    // Le rapport est ecrit dans ce fichier (et non plus dans le terminal).
    outputFile: "gas-report.txt",
    // Pas de codes couleur ANSI : le fichier texte reste lisible.
    noColors: true,
  },
};
