import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";

import {ethers} from "hardhat";
import {Marketplace, ERC721Project} from "../typechain";
import registrarArtifact from "../artifacts/contracts/domains/DomainRegistrar.sol/DomainRegistrar.json";
import chai from "chai";
import {MockContract, solidity} from "ethereum-waffle";
import { deployMockContract } from 'ethereum-waffle';
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {BigNumber, constants, Contract, utils} from "ethers";

chai.use(solidity);
const {expect} = chai;

let creator: SignerWithAddress,
    user1: SignerWithAddress,
    user2: SignerWithAddress;
let marketplace: Contract,
    mockRegistrar: MockContract,
    project: ERC721Project,
    collection: Contract

let mockNode = ethers.utils.namehash("design.emx");

let timeStart: number;
const auctionStep = constants.WeiPerEther.div(100);
const minimalListingValue = ethers.constants.WeiPerEther.div(1000);
const duration = 200;
const royalty = constants.WeiPerEther.div(10);
const minimalBid = constants.WeiPerEther.div(10);
const bidValue = constants.WeiPerEther.mul(5).add(minimalBid);
const buyValue = constants.WeiPerEther.mul(2);
const auctionTokenID = 0;
const fixedPriceTokenID = 1;

enum ListingStatus {
    Pending,
    Active,
    Successful,
    Rejected
}

