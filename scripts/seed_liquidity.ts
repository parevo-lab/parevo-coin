import 'dotenv/config';
import { ethers } from "hardhat";

async function main() {
  const router = process.env.ROUTER!;
  const pai = process.env.PAI!;
  const base = process.env.BASE_TOKEN!;
  const amountPai = ethers.parseUnits(process.env.AMOUNT_PAI || "1000000", 18);
  const amountBase = ethers.parseUnits(process.env.AMOUNT_BASE || "10000", 6);

  const [signer] = await ethers.getSigners();
  const erc20 = await ethers.getContractAt("IERC20", pai);
  const baseErc20 = await ethers.getContractAt("IERC20", base);

  await erc20.approve(router, amountPai);
  await baseErc20.approve(router, amountBase);

  const uni = await ethers.getContractAt("IUniswapV2Router", router);
  const deadline = Math.floor(Date.now() / 1000) + 900;
  await uni.addLiquidity(
    pai,
    base,
    amountPai,
    amountBase,
    amountPai,
    amountBase,
    signer.address,
    deadline
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});


