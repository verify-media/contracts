// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import {ContentGraph} from "../src/ContentGraph.sol";
import {IdentityRegistry} from "../src/identity/IdentityRegistry.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "forge-std/console.sol";

contract Deploy is Script {
    string symbol = "VRFY";
    string name = "Verify";
    string registryName = "IdenityRegistry";
    string version = "V1";
    uint256 admin_pk = vm.envUint("PRIVATE_KEY");

    address user = vm.addr(admin_pk);
    bytes32 hashedName = keccak256(bytes(registryName));
    bytes32 hashedVersion = keccak256(bytes(version));
    bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    address owner = vm.addr(admin_pk);

    function run() external {
        vm.startBroadcast(admin_pk);
        ProxyAdmin identityAdmin = new ProxyAdmin(owner);
        ProxyAdmin graphAdmin = new ProxyAdmin(owner);
        ContentGraph graph_ = new ContentGraph();
        IdentityRegistry registry_ = new IdentityRegistry();

        bytes4 registryIntializeSelector = bytes4(keccak256("initialize(string,string)"));
        bytes memory registryData = abi.encodeWithSelector(registryIntializeSelector, registryName, version);
        TransparentUpgradeableProxy identityProxy =
            new TransparentUpgradeableProxy(address(registry_), address(identityAdmin), registryData);

        bytes4 graphIntializeSelector = bytes4(keccak256("initialize(string,string,address)"));
        bytes memory data = abi.encodeWithSelector(graphIntializeSelector, name, symbol, address(identityProxy));
        TransparentUpgradeableProxy graphProxy =
            new TransparentUpgradeableProxy(address(graph_), address(graphAdmin), data);

        registry_.initialize(registryName, version);
        graph_.initialize(name, symbol, address(registry_));

        console.log("Identity Proxy", address(identityProxy));
        console.log("Identity Admin", address(identityAdmin));
        console.log("Identity Implementation", address(registry_));
        console.log("Graph Proxy", address(graphProxy));
        console.log("Graph Admin", address(graphAdmin));
        console.log("Graph Implementation", address(graph_));
        vm.stopBroadcast();
    }
}
