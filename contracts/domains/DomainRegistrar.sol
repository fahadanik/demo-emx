// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

import "../interfaces/IRegistry.sol";
import "../interfaces/IDomainRegistrar.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract DomainRegistrar is ERC721, IDomainRegistrar  {
    // A map of expiry times
    mapping(bytes32=>uint) expiries;
    mapping(uint256 => string) private _tokenURIs;
    string public baseURI;
    address internal _controller;

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    constructor(IRegistry registry_, bytes32 baseNode_) ERC721("EMX","EMX") {
        registry = registry_;
        baseNode = baseNode_;
        baseURI = "ipfs://";
    }

    modifier live {
        require(registry.owner(baseNode) == address(this), "DomainRegistrar: No rights to register");
        _;
    }

    modifier onlyController() {
        require(_controller == msg.sender, "DomainRegistrar: Not authorized controller");
        _;
    }

    /**
     * @dev Gets the owner of the specified token ID. Names become unowned
     *      when their registration expires.
     * @param tokenId uint256 ID of the token to query the owner of
     * @return address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 tokenId) public view override(IERC721, ERC721) returns (address) {
        bytes32 node = keccak256(abi.encodePacked(baseNode, bytes32(tokenId)));
        if (expiries[node] > block.timestamp) {
            return super.ownerOf(tokenId);
        }
        return address(0);
    }

    function setController(address controller) external override onlyOwner {
        _controller = controller;
        emit ControllerSet(controller);
    }

    function nameExpires(uint256 id) external view override returns(uint) {
        bytes32 node = keccak256(abi.encodePacked(baseNode, bytes32(id)));
        return expiries[node];
    }

    function available(uint256 id) public view override returns(bool) {
        bytes32 node = keccak256(abi.encodePacked(baseNode, bytes32(id)));
        return expiries[node] + GRACE_PERIOD < block.timestamp;
    }

    function active(bytes32 node, address user) public view override returns(bool) {
        return (expiries[node] > block.timestamp && registry.owner(node) == user);
    }

    /**
     * @dev Register a name.
     * @param id The token ID (keccak256 of the label).
     * @param owner The address that should own the registration.
     * @param duration Duration in seconds for the registration.
     */
    function register(uint256 id, string calldata tokenURI, address owner, uint duration) external override live onlyController returns(uint) {
        require(available(id), "DomainRegistrar: Id not available");

        require(
            block.timestamp + duration + GRACE_PERIOD > block.timestamp + GRACE_PERIOD,
                "DomainRegistrar: Incorrect duration"
        ); // Prevent future overflow

        if(_exists(id)) {
            // Name was previously owned, and expired
            _burn(id);
        }

        _mint(owner, id);
        _setTokenURI(id, tokenURI);
        registry.setSubnodeOwner(baseNode, bytes32(id), owner);
        bytes32 node = keccak256(abi.encodePacked(baseNode, bytes32(id)));
        expiries[node] = block.timestamp + duration;

        emit NameRegistered(id, node, owner, block.timestamp + duration);

        return block.timestamp + duration;
    }

    function renew(uint256 id, uint duration) external override live onlyController returns(uint) {
        bytes32 node = keccak256(abi.encodePacked(baseNode, bytes32(id)));

        require(
            expiries[node] + GRACE_PERIOD >= block.timestamp,
                "DomainRegistrar: Too late to renew"
        ); // Name must be registered here or in grace period

        require(
            expiries[node] + duration + GRACE_PERIOD > duration + GRACE_PERIOD,
                "DomainRegistrar: Incorrect duration"
        ); // Prevent future overflow

        expiries[node] += duration;
        emit NameRenewed(id, node, expiries[node]);
        return expiries[node];
    }

    function reclaim(uint256 id, address owner) external override live {
        require(
            _isApprovedOrOwner(msg.sender, id),
                "DomainRegistrar: No rights to reclaim"
        );

        registry.setSubnodeOwner(baseNode, bytes32(id), owner);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
}
