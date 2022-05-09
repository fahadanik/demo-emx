// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

interface IRegistry {

    /**
     * @dev Emitted when the owner of a node assigns a new owner to a subnode.
     */
    event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

    /**
     * @dev Emitted when the owner of a node transfers ownership to a new account.
     */
    event Transfer(bytes32 indexed node, address owner);

    /**
     * @dev Sets new record with 'node' and 'owner'.
     */
    function setRecord(bytes32 node, address owner) external;

    /**
     * @dev Sets new 'owner' for 'node' and 'label'.
     */
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner) external returns(bytes32);

    /**
     * @dev Sets new 'owner' for 'node'.
     */
    function setOwner(bytes32 node, address owner) external;

    /**
     * @return 'owner' for 'node'.
     */
    function owner(bytes32 node) external view returns (address);

    /**
     * @return if record for 'node' exists.
     */
    function recordExists(bytes32 node) external view returns (bool);
}
