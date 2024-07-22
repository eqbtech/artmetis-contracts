// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IStakingPoolManager {
    event PoolAdded(address indexed _pool);
    event PoolRemoved(address indexed _pool);
    event SequencerBound(address indexed _pool, address indexed _signer, uint256 _amount, bytes _signerPubKey);
    event StakingAmountIncreased(address indexed _pool, uint256 _amount);
    event StakingAmountWithdrawn(address indexed _pool, address indexed _recipient, uint256 _amount);

    function addPool(address _pool) external;

    function bindSequencerFor(address _pool, address _signer, bytes calldata _signerPubKey) external;

    function removePool(address _pool) external;

    function stake(address _pool, uint256 _amount) external;

    function withdraw(address _pool, address _recipient, uint256 _amount) external;

    function claimRewards(uint32 _l2GasLimit) external payable;
}