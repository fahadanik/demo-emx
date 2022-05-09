import {ethers, upgrades} from "hardhat";
import {
    Marketplace
} from "../typechain";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

async function main() {
    let creator: SignerWithAddress;

    const registrar = "0x27119e3B41d603D4f9B7C4990234ED3BfF9e310A";
    const nftAuctionStep = ethers.constants.WeiPerEther.div(1000); //1000 ETH
    const minimalListingValue = ethers.constants.WeiPerEther.div(1000); //0.001 ETH
    [creator] = await ethers.getSigners();

    const projectsFactoryFactory = await ethers.getContractFactory("ProjectsFactory", creator);
    const projectsFactory = await projectsFactoryFactory.deploy();
    await projectsFactory.deployed();
    console.log(`Projects Factory is deployed at: ${projectsFactory.address}`);

    const marketplaceFactory = await ethers.getContractFactory("Marketplace", creator);
    const marketplace = await upgrades.deployProxy(
        marketplaceFactory,
        [
            registrar,
            projectsFactory.address,
            nftAuctionStep,
            0,
            minimalListingValue
        ]
    );
    await marketplace.deployed();
    console.log(`Marketplace is deployed at: ${marketplace.address}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
