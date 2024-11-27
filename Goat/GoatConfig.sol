// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Interfaces/IGoatConfig.sol";
import "./Interfaces/IDepositPool.sol";
import "./Interfaces/IWithdrawalManager.sol";
import "./Utils/Constants.sol";

contract GoatConfig is IGoatConfig, AccessControlUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(bytes32 => address) public contractMap;
    EnumerableSet.AddressSet private depositPools;
    EnumerableSet.AddressSet private withdrawalManagers;
    EnumerableSet.AddressSet private distributors;
    EnumerableSet.AddressSet private supportedTokens;
    mapping(address => TokenContracts) public tokenContracts;
    mapping(address => uint256) public tokenRewardWeights;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(Constants.ADMIN_ROLE, msg.sender);
    }

    function setContract(
        bytes32 _contractKey,
        address _contractAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_contractAddress != address(0), "invalid _contractAddress!");
        require(
            contractMap[_contractKey] != _contractAddress,
            "_contractAddress already set!"
        );

        contractMap[_contractKey] = _contractAddress;
        emit ContractSet(_contractKey, _contractAddress);
    }

    function getContract(
        bytes32 _contractKey
    ) public view override returns (address) {
        return contractMap[_contractKey];
    }

    function isDepositPool(
        address _depositPool
    ) public view override returns (bool) {
        return depositPools.contains(_depositPool);
    }

    function addDepositPool(
        address _depositPool
    ) external onlyRole(Constants.ADMIN_ROLE) {
        require(
            !depositPools.contains(_depositPool),
            "_depositPool already added!"
        );
        IDepositPool(_depositPool);
        depositPools.add(_depositPool);
        emit DepositPoolAdded(_depositPool);
    }

    function isWithdrawalManager(
        address _withdrawalManager
    ) public view override returns (bool) {
        return withdrawalManagers.contains(_withdrawalManager);
    }

    function addWithdrawalManager(
        address _withdrawalManager
    ) external onlyRole(Constants.ADMIN_ROLE) {
        require(
            !withdrawalManagers.contains(_withdrawalManager),
            "_withdrawalManager already added!"
        );
        IWithdrawalManager(_withdrawalManager);
        withdrawalManagers.add(_withdrawalManager);
        emit WithdrawalManagerAdded(_withdrawalManager);
    }

    function getTokenContracts(
        address _token
    ) external view override returns (TokenContracts memory) {
        return tokenContracts[_token];
    }

    function setTokenContracts(
        address _token,
        TokenContracts memory _tokenContracts
    ) external {
        tokenContracts[_token] = _tokenContracts;
    }

    function setTokenRewardWeights(
        address[] memory _token,
        uint256[] memory _weight
    ) external onlyRole(Constants.ADMIN_ROLE) {
        require(_token.length == _weight.length, "Invalid input length");

        for (uint256 i = 0; i < _token.length; i++) {
            tokenRewardWeights[_token[i]] = _weight[i];
        }
    }

    function setTokenRewardWeight(
        address _token,
        uint256 _weight
    ) external onlyRole(Constants.ADMIN_ROLE) {
        require(_token != address(0), "Invalid token");
        tokenRewardWeights[_token] = _weight;
    }

    function getTokenRewardWeights(
        address _token
    ) external view override returns (uint256) {
        return tokenRewardWeights[_token];
    }

    function addSupportedToken(
        address _token
    ) external onlyRole(Constants.ADMIN_ROLE) {
        require(
            !supportedTokens.contains(_token),
            "SequencerPool: ALREADY_SUPPORTED_TOKEN"
        );
        supportedTokens.add(_token);
        emit SupportedTokenAdded(_token);
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens.values();
    }

    function isSupportedToken(
        address _token
    ) external view override returns (bool) {
        return supportedTokens.contains(_token);
    }

    function addDistributor(
        address _distributor
    ) external onlyRole(Constants.ADMIN_ROLE) {
        require(
            !distributors.contains(_distributor),
            "SequencerPool: ALREADY_DISTRIBUTOR"
        );
        distributors.add(_distributor);
        emit DistributorAdded(_distributor);
    }

    function isDistributor(address _distributor) external view returns (bool) {
        return distributors.contains(_distributor);
    }
}
