// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {BaguetteToken} from "./BaguetteToken.sol";

/// @title Baguette Distributor
/// @notice Allows claiming 1 Baguette per CTF by submitting the correct flag.
contract BaguetteDistributor {
    error InvalidFlag();
    error AlreadySolved(uint256 ctfId);
    error InvalidCTF(uint256 ctfId);
    error TransferFailed();

    BaguetteToken public immutable baguetteToken;
    address public owner;

    // Hardcoded flag hashes for all 4 CTFs (replace with real hashes)
    bytes32 public constant FLAG_HASH_1 = 0xfd0963045532356fcf5dd0a83d770a11659336e928f21324fa110ce574ad018c;
    bytes32 public constant FLAG_HASH_2 = 0xc7ba8a87595b8bc6e91e300c8923d6531db3cb71d465f7dfad684335750d1dcb;
    bytes32 public constant FLAG_HASH_3 = 0x82a339f7d5da088aab65e885de20747e2c2a97228e0ecc3bed9f2cb59edea586;
    bytes32 public constant FLAG_HASH_4 = 0x4fd1f35a3fac36004a6e5cc49b4adefa45ce4f68f9b0b3fdf6fa728fd8ddc88d;

    // Track if a flag has been solved so it cannot be reused
    bool[4] public isSolved;

    event CTFSolved(uint256 indexed ctfId, address indexed solver);

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Invalid token address");
        owner = msg.sender;
        baguetteToken = BaguetteToken(tokenAddress);
    }

    // Submit for CTF 1
    function submitFlag1(string calldata flag) external {
        _submitFlag(0, flag, FLAG_HASH_1);
    }

    // Submit for CTF 2
    function submitFlag2(string calldata flag) external {
        _submitFlag(1, flag, FLAG_HASH_2);
    }

    // Submit for CTF 3
    function submitFlag3(string calldata flag) external {
        _submitFlag(2, flag, FLAG_HASH_3);
    }

    // Submit for CTF 4
    function submitFlag4(string calldata flag) external {
        _submitFlag(3, flag, FLAG_HASH_4);
    }

    // Internal reuse logic for validation and token transfer
    function _submitFlag(uint256 ctfId, string calldata flag, bytes32 expectedHash) internal {
        if (ctfId >= isSolved.length) revert InvalidCTF(ctfId);
        if (isSolved[ctfId]) revert AlreadySolved(ctfId);
        if (keccak256(abi.encodePacked(flag)) != expectedHash) revert InvalidFlag();

        // Mark solved first to prevent reentrancy issues or double-claims
        isSolved[ctfId] = true;

        // Transfer 1 Baguette to sender
        bool success = baguetteToken.transfer(msg.sender, 1);
        if (!success) revert TransferFailed();

        emit CTFSolved(ctfId, msg.sender);
    }
}
