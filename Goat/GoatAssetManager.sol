// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/ERC20MintBurn.sol";
import "@shared/lib-contracts-v0.8/contracts/Dependencies/AddressLib.sol";
import "./Interfaces/IGoatConfig.sol";
import "./Utils/Constants.sol";
import "./Interfaces/IGoatAssetManager.sol";
import "./Interfaces/IDepositPool.sol";
import "./Interfaces/IWithdrawalManager.sol";
import "./Interfaces/IBaseRewardPool.sol";

contract GoatAssetManager is IGoatAssetManager, AccessControlUpgradeable {
    using AddressLib for address;

    IGoatConfig public config;
    address public artTokenBeaconProxy;
    address public depositPoolBeaconProxy;
    address public withdrawalManagerBeaconProxy;
    address public baseRewardPoolBeaconProxy;

    function initialize(
        address _config,
        address _artTokenBeaconProxy,
        address _depositPoolBeaconProxy,
        address _withdrawalManagerBeaconProxy,
        address _baseRewardPoolBeaconProxy
    ) public initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(Constants.ADMIN_ROLE, msg.sender);

        require(_config != address(0), "GoatAssetManager: INVALID_CONFIG");
        require(
            _artTokenBeaconProxy != address(0),
            "GoatAssetManager: INVALID_ART_TOKEN_BEACON_PROXY"
        );
        require(
            _depositPoolBeaconProxy != address(0),
            "GoatAssetManager: INVALID_DEPOSIT_POOL_BEACON_PROXY"
        );
        require(
            _withdrawalManagerBeaconProxy != address(0),
            "GoatAssetManager: INVALID_WITHDRAWAL_MANAGER_BEACON_PROXY"
        );
        require(
            _baseRewardPoolBeaconProxy != address(0),
            "GoatAssetManager: INVALID_BASE_REWARD_POOL_BEACON_PROXY"
        );

        config = IGoatConfig(_config);
        artTokenBeaconProxy = _artTokenBeaconProxy;
        depositPoolBeaconProxy = _depositPoolBeaconProxy;
        withdrawalManagerBeaconProxy = _withdrawalManagerBeaconProxy;
        baseRewardPoolBeaconProxy = _baseRewardPoolBeaconProxy;

        emit InitializedSet(
            _config,
            _artTokenBeaconProxy,
            _depositPoolBeaconProxy,
            _withdrawalManagerBeaconProxy,
            _baseRewardPoolBeaconProxy
        );
    }

    function addPoolBeacon(
        address _asset,
        uint256 _tokenWeight,
        address[] calldata _rewardTokens
    ) external onlyRole(Constants.ADMIN_ROLE) {
        require(_asset != address(0), "GoatAssetManager: INVALID_ASSET");
        require(
            _rewardTokens.length > 0,
            "GoatAssetManager: INVALID_REWARD_TOKENS"
        );
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            require(
                _rewardTokens[i] != address(0),
                "GoatAssetManager: INVALID_REWARD_TOKEN"
            );
        }

        string memory artTokenName = "";
        string memory artTokenSymbol = "";
        if (address(_asset).isPlatformToken()) {
            artTokenName = string(abi.encodePacked("BTC", " Deposited token"));
            artTokenSymbol = string(abi.encodePacked("Art", "BTC"));
        } else {
            artTokenName = string(
                abi.encodePacked(ERC20(_asset).name(), " Deposited token")
            );
            artTokenSymbol = string(
                abi.encodePacked("Art", ERC20(_asset).symbol())
            );
        }

        BeaconProxy _artToken = new BeaconProxy(
            artTokenBeaconProxy,
            abi.encodeWithSelector(
                ERC20MintBurn.initialize.selector,
                artTokenName,
                artTokenSymbol
            )
        );

        BeaconProxy _depositPool = new BeaconProxy(
            depositPoolBeaconProxy,
            abi.encodeWithSelector(
                IDepositPool.initialize.selector,
                msg.sender,
                address(config),
                _asset,
                address(_artToken)
            )
        );
        ERC20MintBurn(address(_artToken)).grantRole(
            Constants.ADMIN_ROLE,
            address(_depositPool)
        );
        ERC20MintBurn(address(_artToken)).grantRole(
            Constants.ADMIN_ROLE,
            msg.sender
        );

        BeaconProxy _withdrawalManager = new BeaconProxy(
            withdrawalManagerBeaconProxy,
            abi.encodeWithSelector(
                IWithdrawalManager.initialize.selector,
                msg.sender,
                _asset,
                address(_depositPool),
                config.getContract(Constants.WITHDRAWAL_RECIPIENT)
            )
        );

        BeaconProxy _baseRewardPool = new BeaconProxy(
            baseRewardPoolBeaconProxy,
            abi.encodeWithSelector(
                IBaseRewardPool.initialize.selector,
                msg.sender,
                address(config),
                address(_artToken),
                _rewardTokens
            )
        );

        // set to config
        config.addSupportedToken(_asset);
        config.setTokenRewardWeight(_asset, _tokenWeight);
        config.addDepositPool(address(_depositPool));
        config.addWithdrawalManager(address(_withdrawalManager));
        IGoatConfig.TokenContracts memory tokenContracts = IGoatConfig
            .TokenContracts({
                artToken: address(_artToken),
                depositPool: address(_depositPool),
                withdrawalManager: address(_withdrawalManager),
                baseRewardPool: address(_baseRewardPool)
            });
        config.setTokenContracts(_asset, tokenContracts);
        emit PoolBeaconAdded(
            _asset,
            address(_artToken),
            address(_depositPool),
            address(_withdrawalManager),
            address(_baseRewardPool)
        );
    }
}
