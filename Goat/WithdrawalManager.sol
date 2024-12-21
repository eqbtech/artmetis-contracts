// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";
import "./Interfaces/IGoatConfig.sol";
import "./Interfaces/IWithdrawalManager.sol";
import "./Utils/Constants.sol";
import "../Utils/DoubleEndedQueue.sol";
import "./Interfaces/IDepositPool.sol";
import "./Interfaces/IWithdrawalRecipient.sol";

contract WithdrawalManager is IWithdrawalManager, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;
    using TransferHelper for address;

    address public token;
    IDepositPool public depositPool;
    address public withdrawalRecipient;
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

    function initialize(
        address _owner,
        address _token,
        address _depositPool,
        address _withdrawalRecipient
    ) public initializer {
        __AccessControl_init();

        require(_owner != address(0), "WithdrawalManager: INVALID_OWNER");
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(Constants.ADMIN_ROLE, _owner);
        require(_token != address(0), "WithdrawalManager: INVALID_TOKEN");
        require(
            _depositPool != address(0),
            "WithdrawalManager: INVALID_DEPOSIT_POOL"
        );
        require(
            _withdrawalRecipient != address(0),
            "WithdrawalManager: INVALID_WITHDRAWAL_RECIPIENT"
        );
        depositPool = IDepositPool(_depositPool);
        withdrawalRecipient = _withdrawalRecipient;
        token = _token;
        withdrawDelay = 14 days;
        emit WithdrawDelaySet(msg.sender, withdrawDelay);
    }

    function setWithdrawDelay(
        uint256 _withdrawDelay
    ) external onlyRole(Constants.ADMIN_ROLE) {
        withdrawDelay = _withdrawDelay;
        emit WithdrawDelaySet(msg.sender, _withdrawDelay);
    }

    function getUserWithdrawRequest(
        address _user,
        uint256 _userIndex
    ) external view returns (WithdrawRequest memory) {
        require(
            _userIndex < userWithdrawRequestsNonce[_user].length(),
            "WithdrawalManager: INVALID_INDEX"
        );
        return
            withdrawRequests[userWithdrawRequestsNonce[_user].at(_userIndex)];
    }

    function getUserWithdrawRequestLength(
        address _user
    ) external view returns (uint256) {
        return userWithdrawRequestsNonce[_user].length();
    }

    function initiateWithdrawal(address _pool, uint256 _artAmount) external {
        require(_artAmount > 0, "WithdrawalManager: INVALID_AMOUNT");

        uint256 _expectedAmount = depositPool.initiateWithdrawalFor(
            _pool,
            msg.sender,
            _artAmount
        );

        withdrawRequests[nextWithdrawNonce] = WithdrawRequest({
            artAmount: _artAmount,
            expectedAmount: _expectedAmount,
            startTime: block.timestamp,
            maturityTime: block.timestamp + withdrawDelay
        });

        emit WithdrawRequestInitiated(
            msg.sender,
            nextWithdrawNonce,
            _artAmount,
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
    ) external onlyRole(Constants.ADMIN_ROLE) {
        require(
            _firstExcludeNonce > nextUnlockNonce,
            "WithdrawalManager: invalid first exclude nonce"
        );
        uint256 _amount = calculateUnlockNonce(_firstExcludeNonce);
        IWithdrawalRecipient(withdrawalRecipient).withdraw(token, _amount);
        nextUnlockNonce = _firstExcludeNonce;
        emit NextUnlockNonceSet(nextUnlockNonce);
    }

    function calculateUnlockNonce(
        uint256 _firstExcludeNonce
    ) public view returns (uint256) {
        require(
            _firstExcludeNonce <= nextWithdrawNonce,
            "WithdrawalManager: INVALID_NONCE"
        );

        uint256 _amount = 0;
        for (uint256 i = nextUnlockNonce; i < _firstExcludeNonce; i++) {
            WithdrawRequest memory request = withdrawRequests[i];
            _amount += request.expectedAmount;
        }
        return _amount;
    }

    function completeWithdrawal() external {
        DoubleEndedQueue.Uint256Deque
            storage userWithdrawRequests = userWithdrawRequestsNonce[
                msg.sender
            ];
        require(
            userWithdrawRequests.length() > 0,
            "WithdrawalManager: no withdraw request"
        );

        uint256 _userFirstWithdrawNonce = userWithdrawRequests.popFront();
        require(
            _userFirstWithdrawNonce < nextUnlockNonce,
            "WithdrawalManager: withdraw request has not unlocked yet"
        );

        WithdrawRequest storage request = withdrawRequests[
            _userFirstWithdrawNonce
        ];
        require(
            request.maturityTime <= block.timestamp,
            "WithdrawalManager: withdraw request is not ready to complete"
        );

        uint256 _expectedAmount = request.expectedAmount;
        delete withdrawRequests[_userFirstWithdrawNonce];
        if (_expectedAmount > 0) {
            address(token).safeTransferToken(msg.sender, _expectedAmount);
        }
        emit WithdrawRequestCompleted(msg.sender, _userFirstWithdrawNonce);
    }

    receive() external payable {}
}
