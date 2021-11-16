// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./TickMath.sol";
import "./FullMath.sol";

library UniswapV3Math {
    function computeMax0Swap(
        uint160 sqrtPrice1,
        uint160 sqrtPrice2,
        uint128 liquidity
    ) internal pure returns (uint256 maxSwap) {
        if (sqrtPrice1 > sqrtPrice2)
            (sqrtPrice1, sqrtPrice2) = (sqrtPrice2, sqrtPrice1);

        uint256 numerator2 = sqrtPrice2 - sqrtPrice1;
        uint256 factor1 = FullMath.mulDiv(liquidity, 1 << 96, sqrtPrice2);

        require(sqrtPrice1 > 0);

        maxSwap = FullMath.mulDiv(factor1, numerator2, sqrtPrice1);
    }

    function computeMax1Swap(
        uint160 sqrtPrice1,
        uint160 sqrtPrice2,
        uint128 liquidity
    ) internal pure returns (uint256 maxSwap) {
        if (sqrtPrice1 > sqrtPrice2)
            (sqrtPrice1, sqrtPrice2) = (sqrtPrice2, sqrtPrice1);

        return FullMath.mulDiv(liquidity, sqrtPrice2 - sqrtPrice1, 1 << 96);
    }

    function computeSwapWithinTick(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint160 _sqrtRatioX96,
        uint128 _liquidity,
        uint24 _fee
    ) internal pure returns (uint256 obtained) {
        uint256 delta = (_amount * (1000000 - _fee)) / 1000000;

        if (_fromToken < _toToken) {
            uint256 denom_change = FullMath.mulDiv(
                _sqrtRatioX96,
                delta,
                1 << 96
            );
            uint160 newSqrPrice = uint160(
                FullMath.mulDiv(
                    _liquidity,
                    _sqrtRatioX96,
                    _liquidity + denom_change
                )
            );
            obtained = FullMath.mulDiv(
                _sqrtRatioX96 - newSqrPrice,
                _liquidity,
                1 << 96
            );
        } else {
            uint160 newSqrPrice = _sqrtRatioX96 +
                uint160(FullMath.mulDiv(delta, 1 << 96, _liquidity));
            uint256 sum1 = FullMath.mulDiv(_liquidity, 1 << 96, _sqrtRatioX96);
            uint256 sum2 = FullMath.mulDiv(_liquidity, 1 << 96, newSqrPrice);
            obtained = sum1 - sum2;
        }
    }
}
