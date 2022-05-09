import {ethers, upgrades} from "hardhat";
import {
    Marketplace
} from "../typechain";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

async function main() {
    let creator: SignerWithAddress;

    [creator] = await ethers.getSigners();
    const marketplaceProxyAddr = "";

    const marketplaceFactory = await ethers.getContractFactory("Marketplace", creator);
    console.log("Preparing upgrade...");
    const marketplace = await upgrades.upgradeProxy(marketplaceProxyAddr, marketplaceFactory);
    console.log(`Marketplace is at: ${marketplace.address}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
