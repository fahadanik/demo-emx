// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import "../interfaces/IMarketplace.sol";
import "../interfaces/IDomainRegistrar.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract ERC721Project is ERC721Enumerable, Ownable {
    string internal _projectURI;
    IDomainRegistrar internal _registrar;
    IMarketplace internal _marketplace;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => uint256) internal _royalties;
    mapping(uint256 => address) internal _creators;
    mapping(uint256 => bytes32) internal _originDomains;
    bool internal _isDetached;
    string public baseURI;

    constructor(
        address registrar_,
        address marketplace_,
        string memory projectURI_,
        string memory name_,
        string memory symbol_,
        address newOwner_
    ) ERC721(name_, symbol_) {
        _registrar = IDomainRegistrar(registrar_);
        _marketplace = IMarketplace(marketplace_);
        _projectURI = projectURI_;
        baseURI = "ipfs://";
        transferOwnership(newOwner_);
    }

    function mint(
        string calldata tokenURI,
        address creator,
        address receiver,
        uint256 royalty,
        bytes32 node
    ) external returns (uint256) {
        require(
            (msg.sender == owner() && _registrar.active(node, msg.sender)) ||
            (
                !_isDetached &&
                msg.sender == address(_marketplace) &&
                creator == owner() &&
                _registrar.active(node, creator)
            ),
                "ERC721Project: No permissions to mint"
        );

        uint256 supply = totalSupply();
        _mint(receiver, supply);
        _setTokenURI(supply, tokenURI);
        _creators[supply] = creator;
        _originDomains[supply] = node;
        _royalties[supply] = royalty;

        return supply;
    }

    function creator(uint256 tokenId) external view returns (address) {
        return _creators[tokenId];
    }

    function originDomain(uint256 tokenId) external view returns (bytes32) {
        return _originDomains[tokenId];
    }

    function marketplace() external view returns (address) {
        return address(_marketplace);
    }

    function projectURI() external view returns (string memory) {
        return _projectURI;
    }

    function getRoyalty(uint256 tokenId) external view returns (uint256) {
        return _royalties[tokenId];
    }

    function isDetached() external view returns (bool) {
        return _isDetached;
    }

    function toggleDetached() external onlyOwner {
        _isDetached = !_isDetached;
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
