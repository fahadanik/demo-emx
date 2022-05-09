// SPDX-License-Identifier: agpl-3.0

pragma solidity ^0.8.0;

interface IProjectsFactory {
    /**
     * @dev Creates new ERC721Project.
     */
    function createProject(
        address registrar,
        address marketplace,
        string calldata projectURI,
        string calldata name,
        string calldata symbol,
        address newOwner
    ) external returns (address);
}
