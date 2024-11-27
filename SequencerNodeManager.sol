// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./Interfaces/ISequencerNodeManager.sol";

contract SequencerNodeManager is ISequencerNodeManager, AccessControlUpgradeable {

    mapping(address => string) public urlMap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }


    function setUrl(
        address _sequencer,
        string calldata _url
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_sequencer != address(0), "invalid _sequencer!");
        require(
            keccak256(abi.encodePacked(urlMap[_sequencer])) != keccak256(abi.encodePacked(_url)),
            "_sequencer already set!"
        );

        urlMap[_sequencer] = _url;
        emit SequencerSet(_sequencer, _url);
    }

    function getUrl(
        address _sequencer
    ) public view override returns (string memory) {
        return urlMap[_sequencer];
    }
}
