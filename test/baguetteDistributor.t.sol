// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {BaguetteDistributor} from "../contracts/Baguette.sol";
import {BaguetteToken} from "../contracts/BaguetteToken.sol";
import {BaguetteDistributorHarness} from "../contracts/mocks/BaguetteDistributorHarness.sol";

contract BaguetteDistributorTest is Test {
    BaguetteToken internal token;
    BaguetteDistributorHarness internal distributor;

    function setUp() public {
        address predictedDistributor =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        token = new BaguetteToken(predictedDistributor);
        distributor = new BaguetteDistributorHarness(address(token));
    }

    function testDistributesTokenOnCorrectFlag() public {
        address solver = address(0xBEEF);
        string memory flag = "baguette{forge_flag}";
        bytes32 expectedHash = keccak256(bytes(flag));

        vm.prank(solver);
        distributor.submitFlagWithHash(0, flag, expectedHash);

        assertEq(token.balanceOf(solver), 1);
        assertEq(token.balanceOf(address(distributor)), 3);
        assertTrue(distributor.isSolved(0));
    }

    function testRevertsOnFlagReuse() public {
        string memory flag = "baguette{forge_once}";
        bytes32 expectedHash = keccak256(bytes(flag));

        distributor.submitFlagWithHash(1, flag, expectedHash);

        vm.expectRevert(abi.encodeWithSelector(BaguetteDistributor.AlreadySolved.selector, 1));
        distributor.submitFlagWithHash(1, flag, expectedHash);
    }

    function testRejectsInvalidFlags() public {
        address predictedDistributor =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        BaguetteToken localToken = new BaguetteToken(predictedDistributor);
        BaguetteDistributor realDistributor = new BaguetteDistributor(address(localToken));

        vm.expectRevert(BaguetteDistributor.InvalidFlag.selector);
        realDistributor.submitFlag1("wrong-flag");
    }

    function testRejectsInvalidCtfIds() public {
        vm.expectRevert(abi.encodeWithSelector(BaguetteDistributor.InvalidCTF.selector, 7));
        distributor.submitFlagWithHash(7, "baguette{missing}", keccak256("x"));
    }

    function testTokenTransfersRestricted() public {
        address solver = address(0xCAFE);
        string memory flag = "baguette{no_transfer}";
        bytes32 expectedHash = keccak256(bytes(flag));

        vm.prank(solver);
        distributor.submitFlagWithHash(2, flag, expectedHash);

        vm.prank(solver);
        vm.expectRevert(abi.encodeWithSelector(BaguetteToken.UnauthorizedSender.selector, solver));
        token.transfer(address(0x1234), 1);
    }
}
