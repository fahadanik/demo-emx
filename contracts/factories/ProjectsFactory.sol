// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../tokens/ERC721Project.sol";
import "../interfaces/IProjectsFactory.sol";

contract ProjectsFactory is IProjectsFactory {
    function createProject(
        address registrar,
        address marketplace,
        string calldata projectURI,
        string calldata name,
        string calldata symbol,
        address newOwner
    ) external override returns (address project) {
        ERC721Project project = new ERC721Project(registrar, marketplace, projectURI, name, symbol, newOwner);
        return address(project);
    }
}
