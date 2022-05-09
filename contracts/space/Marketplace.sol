// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IMarketplace.sol";
import "../interfaces/IERC721Project.sol";
import "../interfaces/IProjectsFactory.sol";
import "../interfaces/IDomainRegistrar.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract Marketplace is Initializable, IMarketplace, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    IDomainRegistrar _registrar;
    IProjectsFactory _projectsFactory;
    uint256 internal _auctionStep;
    address internal _beneficiary;
    uint256 internal _feesCollected;
    uint256 internal _gracePeriod;
    uint256 internal _minListingVal;

    //keeping track of genuine projects
    mapping(address => bool) internal _projects;
    //keeping track of imported collections
    mapping(address => bool) internal _externalCollections;
    address[] internal _allProjects;
    address[] internal _allExternalCollections;
    //funds that were not able to be transferred are stored
    mapping(address => uint256) public unsentFunds;

    mapping(address => mapping(uint256 => ListingInfo)) internal _listingInfos;

    // MAX royalty is 50%
    uint256 public constant MAX_ROYALTY = 10**18 / 2;
    // Marketplace fee is 5%
    uint256 public constant FEE = 0; //10**18 / 20;

    function initialize(
        address registrar,
        address projectsFactory,
        uint256 auctionStep,
        uint256 gracePeriod,
        uint256 minListingVal
    ) public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        _registrar = IDomainRegistrar(registrar);
        _projectsFactory = IProjectsFactory(projectsFactory);
        _auctionStep = auctionStep;
        _gracePeriod = gracePeriod;
        _minListingVal = minListingVal;
    }

    function createNFTWithAuction(
        address project,
        string calldata tokenURI,
        uint256 timeStart,
        uint256 duration,
        uint256 minimalBid,
        uint256 royalty,
        bytes32 node
    ) external override {
        require(minimalBid > _minListingVal, "Marketplace: Initial listing value is too low");
        require(royalty <= MAX_ROYALTY, "Marketplace: Resale royalty is too high");
        uint256 tokenId = IERC721Project(project).mint(tokenURI, msg.sender, address(this), royalty, node);
        _startListing(project, tokenId, node, timeStart, duration, minimalBid, ListingType.Auction);
    }

    function createNFTWithFixedPrice(
        address project,
        string calldata tokenURI,
        uint256 timeStart,
        uint256 duration,
        uint256 value,
        uint256 royalty,
        bytes32 node
    ) external override {
        require(value > _minListingVal, "Marketplace: Initial listing value is too low");
        require(royalty <= MAX_ROYALTY, "Marketplace: Resell royalty is too high");
        uint256 tokenId = IERC721Project(project).mint(tokenURI, msg.sender, address(this), royalty, node);
        _startListing(project, tokenId, node, timeStart, duration, value, ListingType.FixedPrice);
    }

    function startAuction(
        address collection,
        uint256 tokenId,
        bytes32 node,
        uint256 timeStart,
        uint256 duration,
        uint256 minimalBid
    ) external override {
        require(minimalBid > _minListingVal, "Marketplace: Initial listing value is too low");
        ListingStatus status = _getListingStatus(collection, tokenId);
        ListingInfo storage listing = _listingInfos[collection][tokenId];
        bool isOwnedBySender = msg.sender == IERC721Project(collection).ownerOf(tokenId);

        require(
            (_projects[collection] || _externalCollections[collection]) &&
            (
                isOwnedBySender ||
                (
                    status == ListingStatus.Rejected &&
                    msg.sender == listing.creator
                )
            ),
            "Marketplace: Cannot start listing"
        );

        require(
            _registrar.active(node, msg.sender),
                "Marketplace: Should own active domain for listing"
        );

        if (isOwnedBySender) {
            IERC721Project(collection).transferFrom(msg.sender, address(this), tokenId);
        }

        require(
            IERC721Project(collection).ownerOf(tokenId) == address(this),
                "Marketplace: Space should own item to start listing"
        );

        _startListing(collection, tokenId, node, timeStart, duration, minimalBid, ListingType.Auction);
    }

    function startFixedPrice(
        address collection,
        uint256 tokenId,
        bytes32 node,
        uint256 timeStart,
        uint256 duration,
        uint256 value
    ) external override {
        require(value > _minListingVal, "Marketplace: Initial listing value is too low");
        ListingStatus status = _getListingStatus(collection, tokenId);
        ListingInfo storage listing = _listingInfos[collection][tokenId];
        bool isOwnedBySender = msg.sender == IERC721Project(collection).ownerOf(tokenId);

        require(
            (_projects[collection] || _externalCollections[collection]) &&
            (
                isOwnedBySender ||
                (
                    status == ListingStatus.Rejected &&
                    msg.sender == listing.creator
                )
            ),
            "Marketplace: Cannot start listing"
        );

        require(
            _registrar.active(node, msg.sender),
            "Marketplace: Should own active domain for listing"
        );

        if (isOwnedBySender) {
            IERC721Project(collection).transferFrom(msg.sender, address(this), tokenId);
        }

        require(
            IERC721Project(collection).ownerOf(tokenId) == address(this),
                "Marketplace: Space should own item to start listing"
        );

        _startListing(collection, tokenId, node, timeStart, duration, value, ListingType.FixedPrice);
    }

    function setAuctionStep(uint256 newAuctionStep) external override onlyOwner {
        _auctionStep = newAuctionStep;
        emit AuctionStepChanged(newAuctionStep);
    }

    function setBeneficiary(address newBeneficiary) external override onlyOwner {
        _beneficiary = newBeneficiary;
    }

    function setGracePeriod(uint256 newGracePeriod) external override onlyOwner {
        _gracePeriod = newGracePeriod;
        emit GracePeriodChanged(newGracePeriod);
    }

    function setMinListingVal(uint256 newMinListingVal) external override onlyOwner {
        _minListingVal = newMinListingVal;
    }

    function setRegistrar(address newRegistrar) external override onlyOwner {
        _registrar = IDomainRegistrar(newRegistrar);
    }

    function setProjectsFactory(address newProjectsFactory) external override onlyOwner {
        _projectsFactory = IProjectsFactory(newProjectsFactory);
    }

    function createProject(
        string calldata projectURI,
        string calldata name,
        string calldata symbol
    ) external override returns (address project) {
        project = _projectsFactory.createProject(address(_registrar), address(this), projectURI, name, symbol, msg.sender);
        _allProjects.push(project);
        _projects[project] = true;

        emit ProjectCreated(project, msg.sender, name, symbol);
        return project;
    }

    function importCollection(
        address collection
    ) external override onlyOwner {
        require(!_externalCollections[collection], "Marketplace: Collection already imported");
        _allExternalCollections.push(collection);
        _externalCollections[collection] = true;

        emit CollectionImported(collection);
    }

    function bid(address collection, uint256 tokenId) external override payable nonReentrant {
        require(
            _getListingStatus(collection, tokenId) == ListingStatus.Active,
                "Marketplace: Bid on non-active listing"
        );

        ListingInfo storage listing = _listingInfos[collection][tokenId];
        require(listing.listingType == ListingType.Auction, "Marketplace: Bid on non-auction listing");
        uint256 minimumToBid = listing.minimalBid;
        uint256 lastBid = listing.lastBid;

        if (lastBid != 0) {
            minimumToBid = lastBid;
        }

        require(msg.value >= minimumToBid + _auctionStep, "Marketplace: Bid too low");
        uint256 timeTillEnd = listing.timeStart + listing.duration - block.timestamp;

        if (timeTillEnd < _gracePeriod) {
            listing.duration += _gracePeriod - timeTillEnd;
        }

        bool sent;

        if (lastBid != 0) {
            (sent, ) = payable(listing.lastBidder).call{value: lastBid}("");

            if (!sent) {
                unsentFunds[listing.lastBidder] += lastBid;
            }
        }

        uint256 bidDelta = msg.value - lastBid;
        uint256 fee = bidDelta * FEE / 10**18;
        uint256 sellerAmount = bidDelta - fee;
        _feesCollected += fee;

        if (_externalCollections[collection]) {
            (sent, ) = payable(listing.creator).call{value: sellerAmount}("");

            if (!sent) {
                unsentFunds[listing.creator] += sellerAmount;
            }
        } else if (_projects[collection]) {
            address tokenIdCreator = IERC721Project(collection).creator(tokenId);

            if (listing.creator == tokenIdCreator) {
                (sent, ) = payable(tokenIdCreator).call{value: sellerAmount}("");

                if (!sent) {
                    unsentFunds[tokenIdCreator] += sellerAmount;
                }
            } else {
                uint256 royalty = IERC721Project(collection).getRoyalty(tokenId);
                uint256 royaltyAmount = bidDelta * royalty / 10**18;
                sellerAmount -= royaltyAmount;
                (sent, ) = payable(listing.creator).call{value: sellerAmount}("");

                if (!sent) {
                    unsentFunds[listing.creator] += sellerAmount;
                }

                (sent, ) = payable(tokenIdCreator).call{value: royaltyAmount}("");

                if (!sent) {
                    unsentFunds[tokenIdCreator] += royaltyAmount;
                }
            }
        }

        listing.lastBidder = msg.sender;
        listing.lastBid = msg.value;

        emit AuctionBid(collection, tokenId, msg.sender, msg.value, block.timestamp);
    }

    function purchase(address collection, uint256 tokenId) external override payable nonReentrant {
        require(
            _getListingStatus(collection, tokenId) == ListingStatus.Active,
            "Marketplace: Bid on non-active listing"
        );

        ListingInfo storage listing = _listingInfos[collection][tokenId];
        require(listing.listingType == ListingType.FixedPrice, "Marketplace: Cannot purchase non-fixed-price");
        uint256 price = listing.minimalBid;
        require(msg.value == price, "Marketplace: msg.value doesn't match price");
        listing.lastBidder = msg.sender;
        listing.lastBid = msg.value;
        IERC721Project(collection).transferFrom(address(this), msg.sender, tokenId);

        uint256 fee = price * FEE / 10**18;
        uint256 sellerAmount = price - fee;
        bool sent;
        _feesCollected += fee;

        if (_externalCollections[collection]) {
            (sent, ) = payable(listing.creator).call{value: sellerAmount}("");

            if (!sent) {
                unsentFunds[listing.creator] += sellerAmount;
            }
        } else if (_projects[collection]) {
            address tokenIdCreator = IERC721Project(collection).creator(tokenId);

            if (listing.creator == tokenIdCreator) {
                (sent, ) = payable(tokenIdCreator).call{value: sellerAmount}("");

                if (!sent) {
                    unsentFunds[tokenIdCreator] += sellerAmount;
                }
            } else {
                uint256 royalty = IERC721Project(collection).getRoyalty(tokenId);
                uint256 royaltyAmount = price * royalty / 10**18;
                sellerAmount -= royaltyAmount;
                (sent, ) = payable(listing.creator).call{value: sellerAmount}("");

                if (!sent) {
                    unsentFunds[listing.creator] += sellerAmount;
                }

                (sent, ) = payable(tokenIdCreator).call{value: royaltyAmount}("");

                if (!sent) {
                    unsentFunds[tokenIdCreator] += royaltyAmount;
                }
            }
        }

        emit NFTPurchased(collection, tokenId, msg.sender, msg.value);
    }

    function claimNFT(address collection, uint256 tokenId) external override nonReentrant {
        require(
            _getListingStatus(collection, tokenId) == ListingStatus.Successful,
                "Marketplace: Listing is not over yet"
        );

        ListingInfo memory listing = _listingInfos[collection][tokenId];
        require(listing.lastBidder == msg.sender, "Marketplace: Only winner can claim");
        IERC721Project(collection).transferFrom(address(this), listing.lastBidder, tokenId);

        emit NFTClaimed(collection, tokenId, listing.lastBidder, listing.lastBid);
    }

    function returnFromSale(address collection, uint256 tokenId) external override {
        require(
            _getListingStatus(collection, tokenId) == ListingStatus.Rejected,
                "Marketplace: Listing is not over yet"
        );

        ListingInfo memory listing = _listingInfos[collection][tokenId];
        require(listing.creator == msg.sender, "Marketplace: Only creator can perform");

        IERC721Project(collection).transferFrom(address(this), msg.sender, tokenId);

        emit NFTReturnedFromSale(collection, tokenId, msg.sender);
    }

    function stopListing(address collection, uint256 tokenId) external override {
        ListingStatus status = _getListingStatus(collection, tokenId);
        ListingInfo memory listing = _listingInfos[collection][tokenId];
        require(listing.creator == msg.sender, "Marketplace: Only creator can perform");
        require(
            status == ListingStatus.Pending || (
                status == ListingStatus.Active &&
                (
                    (listing.listingType == ListingType.Auction && listing.lastBid == 0) ||
                    listing.listingType == ListingType.FixedPrice
                )
            ), "Marketplace: Cannot stop this listing"
        );

        _listingInfos[collection][tokenId].timeStart = 0;
        _listingInfos[collection][tokenId].duration = 0;

        emit ListingInfoChanged(collection, tokenId, listing.node, listing.listingType, listing.minimalBid, block.number);
    }

    function claimUnsentFunds() external override nonReentrant {
        uint256 amount = unsentFunds[msg.sender];
        (bool sent, ) = payable(msg.sender).call{value: amount}("");

        if (sent) {
            unsentFunds[msg.sender] = 0;

            emit UnsentFundsClaimed(msg.sender, amount);
        }
    }

    function withdrawFees() external override onlyOwner nonReentrant {
        require(_beneficiary != address(0), "Marketplace: beneficiary not set");
        (bool sent, ) = payable(_beneficiary).call{value: _feesCollected}("");

        if (sent) {
            _feesCollected = 0;
        }
    }

    function allProjectsLength() external view override returns (uint256) {
        return _allProjects.length;
    }

    function allExternalCollectionsLength() external view override returns (uint256) {
        return _allExternalCollections.length;
    }

    function auctionStep() external view override returns (uint256) {
        return _auctionStep;
    }

    function getExternalCollection(uint256 index) external view override returns (address) {
        return _allExternalCollections[index];
    }

    function getListingInfo(address collection, uint256 tokenId) external view override returns (ListingInfo memory) {
        return _listingInfos[collection][tokenId];
    }

    function getListingStatus(address collection, uint256 tokenId) external view override returns (ListingStatus) {
        return _getListingStatus(collection, tokenId);
    }

    function getListingType(address collection, uint256 tokenId) external view override returns (ListingType) {
        return _listingInfos[collection][tokenId].listingType;
    }

    function getProject(uint256 index) external view override returns (address) {
        return _allProjects[index];
    }

    function gracePeriod() external view override returns (uint256) {
        return _gracePeriod;
    }

    function minimalListingValue() external view override returns (uint256) {
        return _minListingVal;
    }

    function _getListingStatus(address collection, uint256 tokenId) internal view returns (ListingStatus) {
        ListingInfo storage listingInfo = _listingInfos[collection][tokenId];

        if (listingInfo.timeStart > block.timestamp) {
            return ListingStatus.Pending;
        }

        if (listingInfo.timeStart + listingInfo.duration > block.timestamp) {
            if (listingInfo.listingType == ListingType.FixedPrice && listingInfo.lastBid != 0) {
                return ListingStatus.Successful;
            }
            return ListingStatus.Active;
        }

        if (listingInfo.lastBid != 0) {
            return ListingStatus.Successful;
        }

        return ListingStatus.Rejected;
    }

    function _startListing(
        address collection,
        uint256 tokenId,
        bytes32 node,
        uint256 timeStart,
        uint256 duration,
        uint256 minimalBid,
        ListingType listingType
    ) internal {
        ListingInfo storage listing = _listingInfos[collection][tokenId];
        listing.blockOfCreation = block.number;
        listing.timeStart = timeStart;
        listing.duration = duration;
        listing.minimalBid = minimalBid;
        listing.lastBid = 0;
        listing.lastBidder = address(0);
        listing.listingType = listingType;
        listing.creator = msg.sender;
        listing.node = node;

        emit ListingInfoChanged(collection, tokenId, node, listingType, minimalBid, block.number);
    }
}
