// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../interfaces/IQuoter.sol";
import "../libraries/UniswapV2/UniswapV2Library.sol";

contract UniswapV2Quoter is IQuoter {
    using SafeERC20 for IERC20;

    address internal immutable uniV2Factory; // TODO should it be immutable?

    constructor(address _uniV2Factory) {
        uniV2Factory = _uniV2Factory;
    }

    function quoteObtainedTokens(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) public view override returns (uint256) {
        uint256 reserveFromToken;
        uint256 reserveToToken;
        if (_fromToken < _toToken)
            (reserveFromToken, reserveToToken) = UniswapV2Library.getReserves(
                uniV2Factory,
                _fromToken,
                _toToken
            );
        else
            (reserveToToken, reserveFromToken) = UniswapV2Library.getReserves(
                uniV2Factory,
                _fromToken,
                _toToken
            );

        return
            UniswapV2Library.getAmountOut(
                _amount,
                reserveFromToken,
                reserveToToken
            );
    }

    function quoteNeededTokens(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) public view override returns (uint256) {
        uint256 reserveFromToken;
        uint256 reserveToToken;
        if (_fromToken < _toToken)
            (reserveFromToken, reserveToToken) = UniswapV2Library.getReserves(
                uniV2Factory,
                _fromToken,
                _toToken
            );
        else
            (reserveToToken, reserveFromToken) = UniswapV2Library.getReserves(
                uniV2Factory,
                _fromToken,
                _toToken
            );

        return
            UniswapV2Library.getAmountIn(
                _amount,
                reserveFromToken,
                reserveToToken
            );
    }
}
