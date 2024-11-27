// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISequencerNodeManager {
    event SequencerSet(address _sequencer, string _url);

    function setUrl(
        address _sequencer,
        string calldata _url
    ) external;

    function getUrl(
        address _sequencer
    ) external view returns (string memory);
}
