// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "./ISequencerInfo.sol";
import "./ILockingInfo.sol";

interface ILockingPool is ISequencerInfo {
    /**
     * @dev Emitted when WITHDRAWAL_DELAY is updated.
     * @param _cur current withdraw delay time
     * @param _prev previours withdraw delay time
     */
    event WithrawDelayTimeChange(uint256 _cur, uint256 _prev);

    /**
     * @dev Emitted when the proxy update threshold in 'updateBlockReward()'.
     *      Note from maintainer:
     *      for compatibility, this ambiguous event is retained
     * @param newReward new block reward
     * @param oldReward  old block reward
     */
    event RewardUpdate(uint256 newReward, uint256 oldReward);

    /**
     * @dev Emitted when mpc address update in 'UpdateMpc'
     * @param _newMpc new min lock.
     */
    event UpdateMpc(address _newMpc);

    /**
     * @dev Emitted when SignerUpdateThrottle is updated
     * @param _n new min value
     */
    event SetSignerUpdateThrottle(uint256 _n);

    /**
     * @dev Emitted when rewards are distributed
     * @param batchId the current batch id
     * @param startEpoch start epoch number
     * @param endEpoch end epoch number
     * @param amount the total that distributed
     * @param rpb the current reward per block
     */
    event DistributeReward(
        uint256 indexed batchId,
        uint256 startEpoch,
        uint256 endEpoch,
        uint256 amount,
        uint256 rpb
    );

    function lockFor(
        address _signer,
        uint256 _amount,
        bytes calldata _signerPubkey
    ) external;

    function lockWithRewardRecipient(
        address _signer,
        address _rewardRecipient,
        uint256 _amount,
        bytes calldata _signerPubkey
    ) external;

    function relock(
        uint256 _seqId,
        uint256 _amount,
        bool _lockReward
    ) external;

    function withdrawRewards(
        uint256 _seqId,
        uint32 _l2Gas
    ) payable external;

    function withdraw(
        uint256 _seqId,
        uint256 _amount
    ) external;

    function escrow() external returns (address);
}