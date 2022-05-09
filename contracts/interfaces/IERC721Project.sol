// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC721Project {
    /**
     * @dev Mints new 'tokenId' with 'tokenURI', 'creator', 'royalty' and 'node' for 'receiver'.
     * @return tokenId.
     */
    function mint(
        string calldata tokenURI,
        address creator,
        address receiver,
        uint256 royalty,
        bytes32 node
    ) external returns (uint256);

    /**
     * @return address of 'owner' for 'tokenId'.
     */
    function ownerOf(uint256 tokenId) external view returns (address);

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @return address of 'creator' for 'tokenId'.
     */
    function creator(uint256 tokenId) external view returns (address);

    /**
     * @return origin node for 'tokenId'.
     */
    function originDomain(uint256 tokenId) external view returns (bytes32);

    /**
     * @return if ERC721Project is detached from the Marketplace.
     */
    function isDetached() external view returns (bool);

    /**
     * @return 'royalty' for 'tokenId'.
     */
    function getRoyalty(uint256 tokenId) external view returns (uint256);

    /**
     * @return Total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);
}
