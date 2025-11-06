// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {BaguetteDistributor} from "../Baguette.sol";

/// @dev Test helper exposing `_submitFlag` for configurable expectations.
contract BaguetteDistributorHarness is BaguetteDistributor {
    constructor(address tokenAddress) BaguetteDistributor(tokenAddress) {}

    function submitFlagWithHash(
        uint256 ctfId,
        string calldata flag,
        bytes32 expectedHash
    ) external {
        _submitFlag(ctfId, flag, expectedHash);
    }
}
