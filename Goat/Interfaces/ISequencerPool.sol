// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISequencerPool {
    event InitializedSet(
        address _locking,
        address _config,
        address _withdrawalRecipient
    );
    event DistributorSet(address indexed _rewardDistributor);
    event WhitelistAdded(address indexed _user);
    event WhitelistRemoved(address indexed _user);
    event Created(
        address indexed _validator,
        bytes32[2] _pubkey,
        bytes32 _sigR,
        bytes32 _sigS,
        uint8 _sigV
    );
    event BindExistsSequencer(address indexed _validator, address _partner);
    event Locked(
        address indexed _user,
        address indexed _token,
        uint256 _amount,
        bool _isPartner
    );
    event Unlocked(
        address indexed _user,
        address indexed _token,
        uint256 _amount,
        bool _isPartner
    );
    event Claimed(
        address indexed _user,
        address _validator,
        address _distributor
    );

    function initialize(
        address _owner,
        address _locking,
        address _config
    ) external;

    function setDistributor(address _rewardDistributor) external;

    function distributor() external view returns (address);

    function open() external view returns (bool);

    function bindExistsSequencer(address _validator, address _partner) external;

    function create(
        bytes32[2] calldata _pubkey,
        bytes32 _sigR,
        bytes32 _sigS,
        uint8 _sigV
    ) external;

    function lock(
        address _user,
        address _token,
        uint256 _amount,
        bool _isPartner
    ) external payable;

    function unlock(
        address _user,
        address _token,
        uint256 _amount,
        bool _isPartner
    ) external;

    function claim() external;

    function addWhitelist(address _user) external;

    function removeWhitelist(address _user) external;

    function getWhitelist() external view returns (address[] memory);

    function totalLocked(address _token) external view returns (uint256);

    function userLocked(
        address _user,
        address _token
    ) external view returns (uint256);
}
