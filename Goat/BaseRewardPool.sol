// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";
import "./Interfaces/IBaseRewardPool.sol";
import "./Utils/Constants.sol";
import "./GoatAccessController.sol";

contract BaseRewardPool is
    GoatAccessController,
    IBaseRewardPool,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;
    using TransferHelper for address;

    IERC20 public stakingToken;
    address[] public rewardTokens;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    struct Reward {
        uint256 rewardPerTokenStored;
        uint256 queuedRewards;
    }

    struct UserReward {
        uint256 userRewardPerTokenPaid;
        uint256 rewards;
    }

    mapping(address => Reward) public rewards;
    mapping(address => bool) public isRewardToken;

    mapping(address => mapping(address => UserReward)) public userRewards;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _config,
        address _stakingToken,
        address[] calldata _rewardTokens
    ) public initializer {
        require(_owner != address(0), "RewardPool: INVALID_OWNER");
        require(_config != address(0), "RewardPool: INVALID_CONFIG");
        require(_stakingToken != address(0), "RewardPool: INVALID_ARB_TOKEN");

        __AccessControl_init();
        __GoatControl_init(_config);

        stakingToken = IERC20(_stakingToken);
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            require(
                _rewardTokens[i] != address(0),
                "RewardPool: INVALID_REWARD_TOKEN"
            );
            rewardTokens.push(_rewardTokens[i]);
            isRewardToken[_rewardTokens[i]] = true;
        }

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(Constants.ADMIN_ROLE, _owner);

        emit InitializedSet(_stakingToken, _rewardTokens);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    modifier updateReward(address _account) {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            UserReward storage userReward = userRewards[_account][rewardToken];
            userReward.rewards = earned(_account, rewardToken);
            userReward.userRewardPerTokenPaid = rewards[rewardToken]
                .rewardPerTokenStored;
        }

        _;
    }

    function earned(
        address _account,
        address _rewardToken
    ) public view override returns (uint256) {
        Reward memory reward = rewards[_rewardToken];
        UserReward memory userReward = userRewards[_account][_rewardToken];
        return
            (balanceOf(_account) *
                (reward.rewardPerTokenStored -
                    userReward.userRewardPerTokenPaid)) /
            1e18 +
            userReward.rewards;
    }

    function stake(uint256 _amount) public override updateReward(msg.sender) {
        require(_amount > 0, "RewardPool : Cannot stake 0");

        _totalSupply += _amount;
        _balances[msg.sender] += _amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 amount) external override {
        _withdraw(msg.sender, amount);
    }

    function _withdraw(
        address _account,
        uint256 _amount
    ) internal virtual updateReward(_account) {
        require(_amount > 0, "RewardPool : Cannot withdraw 0");
        require(
            _balances[_account] >= _amount,
            "RewardPool : Insufficient balance"
        );

        _totalSupply -= _amount;
        _balances[_account] -= _amount;

        stakingToken.safeTransfer(_account, _amount);
        emit Withdrawn(_account, _amount);

        _getReward(_account);
    }

    function claimReward() external override {
        _getReward(msg.sender);
    }

    function _getReward(address _account) internal updateReward(_account) {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint256 reward = earned(_account, rewardToken);
            if (reward > 0) {
                userRewards[_account][rewardToken].rewards = 0;
                rewardToken.safeTransferToken(_account, reward);
                emit RewardPaid(_account, rewardToken, reward);
            }
        }
    }

    function addReward(
        address _rewardToken,
        uint256 _rewards
    ) external payable override onlyDistributor {
        require(_rewards > 0, "invalid reward amount");
        require(isRewardToken[_rewardToken], "invalid reward token");

        if (AddressLib.isPlatformToken(_rewardToken)) {
            require(_rewards == msg.value, "invalid amount");
        } else {
            require(msg.value == 0, "invalid msg.value");
            IERC20(_rewardToken).safeTransferFrom(
                msg.sender,
                address(this),
                _rewards
            );
        }

        Reward storage rewardInfo = rewards[_rewardToken];

        if (totalSupply() == 0) {
            rewardInfo.queuedRewards += _rewards;
            return;
        }

        _rewards += rewardInfo.queuedRewards;
        rewardInfo.queuedRewards = 0;

        rewardInfo.rewardPerTokenStored += (_rewards * 1e18) / totalSupply();
        emit RewardAdded(_rewardToken, _rewards);
    }

    receive() external payable {}
}
