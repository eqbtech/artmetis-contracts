// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Interfaces/IAMTDepositPool.sol";
import "./Interfaces/IAMTRewardPool.sol";
import "./Interfaces/IArtMetis.sol";
import "./Interfaces/IMetis.sol";
import "./Interfaces/IL2Bridge.sol";
import "./Utils/AMTConstants.sol";
import "./Interfaces/IAMTConfig.sol";

contract AMTDepositPool is IAMTDepositPool, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    IAMTConfig public config;
    uint256 public totalDeposits;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _config) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AMTConstants.ADMIN_ROLE, msg.sender);

        config = IAMTConfig(_config);
        totalDeposits = 0;
    }

    function getArtMetisAmountToMint(uint256 _amount)
        public
        view
        returns
        (uint256) {
        if (totalDeposits == 0) {
            return _amount;
        }
        return _amount * IERC20(config.getContract(AMTConstants.ART_METIS)).totalSupply() / totalDeposits;
    }

    function deposit(uint256 _minArtMetisAmountToReceive, string calldata _referralId)
        updateTotalDeposits
        external
        payable
        returns
        (uint256) {
        require(msg.value > 0, "AMTDepositPool: INVALID_AMOUNT");

        uint256 artMetisAmount = getArtMetisAmountToMint(msg.value);

        require(
            artMetisAmount >= _minArtMetisAmountToReceive,
            "AMTDepositPool: artMetis is too high"
        );
        totalDeposits += msg.value;
        IArtMetis(config.getContract(AMTConstants.ART_METIS)).mint(msg.sender, artMetisAmount);

        emit MetisDeposited(msg.sender, msg.value, artMetisAmount, _referralId);
        return artMetisAmount;
    }

    function harvest() public {
        uint256 reward = IAMTRewardPool(config.getContract(AMTConstants.AMT_REWARD_POOL)).claimReward();
        if (reward == 0) {
            return;
        }
        totalDeposits += reward;
        emit Harvested(msg.sender, reward);
    }

    function bridgeMetisToL1() external onlyRole(AMTConstants.ADMIN_ROLE) {
        address l1StakingPool = config.getContract(AMTConstants.L1_STAKING_POOL);
        require(l1StakingPool != address(0), "AMTDepositPool: INVALID_L1_STAKING_POOL");
        uint256 balance = address(this).balance;
        if (balance == 0) {
            return;
        }
        IL2Bridge(IMetis(config.getContract(AMTConstants.METIS)).l2Bridge()).withdrawMetisTo(
            l1StakingPool,
            balance,
            0,
            ""
        );
        emit BridgeMetisToL1(msg.sender, balance);
    }

    modifier updateTotalDeposits() {
        harvest();
        _;
    }

    receive() external payable {}
}