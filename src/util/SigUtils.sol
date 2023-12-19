// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant REGISTER_TYPEHASH = keccak256(
        "register(address root,address intermediate,uint256 expiry,uint256 nonce,uint256 chainID,uint256 deadline)"
    );

    bytes32 public constant UNREGISTER_TYPEHASH =
        keccak256("unregister(address root,address intermediate,uint256 nonce,uint256 chainID,uint256 deadline)");

    struct Register {
        address root;
        address intermediate;
        uint256 expiry;
        uint256 nonce;
        uint256 chainID;
        uint256 deadline;
    }

    struct Unregister {
        address root;
        address intermediate;
        uint256 nonce;
        uint256 chainID;
        uint256 deadline;
    }

    // computes the hash of a permit
    function getRegisterStructHash(Register memory _register) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                REGISTER_TYPEHASH,
                _register.root,
                _register.intermediate,
                _register.expiry,
                _register.nonce,
                _register.chainID,
                _register.deadline
            )
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getRegisterTypedDataHash(Register memory _register) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getRegisterStructHash(_register)));
    }

    // computes the hash of a permit
    function getUnregisterStructHash(Unregister memory _unregister) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                UNREGISTER_TYPEHASH,
                _unregister.root,
                _unregister.intermediate,
                _unregister.nonce,
                _unregister.chainID,
                _unregister.deadline
            )
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getUnregisterTypedDataHash(Unregister memory _unregister) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getUnregisterStructHash(_unregister)));
    }
}
