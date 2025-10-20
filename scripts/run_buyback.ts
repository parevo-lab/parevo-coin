import 'dotenv/config';
import { ethers } from "hardhat";

async function main() {
  const addr = process.env.BUYBACK!;
  const amount = ethers.parseUnits(process.env.AMOUNT || "1000", 6);
  const burn = (process.env.BURN || "true") === "true";

  const buyback = await ethers.getContractAt("Buyback", addr);
  await buyback.perform(amount, burn);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});


