// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// Note: the ERC-165 identifier for this interface is 0x897e2c73.
interface IERC6150 { /* is IERC721, IERC165 */
    /**
     * @notice Emitted when `tokenId` token under `parentId` is minted.
     * @param minter The address of minter
     * @param to The address received token
     * @param parentId The id of parent token, if it's zero, it means minted `tokenId` is a root token.
     * @param tokenId The id of minted token, required to be greater than zero
     */
    event Minted(address indexed minter, address indexed to, uint256 parentId, uint256 tokenId);

    /**
     * @notice Get the parent token of `tokenId` token.
     * @param tokenId The child token
     * @return parentId The Parent token found
     */
    function parentOf(uint256 tokenId) external view returns (uint256 parentId);

    /**
     * @notice Get the children tokens of `tokenId` token.
     * @param tokenId The parent token
     * @return childrenIds The array of children tokens
     */
    function childrenOf(uint256 tokenId) external view returns (uint256[] memory childrenIds);

    /**
     * @notice Check the `tokenId` token if it is a root token.
     * @param tokenId The token want to be checked
     * @return Return `true` if it is a root token; if not, return `false`
     */
    function isRoot(uint256 tokenId) external view returns (bool);

    /**
     * @notice Check the `tokenId` token if it is a leaf token.
     * @param tokenId The token want to be checked
     * @return Return `true` if it is a leaf token; if not, return `false`
     */
    function isLeaf(uint256 tokenId) external view returns (bool);
}

// Note: the ERC-165 identifier for this interface is 0xba541a2e.
interface IERC6150Enumerable is IERC6150 /* IERC721Enumerable */ {
    /**
     * @notice Get total amount of children tokens under `parentId` token.
     * @dev If `parentId` is zero, it means get total amount of root tokens.
     * @return The total amount of children tokens under `parentId` token.
     */
    function childrenCountOf(uint256 parentId) external view returns (uint256);

    /**
     * @notice Get the token at the specified index of all children tokens under `parentId` token.
     * @dev If `parentId` is zero, it means get root token.
     * @return The token ID at `index` of all chlidren tokens under `parentId` token.
     */
    function childOfParentByIndex(uint256 parentId, uint256 index) external view returns (uint256);

    /**
     * @notice Get the index position of specified token in the children enumeration under specified parent token.
     * @dev Throws if the `tokenId` is not found in the children enumeration.
     * If `parentId` is zero, means get root token index.
     * @param parentId The parent token
     * @param tokenId The specified token to be found
     * @return The index position of `tokenId` found in the children enumeration
     */
    function indexInChildrenEnumeration(uint256 parentId, uint256 tokenId) external view returns (uint256);
}

// Note: the ERC-165 identifier for this interface is 0x4ac0aa46.
interface IERC6150Burnable is IERC6150 {
    /**
     * @notice Burn the `tokenId` token.
     * @dev Throws if `tokenId` is not a leaf token.
     * Throws if `tokenId` is not a valid NFT.
     * Throws if `owner` is not the owner of `tokenId` token.
     * Throws unless `msg.sender` is the current owner, an authorized operator, or the approved address for this token.
     * @param tokenId The token to be burnt
     */
    function safeBurn(uint256 tokenId) external;

    /**
     * @notice Batch burn tokens.
     * @dev Throws if one of `tokenIds` is not a leaf token.
     * Throws if one of `tokenIds` is not a valid NFT.
     * Throws if `owner` is not the owner of all `tokenIds` tokens.
     * Throws unless `msg.sender` is the current owner, an authorized operator, or the approved address for all `tokenIds`.
     * @param tokenIds The tokens to be burnt
     */
    function safeBatchBurn(uint256[] memory tokenIds) external;
}

// Note: the ERC-165 identifier for this interface is 0xfa574808.
interface IERC6150ParentTransferable is IERC6150 {
    /**
     * @notice Emitted when the parent of `tokenId` token changed.
     * @param tokenId The token changed
     * @param oldParentId Previous parent token
     * @param newParentId New parent token
     */
    event ParentTransferred(uint256 tokenId, uint256 oldParentId, uint256 newParentId);

    /**
     * @notice Transfer parentship of `tokenId` token to a new parent token
     * @param newParentId New parent token id
     * @param tokenId The token to be changed
     */
    function transferParent(uint256 newParentId, uint256 tokenId) external;

    /**
     * @notice Batch transfer parentship of `tokenIds` to a new parent token
     * @param newParentId New parent token id
     * @param tokenIds Array of token ids to be changed
     */
    function batchTransferParent(uint256 newParentId, uint256[] memory tokenIds) external;
}

// Note: the ERC-165 identifier for this interface is 0x1d04f0b3.
interface IERC6150AccessControl is IERC6150 {
    /**
     * @notice Check the account whether a admin of `tokenId` token.
     * @dev Each token can be set more than one admin. Admin have permission to do something to the token, like mint child token,
     * or burn token, or transfer parentship.
     * @param tokenId The specified token
     * @param account The account to be checked
     * @return If the account has admin permission, return true; otherwise, return false.
     */
    function isAdminOf(uint256 tokenId, address account) external view returns (bool);

    /**
     * @notice Check whether the specified parent token and account can mint children tokens
     * @dev If the `parentId` is zero, check whether account can mint root nodes
     * @param parentId The specified parent token to be checked
     * @param account The specified account to be checked
     * @return If the token and account has mint permission, return true; otherwise, return false.
     */
    function canMintChildren(uint256 parentId, address account) external view returns (bool);

    /**
     * @notice Check whether the specified token can be burnt by specified account
     * @param tokenId The specified token to be checked
     * @param account The specified account to be checked
     * @return If the tokenId can be burnt by account, return true; otherwise, return false.
     */
    function canBurnTokenByAccount(uint256 tokenId, address account) external view returns (bool);
}
