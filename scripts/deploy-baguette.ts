import { network } from "hardhat";

const { ethers } = await network.connect();

function readFlagHashes(): `0x${string}`[] {
  const env = process.env.BAGUETTE_FLAG_HASHES;
  if (!env) {
    throw new Error(
      "Set BAGUETTE_FLAG_HASHES to a comma separated list of 32-byte hex values before running this script.",
    );
  }

  return env
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0)
    .map((value) => {
      if (!ethers.isHexString(value, 32)) {
        throw new Error(`Invalid flag hash: ${value}`);
      }
      return value as `0x${string}`;
    });
}

async function main() {
  const flagHashes = readFlagHashes();
  const [deployer] = await ethers.getSigners();

  console.log(`Deploying Baguette with deployer ${deployer.address}`);

  const baguette = await ethers.deployContract("Baguette", [flagHashes]);
  await baguette.waitForDeployment();

  const distributorAddress = await baguette.getAddress();
  console.log(`Baguette distributor deployed at ${distributorAddress}`);

  const tokenAddress = await baguette.baguetteToken();
  console.log(`Baguette token deployed at ${tokenAddress}`);

  const token = await ethers.getContractAt("BaguetteToken", tokenAddress);
  const totalSupply = await token.totalSupply();
  const prizeBudget = await baguette.PRIZE_PER_CONTEST();
  const prizePool = await baguette.prizePoolDeposited();
  console.log(`Token total supply: ${totalSupply.toString()}`);
  console.log(`Prize budget per contest: ${prizeBudget.toString()}`);
  console.log(`Prize pool currently available: ${prizePool.toString()}`);

  const schedule = await baguette.prizeSchedule();
  console.log("Prize schedule (token wei):", schedule.map((value) => value.toString()));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
