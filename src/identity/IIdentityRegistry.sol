// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IIdentityRegistry {
    function registerRoot(address root, string memory name) external;
    function deregisterRoot(address root) external;
    function registerIdentity(
        bytes memory signature,
        address root,
        address identity,
        uint256 expirary,
        uint256 chainID,
        uint256 deadline
    ) external;
    function deregisterIdentity(bytes memory signature, address root, address identity, uint256 deadline) external;
    function whoIs(address identity) external view returns (address root);
}
