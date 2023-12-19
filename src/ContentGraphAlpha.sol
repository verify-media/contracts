// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {IAuthorization} from "./IAuthorization.sol";
import {ERC6150Upgradeable} from "./util/ERC6150Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

/**
 * @title ContentGraph
 * @author BlockchainCreativeLabs
 *
 * @notice A graph of content
 */
contract ContentGraph is OwnableUpgradeable, ERC6150Upgradeable {
    uint256 public totalSupply;
    mapping(bytes32 => Node) nodes;
    mapping(address => uint256) public nodesCreated;
    mapping(uint256 => bytes32) tokenToId;
    mapping(address => bool) public allowedAddresses;
    bool public allowListed;

    error NotAuthorised();
    error InvalidParams();
    error NodeDoesNotExist();
    error NodeAlreadyExists();

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
        bytes32 id;
        string uri;
        bytes32[] collectionPath;
        address accessAuth;
        address referenceAuth;
    }

    event Moved(bytes32 indexed _id, bytes32 indexed _from, bytes32 indexed _to);
    event AccessAuthUpdate(bytes32 indexed _id, address indexed _auth);
    event ReferenceAuthUpdate(bytes32 indexed _id, address indexed _auth);
    event URIUpdate(bytes32 indexed _id, string indexed _uri);

    /**
     * @notice Validates if a given id is correctly formed.
     * @param id The node id.
     * @param isAssetId A boolean on if the passed id is for a asset node.
     */
    modifier validID(bytes32 id, bool isAssetId) {
        if (nodes[id].token != 0) {
            revert NodeAlreadyExists();
        }
        if (isAssetId) {
            if (id == bytes32(0)) revert InvalidParams();
            _;
        } else {
            uint256 count = nodesCreated[msg.sender] + 1;
            if (id != keccak256(abi.encodePacked(msg.sender, count))) revert InvalidParams();
            _;
        }
    }

    modifier onlyAllowed() {
        if (allowListed) {
            if (!allowedAddresses[msg.sender]) {
                revert NotAuthorised();
            }
        }
        _;
    }

    /**
     * @notice Validates if a given id is associated with an existing node.
     * @param id The id value to check.
     */
    modifier exists(bytes32 id) {
        if (nodes[id].token == 0) {
            revert NodeDoesNotExist();
            _;
        }
        _;
    }

    /**
     * @notice Validates if a id given that will be used as a parent is valid, i,e an admin node.
     * @param id The id value to check.
     */
    modifier validParent(bytes32 id) {
        if (nodes[id].nodeType != NodeType.ADMIN) {
            revert InvalidParams();
        }
        _;
    }

    /**
     * @notice Validates if a caller is the owner of a ID, everyone is the owner of the Root
     * @param id The id to check.
     * @param account The address to check.
     */
    modifier onlyNodeOwner(bytes32 id, address account) {
        uint256 tokenId = nodes[id].token;
        if (tokenId != 0) {
            _requireOwned(tokenId);
            if (!(tokenId == 0) && !(account == ownerOf(tokenId))) {
                revert NotAuthorised();
            }
        } else if (bytes32(0) != id) {
            revert NodeDoesNotExist();
        }
        _;
    }

    /**
     * @notice Validates if a caller can reference all the nodes provided in a collection path.
     * @param collection A list of Assets that a caller wishes to reference in it's collection.
     */
    modifier canReferenceAll(Asset[] calldata collection) {
        uint256 length = collection.length;
        for (uint256 i = 0; i < length;) {
            if (nodes[collection[i].id].token != 0) {
                bool referenceAllowed = refAuth(collection[i].id, msg.sender);
                bool isNotAdmin = nodes[collection[i].id].nodeType != NodeType.ADMIN;
                bool canReference = (isNotAdmin && referenceAllowed);
                if (!canReference) {
                    revert NotAuthorised();
                }
            }
            unchecked {
                ++i;
            }
        }
        _;
    }

    /**
     * @dev Used to intialize the values through the transparent proxy upgrade pattern.
     * https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies
     */
    function initialize(string memory name_, string memory symbol_) public initializer {
        __Ownable_init(msg.sender);
        __ERC6150_init(name_, symbol_);
        allowListed = true;
    }

    /**
     * @notice Sets the allowList state for a given address.
     * @param user The address state to change.
     * @param state The new state for the user.
     */
    function setAllowedAddressesState(address user, bool state) public onlyOwner {
        allowedAddresses[user] = state;
    }

    /**
     * @notice Sets the global usage of the allow list.
     * @param state set if the allow list should be enforced.
     */
    function setAllowListedState(bool state) public onlyOwner {
        allowListed = state;
    }

    /**
     * @notice Publishes a new collection node which contains the content listed in its collection.
     * @param id The id of the collection node to create.
     * @param parentId The id of a admin node to publish the collection, and any new assets under.
     * @param uri The URI for the newly created collection metadata.
     * @param collection A list of assets to reference, or create and reference.
     */
    function publishCollection(bytes32 id, bytes32 parentId, string calldata uri, Asset[] calldata collection) public {
        createNode(id, parentId, NodeType.COLLECTION);
        setCollectionPath(id, collection, uri);
    }

    /**
     * @notice Publishes a new asset node at a given parent in addition to setting the uri for the asset node.
     * @param id The id of the asset node to create.
     * @param parentId The id of a admin node to publish the asset under.
     * @param uri The URI for the newly created asset metadata.
     */
    function publishAsset(bytes32 id, bytes32 parentId, string calldata uri) public {
        createNode(id, parentId, NodeType.ASSET);
        setURI(id, uri);
    }

    /**
     * @notice Creates a node of a given type under the parent node provided.
     * @param id The id of the node to create, must follow correct form based on type.
     * @param parentId The id of a admin node to publish the node under
     * @param nodeType The type of node to create, ADMIN, COLLECTION, or ASSET
     */
    function createNode(bytes32 id, bytes32 parentId, NodeType nodeType)
        public
        onlyAllowed
        onlyNodeOwner(parentId, msg.sender)
        validParent(parentId)
        validID(id, (nodeType == NodeType.ASSET))
    {
        uint256 parentTokenId = nodes[parentId].token;
        uint256 tokenId = totalSupply + 1;
        _safeMintWithParent(msg.sender, parentTokenId, tokenId);
        totalSupply = totalSupply + 1;
        nodes[id].token = tokenId;
        nodes[id].nodeType = nodeType;
        nodes[id].id = id;
        tokenToId[tokenId] = id;
        nodesCreated[msg.sender]++;
    }

    /**
     * @notice Sets the collection path for a passed collection node, creating any new assets listed in the collection.
     * @param id The id of the collection node whose collection path needs to be set.
     * @param collection A list of Assets to reference, or create under the same parent as the collection node and reference.
     * @param uri The URI to the updated metadata for the collection.
     */
    function setCollectionPath(bytes32 id, Asset[] calldata collection, string calldata uri)
        public
        onlyNodeOwner(id, msg.sender)
        canReferenceAll(collection)
    {
        require(nodes[id].nodeType == NodeType.COLLECTION);
        bytes32 parentId = parentOf(id);
        nodes[id].collectionPath = _safeBulkCreateAssets(parentId, collection);
        setURI(id, uri);
    }

    /**
     * @notice Moves a node from current parent to a new parent.
     * @param id The id of the node to move.
     * @param newParentId The id of an existing admin node to move the node under.
     */
    function move(bytes32 id, bytes32 newParentId)
        public
        onlyNodeOwner(id, msg.sender)
        onlyNodeOwner(newParentId, msg.sender)
        validParent(newParentId)
    {
        uint256 token = nodes[id].token;
        uint256 newParent = nodes[newParentId].token;
        bytes32 parentId = tokenToId[parentOf(token)];
        uint256 parent = parentOf(token);
        uint256 nodeIndex = _indexInChildrenArray[token];

        for (uint256 i = nodeIndex; i < _childrenOf[parent].length - 1; i++) {
            _childrenOf[parent][i] = _childrenOf[parent][i + 1];
            _indexInChildrenArray[_childrenOf[parent][i + 1]] = i;
        }
        _childrenOf[parent].pop();
        //Set the parent of token to new id
        _parentOf[token] = newParent;
        //Add the token to the newParent children array
        _childrenOf[newParent].push(token);
        //Change the index in children array to new value
        _indexInChildrenArray[token] = _childrenOf[newParent].length - 1;
        emit Moved(id, parentId, newParentId);
    }

    /**
     * @notice Sets the access auth module for a given node.
     * @param id The id of the node whose auth modules should be set
     * @param accessAuth The address to the auth module to be used access of node's content.
     */
    function setAccessAuth(bytes32 id, address accessAuth) public onlyNodeOwner(id, msg.sender) exists(id) {
        nodes[id].accessAuth = accessAuth;
        emit AccessAuthUpdate(id, accessAuth);
    }

    /**
     * @notice Sets the reference auth module for a given node.
     * @param id The id of the node whose auth modules should be set
     * @param referenceAuth The address to the auth module to be used for referencing a node in collection.
     */
    function setReferenceAuth(bytes32 id, address referenceAuth) public onlyNodeOwner(id, msg.sender) exists(id) {
        nodes[id].referenceAuth = referenceAuth;
        emit ReferenceAuthUpdate(id, referenceAuth);
    }

    /**
     * @notice Sets the uri for a node.
     * @param id The id of the node.
     * @param uri The URI to the metadata to set for a node.
     */
    function setURI(bytes32 id, string calldata uri) public onlyNodeOwner(id, msg.sender) exists(id) {
        nodes[id].uri = uri;
        emit URIUpdate(id, uri);
    }

    /**
     * @notice Validates if a given user may access the content at a given node.
     * @param id The id of the node whose content is being accessed.
     * @param user The address of the user who wishes to access the content.
     */
    function auth(bytes32 id, address user) public view exists(id) returns (bool) {
        bytes32 accessAuthAt;
        address accessAuth;
        (accessAuthAt, accessAuth) = getAccessAuth(id);
        if (accessAuth == address(0)) {
            return (true && authCollection(id, user));
        } else {
            return IAuthorization(accessAuth).auth(accessAuthAt, user) && authCollection(id, user);
        }
    }

    /**
     * @notice Validates if a given user may reference a given node in a collection.
     * @param id The id of the node who is being referenced.
     * @param user The address of the user who wishes to reference the node.
     */
    function refAuth(bytes32 id, address user) public view exists(id) returns (bool) {
        bytes32 referenceAuthAt;
        address referenceAuth;
        (referenceAuthAt, referenceAuth) = getReferenceAuth(id);
        if (referenceAuth == address(0)) {
            return true;
        } else {
            return IAuthorization(referenceAuth).auth(referenceAuthAt, user);
        }
    }

    /**
     * @dev retrieve node from id
     */
    function getNode(bytes32 id) external view exists(id) returns (Node memory node) {
        node = nodes[id];
    }

    /**
     * @dev retrieve node from token id
     */
    function tokenToNode(uint256 token) external view exists(tokenToId[token]) returns (Node memory node) {
        node = nodes[tokenToId[token]];
    }

    /**
     * @dev Used to create new Assets in a collection if they don't already exist.
     */
    function _safeBulkCreateAssets(bytes32 parentId, Asset[] calldata collection)
        internal
        returns (bytes32[] memory ids)
    {
        uint256 collectionLength = collection.length;
        ids = new bytes32[](collectionLength);
        if (collectionLength == 0) revert InvalidParams();
        for (uint256 i = 0; i < collectionLength;) {
            Asset calldata asset = collection[i];
            if (nodes[asset.id].token == 0) {
                publishAsset(asset.id, parentId, asset.uri);
            }
            ids[i] = asset.id;
            unchecked {
                ++i;
            }
        }
        return ids;
    }

    /**
     * @dev Will return a id of a parent node for a passed node id.
     */
    function parentOf(bytes32 id) internal view exists(id) returns (bytes32) {
        return tokenToId[parentOf(nodes[id].token)];
    }

    /**
     * @dev Validates if a user is able to access all elements in a collection. Used in auth() method
     */
    function authCollection(bytes32 id, address user) internal view returns (bool) {
        bytes32[] memory collectionPath = nodes[id].collectionPath;
        uint256 collectionPathLength = collectionPath.length;
        address owner = ownerOf(nodes[id].token);
        for (uint256 i = 0; i < collectionPathLength;) {
            if (!auth(collectionPath[i], user)) {
                return false;
            }
            if (!refAuth(collectionPath[i], owner)) {
                return false;
            }
            unchecked {
                ++i;
            }
        }
        return true;
    }

    /**
     * @dev Recursivly finds the nearest auth module for a given node through traversing through the parent node.
     */
    function getAccessAuth(bytes32 id) public view exists(id) returns (bytes32, address) {
        if (nodes[id].accessAuth == address(0)) {
            bytes32 parent = parentOf(id);
            if (parent == bytes32(0)) {
                return (bytes32(0), address(0));
            } else {
                return getAccessAuth(parent);
            }
        }
        return (id, nodes[id].accessAuth);
    }

    /**
     * @dev Recursivly finds the nearest reference module for a given node through traversing through the parent node.
     */
    function getReferenceAuth(bytes32 id) public view exists(id) returns (bytes32, address) {
        if (nodes[id].referenceAuth == address(0)) {
            bytes32 parent = parentOf(id);
            if (parent == bytes32(0)) {
                return (bytes32(0), address(0));
            } else {
                return getReferenceAuth(parent);
            }
        }
        return (id, nodes[id].referenceAuth);
    }
}
