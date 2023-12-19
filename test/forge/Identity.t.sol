// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {IdentityRegistry} from "../../src/identity/IdentityRegistry.sol";
import {SigUtils} from "../../src/util/SigUtils.sol";

contract IdentityRegistryTest is Test {
    address user0 = vm.addr(1);
    address user1 = vm.addr(2);
    address user2 = vm.addr(3);

    IdentityRegistry identity;

    SigUtils sig;

    function setUp() public {
        string memory name = "IdentityRegistry";
        string memory version = "0";
        identity = new IdentityRegistry();
        identity.initialize("IdentityRegistry", "0");
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        bytes32 typeHash =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 DOMAIN_SEPARATOR =
            keccak256(abi.encode(typeHash, hashedName, hashedVersion, block.chainid, address(identity)));
        sig = new SigUtils(DOMAIN_SEPARATOR);
    }

    function testRegisterRoot() public {
        identity.registerRoot(user0, "org");

        vm.expectRevert();
        identity.registerRoot(user0, "org");

        vm.expectRevert();
        identity.registerRoot(address(0), "org");

        assertTrue(identity.registered(user0));
        assertEq(identity.rootName(user0), "org");

        // Can't register a intermediate as a root
        uint256 rootPrivateKey = 0xA11CE;
        uint256 intermediatePrivateKey = 0xB0B;

        address root = vm.addr(rootPrivateKey);
        address intermediate = vm.addr(intermediatePrivateKey);
        uint256 expiry = 1 days;
        uint256 deadline = 1 days;

        identity.registerRoot(root, "org2");

        SigUtils.Register memory register = SigUtils.Register({
            root: root,
            intermediate: intermediate,
            expiry: expiry,
            nonce: 0,
            chainID: block.chainid,
            deadline: deadline
        });
        bytes32 digest = sig.getRegisterTypedDataHash(register);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(rootPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertTrue(identity.registered(root));
        assertEq(identity.whoIs(intermediate), address(0));
        identity.register(signature, root, intermediate, expiry, block.chainid, deadline);

        vm.expectRevert();
        identity.registerRoot(intermediate, "");
    }

    function testUnregisterRoot() public {
        // Setup
        identity.registerRoot(user0, "org");

        assertTrue(identity.registered(user0));
        assertEq(identity.rootName(user0), "org");
        assertEq(identity.nameToRoot("org"), user0);

        vm.startPrank(user1);
        vm.expectRevert();
        identity.unregisterRoot(user0);
        vm.stopPrank();

        identity.unregisterRoot(user0);
        assertFalse(identity.registered(user0));
        assertEq(identity.rootName(user0), "");
        assertEq(identity.nameToRoot("org"), address(0));
    }

    function testRegisterIdentity() public {
        uint256 rootPrivateKey = 0xA11CE;
        uint256 root1PrivateKey = 0x53885;
        uint256 intermediatePrivateKey = 0xB0B;

        address root = vm.addr(rootPrivateKey);
        address root1 = vm.addr(root1PrivateKey);
        address intermediate = vm.addr(intermediatePrivateKey);
        uint256 expiry = 1 days;
        uint256 deadline = 1 days;

        assertFalse(identity.registered(root));
        identity.registerRoot(root, "ORG");
        assertEq(identity.rootName(root), "ORG");

        SigUtils.Register memory register = SigUtils.Register({
            root: root,
            intermediate: intermediate,
            expiry: expiry,
            nonce: 0,
            chainID: block.chainid,
            deadline: deadline
        });

        bytes32 digest = sig.getRegisterTypedDataHash(register);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(rootPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        assertTrue(identity.registered(root));
        assertEq(identity.whoIs(intermediate), address(0));

        //Cannot use invalid params
        vm.expectRevert();
        identity.register(signature, root, vm.addr(1), expiry, block.chainid, deadline);

        // Success
        identity.register(signature, root, intermediate, expiry, block.chainid, deadline);

        assertTrue(identity.registered(root));
        assertEq(identity.whoIs(intermediate), root);

        //Cannot reuse a signature
        vm.expectRevert();
        identity.register(signature, root, intermediate, expiry, block.chainid, deadline);

        // Expiry
        skip(2 days);
        assertTrue(identity.registered(root));
        assertEq(identity.whoIs(intermediate), address(0));

        //Cannot use a signature past deadline
        register = SigUtils.Register({
            root: root,
            intermediate: intermediate,
            expiry: expiry,
            nonce: 1,
            chainID: block.chainid,
            deadline: deadline
        });

        digest = sig.getRegisterTypedDataHash(register);
        (v, r, s) = vm.sign(rootPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert();
        identity.register(signature, root, intermediate, expiry, block.chainid, deadline);

        rewind(2 days);

        //cannot use a signature from another chain
        register = SigUtils.Register({
            root: root,
            intermediate: intermediate,
            expiry: expiry,
            nonce: 1,
            chainID: block.chainid + 1,
            deadline: deadline
        });

        digest = sig.getRegisterTypedDataHash(register);
        (v, r, s) = vm.sign(rootPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert();
        identity.register(signature, root, intermediate, expiry, block.chainid + 1, deadline);

        //Canot use a exsisting intermediate
        register = SigUtils.Register({
            root: root1,
            intermediate: intermediate,
            expiry: expiry,
            nonce: 0,
            chainID: block.chainid,
            deadline: deadline
        });
        digest = sig.getRegisterTypedDataHash(register);
        (v, r, s) = vm.sign(root1PrivateKey, digest);
        signature = abi.encodePacked(r, s, v);
        identity.registerRoot(root1, "ORG1");
        vm.expectRevert();
        identity.register(signature, root1, intermediate, expiry, block.chainid, deadline);

        //Can't extend a exsisting signature that has expired
        register = SigUtils.Register({
            root: root,
            intermediate: intermediate,
            expiry: 3 days,
            nonce: 1,
            chainID: block.chainid,
            deadline: 2 days
        });
        digest = sig.getRegisterTypedDataHash(register);
        (v, r, s) = vm.sign(rootPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);
        skip(1 days);
        vm.expectRevert();
        identity.register(signature, root, intermediate, 3 days, block.chainid, 2 days);

        // Can extend a existing sig
        rewind(1 days);
        register = SigUtils.Register({
            root: root,
            intermediate: intermediate,
            expiry: 3 days,
            nonce: identity.nonces(root),
            chainID: block.chainid,
            deadline: 1 days
        });
        digest = sig.getRegisterTypedDataHash(register);
        (v, r, s) = vm.sign(rootPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);
        identity.register(signature, root, intermediate, 3 days, block.chainid, 1 days);
    }

    function testUnregister() public {
        address root = vm.addr(0xA11CE);
        address root1 = vm.addr(0x53885);
        address intermediate = vm.addr(0xB0B);

        identity.registerRoot(root, "ORG1");
        identity.registerRoot(root1, "ORG2");

        SigUtils.Register memory register = SigUtils.Register({
            root: root,
            intermediate: intermediate,
            expiry: 1 days,
            nonce: 0,
            chainID: block.chainid,
            deadline: 1 days
        });

        bytes32 digest = sig.getRegisterTypedDataHash(register);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xA11CE, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        identity.register(signature, root, intermediate, 1 days, block.chainid, 1 days);

        // should not be able to forge a signature
        SigUtils.Unregister memory unregister = SigUtils.Unregister({
            root: root,
            intermediate: intermediate,
            nonce: 1,
            chainID: block.chainid,
            deadline: 1 days
        });
        digest = sig.getUnregisterTypedDataHash(unregister);
        (v, r, s) = vm.sign(0x53885, digest);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert();
        identity.unregister(signature, root, intermediate, block.chainid, 1 days);

        // Should not be able to unregister not registered intermediate
        unregister = SigUtils.Unregister({
            root: root,
            intermediate: vm.addr(1),
            nonce: 1,
            chainID: block.chainid,
            deadline: 1 days
        });
        digest = sig.getUnregisterTypedDataHash(unregister);
        (v, r, s) = vm.sign(0xA11CE, digest);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert();
        identity.unregister(signature, root, vm.addr(1), block.chainid, 1 days);

        // should not be able to use expired signatures
        unregister = SigUtils.Unregister({
            root: root,
            intermediate: intermediate,
            nonce: identity.nonces(root),
            chainID: block.chainid,
            deadline: 1
        });
        digest = sig.getUnregisterTypedDataHash(unregister);
        (v, r, s) = vm.sign(0xA11CE, digest);
        signature = abi.encodePacked(r, s, v);

        skip(1);
        vm.expectRevert();
        identity.unregister(signature, root, intermediate, block.chainid, 1);

        // should not be able to use a sig from another chain
        unregister = SigUtils.Unregister({
            root: root,
            intermediate: intermediate,
            nonce: identity.nonces(root),
            chainID: block.chainid + 1,
            deadline: 1 days
        });
        digest = sig.getUnregisterTypedDataHash(unregister);
        (v, r, s) = vm.sign(0xA11CE, digest);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert();
        identity.unregister(signature, root, intermediate, block.chainid + 1, 1 days);

        //Successful unregister
        unregister = SigUtils.Unregister({
            root: root,
            intermediate: intermediate,
            nonce: identity.nonces(root),
            chainID: block.chainid,
            deadline: 1 days
        });
        digest = sig.getUnregisterTypedDataHash(unregister);
        (v, r, s) = vm.sign(0xA11CE, digest);
        signature = abi.encodePacked(r, s, v);

        identity.unregister(signature, root, intermediate, block.chainid, 1 days);

        assertEq(identity.whoIs(intermediate), address(0));
        // assertEq(identity.registryExpiry(root, intermediate), 0);
    }
}
