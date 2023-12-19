// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {ContentGraph} from "../../src/ContentGraph.sol";

contract IdentityRegistry {
    mapping(address => address) identityToRoot;

    constructor() {}

    function addIdentity(address identity, address root) public {
        identityToRoot[identity] = root;
    }

    function whoIs(address user) external view returns (address root) {
        return identityToRoot[user];
    }
}

contract AllowList {
    mapping(bytes32 => mapping(address => bool)) allowList;

    constructor() {}

    function setState(bytes32 id, address user, bool state) public {
        allowList[id][user] = state;
    }

    function auth(bytes32 id, address user) external view returns (bool isAuthorised) {
        isAuthorised = allowList[id][user];
    }
}

contract ContentGraphtestV3 is Test {
    ContentGraph graph;
    AllowList auth = new AllowList();
    IdentityRegistry identity = new IdentityRegistry();

    address user0 = vm.addr(1);
    address user1 = vm.addr(2);
    address user2 = vm.addr(3);
    address user00 = vm.addr(4);
    address user01 = vm.addr(5);
    address user02 = vm.addr(6);
    address user = vm.addr(7);

    function setUp() public {
        graph = new ContentGraph();
        graph.initialize("", "", address(identity));
        identity.addIdentity(user00, user0);
        identity.addIdentity(user01, user1);
        identity.addIdentity(user02, user2);
    }

    function testV3Initialize() public {
        ContentGraph graphNew = new ContentGraph();
        graphNew.initialize("", "", address(identity));
    }

    function testV3CreateNode() public {
        bytes32 id = keccak256(abi.encodePacked(user0, uint256(1)));
        bytes32 parentId = bytes32(0);
        ContentGraph.NodeType nodeType_ = ContentGraph.NodeType.ORG;

        /**
         * ORG NODES
         */

        vm.startPrank(user);
        //fail user not authorized
        vm.expectRevert();
        graph.createNode(keccak256(abi.encodePacked(user, uint256(1))), parentId, nodeType_, bytes32(0));
        vm.stopPrank();

        vm.startPrank(user00);
        //success
        graph.createNode(id, parentId, nodeType_, bytes32(0));

        assertEq(graph.balanceOf(user0), 1);
        assertEq(graph.totalSupply(), 1);

        //Fail already exists
        vm.expectRevert();
        graph.createNode(id, parentId, nodeType_, bytes32(0));

        //Fail as reference should be 0 for admin nodes
        bytes32 newid = keccak256(abi.encodePacked(user0, uint256(2)));
        vm.expectRevert();
        graph.createNode(newid, parentId, nodeType_, bytes32(uint256(1)));

        vm.stopPrank();

        //Fail can't publish to unowned nodes
        newid = keccak256(abi.encodePacked(user1, uint256(1)));
        vm.startPrank(user01);
        vm.expectRevert();
        graph.createNode(newid, id, nodeType_, bytes32(0));
        vm.stopPrank();

        //success
        newid = keccak256(abi.encodePacked(user0, uint256(2)));
        vm.startPrank(user00);
        graph.createNode(newid, id, nodeType_, bytes32(0));
        vm.stopPrank();

        assertEq(graph.balanceOf(user0), 2);
        assertEq(graph.totalSupply(), 2);

        /**
         * ASSET NODES
         */
        bytes32 validAssetId0 = keccak256("Test");
        bytes32 invalidAssetId = bytes32(0);

        //success
        vm.startPrank(user00);
        vm.expectRevert();
        graph.createNode(invalidAssetId, newid, ContentGraph.NodeType.ASSET, bytes32(0));
        graph.createNode(validAssetId0, newid, ContentGraph.NodeType.ASSET, bytes32(0));
        vm.stopPrank();

        assertEq(graph.balanceOf(user0), 3);
        assertEq(graph.totalSupply(), 3);

        //Fail asset already exists
        vm.startPrank(user00);
        vm.expectRevert();
        graph.createNode(validAssetId0, bytes32(0), ContentGraph.NodeType.ASSET, bytes32(0));

        //success
        bytes32 validAssetId1 = keccak256("Test2");
        graph.createNode(validAssetId1, bytes32(0), ContentGraph.NodeType.ASSET, bytes32(0));
        vm.stopPrank();
        assertEq(graph.balanceOf(user0), 4);
        assertEq(graph.totalSupply(), 4);

        /**
         * REFERENCE NODES
         */

        vm.startPrank(user01);

        //Fail referenced token does not exists
        vm.expectRevert();
        graph.createNode(
            keccak256(abi.encodePacked(user1, uint256(1))),
            bytes32(0),
            ContentGraph.NodeType.REFERENCE,
            bytes32(uint256(2))
        );

        //Fail referenced token is not a Asset
        vm.expectRevert();
        graph.createNode(
            keccak256(abi.encodePacked(user1, uint256(1))), bytes32(0), ContentGraph.NodeType.REFERENCE, newid
        );

        //success
        graph.createNode(
            keccak256(abi.encodePacked(user1, uint256(1))), bytes32(0), ContentGraph.NodeType.REFERENCE, validAssetId0
        );
        assertEq(graph.balanceOf(user1), 1);
        assertEq(graph.totalSupply(), 5);

        vm.stopPrank();
    }

    function testV3publish() public {
        /**
         * SET UP
         */
        bytes32 parentId0 = keccak256(abi.encodePacked(user0, uint256(1)));
        vm.startPrank(user00);
        graph.createNode(parentId0, bytes32(0), ContentGraph.NodeType.ORG, bytes32(0));

        //Fail can not publish a ORG Node
        vm.expectRevert();
        graph.publish(
            parentId0,
            ContentGraph.ContentNode(
                keccak256(abi.encodePacked(user0, uint256(2))), ContentGraph.NodeType.ORG, bytes32(0), ""
            )
        );

        //Fail malformed Asset Node
        vm.expectRevert();
        graph.publish(
            parentId0, ContentGraph.ContentNode(keccak256("TEST"), ContentGraph.NodeType.ASSET, bytes32(uint256(1)), "")
        );

        //Fail malformed Reference node
        vm.expectRevert();
        graph.publish(
            parentId0, ContentGraph.ContentNode(keccak256("TEST"), ContentGraph.NodeType.REFERENCE, bytes32(0), "")
        );

        //Sucess on Asset
        graph.publish(
            parentId0,
            ContentGraph.ContentNode(keccak256("TEST"), ContentGraph.NodeType.ASSET, bytes32(0), "ipfs://asdlfkjasldkf")
        );
        assertEq(graph.balanceOf(user0), 2);
        assertEq(graph.totalSupply(), 2);

        vm.stopPrank();

        //Success on Reference
        vm.prank(user01);
        graph.publish(
            bytes32(0),
            ContentGraph.ContentNode(
                keccak256(abi.encodePacked(user1, uint256(1))), ContentGraph.NodeType.REFERENCE, keccak256("TEST"), ""
            )
        );
        vm.stopPrank();
        assertEq(graph.balanceOf(user1), 1);
        assertEq(graph.totalSupply(), 3);
    }

    function testV3PublishBulk() public {
        /**
         * SET UP
         */
        bytes32 parentId0 = keccak256(abi.encodePacked(user0, uint256(1)));
        vm.startPrank(user00);
        graph.createNode(parentId0, bytes32(0), ContentGraph.NodeType.ORG, bytes32(0));

        ContentGraph.ContentNode[] memory content = new ContentGraph.ContentNode[](2);

        content[0] = ContentGraph.ContentNode(
            keccak256("TEST1"), ContentGraph.NodeType.ASSET, bytes32(0), "ipfs://asdlfkjasldkf"
        );
        content[1] = ContentGraph.ContentNode(
            keccak256("TEST2"), ContentGraph.NodeType.ASSET, bytes32(0), "ipfs://asdlfkjasldkf"
        );

        //Sucess on Asset
        graph.publishBulk(parentId0, content);
        assertEq(graph.balanceOf(user0), 3);
        assertEq(graph.totalSupply(), 3);

        content = new ContentGraph.ContentNode[](100);
        for (uint256 i = 0; i < content.length; i++) {
            content[i] = ContentGraph.ContentNode(bytes32(i + 10), ContentGraph.NodeType.ASSET, bytes32(0), "");
        }
        //
        graph.publishBulk(parentId0, content);
        // assertEq(graph.balanceOf(user0), 3);
        // assertEq(graph.totalSupply(), 3);

        vm.stopPrank();
    }

    function testV3Move() public {
        bytes32 asset0 = keccak256(abi.encodePacked("0")); // id: 2
        bytes32 asset1 = keccak256(abi.encodePacked("1")); // id: 3
        bytes32 asset2 = keccak256(abi.encodePacked("2")); // id: 4

        bytes32 org0 = keccak256(abi.encodePacked(user0, uint256(1))); // id: 1

        bytes32 org1 = keccak256(abi.encodePacked(user0, uint256(5))); // id: 5

        ContentGraph.ContentNode[] memory path0 = new ContentGraph.ContentNode[](2);
        path0[0] = ContentGraph.ContentNode(asset0, ContentGraph.NodeType.ASSET, bytes32(0), "");
        path0[1] = ContentGraph.ContentNode(asset1, ContentGraph.NodeType.ASSET, bytes32(0), "");

        vm.startPrank(user00);
        graph.createNode(org0, bytes32(0), ContentGraph.NodeType.ORG, bytes32(0));
        graph.publishBulk(org0, path0);
        graph.publish(bytes32(0), ContentGraph.ContentNode(asset2, ContentGraph.NodeType.ASSET, bytes32(0), ""));
        graph.createNode(org1, org0, ContentGraph.NodeType.ORG, bytes32(0));
        uint256[] memory childrenOfRoot = graph.childrenOf(0);
        uint256[] memory expected = new uint256[](2);
        expected[0] = 1;
        expected[1] = 4;
        assertTrue(arrayMatch(childrenOfRoot, expected));

        uint256[] memory childrenOfOrg0 = graph.childrenOf(1);
        expected = new uint256[](3);
        expected[0] = 2;
        expected[1] = 3;
        expected[2] = 5;
        assertTrue(arrayMatch(childrenOfOrg0, expected));

        graph.move(asset2, org0);
        childrenOfOrg0 = graph.childrenOf(1);
        expected = new uint256[](4);
        expected[0] = 2;
        expected[1] = 3;
        expected[2] = 5;
        expected[3] = 4;
        assertTrue(arrayMatch(childrenOfOrg0, expected));

        graph.move(asset1, bytes32(0));
        childrenOfOrg0 = graph.childrenOf(1);
        expected = new uint256[](3);
        expected[0] = 2;
        expected[1] = 5;
        expected[2] = 4;
        assertTrue(arrayMatch(childrenOfOrg0, expected));

        childrenOfRoot = graph.childrenOf(0);
        expected = new uint256[](2);
        expected[0] = 1;
        expected[1] = 3;
        assertTrue(arrayMatch(childrenOfRoot, expected));

        vm.stopPrank();
    }

    function testV3SetAccessAuth() public {
        ContentGraph.ContentNode memory asset =
            ContentGraph.ContentNode(keccak256("ASSET"), ContentGraph.NodeType.ASSET, bytes32(0), "");
        ContentGraph.ContentNode memory ref = ContentGraph.ContentNode(
            keccak256(abi.encodePacked(user0, uint256(3))), ContentGraph.NodeType.REFERENCE, keccak256("ASSET"), ""
        );
        bytes32 org = keccak256(abi.encodePacked(user0, uint256(1)));
        vm.startPrank(user00);
        graph.createNode(org, bytes32(0), ContentGraph.NodeType.ORG, bytes32(0));
        graph.publish(org, asset);
        graph.publish(org, ref);

        ContentGraph.Node memory orgNode = graph.getNode(org);
        ContentGraph.Node memory assetNode = graph.getNode(asset.id);
        ContentGraph.Node memory referenceNode = graph.getNode(ref.id);

        assertEq(orgNode.accessAuth, address(0));
        assertEq(assetNode.accessAuth, address(0));
        assertEq(referenceNode.accessAuth, address(0));

        graph.setAccessAuth(org, address(auth));
        graph.setAccessAuth(asset.id, address(auth));
        graph.setAccessAuth(ref.id, address(auth));

        orgNode = graph.getNode(org);
        assetNode = graph.getNode(asset.id);
        referenceNode = graph.getNode(ref.id);

        assertEq(orgNode.accessAuth, address(auth));
        assertEq(assetNode.accessAuth, address(auth));
        assertEq(referenceNode.accessAuth, address(auth));

        vm.stopPrank();
    }

    function testV3SetReferenceAuth() public {
        ContentGraph.ContentNode memory asset =
            ContentGraph.ContentNode(keccak256("ASSET"), ContentGraph.NodeType.ASSET, bytes32(0), "");
        ContentGraph.ContentNode memory ref = ContentGraph.ContentNode(
            keccak256(abi.encodePacked(user0, uint256(3))), ContentGraph.NodeType.REFERENCE, keccak256("ASSET"), ""
        );
        bytes32 org = keccak256(abi.encodePacked(user0, uint256(1)));
        vm.startPrank(user00);
        graph.createNode(org, bytes32(0), ContentGraph.NodeType.ORG, bytes32(0));
        graph.publish(org, asset);
        graph.publish(org, ref);

        ContentGraph.Node memory orgNode = graph.getNode(org);
        ContentGraph.Node memory assetNode = graph.getNode(asset.id);
        ContentGraph.Node memory referenceNode = graph.getNode(ref.id);

        assertEq(orgNode.referenceAuth, address(0));
        assertEq(assetNode.referenceAuth, address(0));
        assertEq(referenceNode.referenceAuth, address(0));

        graph.setReferenceAuth(org, address(auth));
        graph.setReferenceAuth(asset.id, address(auth));
        vm.expectRevert();
        graph.setReferenceAuth(ref.id, address(auth));

        orgNode = graph.getNode(org);
        assetNode = graph.getNode(asset.id);
        referenceNode = graph.getNode(ref.id);

        assertEq(orgNode.referenceAuth, address(auth));
        assertEq(assetNode.referenceAuth, address(auth));
        assertEq(referenceNode.referenceAuth, address(0));

        vm.stopPrank();
    }

    function testV3SetURI() public {
        ContentGraph.ContentNode memory asset =
            ContentGraph.ContentNode(keccak256("ASSET"), ContentGraph.NodeType.ASSET, bytes32(0), "");
        ContentGraph.ContentNode memory ref = ContentGraph.ContentNode(
            keccak256(abi.encodePacked(user0, uint256(3))), ContentGraph.NodeType.REFERENCE, keccak256("ASSET"), ""
        );
        bytes32 org = keccak256(abi.encodePacked(user0, uint256(1)));
        vm.startPrank(user00);
        graph.createNode(org, bytes32(0), ContentGraph.NodeType.ORG, bytes32(0));
        graph.publish(org, asset);
        graph.publish(org, ref);

        ContentGraph.Node memory orgNode = graph.getNode(org);
        ContentGraph.Node memory assetNode = graph.getNode(asset.id);
        ContentGraph.Node memory referenceNode = graph.getNode(ref.id);

        assertEq(orgNode.uri, "");
        assertEq(assetNode.uri, "");
        assertEq(referenceNode.uri, "");

        graph.setURI(org, "ipfs://org");
        graph.setURI(asset.id, "ipfs://asset");
        vm.expectRevert();
        graph.setURI(ref.id, "ipfs://ref");

        orgNode = graph.getNode(org);
        assetNode = graph.getNode(asset.id);
        referenceNode = graph.getNode(ref.id);

        assertEq(orgNode.uri, "ipfs://org");
        assertEq(assetNode.uri, "ipfs://asset");
        assertEq(referenceNode.uri, assetNode.uri);

        vm.stopPrank();
    }

    function testV3GetNode() public {
        ContentGraph.ContentNode memory asset = ContentGraph.ContentNode(
            keccak256(abi.encodePacked("SampleData")), ContentGraph.NodeType.ASSET, bytes32(0), "assetURI"
        );
        vm.startPrank(user00);
        graph.publish(bytes32(0), asset);
        vm.stopPrank();

        vm.expectRevert();
        graph.getNode(bytes32(0));

        vm.expectRevert();
        graph.getNode(keccak256("random"));

        ContentGraph.Node memory assetNode = graph.getNode(asset.id);
        assertEq(assetNode.token, 1);
        assertTrue(assetNode.nodeType == ContentGraph.NodeType.ASSET);
        assertEq(assetNode.id, asset.id);
        assertEq(assetNode.referenceOf, asset.referenceOf);
        assertEq(assetNode.uri, asset.uri);
        assertEq(assetNode.accessAuth, address(0));
        assertEq(assetNode.referenceAuth, address(0));
    }

    function testV3TokenToNode() public {
        ContentGraph.ContentNode memory asset = ContentGraph.ContentNode(
            keccak256(abi.encodePacked("SampleData")), ContentGraph.NodeType.ASSET, bytes32(0), "assetURI"
        );
        vm.startPrank(user00);
        graph.publish(bytes32(0), asset);
        vm.stopPrank();

        vm.expectRevert();
        graph.tokenToNode(0);

        vm.expectRevert();
        graph.tokenToNode(2);

        ContentGraph.Node memory assetNode = graph.tokenToNode(1);
        assertEq(assetNode.token, 1);
        assertTrue(assetNode.nodeType == ContentGraph.NodeType.ASSET);
        assertEq(assetNode.id, asset.id);
        assertEq(assetNode.referenceOf, asset.referenceOf);
        assertEq(assetNode.uri, asset.uri);
        assertEq(assetNode.accessAuth, address(0));
        assertEq(assetNode.referenceAuth, address(0));
    }

    function testV3Auth() public {
        ContentGraph.ContentNode memory asset0 =
            ContentGraph.ContentNode(keccak256(abi.encodePacked("0")), ContentGraph.NodeType.ASSET, bytes32(0), "");
        ContentGraph.ContentNode memory asset1 =
            ContentGraph.ContentNode(keccak256(abi.encodePacked("1")), ContentGraph.NodeType.ASSET, bytes32(0), "");
        ContentGraph.ContentNode memory asset2 =
            ContentGraph.ContentNode(keccak256(abi.encodePacked("2")), ContentGraph.NodeType.ASSET, bytes32(0), "");
        ContentGraph.ContentNode memory ref0 = ContentGraph.ContentNode(
            keccak256(abi.encodePacked(user0, uint256(4))), ContentGraph.NodeType.REFERENCE, asset2.id, ""
        );

        bytes32 org0 = keccak256(abi.encodePacked(user0, uint256(1)));
        bytes32 org1 = keccak256(abi.encodePacked(user1, uint256(1)));

        ContentGraph.ContentNode[] memory contents = new ContentGraph.ContentNode[](3);
        contents[0] = asset0;
        contents[1] = asset1;
        contents[2] = ref0;

        vm.startPrank(user01);
        graph.createNode(org1, bytes32(0), ContentGraph.NodeType.ORG, bytes32(0));
        graph.publish(org1, asset2);
        vm.stopPrank();

        vm.startPrank(user00);
        graph.createNode(org0, bytes32(0), ContentGraph.NodeType.ORG, bytes32(0));
        graph.publishBulk(org0, contents);
        vm.stopPrank();

        /**
         * 0
         *       org0     org1
         *     a0 a1 r0    a2
         */

        // Base case no auth set so all users should access
        assertTrue(graph.auth(org0, user));
        assertTrue(graph.auth(org1, user));
        assertTrue(graph.auth(asset0.id, user));
        assertTrue(graph.auth(asset1.id, user));
        assertTrue(graph.auth(asset2.id, user));
        assertTrue(graph.auth(ref0.id, user));

        assertTrue(graph.auth(org0, user2));
        assertTrue(graph.auth(org1, user2));
        assertTrue(graph.auth(asset0.id, user2));
        assertTrue(graph.auth(asset1.id, user2));
        assertTrue(graph.auth(asset2.id, user2));
        assertTrue(graph.auth(ref0.id, user2));

        // Test reference Auth, if a user loses ability to reference access is rejected
        vm.prank(user01);
        graph.setReferenceAuth(asset2.id, address(auth));
        assertTrue(graph.auth(org0, user));
        assertTrue(graph.auth(org1, user));
        assertTrue(graph.auth(asset0.id, user));
        assertTrue(graph.auth(asset1.id, user));
        assertTrue(graph.auth(asset2.id, user));
        assertFalse(graph.auth(ref0.id, user));

        assertTrue(graph.auth(org0, user2));
        assertTrue(graph.auth(org1, user2));
        assertTrue(graph.auth(asset0.id, user2));
        assertTrue(graph.auth(asset1.id, user2));
        assertTrue(graph.auth(asset2.id, user2));
        assertFalse(graph.auth(ref0.id, user2));

        vm.prank(user01);
        auth.setState(asset2.id, user0, true);
        assertTrue(graph.auth(ref0.id, user));
        assertTrue(graph.auth(ref0.id, user2));

        //Test Auth directly
        vm.prank(user00);
        graph.setAccessAuth(asset0.id, address(auth));
        assertTrue(graph.auth(org0, user));
        assertTrue(graph.auth(org1, user));
        assertFalse(graph.auth(asset0.id, user));
        assertTrue(graph.auth(asset1.id, user));
        assertTrue(graph.auth(asset2.id, user));
        assertTrue(graph.auth(ref0.id, user));

        assertTrue(graph.auth(org0, user2));
        assertTrue(graph.auth(org1, user2));
        assertFalse(graph.auth(asset0.id, user2));
        assertTrue(graph.auth(asset1.id, user2));
        assertTrue(graph.auth(asset2.id, user2));
        assertTrue(graph.auth(ref0.id, user2));

        vm.prank(user00);
        auth.setState(asset0.id, user, true);
        assertTrue(graph.auth(org0, user));
        assertTrue(graph.auth(org1, user));
        assertTrue(graph.auth(asset0.id, user));
        assertTrue(graph.auth(asset1.id, user));
        assertTrue(graph.auth(asset2.id, user));
        assertTrue(graph.auth(ref0.id, user));

        assertTrue(graph.auth(org0, user2));
        assertTrue(graph.auth(org1, user2));
        assertFalse(graph.auth(asset0.id, user2));
        assertTrue(graph.auth(asset1.id, user2));
        assertTrue(graph.auth(asset2.id, user2));
        assertTrue(graph.auth(ref0.id, user2));

        //Test Auth from parent
        vm.prank(user00);
        graph.setAccessAuth(org0, address(auth));

        assertFalse(graph.auth(org0, user));
        assertTrue(graph.auth(org1, user));
        assertTrue(graph.auth(asset0.id, user));
        assertFalse(graph.auth(asset1.id, user));
        assertTrue(graph.auth(asset2.id, user));
        assertFalse(graph.auth(ref0.id, user));

        assertFalse(graph.auth(org0, user2));
        assertTrue(graph.auth(org1, user2));
        assertFalse(graph.auth(asset0.id, user2));
        assertFalse(graph.auth(asset1.id, user2));
        assertTrue(graph.auth(asset2.id, user2));
        assertFalse(graph.auth(ref0.id, user2));

        vm.startPrank(user0);
        auth.setState(org0, user, true);
        auth.setState(asset0.id, user, false);
        vm.stopPrank();

        assertTrue(graph.auth(org0, user));
        assertTrue(graph.auth(org1, user));
        assertTrue(graph.auth(asset0.id, user));
        assertTrue(graph.auth(asset1.id, user));
        assertTrue(graph.auth(asset2.id, user));
        assertTrue(graph.auth(ref0.id, user));

        assertFalse(graph.auth(org0, user2));
        assertTrue(graph.auth(org1, user2));
        assertFalse(graph.auth(asset0.id, user2));
        assertFalse(graph.auth(asset1.id, user2));
        assertTrue(graph.auth(asset2.id, user2));
        assertFalse(graph.auth(ref0.id, user2));

        //Test Reference Auth delegation
        vm.prank(user01);
        auth.setState(asset2.id, user0, false);
        assertTrue(graph.auth(org0, user));
        assertTrue(graph.auth(org1, user));
        assertTrue(graph.auth(asset0.id, user));
        assertTrue(graph.auth(asset1.id, user));
        assertTrue(graph.auth(asset2.id, user));
        assertFalse(graph.auth(ref0.id, user));

        assertFalse(graph.auth(org0, user2));
        assertTrue(graph.auth(org1, user2));
        assertFalse(graph.auth(asset0.id, user2));
        assertFalse(graph.auth(asset1.id, user2));
        assertTrue(graph.auth(asset2.id, user2));
        assertFalse(graph.auth(ref0.id, user2));

        vm.startPrank(user01);
        graph.setReferenceAuth(org1, address(auth));
        auth.setState(org1, user0, true);
        vm.stopPrank();
        assertTrue(graph.auth(ref0.id, user));
        assertFalse(graph.auth(ref0.id, user2));
    }

    function testV3AuthCont() public {
        bytes32 org0 = keccak256(abi.encodePacked(user0, uint256(1)));
        bytes32 org1 = keccak256(abi.encodePacked(user0, uint256(2)));
        bytes32 org2 = keccak256(abi.encodePacked(user0, uint256(3)));

        vm.startPrank(user00);
        graph.createNode(org0, bytes32(0), ContentGraph.NodeType.ORG, bytes32(0));
        graph.createNode(org1, org0, ContentGraph.NodeType.ORG, bytes32(0));
        graph.createNode(org2, org1, ContentGraph.NodeType.ORG, bytes32(0));

        // () -> () -> () - 0 : true
        assertEq(graph.auth(org2, user00), true, "1");

        graph.setAccessAuth(org1, address(auth));
        assertEq(auth.auth(org1, user00), false, "STATE: 2");
        // () -> (F) -> () - 0 : false
        assertEq(graph.auth(org2, user00), false, "2");

        graph.setAccessAuth(org0, address(auth));
        assertEq(auth.auth(org1, user00), false, "STATE: 3");
        assertEq(auth.auth(org0, user00), false, "STATE: 3");
        // () -> (F) -> (F) - 0 : false
        assertEq(graph.auth(org2, user00), false, "3");

        auth.setState(org0, user00, true);
        assertEq(auth.auth(org1, user00), false, "STATE: 4");
        assertEq(auth.auth(org0, user00), true, "STATE: 4");
        // () -> (F) -> (T) - 0 : true
        assertEq(graph.auth(org2, user00), true, "4");

        auth.setState(org1, user00, true);
        graph.setAccessAuth(org0, address(0));
        assertEq(auth.auth(org1, user00), true, "STATE: 5");
        // () -> (T) -> () - 0 : true
        assertEq(graph.auth(org2, user00), true, "5");

        graph.setAccessAuth(org0, address(auth));
        auth.setState(org0, user00, false);
        assertEq(auth.auth(org1, user00), true, "STATE: 6");
        assertEq(auth.auth(org0, user00), false, "STATE: 6");
        // () -> (T) -> (F) - 0 : true
        assertEq(graph.auth(org2, user00), true, "6");

        auth.setState(org0, user00, true);
        assertEq(auth.auth(org1, user00), true, "STATE: 7");
        assertEq(auth.auth(org0, user00), true, "STATE: 7");
        // () -> (T) -> (T) - 0 : true
        assertEq(graph.auth(org2, user00), true, "7");

        graph.setAccessAuth(org2, address(auth));
        graph.setAccessAuth(org1, address(0));
        graph.setAccessAuth(org0, address(0));

        assertEq(auth.auth(org2, user00), false, "STATE: 8");
        // (F) -> () -> () - 0 : false
        assertEq(graph.auth(org2, user00), false, "8");

        graph.setAccessAuth(org1, address(auth));
        auth.setState(org1, user00, false);
        assertEq(auth.auth(org2, user00), false, "STATE: 9");
        assertEq(auth.auth(org1, user00), false, "STATE: 9");
        // (F) -> (F) -> () - 0 : false
        assertEq(graph.auth(org2, user00), false, "9");

        graph.setAccessAuth(org0, address(auth));
        auth.setState(org0, user00, false);
        assertEq(auth.auth(org2, user00), false, "STATE: 10");
        assertEq(auth.auth(org1, user00), false, "STATE: 10");
        assertEq(auth.auth(org0, user00), false, "STATE: 10");
        // (F) -> (F) -> (F) - 0 : false
        assertEq(graph.auth(org2, user00), false, "10");

        auth.setState(org0, user00, true);
        assertEq(auth.auth(org2, user00), false, "STATE: 11");
        assertEq(auth.auth(org1, user00), false, "STATE: 11");
        assertEq(auth.auth(org0, user00), true, "STATE: 11");
        // (F) -> (F) -> (T) - 0 : true
        assertEq(graph.auth(org2, user00), true, "11");

        graph.setAccessAuth(org0, address(0));
        auth.setState(org1, user00, true);
        assertEq(auth.auth(org2, user00), false, "STATE: 12");
        assertEq(auth.auth(org1, user00), true, "STATE: 12");
        auth.setState(org1, user00, true);
        // (F) -> (T) -> () - 0 : true
        assertEq(graph.auth(org2, user00), true, "12");

        graph.setAccessAuth(org0, address(auth));
        auth.setState(org0, user00, false);
        assertEq(auth.auth(org2, user00), false, "STATE: 13");
        assertEq(auth.auth(org1, user00), true, "STATE: 13");
        assertEq(auth.auth(org0, user00), false, "STATE: 13");
        // (F) -> (T) -> (F) - 0 : true
        assertEq(graph.auth(org2, user00), true, "13");

        auth.setState(org0, user00, true);
        assertEq(auth.auth(org2, user00), false, "STATE: 10");
        assertEq(auth.auth(org1, user00), true, "STATE: 14");
        assertEq(auth.auth(org0, user00), true, "STATE: 14");
        // (F) -> (T) -> (T) - 0 : true
        assertEq(graph.auth(org2, user00), true, "14");

        graph.setAccessAuth(org2, address(auth));
        graph.setAccessAuth(org1, address(0));
        graph.setAccessAuth(org0, address(0));
        auth.setState(org2, user00, true);
        assertEq(auth.auth(org2, user00), true, "STATE: 15");
        // (T) -> () -> () - 0 : true
        assertEq(graph.auth(org2, user00), true, "15");

        graph.setAccessAuth(org1, address(auth));
        auth.setState(org1, user00, false);
        assertEq(auth.auth(org2, user00), true, "STATE: 16");
        assertEq(auth.auth(org1, user00), false, "STATE: 16");
        // (T) -> (F) -> () - 0 : true
        assertEq(graph.auth(org2, user00), true, "16");

        graph.setAccessAuth(org0, address(auth));
        auth.setState(org0, user00, false);
        assertEq(auth.auth(org2, user00), true, "STATE: 17");
        assertEq(auth.auth(org1, user00), false, "STATE: 17");
        assertEq(auth.auth(org0, user00), false, "STATE: 17");
        // (T) -> (F) -> (F) - 0 : true
        assertEq(graph.auth(org2, user00), true, "17");

        auth.setState(org0, user00, true);
        assertEq(auth.auth(org2, user00), true, "STATE: 18");
        assertEq(auth.auth(org1, user00), false, "STATE: 18");
        assertEq(auth.auth(org0, user00), true, "STATE: 18");
        // (T) -> (F) -> (T) - 0 : true
        assertEq(graph.auth(org2, user00), true, "18");

        graph.setAccessAuth(org0, address(0));
        auth.setState(org1, user00, true);
        assertEq(auth.auth(org2, user00), true, "STATE: 19");
        assertEq(auth.auth(org1, user00), true, "STATE: 19");
        auth.setState(org1, user00, true);
        // (T) -> (T) -> () - 0 : true
        assertEq(graph.auth(org2, user00), true, "19");

        graph.setAccessAuth(org0, address(auth));
        auth.setState(org0, user00, false);
        assertEq(auth.auth(org2, user00), true, "STATE: 20");
        assertEq(auth.auth(org1, user00), true, "STATE: 20");
        assertEq(auth.auth(org0, user00), false, "STATE: 20");
        // (T) -> (T) -> (F) - 0 : true
        assertEq(graph.auth(org2, user00), true, "20");

        auth.setState(org0, user00, true);
        assertEq(auth.auth(org2, user00), true, "STATE: 21");
        assertEq(auth.auth(org1, user00), true, "STATE: 21");
        assertEq(auth.auth(org0, user00), true, "STATE: 21");
        // (T) -> (T) -> (T) - 0 : true
        assertEq(graph.auth(org2, user00), true, "21");

        vm.stopPrank();
    }

    function testV3ReferenceAuth() public {
        ContentGraph.ContentNode memory asset0 =
            ContentGraph.ContentNode(keccak256(abi.encodePacked("0")), ContentGraph.NodeType.ASSET, bytes32(0), "");
        ContentGraph.ContentNode memory ref0 = ContentGraph.ContentNode(
            keccak256(abi.encodePacked(user0, uint256(1))), ContentGraph.NodeType.REFERENCE, asset0.id, ""
        );

        vm.startPrank(user01);
        graph.publish(bytes32(0), asset0);
        vm.stopPrank();

        vm.startPrank(user00);
        graph.publish(bytes32(0), ref0);
        vm.expectRevert();
        graph.setReferenceAuth(ref0.id, address(auth));
        vm.stopPrank();

        assertTrue(graph.refAuth(asset0.id, user));
        assertFalse(graph.refAuth(ref0.id, user));
    }

    function arrayMatch(uint256[] memory a, uint256[] memory b) internal pure returns (bool) {
        if ((a.length == b.length)) {
            bool isMatch = true;
            for (uint256 i = 0; i < a.length; i++) {
                isMatch = isMatch && (a[i] == b[i]);
            }
            return isMatch;
        } else {
            return false;
        }
    }
}
