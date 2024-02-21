// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "./Interfaces/IAMTRewardPool.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./Utils/AMTConstants.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";
import "./Interfaces/IAMTConfig.sol";

contract AMTRewardPool is IAMTRewardPool, AccessControlUpgradeable {
    IAMTConfig public config;
    address public feeReceiver;
    uint256 public feeRate;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _config, address _feeReceiver, uint256 _feeRate) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AMTConstants.ADMIN_ROLE, msg.sender);
        config = IAMTConfig(_config);
        feeReceiver = _feeReceiver;
        feeRate = _feeRate;
    }

    function setFeeReceiver(
        address _feeReceiver
    ) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(_feeReceiver != address(0), "invalid _feeReceiver!");
        require(feeReceiver != _feeReceiver, "_feeReceiver already set!");

        feeReceiver = _feeReceiver;
        emit FeeReceiverSet(_feeReceiver);
    }

    function setFeeRate(
        uint256 _feeRate
    ) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(_feeRate >= 0 && _feeRate <= 1e18, "invalid _feeRate!");

        feeRate = _feeRate;
        emit FeeRateSet(_feeRate);
    }

    function claimReward() onlyDepositPool external returns (uint256) {
        uint256 balance = address(this).balance;
        uint256 feeAmount = balance * feeRate / 1e18;
        uint256 reward = balance - feeAmount;

        if (feeAmount > 0) {
            TransferHelper.safeTransferETH(feeReceiver, feeAmount);
            emit FeeSent(feeReceiver, feeAmount);
        }

        if (reward > 0) {
            TransferHelper.safeTransferETH(config.getContract(AMTConstants.AMT_DEPOSIT_POOL), reward);
            emit RewardClaimed(msg.sender, reward);
        }

        return reward;
    }

    modifier onlyDepositPool() {
        address _depositPool = config.getContract(AMTConstants.AMT_DEPOSIT_POOL);
        require(_depositPool != address(0), "AMTRewardPool: INVALID_DEPOSIT_POOL");
        require(msg.sender == _depositPool, "AMTRewardPool: ONLY_DEPOSIT_POOL");
        _;
    }

    receive() external payable {}
}
