// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";
import "./Interfaces/IAMTWithdrawalManager.sol";
import "./Utils/DoubleEndedQueue.sol";
import "./Utils/AMTConstants.sol";
import "./Interfaces/IAMTConfig.sol";
import "./Interfaces/IAMTDepositPool.sol";
import "./Interfaces/IArtMetis.sol";

contract AMTWithdrawalManager is
    IAMTWithdrawalManager,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;
    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;

    IAMTConfig public config;
    uint256 public nextWithdrawNonce;
    uint256 public nextUnlockNonce;
    uint256 public withdrawDelay;
    mapping(uint256 => WithdrawRequest) public withdrawRequests;
    mapping(address => DoubleEndedQueue.Uint256Deque)
        public userWithdrawRequestsNonce;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _config) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AMTConstants.ADMIN_ROLE, msg.sender);

        config = IAMTConfig(_config);
        withdrawDelay = 14 days;
        emit WithdrawDelaySet(msg.sender, withdrawDelay);
    }

    function setWithdrawDelay(
        uint256 _withdrawDelay
    ) external onlyRole(AMTConstants.ADMIN_ROLE) {
        withdrawDelay = _withdrawDelay;
        emit WithdrawDelaySet(msg.sender, _withdrawDelay);
    }

    function getUserWithdrawRequest(
        address _user,
        uint256 _userIndex
    ) external view returns (WithdrawRequest memory) {
        require(
            _userIndex < userWithdrawRequestsNonce[_user].length(),
            "AMTWithdrawalManager: INVALID_INDEX"
        );
        return
            withdrawRequests[userWithdrawRequestsNonce[_user].at(_userIndex)];
    }

    function getUserWithdrawRequestLength(address _user) external view returns (uint256) {
        return userWithdrawRequestsNonce[_user].length();
    }

    function initiateWithdrawal(uint256 _artMetisAmount) external {
        require(_artMetisAmount > 0, "AMTWithdrawalManager: INVALID_AMOUNT");
        IAMTDepositPool depositPool = IAMTDepositPool(
            config.getContract(AMTConstants.AMT_DEPOSIT_POOL)
        );
        uint256 _expectedAmount = (_artMetisAmount * 1e18) /
            depositPool.getArtMetisAmountToMint(1e18);

        depositPool.initiateWithdrawalFor(
            msg.sender,
            _artMetisAmount,
            _expectedAmount
        );

        withdrawRequests[nextWithdrawNonce] = WithdrawRequest({
            artMetisAmount: _artMetisAmount,
            expectedAmount: _expectedAmount,
            startTime: block.timestamp
        });

        emit WithdrawRequestInitiated(
            msg.sender,
            nextWithdrawNonce,
            _artMetisAmount,
            _expectedAmount
        );

        userWithdrawRequestsNonce[msg.sender].pushBack(nextWithdrawNonce);
        emit UserWithdrawRequestQueued(
            msg.sender,
            withdrawRequests[nextWithdrawNonce]
        );

        nextWithdrawNonce++;
        emit NextWithdrawNonceSet(nextWithdrawNonce);
    }

    function unlockWithdrawal(
        uint256 _firstExcludeNonce
    ) external onlyRole(AMTConstants.ADMIN_ROLE) {
        require(_firstExcludeNonce > nextUnlockNonce, "AMTWithdrawalManager: invalid first exclude nonce");
        uint256 _metisAmount = calculateUnlockNonce(_firstExcludeNonce);
        IAMTDepositPool depositPool = IAMTDepositPool(
            config.getContract(AMTConstants.AMT_DEPOSIT_POOL)
        );
        depositPool.adminWithdrawMetis(_metisAmount);
        nextUnlockNonce = _firstExcludeNonce;
        emit NextUnlockNonceSet(nextUnlockNonce);
    }

    function calculateUnlockNonce(
        uint256 _firstExcludeNonce
    ) public view returns (uint256) {
        require(
            _firstExcludeNonce <= nextWithdrawNonce,
            "AMTWithdrawalManager: INVALID_NONCE"
        );

        uint256 _metisAmount = 0;
        for (uint256 i = nextUnlockNonce; i < _firstExcludeNonce; i++) {
            WithdrawRequest memory request = withdrawRequests[i];
            _metisAmount += request.expectedAmount;
        }
        return _metisAmount;
    }

    function completeWithdrawal() external {
        DoubleEndedQueue.Uint256Deque
            storage userWithdrawRequests = userWithdrawRequestsNonce[
                msg.sender
            ];
        require(
            userWithdrawRequests.length() > 0,
            "AMTWithdrawalManager: no withdraw request"
        );

        uint256 _userFirstWithdrawNonce = userWithdrawRequests.popFront();
        require(
            _userFirstWithdrawNonce < nextUnlockNonce,
            "AMTWithdrawalManager: withdraw request has not unlocked yet"
        );

        WithdrawRequest storage request = withdrawRequests[
            _userFirstWithdrawNonce
        ];
        require(
            request.startTime + withdrawDelay <= block.timestamp,
            "AMTWithdrawalManager: withdraw request is not ready to complete"
        );

        uint256 _expectedAmount = request.expectedAmount;
        delete withdrawRequests[_userFirstWithdrawNonce];
        TransferHelper.safeTransferETH(msg.sender, _expectedAmount);
        emit WithdrawRequestCompleted(msg.sender, _userFirstWithdrawNonce);
    }

    receive() external payable {}
}
