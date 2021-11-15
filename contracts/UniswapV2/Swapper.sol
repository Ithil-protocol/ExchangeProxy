// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../interfaces/Uniswap/IUniswapV2.sol";
import "../libraries/Uniswap/UniswapV2Library.sol";

contract UniswapV2 is IUniswapV2 {
    using SafeERC20 for IERC20;

    address internal uniV2Factory; // TODO should it be immutable?
    
    constructor(address _uniV2Factory) {
        uniV2Factory = _uniV2Factory;
    }

    function _estimateMaxSwapUniswapV2(
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

    function _estimateMinSwapUniswapV2(
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

    function _maxSwapUniswapV2(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint24 _slippage,
        address _recipient
    ) public override returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = _fromToken; // tokenIn
        path[1] = _toToken; // tokenOut

        uint256[] memory amounts = UniswapV2Library.getAmountsOut(
            uniV2Factory,
            _amount,
            path
        );

        uint256 expectedAmountToReceive = _estimateMaxSwapUniswapV2(
            _fromToken,
            _toToken,
            _amount
        );
        require(
            amounts[amounts.length - 1] >= expectedAmountToReceive,
            "Too little received"
        );

        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            UniswapV2Library.pairFor(uniV2Factory, path[0], path[1]),
            amounts[0]
        );

        _swap(amounts, path, _recipient);

        return amounts[0]; /// @todo check it, could be 1
    }

    function _minSwapUniswapV2(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint24 _slippage,
        address _recipient
    ) public override returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = _fromToken; // tokenIn
        path[1] = _toToken; // tokenOut

        uint256[] memory amounts = UniswapV2Library.getAmountsIn(
            uniV2Factory,
            _amount,
            path
        );

        uint256 expectedAmountToGive = _estimateMinSwapUniswapV2(
            _fromToken,
            _toToken,
            _amount
        );
        require(amounts[0] <= expectedAmountToGive, "Too much requested");

        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            UniswapV2Library.pairFor(uniV2Factory, path[0], path[1]),
            amounts[0]
        );

        _swap(amounts, path, _recipient);

        return amounts[0]; /// @todo check it, could be 1
    }

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal {
        for (uint256 i = 0; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = UniswapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? UniswapV2Library.pairFor(uniV2Factory, output, path[i + 2])
                : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(uniV2Factory, input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
}
