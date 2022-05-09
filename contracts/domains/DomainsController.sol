// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

import "./DomainRegistrar.sol";
import "./DomainsResolver.sol";
import "../dependencies/utils/Strlen.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @dev A Domains controller for registering and renewing domains.
 */
contract DomainsController is Ownable, ReentrancyGuard {
    using Strlen for *;

    DomainRegistrar registrar;
    DomainsResolver resolver;

    uint256 public price2Letters;
    uint256 public price3Letters;
    uint256 public price4Letters;
    uint256 public price5Letters;
    uint256 public price6Letters;
    uint256 public price7Letters;
    uint256 public price8Letters;
    uint256 public price9Letters;

    uint256 public minDuration;

    event NameRegistered(string name, bytes32 indexed label, address indexed owner, uint cost, uint expires);
    event NameRenewed(string name, bytes32 indexed label, uint cost, uint expires);

    constructor(
        DomainRegistrar registrar_,
        DomainsResolver resolver_,
        uint256[] memory prices_,
        uint256 minDuration_
    ) {
        registrar = registrar_;
        resolver = resolver_;
        price2Letters = prices_[0];
        price3Letters = prices_[1];
        price4Letters = prices_[2];
        price5Letters = prices_[3];
        price6Letters = prices_[4];
        price7Letters = prices_[5];
        price8Letters = prices_[6];
        price9Letters = prices_[7];
        minDuration = minDuration_;
    }

    function rentPrice(string memory name, uint duration) view public returns(uint) {
        return _price(name, duration);
    }

    function valid(string memory name) public pure returns(bool) {
        return name.strlen() >= 2;
    }

    function available(string memory name) public view returns(bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && registrar.available(uint256(label));
    }

    function register(
        string calldata name,
        string calldata tokenURI,
        address owner,
        uint duration
    ) public payable nonReentrant {
        require(available(name), "DomainsController: Name is unavailable");
        require(duration >= minDuration, "DomainsController: Duration is too low");
        uint256 cost = _price(name, duration);

        bytes32 label = keccak256(bytes(name));
        uint256 tokenId = uint256(label);

        uint expires = registrar.register(tokenId, tokenURI, owner, duration);

        resolver.setInitial(name, label, owner);

        emit NameRegistered(name, label, owner, cost, expires);

        if(msg.value > cost) {
            (bool sent, ) = payable(msg.sender).call{value: msg.value - cost}("");
            require(sent, "DomainsController: Failed to return surplus");
        }
    }

    function renew(string calldata name, uint duration) external payable nonReentrant {
        uint cost = _price(name, duration);
        require(msg.value >= cost, "DomainsController: Underpriced");
        require(duration >= minDuration, "DomainsController: Duration is too low");

        bytes32 label = keccak256(bytes(name));
        uint expires = registrar.renew(uint256(label), duration);

        if(msg.value > cost) {
            (bool sent, ) = payable(msg.sender).call{value: msg.value - cost}("");
            require(sent, "DomainsController: Failed to return surplus");
        }

        emit NameRenewed(name, label, cost, expires);
    }

    function setPrices(uint256[] memory prices) public onlyOwner {
        price2Letters = prices[0];
        price3Letters = prices[1];
        price4Letters = prices[2];
        price5Letters = prices[3];
        price6Letters = prices[4];
        price7Letters = prices[5];
        price8Letters = prices[6];
        price9Letters = prices[7];
    }

    function withdraw() public onlyOwner nonReentrant {
        (bool sent, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(sent, "DomainsController: Failed to withdraw");
    }

    function _price(
        string memory name,
        uint256 duration
    ) internal view returns (uint256) {
        uint256 len = name.strlen();
        uint256 basePrice;

        if (len == 2) {
            basePrice = price2Letters * duration;
        } else if (len == 3) {
            basePrice = price3Letters * duration;
        } else if (len == 4) {
            basePrice = price4Letters * duration;
        } else if (len == 5) {
            basePrice = price5Letters * duration;
        } else if (len == 6) {
            basePrice = price6Letters * duration;
        } else if (len == 7) {
            basePrice = price7Letters * duration;
        } else if (len == 8) {
            basePrice = price8Letters * duration;
        } else {
            basePrice = price9Letters * duration;
        }

        return basePrice;
    }
}
