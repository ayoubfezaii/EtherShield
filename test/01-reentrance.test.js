// Tests de la vulnerabilite n°1 : reentrance (SWC-107)
// Execution : npx hardhat test test/01-reentrance.test.js

const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const UN_ETHER = ethers.parseEther("1");

describe("1 - Reentrance", function () {
  // Fabrique une "fixture" : deploie la banque demandee, fait deposer 5 ETH
  // par deux clients honnetes, puis deploie le contrat d'attaque pointe sur elle.
  // loadFixture restaure cet etat avant chaque test (instantane de la blockchain).
  function creerFixture(nomBanque) {
    return async function fixture() {
      const [alice, bob, attaquant] = await ethers.getSigners();

      const banque = await ethers.deployContract(nomBanque);
      await banque.connect(alice).deposer({ value: ethers.parseEther("3") });
      await banque.connect(bob).deposer({ value: ethers.parseEther("2") });

      const contratAttaque = await ethers.deployContract(
        "AttaquantReentrance",
        [await banque.getAddress()],
        attaquant
      );

      return { banque, contratAttaque, alice, bob, attaquant };
    };
  }

  describe("BanqueVulnerable", function () {
    const fixture = creerFixture("BanqueVulnerable");

    it("fonctionne normalement pour un client honnete", async function () {
      const { banque, alice } = await loadFixture(fixture);

      // Alice recupere exactement ses 3 ETH.
      await expect(banque.connect(alice).retirer()).to.changeEtherBalances(
        [banque, alice],
        [-ethers.parseEther("3"), ethers.parseEther("3")]
      );
      expect(await banque.soldes(alice.address)).to.equal(0);
    });

    it("FAILLE : l'attaquant vide la banque avec une mise de 1 ETH", async function () {
      const { banque, contratAttaque, alice, bob, attaquant } = await loadFixture(fixture);

      // Avant l'attaque : la banque detient les 5 ETH d'Alice et Bob.
      expect(await banque.soldeTotal()).to.equal(ethers.parseEther("5"));

      // L'attaquant depose 1 ETH puis retire en boucle grace a la reentrance.
      await contratAttaque.connect(attaquant).attaquer({ value: UN_ETHER });

      // Apres l'attaque : la banque est vide...
      expect(await banque.soldeTotal()).to.equal(0);
      // ...le contrat d'attaque detient sa mise + les 5 ETH des clients...
      expect(await ethers.provider.getBalance(await contratAttaque.getAddress())).to.equal(
        ethers.parseEther("6")
      );
      // ...et retirer() a ete rappelee 5 fois pendant le premier retrait.
      expect(await contratAttaque.nombreReentrees()).to.equal(5);

      // La comptabilite interne affiche toujours les soldes des victimes,
      // mais il n'y a plus un seul wei pour les payer.
      expect(await banque.soldes(alice.address)).to.equal(ethers.parseEther("3"));
      expect(await banque.soldes(bob.address)).to.equal(ethers.parseEther("2"));
      await expect(banque.connect(alice).retirer()).to.be.revertedWith("Echec envoi");

      // L'attaquant rapatrie le butin sur son compte.
      await expect(contratAttaque.connect(attaquant).recupererButin()).to.changeEtherBalance(
        attaquant,
        ethers.parseEther("6")
      );
    });
  });

  describe("BanqueSecurisee", function () {
    const fixture = creerFixture("BanqueSecurisee");

    it("fonctionne normalement pour un client honnete", async function () {
      const { banque, alice } = await loadFixture(fixture);

      await expect(banque.connect(alice).retirer()).to.changeEtherBalances(
        [banque, alice],
        [-ethers.parseEther("3"), ethers.parseEther("3")]
      );
      expect(await banque.soldes(alice.address)).to.equal(0);
    });

    it("CORRECTION : la meme attaque echoue et les fonds restent intacts", async function () {
      const { banque, contratAttaque, alice, bob, attaquant } = await loadFixture(fixture);

      // Le rappel de retirer() est rejete dans la banque ; l'envoi d'ethers
      // echoue donc, et toute la transaction d'attaque est annulee.
      await expect(
        contratAttaque.connect(attaquant).attaquer({ value: UN_ETHER })
      ).to.be.revertedWith("Echec envoi");

      // La banque detient toujours les 5 ETH des clients, l'attaquant n'a rien gagne.
      expect(await banque.soldeTotal()).to.equal(ethers.parseEther("5"));
      expect(await ethers.provider.getBalance(await contratAttaque.getAddress())).to.equal(0);

      // Les clients honnetes peuvent toujours retirer leur argent.
      await expect(banque.connect(alice).retirer()).to.changeEtherBalance(
        alice,
        ethers.parseEther("3")
      );
      await expect(banque.connect(bob).retirer()).to.changeEtherBalance(
        bob,
        ethers.parseEther("2")
      );
    });
  });
});
