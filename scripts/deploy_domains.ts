import {ethers, upgrades} from "hardhat";
import {
    Registry,
    DomainRegistrar,
    DomainsController
} from "../typechain";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

async function main() {
    const ZERO_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000";

    const price2Letters = ethers.constants.WeiPerEther.div(31536000);
    const price3Letters = ethers.constants.WeiPerEther.div(2).div(31536000);
    const price4Letters = ethers.constants.WeiPerEther.div(4).div(31536000);
    const price5Letters = ethers.constants.WeiPerEther.div(10).div(31536000);
    const price6Letters = ethers.constants.WeiPerEther.div(100).div(31536000);
    const price7Letters = ethers.constants.WeiPerEther.div(500).div(31536000);
    const price8Letters = ethers.constants.WeiPerEther.div(1000).div(31536000);
    const price9Letters = 0;

    const minDuration = 31535000;

    const labelhash = (label: string) => ethers.utils.keccak256(ethers.utils.toUtf8Bytes(label));
    const tld = "emx";

    let creator: SignerWithAddress;
    [creator] = await ethers.getSigners();
    const registryFactory = await ethers.getContractFactory("Registry", creator);
    const domainRegistrarFactory = await ethers.getContractFactory("DomainRegistrar", creator);
    const domainsControllerFactory = await ethers.getContractFactory("DomainsController", creator);
    const domainsResolverFactory = await ethers.getContractFactory("DomainsResolver", creator);

    const registry = await registryFactory.deploy();
    await registry.deployed();
    console.log(`Registry deployed at: ${registry.address}`);

    const domainRegistrar = await domainRegistrarFactory.deploy(registry.address, ethers.utils.namehash(tld));
    await domainRegistrar.deployed();
    console.log(`Domain Registrar deployed at: ${domainRegistrar.address}`);

    const domainsResolver = await domainsResolverFactory.deploy(domainRegistrar.address, ethers.utils.namehash(tld), tld);
    await domainsResolver.deployed();
    console.log(`Domain Resolver deployed at: ${domainsResolver.address}`);

    const domainsController = await domainsControllerFactory.deploy(
        domainRegistrar.address,
        domainsResolver.address,
        [
            price2Letters,
            price3Letters,
            price4Letters,
            price5Letters,
            price6Letters,
            price7Letters,
            price8Letters,
            price9Letters
        ],
        minDuration
    );
    await domainsController.deployed();
    console.log(`Domains Controller deployed at: ${domainsController.address}`);

    let tx = await registry.setSubnodeOwner(ZERO_HASH, labelhash(tld), domainRegistrar.address);
    await tx.wait();
    tx = await domainRegistrar.setController(domainsController.address);
    await tx.wait();
    tx = await domainsResolver.setController(domainsController.address);
    await tx.wait();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