describe('Marketplace', function () {
    this.timeout(3000000);
    describe('Base Marketplace features', function () {
        it('Marketplace is created', async () => {
            [user1, user2, creator] = await ethers.getSigners();
            mockRegistrar = await deployMockContract(creator, (registrarArtifact.abi));
            const projectsFactoryFactory = await ethers.getContractFactory("ProjectsFactory", creator);
            const projectsFactory = await projectsFactoryFactory.deploy();
            await projectsFactory.deployed();
            const marketplaceFactory = await ethers.getContractFactory("Marketplace", creator);
            marketplace = await marketplaceFactory.deploy();
            await marketplace.deployed();

            const tx = await marketplace.initialize(
                mockRegistrar.address,
                projectsFactory.address,
                auctionStep,
                0,
                minimalListingValue
            );

            await tx.wait();
            expect(await marketplace.auctionStep()).to.be.eq(auctionStep);
        });

        it('Project is created', async () => {
            const name = "Project name";
            const symbol = "Project symbol";
            const projectURI = "project.uri/metadata.json";

            await marketplace.createProject(projectURI, name, symbol);
            project = await ethers.getContractAt("ERC721Project", await marketplace.getProject(0), creator) as ERC721Project;
            expect(await project.name()).to.be.eq(name);
            expect(await project.symbol()).to.be.eq(symbol);
        });

        it('NFT is minted and auction is started', async () => {
            const tokenURI = "cid/metadata.json";
            timeStart = await getCurrentBlockTimestamp();
            await mockRegistrar.mock.active.withArgs(mockNode, creator.address).returns(true);

            await marketplace.connect(creator).createNFTWithAuction(
                project.address,
                tokenURI,
                timeStart,
                duration,
                minimalBid,
                royalty,
                mockNode
            );

            expect(await project.tokenURI(auctionTokenID)).to.be.eq("ipfs://" + tokenURI);
            await mineNSeconds(Math.floor(duration / 2));
            expect(await marketplace.getListingStatus(project.address, auctionTokenID)).to.be.eq(ListingStatus.Active);
        });

        it(`Users should successfully bid for NFT on auction, incorrect bids are reverted`, async () => {
            await marketplace.connect(user2).bid(project.address, auctionTokenID, {value: bidValue.div(2)});
            await marketplace.connect(user1).bid(project.address, auctionTokenID, {value: bidValue});
            expect((await marketplace.getListingInfo(project.address, auctionTokenID)).lastBidder).to.be.eq(user1.address);
            expect((await marketplace.getListingInfo(project.address, auctionTokenID)).lastBid).to.be.eq(bidValue);
            await expect(marketplace.connect(user2).bid(project.address, auctionTokenID, {value: bidValue.div(2)})).to.be.reverted;
        });

        it(`Winner should acquire NFT from winning an auction`, async () => {
            await mineNSeconds(Math.round(duration / 2));
            expect(await marketplace.getListingStatus(project.address, auctionTokenID)).to.be.eq(ListingStatus.Successful);
            await marketplace.connect(user1).claimNFT(project.address, auctionTokenID);
            expect(await project.ownerOf(auctionTokenID)).to.be.eq(user1.address);
        });

        it('NFT is minted and fixed price listing is started', async () => {
            const tokenURI = "cid/metadata.json";
            timeStart = await getCurrentBlockTimestamp();

            await marketplace.connect(creator).createNFTWithFixedPrice(
                project.address,
                tokenURI,
                timeStart,
                duration,
                buyValue,
                royalty,
                mockNode
            );

            expect(await project.tokenURI(fixedPriceTokenID)).to.be.eq("ipfs://" + tokenURI);
            await mineNSeconds(Math.floor(duration / 2));
            expect(await marketplace.getListingStatus(project.address, fixedPriceTokenID)).to.be.eq(ListingStatus.Active);
        });

        it(`User should buy NFT for fixed price`, async () => {
            await marketplace.connect(user2).purchase(project.address, fixedPriceTokenID, {value: buyValue});
            expect(await marketplace.getListingStatus(project.address, fixedPriceTokenID)).to.be.eq(ListingStatus.Successful);
            expect(await project.ownerOf(fixedPriceTokenID)).to.be.eq(user2.address);
        });

        //RESALES
        it('NFT auction is started', async () => {
            timeStart = await getCurrentBlockTimestamp();
            await project.connect(user1).approve(marketplace.address, auctionTokenID);
            await mockRegistrar.mock.active.withArgs(mockNode, user1.address).returns(true);

            await marketplace.connect(user1).startAuction(
                project.address,
                auctionTokenID,
                mockNode,
                timeStart,
                duration,
                minimalBid
            );

            await mineNSeconds(Math.floor(duration / 2));
            expect(await marketplace.getListingStatus(project.address, auctionTokenID)).to.be.eq(ListingStatus.Active);
        });

        it(`Users should successfully bid for NFT on resale auction, incorrect bids are reverted`, async () => {
            await marketplace.connect(creator).bid(project.address, auctionTokenID, {value: bidValue.div(2)});
            await marketplace.connect(user2).bid(project.address, auctionTokenID, {value: bidValue});
            expect((await marketplace.getListingInfo(project.address, auctionTokenID)).lastBidder).to.be.eq(user2.address);
            expect((await marketplace.getListingInfo(project.address, auctionTokenID)).lastBid).to.be.eq(bidValue);
            await expect(marketplace.connect(user2).bid(project.address, auctionTokenID, {value: bidValue.div(2)})).to.be.reverted;
        });

        it(`Winner should acquire NFT from winning a resale auction`, async () => {
            await mineNSeconds(Math.round(duration / 2));
            expect(await marketplace.getListingStatus(project.address, auctionTokenID)).to.be.eq(ListingStatus.Successful);
            await marketplace.connect(user2).claimNFT(project.address, auctionTokenID);
            expect(await project.ownerOf(auctionTokenID)).to.be.eq(user2.address);
        });

        it('NFT fixed price resale is started', async () => {
            timeStart = await getCurrentBlockTimestamp();
            await project.connect(user2).approve(marketplace.address, fixedPriceTokenID);

            await mockRegistrar.mock.active.withArgs(mockNode, user2.address).returns(true);
            await marketplace.connect(user2).startFixedPrice(
                project.address,
                fixedPriceTokenID,
                mockNode,
                timeStart,
                duration,
                buyValue
            );

            await mineNSeconds(Math.floor(duration / 2));
            expect(await marketplace.getListingStatus(project.address, fixedPriceTokenID)).to.be.eq(ListingStatus.Active);
        });

        it(`User should buy NFT for fixed price on resale`, async () => {
            await marketplace.connect(user1).purchase(project.address, fixedPriceTokenID, {value: buyValue});
            expect(await marketplace.getListingStatus(project.address, fixedPriceTokenID)).to.be.eq(ListingStatus.Successful);
            expect(await project.ownerOf(fixedPriceTokenID)).to.be.eq(user1.address);
        });

        describe('External collection', function () {
            it('External ERC721 Collection is imported', async () => {
                const collectionFactory = await ethers.getContractFactory("ERC721Project", creator);

                collection = await collectionFactory.deploy(
                    mockRegistrar.address,
                    ethers.constants.AddressZero,
                    "uri.cid",
                    "TEST",
                    "TST",
                    creator.address
                );

                let tx = await collection.mint(
                    "uri1.cid",
                    creator.address,
                    creator.address,
                    0,
                    mockNode
                );
                await tx.wait();

                tx = await collection.mint(
                    "uri2.cid",
                    creator.address,
                    creator.address,
                    0,
                    mockNode
                );
                await tx.wait();

                await marketplace.importCollection(collection.address);
                expect(await marketplace.allExternalCollectionsLength()).to.be.eq(1);
                expect(await marketplace.getExternalCollection(0)).to.be.eq(collection.address);
            });
            it('External NFT auction is started', async () => {
                timeStart = await getCurrentBlockTimestamp();
                await collection.connect(creator).approve(marketplace.address, auctionTokenID);
                await marketplace.connect(creator).startAuction(collection.address, auctionTokenID, mockNode, timeStart, duration, minimalBid)

                await mineNSeconds(Math.floor(duration / 2));
                expect(await marketplace.getListingStatus(collection.address, auctionTokenID)).to.be.eq(ListingStatus.Active);
            });
            it(`Users should successfully bid for an external NFT on an auction, incorrect bids are reverted`, async () => {
                await marketplace.connect(user1).bid(collection.address, auctionTokenID, {value: bidValue.div(2)});
                await marketplace.connect(user2).bid(collection.address, auctionTokenID, {value: bidValue});
                expect((await marketplace.getListingInfo(collection.address, auctionTokenID)).lastBidder).to.be.eq(user2.address);
                expect((await marketplace.getListingInfo(collection.address, auctionTokenID)).lastBid).to.be.eq(bidValue);
                await expect(marketplace.connect(user2).bid(collection.address, auctionTokenID, {value: bidValue.div(2)})).to.be.reverted;
            });
            it(`Winner should acquire an external NFT from winning an auction`, async () => {
                await mineNSeconds(Math.round(duration / 2));
                expect(await marketplace.getListingStatus(collection.address, auctionTokenID)).to.be.eq(ListingStatus.Successful);
                await marketplace.connect(user2).claimNFT(collection.address, auctionTokenID);
                expect(await collection.ownerOf(auctionTokenID)).to.be.eq(user2.address);
            });
            it('External NFT fixed price listing is started', async () => {
                timeStart = await getCurrentBlockTimestamp();
                await collection.connect(creator).approve(marketplace.address, fixedPriceTokenID);
                await marketplace.connect(creator).startFixedPrice(collection.address, fixedPriceTokenID, mockNode, timeStart, duration, buyValue);

                await mineNSeconds(Math.floor(duration / 2));
                expect(await marketplace.getListingStatus(collection.address, fixedPriceTokenID)).to.be.eq(ListingStatus.Active);
            });
            it(`User should buy an external NFT for fixed price`, async () => {
                await marketplace.connect(user2).purchase(collection.address, fixedPriceTokenID, {value: buyValue});
                expect(await marketplace.getListingStatus(collection.address, fixedPriceTokenID)).to.be.eq(ListingStatus.Successful);
                expect(await collection.ownerOf(fixedPriceTokenID)).to.be.eq(user2.address);
            });
        });
    });
})

export const getCurrentBlockTimestamp = async function () {
    const latestBlock = await ethers.provider.getBlock(await ethers.provider.getBlockNumber());
    return latestBlock.timestamp;
}

export const mineNSeconds = async function (seconds: number) {
    await ethers.provider.send('evm_increaseTime', [seconds]);
    return await ethers.provider.send('evm_mine', []);
}
