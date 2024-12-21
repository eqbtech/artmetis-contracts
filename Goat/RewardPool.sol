// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";
import "./Interfaces/IRewardPool.sol";
import "./Utils/Constants.sol";
import "./GoatAccessController.sol";

contract RewardPool is
    GoatAccessController,
    IRewardPool,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _config,
        address _goatToken
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init_unchained();

        require(_config != address(0), "RewardPool: INVALID_CONFIG");
        __GoatControl_init(_config);

        require(_goatToken != address(0), "RewardPool: INVALID_GOAT_TOKEN");
        goatToken = _goatToken;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.ADMIN_ROLE, msg.sender);

        emit InitializedSet(_goatToken);
    }

    address public goatToken;

    // user => amount
    mapping(address => uint256) public btcRewards;
    // user => amount
    mapping(address => uint256) public goatRewards;

    function claimAll() external nonReentrant {
        uint256 _btcAmount = btcRewards[msg.sender];
        uint256 _goatAmount = goatRewards[msg.sender];

        if (_btcAmount > 0) {
            btcRewards[msg.sender] = 0;
            TransferHelper.safeTransferETH(msg.sender, _btcAmount);
        }

        if (_goatAmount > 0) {
            goatRewards[msg.sender] = 0;
            IERC20(goatToken).safeTransfer(msg.sender, _goatAmount);
        }

        emit Claimed(msg.sender, _btcAmount, _goatAmount);
    }

    function addReward(
        address _user,
        address _token,
        uint256 _amount
    ) external payable onlyDistributor {
        require(_user != address(0), "RewardPool: INVALID_USER");
        require(_amount > 0, "RewardPool: INVALID_AMOUNT");
        require(
            _token == goatToken || _token == AddressLib.PLATFORM_TOKEN_ADDRESS,
            "RewardPool: INVALID_TOKEN"
        );

        if (_token == goatToken) {
            IERC20(goatToken).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
            goatRewards[_user] += _amount;
        } else {
            require(msg.value == _amount, "RewardPool: msg.value != _amount");
            btcRewards[_user] += _amount;
        }
        emit RewardAdded(_user, _token, _amount);
    }
}
