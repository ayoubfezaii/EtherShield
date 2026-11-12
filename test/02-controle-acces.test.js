// Tests de la vulnerabilite n°2 : controle d'acces manquant (SWC-105 / SWC-106)
// Execution : npx hardhat test test/02-controle-acces.test.js

const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const DIX_ETHERS = ethers.parseEther("10");

describe("2 - Controle d'acces manquant", function () {
  // Deploie le coffre demande (le premier compte en devient proprietaire)
  // et y depose 10 ETH.
  function creerFixture(nomCoffre) {
    return async function fixture() {
      const [proprietaire, attaquant, autre] = await ethers.getSigners();

      const coffre = await ethers.deployContract(nomCoffre);
      await coffre.connect(proprietaire).deposer({ value: DIX_ETHERS });

      return { coffre, proprietaire, attaquant, autre };
    };
  }

  describe("CoffreVulnerable", function () {
    const fixture = creerFixture("CoffreVulnerable");

    it("FAILLE : n'importe qui peut se nommer proprietaire puis vider le coffre", async function () {
      const { coffre, proprietaire, attaquant } = await loadFixture(fixture);

      // Le vol direct est bien refuse...
      await expect(coffre.connect(attaquant).retirerTout()).to.be.revertedWith(
        "Pas le proprietaire"
      );

      // ...mais rien n'empeche l'attaquant de prendre la propriete du coffre.
      await coffre.connect(attaquant).changerProprietaire(attaquant.address);
      expect(await coffre.proprietaire()).to.equal(attaquant.address);

      // Devenu proprietaire, il vide le coffre en toute "legitimite".
      await expect(coffre.connect(attaquant).retirerTout()).to.changeEtherBalances(
        [coffre, attaquant],
        [-DIX_ETHERS, DIX_ETHERS]
      );

      // Le proprietaire d'origine a perdu tout controle sur son contrat.
      await expect(coffre.connect(proprietaire).retirerTout()).to.be.revertedWith(
        "Pas le proprietaire"
      );
    });
  });

  describe("CoffreSecurise", function () {
    const fixture = creerFixture("CoffreSecurise");

    it("CORRECTION : un inconnu ne peut pas changer le proprietaire", async function () {
      const { coffre, proprietaire, attaquant } = await loadFixture(fixture);

      await expect(
        coffre.connect(attaquant).changerProprietaire(attaquant.address)
      ).to.be.revertedWith("Pas le proprietaire");

      expect(await coffre.proprietaire()).to.equal(proprietaire.address);
    });

    it("CORRECTION : un inconnu ne peut pas vider le coffre", async function () {
      const { coffre, attaquant } = await loadFixture(fixture);

      await expect(coffre.connect(attaquant).retirerTout()).to.be.revertedWith(
        "Pas le proprietaire"
      );
      expect(await ethers.provider.getBalance(await coffre.getAddress())).to.equal(DIX_ETHERS);
    });

    it("le proprietaire legitime peut retirer et transmettre la propriete", async function () {
      const { coffre, proprietaire, autre } = await loadFixture(fixture);

      // Transmission de propriete : evenement emis et etat mis a jour.
      await expect(coffre.connect(proprietaire).changerProprietaire(autre.address))
        .to.emit(coffre, "ProprietaireChange")
        .withArgs(proprietaire.address, autre.address);
      expect(await coffre.proprietaire()).to.equal(autre.address);

      // L'ancien proprietaire n'a plus les droits, le nouveau peut retirer.
      await expect(coffre.connect(proprietaire).retirerTout()).to.be.revertedWith(
        "Pas le proprietaire"
      );
      await expect(coffre.connect(autre).retirerTout()).to.changeEtherBalances(
        [coffre, autre],
        [-DIX_ETHERS, DIX_ETHERS]
      );
    });

    it("refuse l'adresse zero comme nouveau proprietaire", async function () {
      const { coffre, proprietaire } = await loadFixture(fixture);

      await expect(
        coffre.connect(proprietaire).changerProprietaire(ethers.ZeroAddress)
      ).to.be.revertedWith("Adresse zero interdite");
    });
  });
});
