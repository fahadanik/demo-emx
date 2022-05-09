// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

import "./DomainRegistrar.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev A Domains Resolver for names and addresses lookup.
 */
contract DomainsResolver is Ownable {
    DomainRegistrar public registrar;
    string public tld;
    // The namehash of the TLD
    bytes32 public baseNode;
    address private _controller;

    mapping(bytes32 => string) private _names;
    mapping(bytes32 => address) private _addresses;

    event NameSet(bytes32 indexed node, string indexed name, address sender);
    event AddressSet(bytes32 indexed node, address indexed addr, address sender);
    event ControllerSet(address indexed controller);

    modifier onlyController() {
        require(_controller == msg.sender, "DomainsResolver: Not authorized controller");
        _;
    }

    constructor(DomainRegistrar registrar_, bytes32 baseNode_, string memory tld_) {
        registrar = registrar_;
        baseNode = baseNode_;
        tld = tld_;
    }

    function setInitial(
        string memory name,
        bytes32 label,
        address owner
    ) public onlyController {
        bytes32 node = keccak256(abi.encodePacked(baseNode, label));
        string memory resultName = string(abi.encodePacked(name, string("."), tld));
        _setName(node, resultName);
        _setAddress(node, owner);
    }

    function setName(bytes32 node, string memory name) external onlyController {
        _setName(node, name);
        emit NameSet(node, name, msg.sender);
    }

    function setAddress(bytes32 node, address addr) external {
        require(registrar.active(node, msg.sender), "DomainsResolver: Non-owner cannot set address");
        _setAddress(node, addr);
        emit AddressSet(node, addr, msg.sender);
    }

    function setController(address controller) external onlyOwner {
        _controller = controller;
        emit ControllerSet(controller);
    }

    function getName(bytes32 node) public view returns (string memory) {
        return _names[node];
    }

    function getAddress(bytes32 node) public view returns (address) {
        return _addresses[node];
    }

    function _setName(bytes32 node, string memory name) internal {
        _names[node] = name;
    }

    function _setAddress(bytes32 node, address addr) internal {
        _addresses[node] = addr;
    }
}
