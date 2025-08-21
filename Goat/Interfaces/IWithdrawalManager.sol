// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IWithdrawalManager {
    function initialize(
        address _owner,
        address _token,
        address _depositPool,
        address _withdrawalRecipient
    ) external;

    function setWithdrawDelay(uint256 _withdrawDelay) external;

    function getUserWithdrawRequest(
        address _user,
        uint256 _userIndex
    ) external view returns (WithdrawRequest memory);

    function getUserWithdrawRequestLength(
        address _user
    ) external view returns (uint256);

    function initiateWithdrawal(
        address _pool,
        uint256 _artMetisAmount
    ) external;

    function unlockWithdrawal(uint256 _firstExcludeNonce) external;

    function calculateUnlockNonce(
        uint256 _firstExcludeNonce
    ) external view returns (uint256);

    function completeWithdrawal() external;

    event WithdrawDelaySet(address indexed _user, uint256 _withdrawDelay);
    event WithdrawRequestInitiated(
        address indexed _user,
        uint256 _nonce,
        uint256 _artAmount,
        uint256 _expectedAmount
    );
    event WithdrawRequestCompleted(address indexed _user, uint256 _nonce);
    event NextWithdrawNonceSet(uint256 _nextWithdrawNonce);
    event NextUnlockNonceSet(uint256 _nextUnlockNonce);
    event UserWithdrawRequestQueued(
        address indexed _user,
        WithdrawRequest _withdrawRequest
    );

    struct WithdrawRequest {
        uint256 artAmount;
        uint256 expectedAmount;
        uint256 startTime;
        uint256 maturityTime;
    }
}
