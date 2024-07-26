// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Interfaces/Metis/ILockingPool.sol";
import "./Interfaces/Metis/ILockingInfo.sol";
import "./Interfaces/Metis/IL1ERC20Bridge.sol";
import "./Interfaces/IStakingPool.sol";
import "../Utils/AMTConstants.sol";

contract StakingPool is IStakingPool, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    ILockingInfo public lockingInfo;
    ILockingPool public lockingPool;
    address public l1Token;
    address public stakingPoolManager;
    address public rewardRecipient;

    address public signer;
    uint256 public sequencerId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _lockingPool,
        address _l1Token,
        address _rewardRecipient,
        address _stakingPoolManager
    ) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(AMTConstants.ADMIN_ROLE, _owner);

        require(
            _lockingPool != address(0),
            "StakingPool: invalid locking pool"
        );
        require(_l1Token != address(0), "StakingPool: invalid l1 token");
        require(
            _stakingPoolManager != address(0),
            "StakingPool: invalid staking pool manager"
        );
        require(
            _rewardRecipient != address(0),
            "StakingPool: invalid reward recipient"
        );

        lockingPool = ILockingPool(_lockingPool);
        address _lockingInfo = lockingPool.escrow();
        require(
            _lockingInfo != address(0),
            "StakingPool: invalid locking info"
        );
        lockingInfo = ILockingInfo(_lockingInfo);

        l1Token = _l1Token;
        stakingPoolManager = _stakingPoolManager;
        rewardRecipient = _rewardRecipient;

        emit PoolInitialized(
            _lockingPool,
            _l1Token,
            _stakingPoolManager,
            _rewardRecipient
        );
    }

    modifier onlyStakingManager() {
        require(
            msg.sender == stakingPoolManager,
            "StakingPool: only staking pool manager"
        );
        _;
    }

    // can only be called success once, and will bind a sequencer to the contract
    function bindSequencer(
        address _signer,
        uint256 _amount,
        bytes calldata _signerPubKey
    ) external onlyStakingManager {
        require(sequencerId == 0, "StakingPool: sequencer already binded");
        require(_signer != address(0), "StakingPool: invalid signer");
        require(
            _signerPubKey.length > 0,
            "StakingPool: invalid signer pub key"
        );
        require(
            _amount >= lockingInfo.minLock() &&
                _amount <= lockingInfo.maxLock(),
            "StakingPool: invalid amount"
        );

        IERC20(l1Token).safeTransferFrom(msg.sender, address(this), _amount);

        // lockingInfo will transfer from this contract
        IERC20(l1Token).safeApprove(address(lockingInfo), _amount);
        lockingPool.lockWithRewardRecipient(
            _signer,
            rewardRecipient,
            _amount,
            _signerPubKey
        );
        sequencerId = lockingPool.seqOwners(address(this));
        signer = _signer;

        emit SequencerBound(_signer, _amount, _signerPubKey, sequencerId);
    }

    function increaseStakingAmount(
        uint256 _amount
    ) external onlyStakingManager {
        require(_amount > 0, "StakingPool: invalid amount");
        require(canStake(_amount), "StakingPool: exceed max lock");
        IERC20(l1Token).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(l1Token).safeApprove(address(lockingInfo), _amount);
        lockingPool.relock(sequencerId, _amount, false);
        emit StakingAmountIncreased(_amount);
    }

    function withdrawStakingAmount(
        address _recipient,
        uint256 _amount
    ) external onlyStakingManager {
        require(_amount > 0, "StakingPool: invalid amount");
        require(
            _recipient != address(0),
            "StakingPool: invalid recipient"
        );
        require(_getLocked() >= lockingInfo.minLock() + _amount, "StakingPool: exceed min lock");
        lockingPool.withdraw(sequencerId, _amount);
        _bridgeTo(_recipient, _amount, 0);
        emit StakingAmountWithdrawn(_recipient, _amount);
    }

    // l2GasLimit * discount < msg.value
    function claimRewards(
        uint32 _l2GasLimit
    ) external payable onlyStakingManager {
        uint256 _rewards = _getRewards();
        lockingPool.withdrawRewards{value: msg.value}(sequencerId, _l2GasLimit);
        emit RewardsClaimed(_rewards);
    }

    function stakingAmount() public view returns (uint256) {
        if (sequencerId == 0) {
            return 0;
        }
        return _getLocked();
    }

    function canStake(uint256 _amount) public view returns (bool) {
        if (sequencerId == 0) {
            return false;
        }
        return _amount + _getLocked() <= lockingInfo.maxLock();
    }

    function getRewards() external view returns (uint256) {
        return _getRewards();
    }

    function _getLocked() internal view returns (uint256 _locked) {
        bytes memory _sequencer = _getSequencer();
        assembly {
            _locked := mload(add(_sequencer, 32))
        }
    }

    function _getRewards() internal view returns (uint256 _rewards) {
        bytes memory _sequencer = _getSequencer();
        assembly {
            _rewards := mload(add(_sequencer, 64))
        }
    }

    function _getSequencer() internal view returns (bytes memory) {
        (bool success, bytes memory returnData) = address(lockingPool)
            .staticcall(
                abi.encodeWithSignature("sequencers(uint256)", sequencerId)
            );
        require(success, "StakingPool: get Sequencer failed");
        return returnData;
    }

    function _bridgeTo(
        address _recipient,
        uint256 _amount,
        uint32 _l2gas
    ) internal {
        if (_amount == 0) {
            return;
        }

        address l2Token = lockingInfo.l2Token();
        address bridge = lockingInfo.bridge();
        uint256 l2ChainId = lockingInfo.l2ChainId();
        IERC20(l1Token).safeIncreaseAllowance(bridge, _amount);
        IL1ERC20Bridge(bridge).depositERC20ToByChainId{value: msg.value}(
            l2ChainId,
            l1Token,
            l2Token,
            _recipient,
            _amount,
            _l2gas,
            ""
        );
    }
}
