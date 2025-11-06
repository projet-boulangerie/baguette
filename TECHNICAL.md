# Technical Guide

## Tooling & Environment

This repository is now Forge-only. Install the Foundry toolchain and keep your environment offline-ready to avoid blocked compiler downloads.

### Prerequisites
- Install Foundry: `curl -L https://foundry.paradigm.xyz | bash` then `foundryup`
- Configure the repository remappings (already committed in `foundry.toml`)
- If network access is unavailable, place a matching `solc` binary somewhere accessible and set `FOUNDRY_SOLC=/path/to/solc-0.8.28`

### Testing

Run the Solidity suite:

```bash
forge test
```

- Uses `test/baguetteDistributor.t.sol`, which covers minting, correct flag submission, double-claim protection, invalid hash failures, invalid index reverts, and ERC20 transfer restrictions.
- Forge compiles contracts into `out/` and caches results under `cache/`; both folders are ignored.

### Deployment

The deployment entry point lives in `script/DeployBaguette.s.sol`.

Example commands:

```bash
export PRIVATE_KEY=0xYOUR_TEST_KEY
forge script script/DeployBaguette.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast
```

Key points:
- The script predicts the distributor address (`vm.computeCreateAddress`) so the BaguetteToken constructor can mint all four BAGUETTE units to the distributor.
- `vm.startBroadcast` signs transactions with the provided key; stop broadcasting before any local-only interactions.
- Inspect the broadcast logs under `broadcast/DeployBaguette.s.sol/*` for transaction traces and deployed addresses.

## Contract Architecture

### `BaguetteToken.sol`
- ERC20 subclass with symbol/name `BAGUETTE`.
- Constant `TOTAL_SUPPLY = 4`; constructor mints the entire supply to a distributor address passed at deployment.
- Overrides `_update` to permit transfers only when `from` is `address(0)` (mint) or the authorized distributor; otherwise reverts with `UnauthorizedSender`.
- Forces `decimals()` to zero to represent indivisible “whole baguettes”.

### `Baguette.sol` (`BaguetteDistributor`)
- Stores immutable reference to `BaguetteToken` instance and an owner.
- Contains four hard-coded flag hashes (`FLAG_HASH_1` … `FLAG_HASH_4`); each corresponds to a single Capture-The-Flag challenge.
- `submitFlag{1..4}` call the internal `_submitFlag(ctfId, flag, expectedHash)`:
  - Validates index bounds and whether the CTF is already solved (`isSolved[ctfId]`).
  - Compares `keccak256(abi.encodePacked(flag))` to the expected hash; reverts with `InvalidFlag` on mismatch.
  - Marks the CTF as solved before transferring to mitigate reentrancy.
  - Transfers exactly one BAGUETTE token to the caller; reverts with `TransferFailed` if the ERC20 transfer returns false.
  - Emits `CTFSolved(ctfId, solver)`.

### `BaguetteDistributorHarness.sol`
- Test helper contract that inherits from `BaguetteDistributor`.
- Exposes `submitFlagWithHash(uint256 ctfId, string calldata flag, bytes32 expectedHash)` to drive `_submitFlag` with arbitrary expected hashes during testing while keeping production entry points unchanged.
