// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Baguette Token
/// @notice Fixed-supply token minted to the distributor; only the distributor can transfer tokens out.
contract BaguetteToken is ERC20 {
  error UnauthorizedSender(address sender);

  uint256 public constant TOTAL_SUPPLY = 4 ether;

  address public immutable distributor;

  constructor(address distributor_) ERC20("Baguette", "BAGUETTE") {
    require(distributor_ != address(0), "BaguetteToken: distributor zero");
    distributor = distributor_;
    _mint(distributor_, TOTAL_SUPPLY);
  }

  function _update(address from, address to, uint256 value) internal override {
    if (from != address(0) && from != distributor) {
      revert UnauthorizedSender(from);
    }
    super._update(from, to, value);
  }
}
