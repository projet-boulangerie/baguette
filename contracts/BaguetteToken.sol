// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Baguette Token
/// @notice Non-transferable token, 4 units of whole baguettes only.
contract BaguetteToken is ERC20 {
    error UnauthorizedSender(address sender);

    uint256 public constant TOTAL_SUPPLY = 4;

    address public immutable distributor;

    constructor(address distributor_) ERC20("Baguette", "BAGUETTE") {
        require(distributor_ != address(0), "BaguetteToken: distributor zero");
        distributor = distributor_;
        _mint(distributor_, TOTAL_SUPPLY);
    }

    /// @notice Overrides transfer logic to restrict token movement
    function _update(address from, address to, uint256 value) internal override {
        // Allow minting (from=0) and transfers by the distributor only
        if (from != address(0) && from != distributor) {
            revert UnauthorizedSender(from);
        }
        super._update(from, to, value);
    }

    /// @notice Override decimals to enforce whole-token logic
    function decimals() public pure override returns (uint8) {
        return 0;
    }
}
