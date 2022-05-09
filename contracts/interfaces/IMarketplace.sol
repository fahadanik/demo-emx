// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

interface IMarketplace {

    /**
     * @dev Indicates type of a listing.
     */
    enum ListingType {
        FixedPrice,
        Auction
    }

    /**
     * @dev Indicates status of a listing.
     */
    enum ListingStatus {
        Pending,
        Active,
        Successful,
        Rejected
    }

    /**
     * @dev Contains all information for a specific listing.
     */
    struct ListingInfo {
        uint256 blockOfCreation;
        uint256 timeStart;
        uint256 duration;
        uint256 minimalBid;
        uint256 lastBid;
        address lastBidder;
        address creator;
        bytes32 node;
        ListingType listingType;
    }

    /**
     * @dev Emitted when '_auctionStep' is changed.
     */
    event AuctionStepChanged(uint256 newAuctionStep);

    /**
     * @dev Emitted when '_gracePeriod' is changed.
     */
    event GracePeriodChanged(uint256 newGracePeriod);

    /**
     * @dev Emitted when ERC721Project is created.
     */
    event ProjectCreated(address indexed project, address indexed creator, string indexed name, string symbol);

    /**
     * @dev Emitted when external collection is imported.
     */
    event CollectionImported(address indexed collection);

    /**
     * @dev Emitted when listing info is changed.
     */
    event ListingInfoChanged(address indexed collection, uint256 indexed tokenId, bytes32 indexed node, ListingType listingType, uint256 minimalBid, uint256 blockNum);

    /**
     * @dev Emitted when bid for listing with type 'Auction' is successful.
     */
    event AuctionBid(address indexed collection, uint256 indexed tokenId, address indexed bidder, uint256 amount, uint256 blockTimestamp);

    /**
     * @dev Emitted when 'tokenId' from 'collection' is purchased.
     */
    event NFTPurchased(address indexed collection, uint256 indexed tokenId, address indexed newOwner, uint256 payed);

    /**
     * @dev Emitted when 'tokenId' from 'collection' is claimed after successful 'Auction' listing ending.
     */
    event NFTClaimed(address indexed collection, uint256 indexed tokenId, address indexed newOwner, uint256 payed);

    /**
     * @dev Emitted when 'tokenId' from 'collection' is returned to 'recipient' after an unsuccessful listing.
     */
    event NFTReturnedFromSale(address indexed collection, uint256 indexed tokenId, address indexed recipient);

    /**
     * @dev Emitted when 'amount' of funds is claimed by 'recipient'.
     */
    event UnsentFundsClaimed(address recipient, uint256 amount);

    /**
     * @return _auctionStep.
     */
    function auctionStep() external view returns (uint256);

    /**
     * @return _gracePeriod.
     */
    function gracePeriod() external view returns (uint256);

    /**
     * @return _minListingVal.
     */
    function minimalListingValue() external view returns (uint256);

    /**
     * @return length of _allProjects.
     */
    function allProjectsLength() external view returns (uint256);

    /**
     * @return length of _allExternalCollections.
     */
    function allExternalCollectionsLength() external view returns (uint256);

    /**
     * @return address of a project with 'index'.
     */
    function getProject(uint256 index) external view returns (address);

    /**
     * @return address of an external collection with 'index'.
     */
    function getExternalCollection(uint256 index) external view returns (address);

    /**
     * @return listing info of a 'collection' with 'tokenId'.
     */
    function getListingInfo(address collection, uint256 tokenId) external view returns (ListingInfo memory);

    /**
     * @return listing status of a 'collection' with 'tokenId'.
     */
    function getListingStatus(address collection, uint256 tokenId) external view returns (ListingStatus);

    /**
     * @return listing type of a 'collection' with 'tokenId'.
     */
    function getListingType(address collection, uint256 tokenId) external view returns (ListingType);

    /**
     * @dev Sets '_auctionStep' with 'newAuctionStep' value.
     */
    function setAuctionStep(uint256 newAuctionStep) external;

    /**
     * @dev Sets '_beneficiary' with 'newBeneficiary' address.
     */
    function setBeneficiary(address newBeneficiary) external;

    /**
     * @dev Sets '_gracePeriod' with 'newGracePeriod' value.
     */
    function setGracePeriod(uint256 newGracePeriod) external;

    /**
     * @dev Sets '_minListingVal' with 'newMinListingVal' value.
     */
    function setMinListingVal(uint256 newMinListingVal) external;

    /**
     * @dev Sets '_registrar' with 'newRegistrar' address.
     */
    function setRegistrar(address newRegistrar) external;

    /**
     * @dev Sets '_projectsFactory' with 'newProjectsFactory' address.
     */
    function setProjectsFactory(address newProjectsFactory) external;

    /**
     * @dev Mints new 'tokenId' in 'collection' and starts listing with type 'Auction'.
     */
    function createNFTWithAuction(
        address project,
        string calldata tokenURI,
        uint256 timeStart,
        uint256 duration,
        uint256 minimalBid,
        uint256 royalty,
        bytes32 node
    ) external;

    /**
     * @dev Mints new 'tokenId' in 'collection' and starts listing with type 'FixedPrice'.
     */
    function createNFTWithFixedPrice(
        address project,
        string calldata tokenURI,
        uint256 timeStart,
        uint256 duration,
        uint256 value,
        uint256 royalty,
        bytes32 node
    ) external;

    /**
     * @dev Starts listing with type 'Auction'.
     */
    function startAuction(
        address collection,
        uint256 tokenId,
        bytes32 node,
        uint256 timeStart,
        uint256 duration,
        uint256 minimalBid
    ) external;

    /**
     * @dev Starts listing with type 'FixedPrice'.
     */
    function startFixedPrice(
        address collection,
        uint256 tokenId,
        bytes32 node,
        uint256 timeStart,
        uint256 duration,
        uint256 value
    ) external;

    /**
     * @dev Creates ERC721Project.
     * @return address
     */
    function createProject(
        string calldata projectURI,
        string calldata name,
        string calldata symbol
    ) external returns (address);

    /**
     * @dev Adds external collection address.
     */
    function importCollection(
        address collection
    ) external;

    /**
     * @dev Puts bid on a listing with 'Auction' listing type.
     */
    function bid(address collection, uint256 tokenId) external payable;

    /**
     * @dev Allows to purchase 'tokenId' from 'collection' with 'FixedPrice' listing type.
     */
    function purchase(address collection, uint256 tokenId) external payable;

    /**
     * @dev Allows to claim 'tokenId' from 'collection' after successful listing with 'Auction' type.
     */
    function claimNFT(address collection, uint256 tokenId) external;

    /**
     * @dev Allows to claim unsent funds by msg.sender.
     */
    function claimUnsentFunds() external;

    /**
     * @dev Allows to return 'tokenId' from the Marketplace after unsuccessful listing.
     */
    function returnFromSale(address collection, uint256 tokenId) external;

    /**
     * @dev Allows to stop listing of 'tokenId' from 'collection'.
     */
    function stopListing(address collection, uint256 tokenId) external;

    /**
     * @dev Allows to withdraw collected fees.
     */
    function withdrawFees() external;
}
