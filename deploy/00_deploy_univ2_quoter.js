module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("UniswapV2Quoter", {
    from: deployer,
    args: ["0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"],
    log: true,
  });

};
module.exports.tags = ["UniswapV2Quoter"];
