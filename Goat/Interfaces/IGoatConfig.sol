// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGoatConfig {
    event ContractSet(bytes32 _contractKey, address _contractAddress);
    event GoatRewardWeightSet(uint256 _goatRewardWeight);
    event DepositPoolAdded(address _pool);
    event WithdrawalManagerAdded(address _manager);
    event BtcTokenAdded(address indexed _token);
    event SupportedTokenAdded(address indexed _token);
    event DistributorAdded(address indexed _distributor);

    function setContract(
        bytes32 _contractKey,
        address _contractAddress
    ) external;

    function getContract(bytes32 _contractKey) external view returns (address);

    function isDepositPool(address _pool) external view returns (bool);

    function addDepositPool(address _pool) external;

    function isWithdrawalManager(address _manager) external view returns (bool);

    function addWithdrawalManager(address _manager) external;

    function getTokenContracts(
        address _token
    ) external view returns (TokenContracts memory);

    function setTokenContracts(
        address _token,
        TokenContracts memory _tokenContracts
    ) external;

    function setTokenRewardWeights(
        address[] memory _token,
        uint256[] memory _weight
    ) external;

    function setTokenRewardWeight(address _token, uint256 _weight) external;

    function getTokenRewardWeights(
        address _token
    ) external view returns (uint256);

    function addSupportedToken(address _token) external;

    function getSupportedTokens() external view returns (address[] memory);

    function isSupportedToken(address _token) external view returns (bool);

    function addDistributor(address _distributor) external;

    function isDistributor(address _distributor) external view returns (bool);

    struct TokenContracts {
        address artToken;
        address depositPool;
        address withdrawalManager;
        address baseRewardPool;
    }
}
