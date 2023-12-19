// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {IAuthorization} from "./IAuthorization.sol";
import {IIdentityRegistry} from "./identity/IIdentityRegistry.sol";
import {ERC6150Upgradeable} from "./util/ERC6150Upgradeable.sol";

/**
 * @title ContentGraph
 * @author Blockchain Creative Labs
 * @notice A graph of content with reference to their metadata and license.
 */
contract ContentGraph is ERC6150Upgradeable {
    uint256 public totalSupply;
    mapping(bytes32 => Node) nodes;
    mapping(address => uint256) public nodesCreated;
    mapping(uint256 => bytes32) tokenToId;

    IIdentityRegistry identity;

    error NotAuthorized();
    error InvalidParams();
    error NodeDoesNotExist();
    error NodeAlreadyExists();

    enum NodeType {
        ORG,
        REFERENCE,
        ASSET
    }

    struct ContentNode {
        bytes32 id;
        NodeType nodeType;
        bytes32 referenceOf;
        string uri;
    }

    struct Node {
        uint256 token;
        NodeType nodeType;
        bytes32 id;
        bytes32 referenceOf;
        string uri;
        address accessAuth;
        address referenceAuth;
    }

    event Moved(bytes32 indexed _id, bytes32 indexed _from, bytes32 indexed _to);
    event AccessAuthUpdate(bytes32 indexed _id, address indexed _auth);
    event ReferenceAuthUpdate(bytes32 indexed _id, address indexed _auth);
    event URIUpdate(bytes32 indexed _id, string indexed _uri);

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
     * @notice Validates if a caller is the owner of a ID using the identity registry, everyone is the owner of the Root
     * @param id The id to check.
     * @param account The address to check. Should be an intermediate of a registered root identity.
     */
    modifier onlyNodeOwner(bytes32 id, address account) {
        if (identity.whoIs(account) == address(0)) {
            revert NotAuthorized();
        }
        uint256 tokenId = nodes[id].token;
        if (tokenId != 0) {
            _requireMinted(tokenId);
            if (identity.whoIs(account) != ownerOf(tokenId)) {
                revert NotAuthorized();
            }
        }
        _;
    }

    /**
     * @dev Used to initialize the values through the transparent proxy upgrade pattern.
     * https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies
     */
    function initialize(string memory name_, string memory symbol_, address _identity) public initializer {
        __ERC6150_init(name_, symbol_);
        identity = IIdentityRegistry(_identity);
    }

    /**
     * @notice Publishes a new set content node (assets/references) to the passed parent id.
     * @param parentId The id of an ORG node to publish the set of content nodes.
     * @param content A list of content.
     */
    function publishBulk(bytes32 parentId, ContentNode[] calldata content) public {
        require(content.length <= 100);
        uint256 contents = content.length;
        for (uint256 i = 0; i < contents;) {
            publish(parentId, content[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Publishes a new asset node at a given parent in addition to setting the uri for the asset node.
     * @param parentId The id of an ORG node to publish the set of content nodes.
     * @param content A content node to publish.
     */
    function publish(bytes32 parentId, ContentNode calldata content) public {
        require(content.nodeType != NodeType.ORG);
        createNode(content.id, parentId, content.nodeType, content.referenceOf);
        if (content.nodeType == NodeType.ASSET) {
            setURI(content.id, content.uri);
        }
    }

    /**
     * @notice Creates a node of a given type under the parent node provided.
     * @param id The id of the node to create, must follow the correct form based on type.
     * @param parentId The id of a ORG node to publish the node under
     * @param nodeType The type of node to create, ORG, REFERENCE, or ASSET
     * @param referenceOf If the type is of REFERENCE the id of the node that is being referenced
     */
    function createNode(bytes32 id, bytes32 parentId, NodeType nodeType, bytes32 referenceOf)
        public
        onlyNodeOwner(parentId, msg.sender)
    {
        address owner = identity.whoIs(msg.sender);
        if (nodes[id].token != 0) {
            revert NodeAlreadyExists();
        }
        if (nodes[parentId].nodeType != NodeType.ORG) {
            revert InvalidParams();
        }
        if (nodeType == NodeType.ASSET) {
            if ((id == bytes32(0)) || (referenceOf != bytes32(0))) revert InvalidParams();
        } else {
            if (nodeType == NodeType.REFERENCE) {
                if (nodes[referenceOf].token == 0) revert InvalidParams();
                else if (nodes[referenceOf].nodeType != NodeType.ASSET) revert InvalidParams();
            } else {
                if (referenceOf != bytes32(0)) revert InvalidParams();
            }
        }
        uint256 tokenId = totalSupply + 1;
        _safeMintWithParent(owner, nodes[parentId].token, tokenId);
        totalSupply = totalSupply + 1;
        nodes[id].token = tokenId;
        nodes[id].nodeType = nodeType;
        nodes[id].id = id;
        nodes[id].referenceOf = referenceOf;
        tokenToId[tokenId] = id;
        ++nodesCreated[owner];
    }

    /**
     * @notice Moves a node from current parent to a new parent.
     * @param id The id of the node to move.
     * @param newParentId The id of an existing ORG node to move the node under.
     */
    function move(bytes32 id, bytes32 newParentId)
        public
        onlyNodeOwner(id, msg.sender)
        onlyNodeOwner(newParentId, msg.sender)
    {
        if (nodes[newParentId].nodeType != NodeType.ORG) {
            revert InvalidParams();
        }
        uint256 token = nodes[id].token;
        uint256 newParent = nodes[newParentId].token;
        bytes32 parentId = tokenToId[parentOf(token)];
        uint256 parent = parentOf(token);
        uint256 nodeIndex = _indexInChildrenArray[token];

        uint256 children = _childrenOf[parent].length;
        for (uint256 i = nodeIndex; i < children - 1;) {
            _childrenOf[parent][i] = _childrenOf[parent][i + 1];
            _indexInChildrenArray[_childrenOf[parent][i + 1]] = i;
            unchecked {
                ++i;
            }
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
     * @param id The id of the node whose auth modules should be set.
     * @param accessAuth The address to the auth module to be used for access of node's content.
     */
    function setAccessAuth(bytes32 id, address accessAuth) public onlyNodeOwner(id, msg.sender) exists(id) {
        nodes[id].accessAuth = accessAuth;
        emit AccessAuthUpdate(id, accessAuth);
    }

    /**
     * @notice Sets the reference auth module for a given ORG or ASSET node.
     * @param id The id of the node whose auth modules should be set.
     * @param referenceAuth The address to the auth module to be used for referencing a node by a REFERENCE node.
     */
    function setReferenceAuth(bytes32 id, address referenceAuth) public onlyNodeOwner(id, msg.sender) exists(id) {
        require(nodes[id].nodeType != NodeType.REFERENCE);
        nodes[id].referenceAuth = referenceAuth;
        emit ReferenceAuthUpdate(id, referenceAuth);
    }

    /**
     * @notice Sets the uri for an ORG or ASSET node.
     * @param id The id of the node.
     * @param uri The URI to the metadata to set for a node.
     */
    function setURI(bytes32 id, string calldata uri) public onlyNodeOwner(id, msg.sender) exists(id) {
        require(nodes[id].nodeType != NodeType.REFERENCE);
        nodes[id].uri = uri;
        emit URIUpdate(id, uri);
    }

    /**
     * @notice Validates if a given user may access the content at a given node.
     * @param id The id of the node whose content is being accessed.
     * @param user The address of the user who wishes to access the content.
     */
    function auth(bytes32 id, address user) public view exists(id) returns (bool) {
        bool isAuthorized = true;
        if (nodes[id].nodeType == NodeType.REFERENCE) {
            isAuthorized = refAuth(nodes[id].referenceOf, ownerOf(nodes[id].token));
        }
        return (_auth(id, user, false) && isAuthorized);
    }

    /**
     * @dev Internal Auth function which will delegate auth to most privilege node except for root
     */
    function _auth(bytes32 id, address user, bool rejected) internal view returns (bool) {
        address accessAuth = nodes[id].accessAuth;
        bytes32 parent = tokenToId[parentOf(nodes[id].token)];
        if (accessAuth == address(0)) {
            if (parent == bytes32(0)) return (true && !rejected);
            else return _auth(parent, user, rejected);
        } else {
            bool authorized = IAuthorization(accessAuth).auth(id, user);
            if (authorized) {
                return true;
            } else {
                if (parent == bytes32(0)) return false;
                return _auth(parent, user, true);
            }
        }
    }

    // (F) -> (F) -> (F) - 0 : false

    /**
     * @notice Validates if a given user may reference a given node in a collection. Only ORG and ASSET nodes.
     * @param id The id of the node who is being referenced.
     * @param user The address of the user who wishes to reference the node.
     */
    function refAuth(bytes32 id, address user) public view exists(id) returns (bool) {
        if (nodes[id].nodeType == NodeType.REFERENCE) {
            return false;
        }
        return _refAuth(id, user, false);
    }

    /**
     * @dev Internal refAuth function which will delegate auth to most privilege nodes except for root.
     */
    function _refAuth(bytes32 id, address user, bool rejected) internal view returns (bool) {
        address referenceAuth = nodes[id].referenceAuth;
        bytes32 parent = tokenToId[parentOf(nodes[id].token)];
        if (referenceAuth == address(0)) {
            if (rejected) return false;
            else if (parent == bytes32(0)) return true;
            else return _refAuth(parent, user, rejected);
        } else {
            bool authorized = IAuthorization(referenceAuth).auth(id, user);
            if (authorized) return true;
            else return _refAuth(parent, user, true);
        }
    }

    /**
     * @notice retrieve node from node id
     * @param id The id of the node to retrieve.
     */
    function getNode(bytes32 id) public view exists(id) returns (Node memory node) {
        node = nodes[id];
        if (node.nodeType == NodeType.REFERENCE) {
            node.uri = nodes[node.referenceOf].uri;
        }
    }

    /**
     * @dev retrieve node from token id
     * @param token The tokenId for the node to retrieve.
     */
    function tokenToNode(uint256 token) external view exists(tokenToId[token]) returns (Node memory node) {
        node = getNode(tokenToId[token]);
    }
}
