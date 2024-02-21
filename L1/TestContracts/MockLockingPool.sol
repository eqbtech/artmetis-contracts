// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Interfaces/Metis/ILockingPool.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockLockingPool is ILockingPool {
    using SafeERC20 for IERC20;

    enum Status {Inactive, Active, Unlocked}  // Unlocked means sequencer exist

    struct MpcHistoryItem {
        uint256 startBlock;
        address newMpcAddress;
    }

    struct State {
        uint256 amount;
        uint256 lockerCount;
    }

    struct StateChange {
        int256 amount;
        int256 lockerCount;
    }

    struct Sequencer {
        uint256 amount;             // sequencer current lock amount
        uint256 reward;             // sequencer current reward
        uint256 activationBatch;    // sequencer activation batch id
        uint256 deactivationBatch;  // sequencer deactivation batch id
        uint256 deactivationTime;   // sequencer deactivation timestamp
        uint256 unlockClaimTime;    // sequencer unlock lock amount timestamp, has a withdraw delay time
        address signer;             // sequencer signer address
        address rewardRecipient;    // seqeuncer rewarder recipient address
        Status status;              // sequencer status
    }

    uint256 internal constant INCORRECT_SEQUENCER_ID = 2**256 - 1;

    address public bridge;     // L1 metis bridge address
    address public l1Token;    // L1 metis token address
    address public l2Token;    // L2 metis token address
    address public NFTContract;  // NFT for locker
    uint256 public WITHDRAWAL_DELAY;    // delay time for unlock
    uint256 public currentBatch;    // current batch id
    uint256 public totalLocked;     // total locked amount of all sequencers
    uint256 public counter;      // current count
    uint256 public totalRewardsLiquidated; // total rewards had been liquidated
    uint256 public currentUnlockedInit; // sequencer unlock queue count, need have a limit
    uint256 public lastRewardEpochId; // the last epochId for update reward
    uint256 public lastRewardTime; // the last reward time for update reward

    // genesis variables
    uint256 public perSecondReward; // reward per second
    uint256 public minLock; // min lock Metis token
    uint256 public maxLock; // max lock Metis token
    uint256 public signerUpdateLimit; // sequencer signer need have a update limit,how many batches are not allowed to update the signer
    address public mpcAddress; // current mpc address for batch submit reward
    uint256 public sequencerThreshold; // maximum sequencer limit

    mapping(uint256 => Sequencer) public sequencers;
    mapping(address => uint256) public signerToSequencer;
    mapping(uint256 => bool) public batchSubmitHistory;   // batch submit

    // current Batch lock power and lockers count
    State public sequencerState;
    mapping(uint256 => StateChange) public sequencerStateChanges;

    // sequencerId to last signer update Batch
    mapping(uint256 => uint256) public latestSignerUpdateBatch;

    // white address list who can lock token
    mapping(address => bool) public whiteListAddresses;
    // A whitelist address can only be bound to one sequencer
    mapping(address => address) public whiteListBoundSequencer;

    // mpc history
    MpcHistoryItem[] public mpcHistory; // recent mpc

    constructor(
        address _l1Token
    ) {
        require(_l1Token != address(0),"invalid _l1Token");

        l1Token = _l1Token;

        WITHDRAWAL_DELAY = 21 days; // sequencer exit withdraw delay time
        currentBatch = 1;  // default start from batch 1
        perSecondReward = 1 * (10**8); // per second reward
        minLock = 20000* (10**18);  // min lock amount
        maxLock = 100000 * (10**18); // max lock amount
        signerUpdateLimit = 10; // how many batches are not allowed to update the signer
        sequencerThreshold = 10; // allow max sequencers
        counter = 1; // sequencer id
    }

    /**
        Admin Methods
     */

    /**
     * @dev forceUnlock Allow owner to force a sequencer node to exit
     * @param sequencerId unique integer to identify a sequencer.
     * @param l2Gas bridge reward to L2 gasLimit
     */
    function forceUnlock(uint256 sequencerId,uint32 l2Gas) external {
    }

    /**
    * @dev setWhiteListAddress Allow owner to update white address list
     * @param user the address who can lock token
     * @param verified white address state
     */
    function setWhiteListAddress(address user, bool verified) external {
        require(whiteListAddresses[user] != verified, "state not change");
        whiteListAddresses[user] = verified;
    }

    /**
    * @dev lockFor is used to lock Metis and participate in the sequencer block node application
     * @param user sequencer signer address
     * @param amount Amount of L1 metis token to lock for.
     * @param signerPubkey sequencer signer pubkey
     */
    function lockFor(
        address user,
        uint256 amount,
        bytes memory signerPubkey
    ) override external {
        require(whiteListAddresses[msg.sender],"msg sender should be in the white list");
        require(amount >= minLock, "amount less than minLock");
        require(amount <= maxLock, "amount large than maxLock");
        require(whiteListBoundSequencer[msg.sender] == address(0), "had bound sequencer");

        _lockFor(user, amount, signerPubkey);
        whiteListBoundSequencer[msg.sender] = user;
        _transferTokenFrom(msg.sender, address(this), amount);
    }


    /**
    * @dev unlock is used to unlock Metis and exit the sequencer node
     *
     * @param sequencerId sequencer id
     * @param l2Gas bridge reward to L2 gasLimit
     */
    function unlock(uint256 sequencerId, uint32 l2Gas) override external payable {
    }


    /**
    * @dev unlockClaim Because unlock has a waiting period, after the waiting period is over, you can claim locked tokens
     *
     * @param sequencerId sequencer id
     * @param l2Gas bridge reward to L2 gasLimit
     */
    function unlockClaim(uint256 sequencerId, uint32 l2Gas) override external payable {
    }

    /**
     * @dev relock Allow sequencer to increase the amount of locked positions
     * @param sequencerId unique integer to identify a sequencer.
     * @param amount Amount of L1 metis token to relock for.
     * @param lockRewards Whether to lock the current rewards
     */
    function relock(
        uint256 sequencerId,
        uint256 amount,
        bool lockRewards
    ) override external {
        require(sequencers[sequencerId].amount > 0,"invalid sequencer locked amount");
        require(sequencers[sequencerId].deactivationBatch == 0, "no relocking");
        require(whiteListAddresses[msg.sender],"msg sender should be in the white list");
        require(whiteListBoundSequencer[msg.sender] == sequencers[sequencerId].signer,"whiteAddress and boundSequencer mismatch");

        uint256 relockAmount = amount;

        if (lockRewards) {
            amount = amount + sequencers[sequencerId].reward;
            sequencers[sequencerId].reward = 0;
        }
        require(amount > 0,"invalid relock amount");

        totalLocked = totalLocked + amount;
        sequencers[sequencerId].amount = sequencers[sequencerId].amount + amount;
        require(sequencers[sequencerId].amount <= maxLock, "amount large than maxLock");

        _transferTokenFrom(msg.sender, address(this), relockAmount);
    }

    /**
     * @dev withdrawRewards withdraw current rewards
     *
     * @param sequencerId unique integer to identify a sequencer.
     * @param l2Gas bridge reward to L2 gasLimit
     */
    function withdrawRewards(uint256 sequencerId, uint32 l2Gas) override external payable {
        require(whiteListAddresses[msg.sender],"msg sender should be in the white list");
        require(whiteListBoundSequencer[msg.sender] == sequencers[sequencerId].signer,"whiteAddress and boundSequencer mismatch");

        Sequencer storage sequencerInfo = sequencers[sequencerId];
        _liquidateRewards(sequencerId, sequencerInfo.rewardRecipient, l2Gas);
    }

    /**
     * @dev batchSubmitRewards Allow to submit L2 sequencer block information, and attach Metis reward tokens for reward distribution
     * @param batchId The batchId that submitted the reward is that
     * @param payeer Who Pays the Reward Tokens
     * @param startEpoch The startEpoch that submitted the reward is that
     * @param endEpoch The endEpoch that submitted the reward is that
     * @param _sequencers Those sequencers can receive rewards
     * @param finishedBlocks How many blocks each sequencer finished.
     * @param signature Confirmed by mpc and signed for reward distribution
     */
    function batchSubmitRewards(
        uint256 batchId,
        address payeer,
        uint256 startEpoch,
        uint256 endEpoch,
        address[] memory _sequencers,
        uint256[] memory finishedBlocks,
        bytes memory signature
    )  external payable returns (uint256) {
        require(_sequencers.length == finishedBlocks.length, "mismatch length");
        require(batchId >= 0, "invalid batchId");
        require(startEpoch >= 0, "invalid startEpoch");
        require(endEpoch >= 0, "invalid endEpoch");
        require(signature.length >= 0, "invalid signature");

        // mock earn reward
        uint256 totalReward = 1e22;

        // calc total finished blocks
        uint256 totalFinishedBlocks;
        for (uint256 i = 0; i < finishedBlocks.length;) {
            unchecked{
                totalFinishedBlocks += finishedBlocks[i];
                ++i;
            }
        }

        // distribute reward
        for (uint256 i = 0; i < _sequencers.length;) {
            require(signerToSequencer[_sequencers[i]] > 0,"sequencer not exist");

            uint256 reward = _calculateReward(totalReward,totalFinishedBlocks,finishedBlocks[i]);
            _increaseReward(_sequencers[i],reward);

            unchecked{
                ++i;
            }
        }

        // reward income
        IERC20(l1Token).safeTransferFrom(payeer, address(this), totalReward);
        return totalReward;
    }

    /**
     * @dev setSequencerRewardRecipient Allow sequencer owner to set a reward recipient
     * @param sequencerId The sequencerId
     * @param recipient Who will receive the reward token
     */
    function setSequencerRewardRecipient(
        uint256 sequencerId,
        address recipient
    )  external {
        require(whiteListAddresses[msg.sender],"msg sender should be in the white list");
        require(whiteListBoundSequencer[msg.sender] == sequencers[sequencerId].signer,"whiteAddress and boundSequencer mismatch");
        require(recipient != address(0), "invalid recipient");

        Sequencer storage sequencerInfo = sequencers[sequencerId];
        sequencerInfo.rewardRecipient = recipient;
    }

    // query owenr by NFT token id
    function ownerOf(uint256 tokenId) override external pure returns (address) {
        require(tokenId >= 0, "invalid tokenId");
        return address(0);
    }

    // query current lock amount by sequencer id
    function sequencerLock(uint256 sequencerId) override external view returns (uint256) {
        return sequencers[sequencerId].amount;
    }

    // get sequencer id by address
    function getSequencerId(address user) override external view returns (uint256) {
        return signerToSequencer[user];
    }

    //  get sequencer reward by sequencer id
    function sequencerReward(uint256 sequencerId) override external view returns (uint256) {
        return sequencers[sequencerId].reward ;
    }

    // get total lock amount for all sequencers
    function currentSequencerSetTotalLock() override external pure returns (uint256) {
        return 0;
    }

    /**
      * @dev fetchMpcAddress query mpc address by L1 block height, used by batch-submitter
      * @param blockHeight the L1 block height
      */
    function fetchMpcAddress(uint256 blockHeight) override external pure returns(address){
        require(blockHeight >= 0, "invalid blockHeight");
        return address(0);
    }



    /*
    * @dev getL2ChainId return the l2 chain id
    * @param l1ChainId the L1 chain id
    */
    function getL2ChainId(uint256 l1ChainId) override public pure returns(uint256) {
        if (l1ChainId == 1) {
            return 1088;
        }
        return 59901;
    }

    // get all sequencer count
    function currentSequencerSetSize() override public pure returns (uint256) {
        return 0;
    }

    function _lockFor(
        address user,
        uint256 amount,
        bytes memory signerPubkey
    ) internal returns (uint256) {
        require(signerPubkey.length >= 0, "invalid signer pubkey");
        address signer = user;

        uint256 sequencerId = counter;
        totalLocked += amount;

        sequencers[sequencerId] = Sequencer({
            reward: 0,
            amount: amount,
            activationBatch: 0,
            deactivationBatch: 0,
            deactivationTime: 0,
            unlockClaimTime: 0,
            signer: signer,
            rewardRecipient: address(0),
            status: Status.Active
        });

        signerToSequencer[signer] = sequencerId;
        counter = sequencerId + 1;

        return sequencerId;
    }

    // The function restricts the sequencer's exit if the number of total locked sequencers divided by 3 is less than the number of
    // sequencers that have already exited. This would effectively freeze the sequencer's unlock function until a sufficient number of
    // new sequencers join the system.
    function _unlock(uint256 sequencerId, uint256 exitBatch,bool force,uint32 l2Gas) internal {
    }

    function isContract(address _target) internal view returns (bool) {
        if (_target == address(0)) {
            return false;
        }

        uint256 size;
        assembly {
            size := extcodesize(_target)
        }
        return size > 0;
    }

    function _calculateReward(
        uint256 totalRewards,
        uint256 totalBlocks,
        uint256 finishedBlocks
    ) internal pure returns (uint256) {
        // rewards are based on BlockInterval multiplied on `perSecondReward`
        return totalRewards * finishedBlocks / totalBlocks;
    }


    /**
        Private Methods
     */

    function _increaseReward(
        address sequencer,
        uint256 reward
    ) private  {
        uint256 sequencerId = signerToSequencer[sequencer];
        // update reward
        sequencers[sequencerId].reward +=  reward;
    }

    function _liquidateRewards(uint256 sequencerId, address recipient, uint32 l2Gas) private {
        require(recipient != address(0), "invalid reward recipient");
        require(l2Gas >= 0, "invalid l2Gas");
        uint256 reward = sequencers[sequencerId].reward ;
        totalRewardsLiquidated = totalRewardsLiquidated + reward;
        sequencers[sequencerId].reward = 0;

        // mock withdraw reward to L2
        _transferToken(recipient, reward);
    }

    function _transferToken(address destination, uint256 amount) private {
        IERC20(l1Token).safeTransfer(destination, amount);
    }

    function _transferTokenFrom(
        address from,
        address destination,
        uint256 amount
    ) private {
        IERC20(l1Token).safeTransferFrom(from, destination, amount);
    }
}
