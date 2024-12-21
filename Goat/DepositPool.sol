// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";
import "@shared/lib-contracts-v0.8/contracts/Interfaces/IERC20MintBurn.sol";
import "./Interfaces/IDepositPool.sol";
import "./Interfaces/ISequencerPool.sol";
import "./Interfaces/IRewardDistributor.sol";
import "./Interfaces/ISequencerPoolManager.sol";
import "./Utils/Constants.sol";
import "./GoatAccessController.sol";

contract DepositPool is
    GoatAccessController,
    IDepositPool,
    AccessControlUpgradeable
{
    using TransferHelper for address;
    using SafeERC20 for IERC20;

    uint256 public totalDeposited;
    // the allowed tokens to deposit
    address public token;
    // the artToken
    address public artToken;

    /// @custom:oz-upgrades-unsafe-allow constructor
    function initialize(
        address _owner,
        address _config,
        address _token,
        address _artToken
    ) public initializer {
        __AccessControl_init();
        require(_owner != address(0), "DepositPool: INVALID_OWNER");
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(Constants.ADMIN_ROLE, _owner);

        require(_config != address(0), "DepositPool: INVALID_CONFIG");
        __GoatControl_init(_config);

        require(_token != address(0), "DepositPool: INVALID_TOKEN");
        require(_artToken != address(0), "DepositPool: INVALID_ART_TOKEN");
        token = _token;
        artToken = _artToken;
        emit InitializedSet(_token, _artToken);
    }

    function getArtTokenAmountToMint(
        uint256 _amount
    ) public view returns (uint256) {
        if (totalDeposited == 0) {
            return _amount;
        }
        return (_amount * IERC20(artToken).totalSupply()) / totalDeposited;
    }

    function deposit(
        address _pool,
        uint256 _amount,
        uint256 _minArtTokenAmountToReceive,
        string calldata _referralId
    )
        external
        payable
        validSequencerPool(_pool)
        harvest(_pool)
        returns (uint256)
    {
        require(_amount > 0, "DepositPool: INVALID_AMOUNT");
        uint256 _artTokenAmount = getArtTokenAmountToMint(_amount);
        require(
            _artTokenAmount >= _minArtTokenAmountToReceive,
            "DepositPool: artToken is too high"
        );

        if (AddressLib.isPlatformToken(token)) {
            require(msg.value == _amount, "DepositPool: INVALID_AMOUNT");
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        }

        // lock the balance
        _deposit(_pool, _pool, address(token).balanceOf(address(this)), false);

        totalDeposited += _amount;
        IERC20MintBurn(artToken).mint(msg.sender, _artTokenAmount);

        emit Deposited(
            _pool,
            msg.sender,
            _amount,
            _artTokenAmount,
            _referralId
        );
        return _artTokenAmount;
    }

    function partnerDeposit(
        address _pool,
        uint256 _amount
    ) external payable validSequencerPool(_pool) harvest(_pool) {
        require(_amount > 0, "DepositPool: INVALID_AMOUNT");
        if (AddressLib.isPlatformToken(token)) {
            require(msg.value == _amount, "DepositPool: INVALID_AMOUNT");
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        }
        _deposit(_pool, msg.sender, _amount, true);
        emit PartnerDeposited(_pool, msg.sender, _amount);
    }

    function _deposit(
        address _pool,
        address _user,
        uint256 _amount,
        bool _isPartner
    ) internal {
        address _token = token;
        if (AddressLib.isPlatformToken(_token)) {
            ISequencerPool(_pool).lock{value: _amount}(
                _user,
                _token,
                _amount,
                _isPartner
            );
        } else {
            IERC20(_token).approve(_pool, _amount);
            ISequencerPool(_pool).lock(_user, _token, _amount, _isPartner);
        }
    }

    function partnerWithdraw(
        address _pool,
        uint256 _amount
    ) external validSequencerPool(_pool) harvest(_pool) {
        require(_amount > 0, "DepositPool: INVALID_AMOUNT");
        ISequencerPool(_pool).unlock(msg.sender, token, _amount, true);
    }

    function initiateWithdrawalFor(
        address _pool,
        address _user,
        uint256 _artAmount
    )
        external
        onlyWithdrawalManager
        validSequencerPool(_pool)
        harvest(_pool)
        returns (uint256)
    {
        require(_artAmount > 0, "AMTDepositPool: invalid amount");
        uint256 _amount = (_artAmount * 1e18) / getArtTokenAmountToMint(1e18);
        IERC20MintBurn(artToken).burn(_user, _artAmount);

        totalDeposited -= _amount;
        ISequencerPool(_pool).unlock(_pool, token, _amount, false);
        emit InitiateWithdrawalFor(token, _user, _artAmount, _amount);

        return _amount;
    }

    function addReward(
        address _token,
        uint256 _amount
    ) external payable override onlyDistributor {
        require(_token == token, "DepositPool: INVALID_TOKEN");
        require(_amount > 0, "DepositPool: INVALID_AMOUNT");
        if (AddressLib.isPlatformToken(_token)) {
            require(msg.value == _amount, "DepositPool: INVALID_AMOUNT");
        } else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }
        totalDeposited += _amount;
        emit RewardAdded(_amount);
    }

    modifier validSequencerPool(address _pool) {
        address _sequencerPoolManager = config.getContract(
            Constants.SEQUENCER_POOL_MANAGER
        );
        require(
            _sequencerPoolManager != address(0),
            "DepositPool: INVALID_SEQUENCER_POOL_MANAGER"
        );
        require(
            ISequencerPoolManager(_sequencerPoolManager).isValidPool(_pool),
            "DepositPool: INVALID_SEQUENCER_POOL"
        );
        _;
    }

    modifier harvest(address _pool) {
        IRewardDistributor(ISequencerPool(_pool).distributor())
            .distributeReward();
        _;
    }
}
