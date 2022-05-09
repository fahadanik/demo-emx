// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

import "./IRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

abstract contract IDomainRegistrar is Ownable, IERC721 {
    uint constant public GRACE_PERIOD = 90 days;

    /**
     * @dev Emitted when new controller is set.
     */
    event ControllerSet(address indexed controller);

    /**
     * @dev Emitted when name with 'id' and 'node' is registered.
     */
    event NameRegistered(uint256 indexed id, bytes32 indexed node, address indexed owner, uint expires);

    /**
     * @dev Emitted when name with 'id' and 'node' is renewed.
     */
    event NameRenewed(uint256 indexed id, bytes32 indexed node, uint expires);

    // The registry
    IRegistry public registry;

    // The namehash of the TLD this registrar owns (eg, .ecx)
    bytes32 public baseNode;

    /**
     * @dev Authorises a controller, who can register and renew domains.
     */
    function setController(address controller) virtual external;

    /**
     * @dev Returns the expiration timestamp of the specified id.
     */
    function nameExpires(uint256 id) virtual external view returns(uint);

    /**
     * @dev Returns true if the specified name is available for registration.
     */
    function available(uint256 id) virtual public view returns(bool);

    /**
     * @dev Returns true if domain is valid and owned by the user.
     */
    function active(bytes32 node, address user) virtual public view returns(bool);

    /**
     * @dev Register a name.
     */
    function register(uint256 id, string calldata tokenURI, address owner, uint duration) virtual external returns(uint);

    /**
     * @dev Renew a name.
     */
    function renew(uint256 id, uint duration) virtual external returns(uint);

    /**
     * @dev Reclaim ownership of a name in Registry, if msg.sender owns it in the registrar.
     */
    function reclaim(uint256 id, address owner) virtual external;
}
