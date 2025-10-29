import { expect } from "chai";
import { keccak256, parseEther, toUtf8Bytes } from "ethers";
import { network } from "hardhat";

const { ethers } = await network.connect();

const demoFlags = ["baguette{flag_one}", "baguette{flag_two}", "baguette{flag_three}"];

function hashFlag(flag: string) {
  return keccak256(toUtf8Bytes(flag));
}

describe("Baguette", function () {
  it("pays the correct prize to the first solver", async function () {
    const flagHashes = demoFlags.map(hashFlag);
    const [deployer, solver] = await ethers.getSigners();

    const baguette = await ethers.deployContract("Baguette", [flagHashes]);
    const tokenAddress = await baguette.baguetteToken();
    const token = await ethers.getContractAt("BaguetteToken", tokenAddress);

    await expect(baguette.connect(solver).submitFlag(0, 0, demoFlags[0]))
      .to.emit(baguette, "FlagSolved")
      .withArgs(solver.address, 0n, 0n, 0n, parseEther("0.05"));

    expect(await baguette.contestWinnerAt(0, 0)).to.equal(solver.address);
    expect(await baguette.contestHasClaimed(0, solver.address)).to.equal(true);
    expect(await token.balanceOf(solver.address)).to.equal(parseEther("0.05"));

    await expect(
      token.connect(solver).transfer(deployer.address, 1n),
    ).to.be.revertedWithCustomError(token, "UnauthorizedSender").withArgs(solver.address);
  });

  it("reverts on invalid flag submissions", async function () {
    const baguette = await ethers.deployContract("Baguette", [[hashFlag(demoFlags[0])]]);

    await expect(baguette.submitFlag(0, 0, "wrong")).to.be.revertedWithCustomError(
      baguette,
      "InvalidFlag",
    );
  });

  it("blocks additional winners once the leaderboard is full", async function () {
    const flags = Array.from({ length: 15 }, (_, i) => `baguette{${i + 1}}`);
    const baguette = await ethers.deployContract("Baguette", [flags.map(hashFlag)]);

    const signers = await ethers.getSigners();

    for (let i = 0; i < 14; i++) {
      await baguette.connect(signers[i + 1]).submitFlag(0, i, flags[i]);
    }

    await expect(
      baguette.connect(signers[15]).submitFlag(0, 14, flags[14]),
    ).to.be.revertedWithCustomError(baguette, "LeaderboardFull").withArgs(0n);
  });

  it("supports multiple contests with independent leaderboards", async function () {
    const baguette = await ethers.deployContract("Baguette", [[hashFlag(demoFlags[0])]]);
    const [contestZeroSolver, contestOneSolver] = (await ethers.getSigners()).slice(1, 3);

    await baguette.connect(contestZeroSolver).submitFlag(0, 0, demoFlags[0]);

    const newContestFlags = ["baguette{new_flag}"].map(hashFlag);
    const newContestId = await baguette.startContest.staticCall(newContestFlags);
    await baguette.startContest(newContestFlags);

    const winnersLength = await baguette.contestWinnersLength(newContestId);
    expect(winnersLength).to.equal(0n);

    await baguette.connect(contestOneSolver).submitFlag(newContestId, 0, "baguette{new_flag}");
    expect(await baguette.contestWinnerAt(newContestId, 0)).to.equal(contestOneSolver.address);
  });
});
