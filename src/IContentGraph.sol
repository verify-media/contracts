// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import "./util/IERC6150.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IContentGraph is IERC6150, IERC721 {
    event Moved(bytes32 indexed _id, bytes32 indexed _from, bytes32 indexed _to);
    event AccessAuthUpdate(bytes32 indexed _id, address indexed _auth);
    event ReferenceAuthUpdate(bytes32 indexed _id, address indexed _auth);
    event URIUpdate(bytes32 indexed _id, string indexed _uri);

    enum NodeType {
        ADMIN,
        COLLECTION,
        ASSET
    }

    struct Asset {
        bytes32 id;
        string uri;
    }

    struct Node {
        uint256 token;
        NodeType nodeType;
        bytes32 id; //TODO not used and not needed
        string uri;
        bytes32[] collectionPath;
        address accessAuth;
        address referenceAuth;
    }

    /**
     * @notice Sets the allowList state for a given address.
     * @param user The address state to change.
     * @param state The new state for the user.
     */
    function setAllowedAddressesState(address user, bool state) external;

    /**
     * @notice Sets the global usage of the allow list.
     * @param state set if the allow list should be enforced.
     */
    function setAllowListedState(bool state) external;

    /**
     * @notice Publishes a new collection node which contains the content listed in its collection.
     * @param id The id of the collection node to create.
     * @param parentId The id of a admin node to publish the collection, and any new assets under.
     * @param uri The URI for the newly created collection metadata.
     * @param collection A list of assets to reference, or create and reference.
     */
    function publishCollection(bytes32 id, bytes32 parentId, string calldata uri, Asset[] calldata collection)
        external;

    /**
     * @notice Publishes a new asset node at a given parent in addition to setting the uri for the asset node.
     * @param id The id of the asset node to create.
     * @param parentId The id of a admin node to publish the asset under.
     * @param uri The URI for the newly created asset metadata.
     */
    function publishAsset(bytes32 id, bytes32 parentId, string calldata uri) external;

    /**
     * @notice Creates a node of a given type under the parent node provided.
     * @param id The id of the node to create, must follow correct form based on type.
     * @param parentId The id of a admin node to publish the node under
     * @param nodeType The type of node to create, ADMIN, COLLECTION, or ASSET
     */
    function createNode(bytes32 id, bytes32 parentId, NodeType nodeType) external;

    /**
     * @notice Sets the collection path for a passed collection node, creating any new assets listed in the collection.
     * @param id The id of the collection node whose collection path needs to be set.
     * @param collection A list of Assets to reference, or create under the same parent as the collection node and reference.
     * @param uri The URI to the updated metadata for the collection.
     */
    function setCollectionPath(bytes32 id, Asset[] calldata collection, string calldata uri) external;

    /**
     * @notice Moves a node from current parent to a new parent.
     * @param id The id of the node to move.
     * @param newParentId The id of an existing admin node to move the node under.
     */
    function move(bytes32 id, bytes32 newParentId) external;

    /**
     * @notice Sets the access auth module for a given node.
     * @param id The id of the node whose auth modules should be set
     * @param accessAuth The address to the auth module to be used access of node's content.
     */
    function setAccessAuth(bytes32 id, address accessAuth) external;

    /**
     * @notice Sets the reference auth module for a given node.
     * @param id The id of the node whose auth modules should be set
     * @param referenceAuth The address to the auth module to be used for referencing a node in collection.
     */
    function setReferenceAuth(bytes32 id, address referenceAuth) external;

    /**
     * @notice Sets the uri for a node.
     * @param id The id of the node.
     * @param uri The URI to the metadata to set for a node.
     */
    function setURI(bytes32 id, string calldata uri) external;

    /**
     * @notice Validates if a given user may access the content at a given node.
     * @param id The id of the node whose content is being accessed.
     * @param user The address of the user who wishes to access the content.
     */
    function auth(bytes32 id, address user) external view returns (bool);

    /**
     * @notice Validates if a given user may reference a given node in a collection.
     * @param id The id of the node who is being referenced.
     * @param user The address of the user who wishes to reference the node.
     */
    function refAuth(bytes32 id, address user) external view returns (bool);

    /**
     * @dev adds a new child element to all parents
     */
    function getNode(bytes32 id) external view returns (Node memory node);

    /**
     * @dev Recursivly finds the nearest auth module for a given node through traversing through the parent node.
     */
    function getAccessAuth(bytes32 id) external view returns (bytes32, address);

    /**
     * @dev Recursivly finds the nearest reference module for a given node through traversing through the parent node.
     */
    function getReferenceAuth(bytes32 id) external view returns (bytes32, address);
}
