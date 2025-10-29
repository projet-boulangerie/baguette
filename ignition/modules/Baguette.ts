import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const DEFAULT_FLAG_HASHES: `0x${string}`[] = [
  "0xefa7e22eae59a11934d758865481e3dc94cbc853048036e4a3d61075d7f8f3a7",
];

const BaguetteModule = buildModule("BaguetteModule", (m) => {
  const flagHashes = m.getParameter<`0x${string}`[]>("flagHashes", DEFAULT_FLAG_HASHES);

  const baguette = m.contract("Baguette", [flagHashes]);

  return { baguette };
});

export default BaguetteModule;
