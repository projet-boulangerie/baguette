// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";

import {BaguetteDistributor} from "../contracts/Baguette.sol";
import {BaguetteToken} from "../contracts/BaguetteToken.sol";
/// @notice Deploys the token and distributor contracts using Foundry.
contract DeployBaguette is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        address deployer = vm.addr(deployerKey);
        uint256 currentNonce = vm.getNonce(deployer);
        address distributorAddress = vm.computeCreateAddress(deployer, currentNonce + 1);

        BaguetteToken token = new BaguetteToken(distributorAddress);
        BaguetteDistributor distributor = new BaguetteDistributor(address(token));

        vm.stopBroadcast();

        console2.log("BaguetteToken deployed at", address(token));
        console2.log("BaguetteDistributor deployed at", address(distributor));
    }
}
