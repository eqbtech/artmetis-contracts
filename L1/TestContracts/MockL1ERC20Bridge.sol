// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Interfaces/Metis/IL1ERC20Bridge.sol";

contract MockL1ERC20Bridge is IL1ERC20Bridge {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public l2Balances;

    function depositERC20ToByChainId(
        uint256,
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32,
        bytes calldata _data
    ) external payable {
        IERC20(_l1Token).transferFrom(msg.sender, address(this), _amount);
        l2Balances[_to] += _amount;
    }
}