// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/UniswapV2Library.sol";

contract FlashLoan {
    using SafeERC20 for IERC20;
    //pancakeswap factory and router addresses
    address private constant PANCAKESWAP_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address private constant PANCAKESWAP_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;


    //token addresses
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address private constant CROX = 0x2c094F5A7D1146BB93850f629501eB749f6Ed491;

    uint256 private deadline = block.timestamp + 1 days;
    uint256 private constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    function initiateArbitrage(address _busdBorrow, uint256 _amount) public {
        IERC20(BUSD).safeApprove(PANCAKESWAP_ROUTER, MAX_INT);
        IERC20(CROX).safeApprove(PANCAKESWAP_ROUTER, MAX_INT);
        IERC20(CAKE).safeApprove(PANCAKESWAP_ROUTER, MAX_INT);

        address liquidity_pool = IUniswapV2Factory(PANCAKESWAP_FACTORY).getPair(_busdBorrow, WBNB);
        require(liquidity_pool != address(0), "Liquidity pool does not exist.");

        address token0 = IUniswapV2Pair(liquidity_pool).token0();
        address token1 = IUniswapV2Pair(liquidity_pool).token1();

        uint256 amount0Out = _busdBorrow==token0?_amount:0; 
        uint256 amount1Out = _busdBorrow==token1?_amount:0;

        bytes memory data = abi.encode(_busdBorrow, _amount);
        IUniswapV2Pair(liquidity_pool).swap(amount0Out, amount1Out, address(this), data);
    }

}