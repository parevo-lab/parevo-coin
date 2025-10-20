import 'dotenv/config';
import { ethers, network } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  const deployerAddr = await deployer.getAddress();
  console.log(`Deployer: ${deployerAddr} on ${network.name}`);

  const envAdmin = (process.env.ADMIN_MULTISIG || "").trim();
  const admin = ethers.isAddress(envAdmin) ? envAdmin : deployerAddr;
  const initialSupply = ethers.parseUnits("1000000000", 18); // 1B

  const tokenName = (process.env.TOKEN_NAME || 'PaiasCoin').trim();
  const tokenSymbol = (process.env.TOKEN_SYMBOL || 'PAI').trim();
  const Coin = await ethers.getContractFactory("Coin");
  const pai = await Coin.deploy(tokenName, tokenSymbol, admin, initialSupply);
  await pai.waitForDeployment();
  console.log("PAI:", await pai.getAddress());

  const Staking = await ethers.getContractFactory("Staking");
  const staking = await Staking.deploy(
    admin,
    await pai.getAddress(),
    await pai.getAddress(),
    ethers.parseUnits("0.5", 18) / BigInt(86400), // ~0.5 PAI/day per 1 PAI staked example
    30 * 24 * 60 * 60 // 30d lock
  );
  await staking.waitForDeployment();
  console.log("Staking:", await staking.getAddress());

  const Vesting = await ethers.getContractFactory("Vesting");
  const vesting = await Vesting.deploy(admin, await pai.getAddress());
  await vesting.waitForDeployment();
  console.log("Vesting:", await vesting.getAddress());

  const baseRaw = (process.env.BASE_TOKEN || '').trim();
  const routerRaw = (process.env.ROUTER || '').trim();
  const hasBuybackDeps = ethers.isAddress(baseRaw) && ethers.isAddress(routerRaw);
  if (!hasBuybackDeps) {
    console.log("[warn] Skipping Buyback deploy: BASE_TOKEN/ROUTER not set or invalid.");
    return;
  }
  const Buyback = await ethers.getContractFactory("Buyback");
  const path = [baseRaw, await pai.getAddress()];
  const buyback = await Buyback.deploy(admin, baseRaw, await pai.getAddress(), routerRaw, path);
  await buyback.waitForDeployment();
  console.log("Buyback:", await buyback.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});


