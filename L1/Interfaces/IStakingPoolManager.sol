// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IStakingPoolManager {
    event PoolAdded(address indexed _pool);
    event PoolRemoved(address indexed _pool);
    event SequencerBound(
        address indexed _pool,
        address indexed _signer,
        uint256 _amount,
        bytes _signerPubKey
    );
    event StakingAmountIncreased(address indexed _pool, uint256 _amount);
    event StakingAmountWithdrawn(
        address indexed _pool,
        address indexed _recipient,
        uint256 _amount
    );
    event SequencerUnboundInitialize(address indexed _pool);
    event SequencerUnboundFinalize(address indexed _pool);

    function addPool(address _pool) external;

    function bindSequencerFor(
        address _pool,
        address _signer,
        bytes calldata _signerPubKey
    ) external;

    function unlockSequencerInitialize(address _pool, uint32 _l2Gas) external payable;

    function unlockSequencerFinalize(address _pool, uint32 _l2Gas) external payable;

    function removePool(address _pool) external;

    function stake(address _pool, uint256 _amount) external;

    function withdraw(
        address _pool,
        address _recipient,
        uint256 _amount
    ) external;

    function withdrawToManager(address _pool, uint256 _amount) external;

    function claimRewards(uint32 _l2GasLimit) external payable;
}
