// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/TransferHelper.sol";
import "./Interfaces/ISequencerPool.sol";
import "./Official/Interfaces/ILocking.sol";
import "./Official/Utils/Pubkey.sol";
import "./Utils/Constants.sol";
import "./Interfaces/IGoatConfig.sol";
import "./GoatAccessController.sol";

contract SequencerPool is
    GoatAccessController,
    ISequencerPool,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;
    using Pubkey for bytes32[2];
    using EnumerableSet for EnumerableSet.AddressSet;
    using TransferHelper for address;

    ILocking public locking;
    address public validator;
    address public distributor;
    address public withdrawalRecipient;
    EnumerableSet.AddressSet private whitelist;
    // token => totalLocked
    mapping(address => uint256) public totalLocked;
    // user => token => locked
    mapping(address => mapping(address => uint256)) public userLocked;

    bool public open;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _locking,
        address _config
    ) public initializer {
        require(_locking != address(0), "SequencerPool: INVALID_LOCKING");
        require(_config != address(0), "SequencerPool: INVALID_CONFIG");

        __AccessControl_init();
        __GoatControl_init(_config);

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(Constants.ADMIN_ROLE, _owner);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.ADMIN_ROLE, msg.sender);

        locking = ILocking(_locking);

        address _withdrawalRecipient = config.getContract(
            Constants.WITHDRAWAL_RECIPIENT
        );
        require(
            _withdrawalRecipient != address(0),
            "SequencerPool: INVALID_WITHDRAWAL_RECIPIENT"
        );

        withdrawalRecipient = _withdrawalRecipient;

        emit InitializedSet(_locking, _config, _withdrawalRecipient);
    }

    function setDistributor(
        address _distributor
    ) external onlyRole(Constants.ADMIN_ROLE) {
        distributor = _distributor;
        emit DistributorSet(_distributor);
    }

    function addWhitelist(address _user) public onlyRole(Constants.ADMIN_ROLE) {
        require(
            !whitelist.contains(_user),
            "SequencerPool: ALREADY_WHITELISTED"
        );
        whitelist.add(_user);
        emit WhitelistAdded(_user);
    }

    function removeWhitelist(
        address _user
    ) external onlyRole(Constants.ADMIN_ROLE) {
        require(whitelist.contains(_user), "SequencerPool: NOT_WHITELISTED");
        whitelist.remove(_user);
        emit WhitelistRemoved(_user);
    }

    function getWhitelist() external view returns (address[] memory) {
        address[] memory _whitelist = new address[](whitelist.length());
        for (uint256 i = 0; i < whitelist.length(); i++) {
            _whitelist[i] = whitelist.at(i);
        }
        return _whitelist;
    }

    function bindExistsSequencer(
        address _validator,
        address _partner
    ) external override onlyRole(Constants.ADMIN_ROLE) {
        require(validator == address(0), "SequencerPool: VALIDATOR_EXISTS");
        require(_validator != address(0), "SequencerPool: INVALID_VALIDATOR");
        require(_partner != address(0), "SequencerPool: INVALID_PARTNER");
        ILocking.Locking[] memory _locking = locking.creationThreshold();
        for (uint256 i = 0; i < _locking.length; i++) {
            address _token = _locking[i].token;
            uint256 _lockedAmount = locking.locking(_validator, _token);
            if (_lockedAmount == 0) {
                continue;
            }
            if (_token == address(0)) {
                _token = AddressLib.PLATFORM_TOKEN_ADDRESS;
            }
            totalLocked[_token] += _lockedAmount;
            userLocked[_partner][_token] += _lockedAmount;
            emit Locked(_partner, _token, _lockedAmount, true);
        }
        addWhitelist(_partner);
        validator = _validator;
        open = true;
        emit BindExistsSequencer(_validator, _partner);
    }

    function create(
        bytes32[2] calldata _pubkey,
        bytes32 _sigR,
        bytes32 _sigS,
        uint8 _sigV
    ) external override onlyRole(Constants.ADMIN_ROLE) {
        // create validator
        require(validator == address(0), "SequencerPool: VALIDATOR_EXISTS");

        // there is some problem with the locking:
        // if you want to create a validator, you must lock all
        // the supported asset at the threshold
        ILocking.Locking[] memory _locking = locking.creationThreshold();
        uint256 _eth;
        for (uint256 i = 0; i < _locking.length; i++) {
            if (_locking[i].token == address(0)) {
                uint256 _balance = address(this).balance;
                require(
                    _balance >= _locking[i].amount,
                    "SequencerPool: INVALID_AMOUNT"
                );
                _eth = _locking[i].amount;
            } else {
                uint256 _balance = IERC20(_locking[i].token).balanceOf(
                    address(this)
                );
                require(
                    _balance >= _locking[i].amount,
                    "SequencerPool: INVALID_AMOUNT"
                );
                IERC20(_locking[i].token).safeApprove(
                    address(locking),
                    _locking[i].amount
                );
            }
        }
        locking.create{value: _eth}(_pubkey, _sigR, _sigS, _sigV);
        validator = _pubkey.ConsAddress();

        open = true;
        emit Created(validator, _pubkey, _sigR, _sigS, _sigV);
    }

    function lock(
        address _user,
        address _token,
        uint256 _amount,
        bool _isPartner
    ) external payable override onlyDepositPool onlySupportedToken(_token) {
        if (_isPartner) {
            require(
                whitelist.contains(_user),
                "SequencerPool: NOT_WHITELISTED"
            );
        }
        _lock(_user, _token, _amount);
        emit Locked(_user, _token, _amount, _isPartner);
    }

    function _lock(
        address _user,
        address _token,
        uint256 _amount
    ) internal updateLocked(_user, _token, _amount, true) {
        // if token is ETH
        if (AddressLib.isPlatformToken(_token)) {
            require(msg.value == _amount, "SequencerPool: INVALID_AMOUNT");
        } else {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }
        if (!open) {
            return;
        }
        require(validator != address(0), "SequencerPool: NO_VALIDATOR");

        // the current balance of the token in the contract, if it can lock, lock it
        uint256 _balance;
        uint256 _eth;
        if (AddressLib.isPlatformToken(_token)) {
            _balance = address(this).balance;
            _eth = _balance;
            _token = address(0);
        } else {
            _balance = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeApprove(address(locking), _balance);
        }
        if (!_canLock(_token, _balance)) {
            return;
        }
        ILocking.Locking[] memory _locking = new ILocking.Locking[](1);
        _locking[0] = ILocking.Locking(_token, _balance);
        locking.lock{value: _eth}(validator, _locking);
    }

    function _canLock(
        address _token,
        uint256 _balance
    ) internal view returns (bool) {
        (, , uint256 _limit, uint256 _threshold) = locking.tokens(_token);
        uint256 _locked = locking.locking(validator, _token);
        _locked += _balance;
        return _locked <= _limit && _locked >= _threshold;
    }

    function unlock(
        address _user,
        address _token,
        uint256 _amount,
        bool _isPartner
    ) external onlyDepositPool onlySupportedToken(_token) {
        if (_isPartner) {
            require(
                whitelist.contains(_user),
                "SequencerPool: NOT_WHITELISTED"
            );
        }
        require(
            userLocked[_user][_token] >= _amount,
            "SequencerPool: INSUFFICIENT_BALANCE"
        );

        _unlock(_user, _token, _amount, _isPartner);
        emit Unlocked(_user, _token, _amount, _isPartner);
    }

    function _unlock(
        address _user,
        address _token,
        uint256 _amount,
        bool _isPartner
    ) internal updateLocked(_user, _token, _amount, false) {
        require(validator != address(0), "SequencerPool: NO_VALIDATOR");
        require(distributor != address(0), "SequencerPool: NO_DISTRIBUTOR");
        if (AddressLib.isPlatformToken(_token)) {
            _token = address(0);
        }
        ILocking.Locking[] memory _locking = new ILocking.Locking[](1);
        _locking[0] = ILocking.Locking(_token, _amount);
        address _recipient = _isPartner ? _user : withdrawalRecipient;
        locking.unlock(validator, _recipient, _locking);
    }

    function claim() external {
        if (validator == address(0)) {
            return;
        }
        require(distributor != address(0), "SequencerPool: NO_DISTRIBUTOR");
        locking.claim(validator, distributor);
        emit Claimed(msg.sender, validator, distributor);
    }

    function _updateLocked(
        address _user,
        address _token,
        uint256 _amount,
        bool _increase
    ) internal {
        if (_increase) {
            totalLocked[_token] += _amount;
            userLocked[_user][_token] += _amount;
        } else {
            totalLocked[_token] -= _amount;
            userLocked[_user][_token] -= _amount;
        }
    }

    modifier updateLocked(
        address _user,
        address _token,
        uint256 _amount,
        bool _increase
    ) {
        _updateLocked(_user, _token, _amount, _increase);
        _;
    }
}
