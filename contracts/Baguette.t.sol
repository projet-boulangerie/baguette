// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Baguette} from "./Baguette.sol";
import {BaguetteToken} from "./BaguetteToken.sol";
import {Test} from "forge-std/Test.sol";

contract BaguetteTest is Test {
  Baguette internal baguette;
  BaguetteToken internal token;

  string internal constant FLAG_ONE = "baguette{flag_one}";
  string internal constant FLAG_TWO = "baguette{flag_two}";

  function setUp() public {
    bytes32[] memory flagHashes = new bytes32[](2);
    flagHashes[0] = keccak256(bytes(FLAG_ONE));
    flagHashes[1] = keccak256(bytes(FLAG_TWO));

    baguette = new Baguette(flagHashes);
    token = baguette.baguetteToken();
  }

  function test_SubmitFlagPaysTopPrize() public {
    address solver = makeAddr("solver");

    vm.prank(solver);
    uint256 prize = baguette.submitFlag(0, 0, FLAG_ONE);

    assertEq(prize, 50_000_000_000_000_000, "Top prize mismatch");
    assertTrue(baguette.contestHasClaimed(0, solver), "Solver should be marked for contest 0");
    assertEq(baguette.contestWinnerAt(0, 0), solver, "Solver should be first winner");
    assertEq(token.balanceOf(solver), prize, "Prize not received");
  }

  function test_TokensCannotBeTransferredByWinners() public {
    address solver = makeAddr("solver");
    address recipient = makeAddr("recipient");

    vm.prank(solver);
    baguette.submitFlag(0, 0, FLAG_ONE);

    vm.expectRevert(abi.encodeWithSelector(BaguetteToken.UnauthorizedSender.selector, solver));
    vm.prank(solver);
    token.transfer(recipient, 1);
  }

  function test_RevertOnInvalidFlag() public {
    vm.expectRevert(Baguette.InvalidFlag.selector);
    baguette.submitFlag(0, 0, "wrong_flag");
  }

  function test_LeaderboardFull() public {
    string[15] memory flags = [
      "baguette{1}",
      "baguette{2}",
      "baguette{3}",
      "baguette{4}",
      "baguette{5}",
      "baguette{6}",
      "baguette{7}",
      "baguette{8}",
      "baguette{9}",
      "baguette{10}",
      "baguette{11}",
      "baguette{12}",
      "baguette{13}",
      "baguette{14}",
      "baguette{15}"
    ];

    bytes32[] memory flagHashes = new bytes32[](15);
    for (uint256 i = 0; i < flags.length; i++) {
      flagHashes[i] = keccak256(bytes(flags[i]));
    }

    baguette = new Baguette(flagHashes);
    token = baguette.baguetteToken();

    for (uint256 i = 0; i < 14; i++) {
      address solver = makeAddr(vm.toString(i));
      vm.prank(solver);
      baguette.submitFlag(0, i, flags[i]);
    }

    vm.expectRevert(abi.encodeWithSelector(Baguette.LeaderboardFull.selector, uint256(0)));
    vm.prank(makeAddr("overflow"));
    baguette.submitFlag(0, 14, flags[14]);
  }

  function test_StartNewContestResetsLeaderboard() public {
    // Finish first contest slot
    address solver = makeAddr("solver");
    vm.prank(solver);
    baguette.submitFlag(0, 0, FLAG_ONE);

    bytes32[] memory newFlags = new bytes32[](1);
    newFlags[0] = keccak256(bytes("baguette{new_flag}"));

    uint256 nextContestId = baguette.startContest(newFlags);
    assertEq(nextContestId, 1, "Next contest id should be 1");
    assertEq(baguette.contestWinnersLength(nextContestId), 0, "Fresh contest should start empty");

    address newSolver = makeAddr("new_solver");
    vm.prank(newSolver);
    baguette.submitFlag(nextContestId, 0, "baguette{new_flag}");

    assertTrue(
      baguette.contestHasClaimed(nextContestId, newSolver),
      "New solver should be registered for new contest"
    );
  }
}
