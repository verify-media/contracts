// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import {ContentGraph} from "../src/ContentGraph.sol";
import {IdentityRegistrySandbox} from "../src/identity/IdentityRegistrySandbox.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "forge-std/console.sol";

contract DeploySandbox is Script {
    string symbol = "VRFYS";
    string name = "VerifySandbox";
    string registryName = "IdenityRegistrySandbox";
    string version = "V1";
    uint256 admin_pk = vm.envUint("PRIVATE_KEY");

    address user = vm.addr(admin_pk);
    bytes32 hashedName = keccak256(bytes(registryName));
    bytes32 hashedVersion = keccak256(bytes(version));
    bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function run() external {
        vm.startBroadcast(admin_pk);
        ProxyAdmin identityAdmin = new ProxyAdmin();
        ProxyAdmin graphAdmin = new ProxyAdmin();
        ContentGraph graph_ = new ContentGraph();
        IdentityRegistrySandbox registry_ = new IdentityRegistrySandbox();

        bytes4 registryIntializeSelector = bytes4(keccak256("initialize(string,string)"));
        bytes memory registryData = abi.encodeWithSelector(registryIntializeSelector, registryName, version);
        TransparentUpgradeableProxy identityProxy =
            new TransparentUpgradeableProxy(address(registry_), address(identityAdmin), registryData);

        bytes4 graphIntializeSelector = bytes4(keccak256("initialize(string,string,address)"));
        bytes memory data = abi.encodeWithSelector(graphIntializeSelector, name, symbol, address(identityProxy));
        TransparentUpgradeableProxy graphProxy =
            new TransparentUpgradeableProxy(address(graph_), address(graphAdmin), data);

        console.log("Identity Sandbox Proxy", address(identityProxy));
        console.log("Identity Sandbox Admin", address(identityAdmin));
        console.log("Identity Sandbox Implementation", address(registry_));
        console.log("Graph Sandbox Proxy", address(graphProxy));
        console.log("Graph Sandbox Admin", address(graphAdmin));
        console.log("Graph Sandbox Implementation", address(graph_));
        vm.stopBroadcast();
    }
}
