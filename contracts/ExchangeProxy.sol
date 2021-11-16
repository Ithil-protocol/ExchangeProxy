// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IQuoter.sol";
import "./interfaces/ISwapper.sol";

contract ExchangeProxy is Ownable {
  struct Exchange {
    address quoter;
    address swapper;
  }
  Exchange[] public dexes;

  function addDex(address _quoter, address _swapper) external onlyOwner returns(uint256) {
    dexes.push(Exchange({quoter: _quoter, swapper: _swapper}));

    return  dexes.length - 1;
  }

  function removeDex(uint256 id) external onlyOwner {
    delete dexes[id];
  }

  function quoteSell(address token0, address token1, uint256 amount) external view returns(uint256) {
    for(uint256 id = 0; id < dexes.length; id++) {

    }
  }

  function quoteBuy(address token0, address token1, uint256 amount) external view returns(uint256) {
    for(uint256 id = 0; id < dexes.length; id++) {
      
    }
  }

  function sell(address token0, address token1, uint256 amount, uint256 maxInput, uint256 dexId) external  returns(uint256) {

  }

  function buy(address token0, address token1, uint256 amount, uint256 minOutput, uint256 dexId) external  returns(uint256) {
    
  }

}
