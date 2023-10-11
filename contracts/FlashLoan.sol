// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./libraries/SafeERC20.sol";

contract FlashLoan {
    using SafeERC20 for IERC20;

    //pancakeswap factory and router addresses
    address private constant PANCAKESWAP_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address private constant PANCAKESWAP_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    //token addresses
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address private constant CROX = 0x2c094F5A7D1146BB93850f629501eB749f6Ed491;

    uint256 private deadline = block.timestamp + 1 days;
    uint256 private constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    function checkResult(uint256 _repayAmount, uint256 _finalTrade) private pure returns(bool) {
        return _finalTrade > _repayAmount;
    }

    function getBalanceOfToken(address _token) public view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function placeTrade(address _from, address _to, uint256 _amount) private returns(uint256) {
        address liquidity_pool = IUniswapV2Factory(PANCAKESWAP_FACTORY).getPair(_from, _to);
        require(liquidity_pool != address(0), "Liquidity pool does not exist.");
        
        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = _to;

        uint256 amountRequired = IUniswapV2Router01(PANCAKESWAP_ROUTER).getAmountsOut(_amount, path)[1];
        uint256 amountReceived = IUniswapV2Router01(PANCAKESWAP_ROUTER)
                                    .swapExactTokensForTokens(
                                        _amount,
                                        amountRequired,
                                        path,
                                        address(this),
                                        deadline
                                    )[1];

        require(amountReceived > 0, "Transaction aborted.");
        return amountReceived;    
    }

    function initiateArbitrage(address _tokenBorrow, uint256 _amount) external {
        IERC20(_tokenBorrow).safeApprove(PANCAKESWAP_ROUTER, MAX_INT);
        IERC20(CROX).safeApprove(PANCAKESWAP_ROUTER, MAX_INT);
        IERC20(CAKE).safeApprove(PANCAKESWAP_ROUTER, MAX_INT);

        address liquidity_pool = IUniswapV2Factory(PANCAKESWAP_FACTORY).getPair(_tokenBorrow, WBNB);
        require(liquidity_pool != address(0), "Liquidity pool does not exist.");

        address token0 = IUniswapV2Pair(liquidity_pool).token0();
        address token1 = IUniswapV2Pair(liquidity_pool).token1();

        uint256 amount0Out = _tokenBorrow==token0?_amount:0; 
        uint256 amount1Out = _tokenBorrow==token1?_amount:0;

        bytes memory data = abi.encode(_tokenBorrow, _amount, msg.sender);
        IUniswapV2Pair(liquidity_pool).swap(amount0Out, amount1Out, address(this), data);
    }

    function pancakeCall(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        address liquidity_pool = IUniswapV2Factory(PANCAKESWAP_FACTORY).getPair(token0, token1);
        require(msg.sender == liquidity_pool, "Liquidity pool does not match.");
        require(_sender == address(this), "_sender  does not match.");

        (address tokenBorrow, uint256 amount, address myAccount) = abi.decode(_data, (address, uint256, address));

        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 repayAmount = amount + fee;
        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;

        //triangular arbitrage
        uint256 trade1 = placeTrade(tokenBorrow, CROX, loanAmount);
        uint256 trade2 = placeTrade(CROX, CAKE, trade1);
        uint256 trade3 = placeTrade(CAKE, tokenBorrow, trade2);

        bool isProfitable = checkResult(repayAmount, trade3);
        require(isProfitable, "Arbitrage is not profitable.");

        uint256 profit = trade3 - repayAmount;
        IERC20(tokenBorrow).safeTransfer(myAccount, profit);
        IERC20(tokenBorrow).safeTransfer(liquidity_pool, repayAmount);
    }
}