// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";

/**
 * @title IdenityRegistry
 * @author Blockchain Creative Labs
 * @notice A registry of named root signing key pairs and their intermediate keypairs.
 */
contract IdentityRegistry is OwnableUpgradeable, EIP712Upgradeable {
    mapping(address => bool) public registered;
    mapping(address => string) public rootName;
    mapping(string => address) public nameToRoot;
    mapping(address => uint256) public nonces;
    mapping(address => bool) public used;

    mapping(address => address) intermediateToRoot;
    mapping(address => mapping(address => uint256)) registryExpiry;

    error NotRegistered();
    error InvalidSignature();
    error InvalidParams();
    error RegistryExpired();
    error SignatureExpired();
    error AlreadyRegistered();

    modifier onlyRegistered(address user) {
        if (!registered[user]) {
            revert NotRegistered();
        }
        _;
    }

    bytes32 emptyString = keccak256(abi.encode(""));

    /**
     * @dev Used to initialize the values through the transparent proxy upgrade pattern.
     * https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies
     */
    function initialize(string memory name_, string memory version_) public initializer {
        __Ownable_init(msg.sender);
        __EIP712_init(name_, version_);
    }

    /**
     * @notice Registers a given root address to a user facing name, only callable from the protocol wallet
     * @param root The address to register.
     * @param name The user facing name of the address, Org or real world entity.
     */
    function registerRoot(address root, string memory name) external onlyOwner {
        if (root == address(0) || (keccak256(abi.encode(name)) == emptyString)) revert InvalidParams();
        if (used[root] || (nameToRoot[name] != address(0))) revert AlreadyRegistered();
        used[root] = true;
        registered[root] = true;
        rootName[root] = name;
        nameToRoot[name] = root;
    }

    /**
     * @notice Unregisters an address from the registry. Only Callable from the protocol wallet.
     * @param root The address to unregister.
     */
    function unregisterRoot(address root) external onlyOwner {
        nameToRoot[rootName[root]] = address(0);
        registered[root] = false;
        rootName[root] = "";
    }

    /**
     * @notice Registers an address as a intermediate identity of a registered root identity using a signature from the root identity keypair.
     * Will only register intermediate identities that have not been registered before. Can be used to extend a existing registry during only
     * while the existing signature has not expired.
     * @param signature The signature from the root identity.
     * @param root the address of the root identity.
     * @param intermediate the address of the intermediate identity to register
     * @param expiry the uint256 timestamp of the expiry of the intermediate identity acting on behalf of the root.
     * @param chainID the id of the chain which this signature is for, used to avoid replay signatures between testnet/mainnet enviorments.
     * @param deadline the uint256 timestamp of the deadline to use the signature by.
     */
    function register(
        bytes memory signature,
        address root,
        address intermediate,
        uint256 expiry,
        uint256 chainID,
        uint256 deadline
    ) external onlyRegistered(root) {
        if (block.timestamp > deadline) revert SignatureExpired();
        if (used[intermediate]) {
            if (intermediateToRoot[intermediate] != root) revert AlreadyRegistered();
            if (block.timestamp > registryExpiry[root][intermediate]) revert RegistryExpired();
        }
        if (chainID != block.chainid) revert InvalidParams();
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "register(address root,address intermediate,uint256 expiry,uint256 nonce,uint256 chainID,uint256 deadline)"
                    ),
                    root,
                    intermediate,
                    expiry,
                    nonces[root],
                    chainID,
                    deadline
                )
            )
        );
        address signer = ECDSA.recover(digest, signature);
        if (signer != root) revert InvalidSignature();
        ++nonces[root];
        _register(root, intermediate, expiry);
    }

    /**
     * @dev Internal function which stores the signature and registers the intermediate identity address to the root identity address.
     */
    function _register(address root, address intermediate, uint256 expiry) internal {
        used[intermediate] = true;
        registryExpiry[root][intermediate] = expiry;
        intermediateToRoot[intermediate] = root;
    }

    /**
     * @notice Unregisters an intermediate identity address from a root identity using a signature from the root identity.
     * @param signature The signature from the root identity.
     * @param root the address of the root identity.
     * @param intermediate the address of the intermediate identity to unregister.
     * @param chainID the id of the chain which this signature is for, used to avoid replay signatures between testnet/mainnet enviorments.
     * @param deadline the uint256 timestamp of the deadline to use the signature by.
     */
    function unregister(bytes memory signature, address root, address intermediate, uint256 chainID, uint256 deadline)
        external
        onlyRegistered(root)
    {
        if (intermediateToRoot[intermediate] != root) revert InvalidParams();
        if (block.timestamp > deadline) revert SignatureExpired();
        if (chainID != block.chainid) revert InvalidParams();
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "unregister(address root,address intermediate,uint256 nonce,uint256 chainID,uint256 deadline)"
                    ),
                    root,
                    intermediate,
                    nonces[root],
                    chainID,
                    deadline
                )
            )
        );
        address signer = ECDSA.recover(digest, signature);
        if (signer != root) revert InvalidSignature();
        ++nonces[root];
        _unregister(root, intermediate);
    }

    /**
     * @dev Internal function to expire a signature to end association between intermediate identity address and root identity.
     */
    function _unregister(address root, address intermediate) internal {
        registryExpiry[root][intermediate] = 0;
    }

    /**
     * @notice Returns the corresponding root identity of an intermediate identity while the stored signature is valid. Address(0) means no association exists
     * @param identity The address of an intermediate identity to lookup.
     */
    function whoIs(address identity) external view returns (address root) {
        root = intermediateToRoot[identity];
        if (registered[root]) {
            if (block.timestamp > registryExpiry[root][identity]) root = address(0);
        } else {
            return address(0);
        }
    }
}
