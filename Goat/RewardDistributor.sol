// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";
import "./Interfaces/IRewardDistributor.sol";
import "./Interfaces/ISequencerPool.sol";
import "./Interfaces/IRewardPool.sol";
import "./Interfaces/IBaseRewardPool.sol";
import "./Interfaces/IDepositPool.sol";
import "./Interfaces/IGoatConfig.sol";
import "./Utils/Constants.sol";

contract RewardDistributor is IRewardDistributor, AccessControlUpgradeable {
    using TransferHelper for address;
    using SafeERC20 for IERC20;

    IGoatConfig public config;
    address public rewardPool;
    address public sequencerPool;
    address public rewardRecipient;
    address public goat;
    uint256 public feeRate;
    uint256 public feeShare;
    uint256 public extraShare;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _config,
        address _sequencerPool
    ) public initializer {
        __AccessControl_init();

        require(_config != address(0), "RewardDistributor: INVALID_CONFIG");
        require(
            _sequencerPool != address(0),
            "RewardDistributor: INVALID_SEQUENCER_LOCKING_POOL"
        );

        config = IGoatConfig(_config);
        sequencerPool = _sequencerPool;

        address _rewardRecipient = config.getContract(
            Constants.REWARD_RECIPIENT
        );
        require(
            _rewardRecipient != address(0),
            "RewardDistributor: INVALID_REWARD_RECIPIENT"
        );
        rewardPool = config.getContract(Constants.REWARD_POOL);
        require(
            rewardPool != address(0),
            "RewardDistributor: INVALID_REWARD_POOL"
        );
        goat = config.getContract(Constants.GOAT_TOKEN);
        require(goat != address(0), "RewardDistributor: INVALID_GOAT");

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(Constants.ADMIN_ROLE, _owner);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.ADMIN_ROLE, msg.sender);

        emit InitializedSet(_config, _sequencerPool, rewardPool, goat);
    }

    function setParams(
        uint256 _feeRate,
        uint256 _feeShare,
        uint256 _extraShare
    ) external onlyRole(Constants.ADMIN_ROLE) {
        feeRate = _feeRate;
        feeShare = _feeShare;
        extraShare = _extraShare;

        emit ParamsSet(msg.sender, _feeRate, _feeShare, _extraShare);
    }

    function setFeeRate(
        uint256 _feeRate
    ) external onlyRole(Constants.ADMIN_ROLE) {
        feeRate = _feeRate;
        emit FeeRateSet(msg.sender, _feeRate);
    }

    function setFeeShare(
        uint256 _feeShare
    ) external onlyRole(Constants.ADMIN_ROLE) {
        feeShare = _feeShare;
        emit FeeShareSet(msg.sender, _feeShare);
    }

    function setExtraShare(
        uint256 _extraShare
    ) external onlyRole(Constants.ADMIN_ROLE) {
        extraShare = _extraShare;
        emit ExtraShareSet(msg.sender, _extraShare);
    }

    function distributeReward() external {
        // check if sequencer pool is open
        if (!ISequencerPool(sequencerPool).open()) {
            return;
        }
        uint256 _goatReward = IERC20(goat).balanceOf(address(this));
        uint256 _btcReward = address(this).balance;
        if (_goatReward == 0 && _btcReward == 0) {
            return;
        }

        address[] memory _whitelist = ISequencerPool(sequencerPool)
            .getWhitelist();
        (
            uint256[] memory _weightInPartner,
            uint256[] memory _totalWeight
        ) = _getPartnerWeight(_whitelist);
        _distributeToPartner(
            _whitelist,
            _totalWeight
        );
        _distributeFee(_whitelist, _weightInPartner);
        _distributeToPool();
    }

    function _distributeFee(
        address[] memory partners,
        uint256[] memory _weight
    ) internal {
        uint256 _goatReward = IERC20(goat).balanceOf(address(this));
        uint256 _btcReward = address(this).balance;
        uint256 _goatFee = (_goatReward * feeRate) / 1e18;
        uint256 _btcFee = (_btcReward * feeRate) / 1e18;
        if (_goatFee == 0 && _btcFee == 0) {
            return;
        }

        uint256 _recipientGoatFee = ((_goatFee * feeShare) / 1e18);
        uint256 _partnerGoatFee = _goatFee - _recipientGoatFee;
        uint256 _recipientBtcFee = ((_btcFee * feeShare) / 1e18);
        uint256 _partnerBtcFee = _btcFee - _recipientBtcFee;

        if (_recipientGoatFee > 0) {
            TransferHelper.safeTransferToken(
                goat,
                config.getContract(Constants.REWARD_RECIPIENT),
                _recipientGoatFee
            );
        }
        if (_recipientBtcFee > 0) {
            TransferHelper.safeTransferETH(
                config.getContract(Constants.REWARD_RECIPIENT),
                _recipientBtcFee
            );
        }

        for (uint256 i = 0; i < partners.length; i++) {
            address _partner = partners[i];
            uint256 _goatAmount = (_partnerGoatFee * _weight[i]) / 1e18;
            uint256 _btcAmount = (_partnerBtcFee * _weight[i]) / 1e18;
            if (_goatAmount > 0) {
                safeTransferToRewardPool(_partner, goat, _goatAmount);
            }
            if (_btcAmount > 0) {
                safeTransferToRewardPool(
                    _partner,
                    AddressLib.PLATFORM_TOKEN_ADDRESS,
                    _btcAmount
                );
            }
        }
    }

    function _distributeToPartner(
        address[] memory partners,
        uint256[] memory _weight
    ) internal {
        uint256 _goatReward = IERC20(goat).balanceOf(address(this));
        uint256 _btcReward = address(this).balance;

        for (uint256 i = 0; i < partners.length; i++) {
            address _partner = partners[i];
            uint256 _goatAmount = (_goatReward * _weight[i]) / 1e18;
            uint256 _btcAmount = (_btcReward * _weight[i]) / 1e18;
            if (_btcAmount > 0) {
                safeTransferToRewardPool(
                    _partner,
                    AddressLib.PLATFORM_TOKEN_ADDRESS,
                    _btcAmount
                );
            }
            if (_goatAmount > 0) {
                safeTransferToRewardPool(_partner, goat, _goatAmount);
            }
        }
    }

    function _getPartnerWeight(
        address[] memory _whitelist
    ) internal view returns (uint256[] memory, uint256[] memory) {
        address[] memory _lockedTokens = _getLockedTokens();
        uint256[] memory _weightInPartner = new uint256[](_whitelist.length);
        uint256[] memory _totalWeight = new uint256[](_whitelist.length);
        uint256[] memory _tokenRewardWeights = _convertRewardsWeight(
            _lockedTokens
        );

        for (uint256 i = 0; i < _lockedTokens.length; i++) {
            uint256 _totalLocked = ISequencerPool(sequencerPool).totalLocked(
                _lockedTokens[i]
            );
            uint256 _totalForPartner = _totalLocked -
                ISequencerPool(sequencerPool).userLocked(
                    sequencerPool,
                    _lockedTokens[i]
                );
            if (_totalLocked == 0) {
                continue;
            }
            uint256 _tokenWeight = _tokenRewardWeights[i];
            for (uint256 j = 0; j < _whitelist.length; j++) {
                address _partner = _whitelist[j];
                uint256 _locked = ISequencerPool(sequencerPool).userLocked(
                    _partner,
                    _lockedTokens[i]
                );
                uint256 _currentWeight = (_locked * _tokenWeight) /
                    _totalLocked;
                _totalWeight[j] += _currentWeight;
                if (_totalForPartner != 0) {
                    _weightInPartner[j] +=
                        (_locked * _tokenWeight) /
                        _totalForPartner;
                }
            }
        }
        return (_weightInPartner, _totalWeight);
    }

    function _convertRewardsWeight(
        address[] memory _lockedTokens
    ) internal view returns (uint256[] memory) {
        uint256 _totalWeight = 0;
        for (uint256 i = 0; i < _lockedTokens.length; i++) {
            _totalWeight += IGoatConfig(config).getTokenRewardWeights(
                _lockedTokens[i]
            );
        }
        uint256[] memory _weight = new uint256[](_lockedTokens.length);
        require(_totalWeight > 0, "RewardDistributor: INVALID_TOTAL_WEIGHT");
        for (uint256 i = 0; i < _lockedTokens.length; i++) {
            _weight[i] =
                (IGoatConfig(config).getTokenRewardWeights(_lockedTokens[i]) *
                    1e18) /
                _totalWeight;
        }
        return _weight;
    }

    function _calculateTokenRewardWeight(
        address[] memory _lockedTokens
    ) internal view returns (uint256[] memory) {
        uint256[] memory _rewardsTokenWeight = _convertRewardsWeight(
            _lockedTokens
        );
        uint256[] memory _tokenRewardWeights = new uint256[](
            _lockedTokens.length
        );
        uint256 _total = 0;
        for (uint256 i = 0; i < _lockedTokens.length; i++) {
            _tokenRewardWeights[i] =
                _rewardsTokenWeight[i] *
                ISequencerPool(sequencerPool).userLocked(
                    sequencerPool,
                    _lockedTokens[i]
                );
            _total += _tokenRewardWeights[i];
        }
        if (_total == 0) {
            return _tokenRewardWeights;
        }

        for (uint256 i = 0; i < _lockedTokens.length; i++) {
            _tokenRewardWeights[i] = (_tokenRewardWeights[i] * 1e18) / _total;
        }
        return _tokenRewardWeights;
    }

    function _distributeByToken(
        address _token,
        uint256 _btcAmount,
        uint256 _goatAmount
    ) internal {
        IGoatConfig.TokenContracts memory _tokenContracts = config
            .getTokenContracts(_token);
        if (_token != goat && _token != AddressLib.PLATFORM_TOKEN_ADDRESS) {
            _distributeToArtStakingRewardPool(
                _tokenContracts.baseRewardPool,
                goat,
                _goatAmount
            );
            _distributeToArtStakingRewardPool(
                _tokenContracts.baseRewardPool,
                AddressLib.PLATFORM_TOKEN_ADDRESS,
                _btcAmount
            );
        }
        if (_token == goat) {
            if (_goatAmount > 0) {
                safeTransferRewards(
                    IRewardReceiver(_tokenContracts.depositPool),
                    goat,
                    _goatAmount
                );
            }
            _distributeToArtStakingRewardPool(
                _tokenContracts.baseRewardPool,
                AddressLib.PLATFORM_TOKEN_ADDRESS,
                _btcAmount
            );
        }
        if (_token == AddressLib.PLATFORM_TOKEN_ADDRESS) {
            if (_btcAmount > 0) {
                safeTransferRewards(
                    IRewardReceiver(_tokenContracts.depositPool),
                    AddressLib.PLATFORM_TOKEN_ADDRESS,
                    _btcAmount
                );
            }
            _distributeToArtStakingRewardPool(
                _tokenContracts.baseRewardPool,
                goat,
                _goatAmount
            );
        }
    }

    function _distributeToArtStakingRewardPool(
        address _pool,
        address _rewardToken,
        uint256 _amount
    ) internal {
        if (_amount == 0) {
            return;
        }
        uint256 _extraToRecipient = (_amount * extraShare) / 1e18;
        uint256 _amountToPool = _amount - _extraToRecipient;

        if (_extraToRecipient > 0) {
            address(_rewardToken).safeTransferToken(
                config.getContract(Constants.REWARD_RECIPIENT),
                _extraToRecipient
            );
        }

        if (_amountToPool > 0) {
            safeTransferRewards(
                IRewardReceiver(_pool),
                _rewardToken,
                _amountToPool
            );
        }
    }

    function _distributeToPool() internal {
        uint256 _goatReward = IERC20(goat).balanceOf(address(this));
        uint256 _btcReward = address(this).balance;
        if (_goatReward == 0 && _btcReward == 0) {
            return;
        }
        address[] memory _lockedTokens = _getLockedTokens();
        uint256[] memory _tokenRewardWeights = _calculateTokenRewardWeight(
            _lockedTokens
        );
        for (uint256 i = 0; i < _lockedTokens.length; i++) {
            address _token = _lockedTokens[i];
            uint256 _goatRewardToPool = (_goatReward * _tokenRewardWeights[i]) /
                1e18;
            uint256 _btcRewardToPool = (_btcReward * _tokenRewardWeights[i]) /
                1e18;
            _distributeByToken(_token, _btcRewardToPool, _goatRewardToPool);
        }
    }

    function _getLockedTokens() internal view returns (address[] memory) {
        address[] memory _supportedTokens = config.getSupportedTokens();
        address[] memory _lockedTokensTemp = new address[](
            _supportedTokens.length
        );
        uint256 count = 0;

        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            if (
                ISequencerPool(sequencerPool).totalLocked(_supportedTokens[i]) >
                0
            ) {
                _lockedTokensTemp[count] = _supportedTokens[i];
                count++;
            }
        }

        address[] memory _lockedTokens = new address[](count);
        for (uint256 j = 0; j < count; j++) {
            _lockedTokens[j] = _lockedTokensTemp[j];
        }

        return _lockedTokens;
    }

    function safeTransferRewards(
        IRewardReceiver _pool,
        address _token,
        uint256 _amount
    ) internal {
        if (AddressLib.isPlatformToken(_token)) {
            _pool.addReward{value: _amount}(
                AddressLib.PLATFORM_TOKEN_ADDRESS,
                _amount
            );
        } else {
            IERC20(_token).approve(address(_pool), _amount);
            _pool.addReward(_token, _amount);
        }
        emit RewardDistributed(address(_pool), address(0), _token, _amount);
    }

    function safeTransferToRewardPool(
        address _user,
        address _token,
        uint256 _amount
    ) internal {
        if (AddressLib.isPlatformToken(_token)) {
            IRewardPool(rewardPool).addReward{value: _amount}(
                _user,
                AddressLib.PLATFORM_TOKEN_ADDRESS,
                _amount
            );
        } else {
            IERC20(_token).approve(rewardPool, _amount);
            IRewardPool(rewardPool).addReward(_user, _token, _amount);
        }
        emit RewardDistributed(rewardPool, sequencerPool, _token, _amount);
    }

    receive() external payable {}
}
