import { run } from "hardhat";

async function main() {
  const address = process.env.CONTRACT!;
  const constructorArgs = process.env.ARGS ? JSON.parse(process.env.ARGS) : [];
  await run("verify:verify", { address, constructorArguments: constructorArgs });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});


