module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("UniswapV3Quoter", {
    from: deployer,
    args: ["0x1F98431c8aD98523631AE4a59f267346ea31F984"],
    log: true,
  });

};
module.exports.tags = ["UniswapV3Quoter"];
