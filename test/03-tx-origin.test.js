// Tests de la vulnerabilite n°3 : authentification par tx.origin (SWC-115)
// Execution : npx hardhat test test/03-tx-origin.test.js

const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const DIX_ETHERS = ethers.parseEther("10");

describe("3 - Authentification par tx.origin", function () {
  // Deploie le portefeuille demande avec 10 ETH (le premier compte en est
  // proprietaire), puis le contrat piege deploye par l'attaquant.
  function creerFixture(nomPortefeuille) {
    return async function fixture() {
      const [proprietaire, attaquant, ami] = await ethers.getSigners();

      const portefeuille = await ethers.deployContract(nomPortefeuille, [], {
        value: DIX_ETHERS,
      });

      const piege = await ethers.deployContract(
        "AttaquantPhishing",
        [await portefeuille.getAddress()],
        attaquant
      );

      return { portefeuille, piege, proprietaire, attaquant, ami };
    };
  }

  describe("PortefeuilleVulnerable", function () {
    const fixture = creerFixture("PortefeuilleVulnerable");

    it("fonctionne normalement quand le proprietaire appelle directement", async function () {
      const { portefeuille, proprietaire, ami } = await loadFixture(fixture);
      const unEther = ethers.parseEther("1");

      await expect(
        portefeuille.connect(proprietaire).transferer(ami.address, unEther)
      ).to.changeEtherBalances([portefeuille, ami], [-unEther, unEther]);
    });

    it("refuse un appel direct de l'attaquant", async function () {
      const { portefeuille, attaquant } = await loadFixture(fixture);

      // Appel direct : tx.origin = attaquant, la verification joue son role.
      await expect(
        portefeuille.connect(attaquant).transferer(attaquant.address, DIX_ETHERS)
      ).to.be.revertedWith("Pas le proprietaire");
    });

    it("FAILLE : le portefeuille est vide si le proprietaire appelle le contrat piege", async function () {
      const { portefeuille, piege, proprietaire, attaquant } = await loadFixture(fixture);

      // Hameconnage : la victime signe elle-meme un appel au contrat piege.
      // Dans le portefeuille, tx.origin = proprietaire -> verification validee.
      await expect(
        piege.connect(proprietaire).reclamerRecompense()
      ).to.changeEtherBalances([portefeuille, attaquant], [-DIX_ETHERS, DIX_ETHERS]);

      expect(await ethers.provider.getBalance(await portefeuille.getAddress())).to.equal(0);
    });
  });

  describe("PortefeuilleSecurise", function () {
    const fixture = creerFixture("PortefeuilleSecurise");

    it("fonctionne normalement quand le proprietaire appelle directement", async function () {
      const { portefeuille, proprietaire, ami } = await loadFixture(fixture);
      const unEther = ethers.parseEther("1");

      await expect(
        portefeuille.connect(proprietaire).transferer(ami.address, unEther)
      ).to.changeEtherBalances([portefeuille, ami], [-unEther, unEther]);
    });

    it("CORRECTION : le meme hameconnage echoue et les fonds restent intacts", async function () {
      const { portefeuille, piege, proprietaire } = await loadFixture(fixture);

      // Dans le portefeuille, msg.sender = contrat piege -> appel rejete.
      await expect(
        piege.connect(proprietaire).reclamerRecompense()
      ).to.be.revertedWith("Pas le proprietaire");

      expect(await ethers.provider.getBalance(await portefeuille.getAddress())).to.equal(
        DIX_ETHERS
      );
    });
  });
});
