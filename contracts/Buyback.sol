// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IUniswapV2Router} from "./interfaces/IUniswapV2Router.sol";

contract Buyback is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IERC20 public immutable baseToken; // USDC/WETH/BNB etc.
    IERC20 public immutable paiToken;  // PAI
    IUniswapV2Router public immutable router;

    address[] public path; // base -> PAI
    uint256 public minOutBps = 9900; // 99% slippage limit

    event BuybackPerformed(uint256 baseSpent, uint256 paiBought, bool burned);
    event PathUpdated(address[] path);
    event MinOutBpsUpdated(uint256 bps);

    constructor(address adminMultisig, IERC20 _base, IERC20 _pai, IUniswapV2Router _router, address[] memory _path) {
        _grantRole(DEFAULT_ADMIN_ROLE, adminMultisig);
        _grantRole(OPERATOR_ROLE, adminMultisig);
        baseToken = _base;
        paiToken = _pai;
        router = _router;
        path = _path;
    }

    function setPath(address[] calldata _path) external onlyRole(OPERATOR_ROLE) {
        require(_path.length >= 2 && _path[0] == address(baseToken) && _path[_path.length-1] == address(paiToken), "path");
        path = _path;
        emit PathUpdated(_path);
    }

    function setMinOutBps(uint256 bps) external onlyRole(OPERATOR_ROLE) {
        require(bps <= 10000, "bps");
        minOutBps = bps;
        emit MinOutBpsUpdated(bps);
    }

    function perform(uint256 amountIn, bool burnOut) external onlyRole(OPERATOR_ROLE) nonReentrant {
        require(amountIn > 0, "amount");
        baseToken.safeIncreaseAllowance(address(router), amountIn);
        uint256 balBefore = paiTokenBalance();
        uint256 minOut = amountIn * minOutBps / 10000; // simplistic: assumes ~1:1 priced path for example; adjust per oracle
        router.swapExactTokensForTokens(amountIn, minOut, path, address(this), block.timestamp + 900);
        uint256 bought = paiTokenBalance() - balBefore;
        if (burnOut) {
            // burn by sending to address(0)
            paiToken.safeTransfer(address(0x000000000000000000000000000000000000dEaD), bought);
        }
        emit BuybackPerformed(amountIn, bought, burnOut);
    }

    function fund(uint256 amount) external onlyRole(OPERATOR_ROLE) {
        baseToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function paiTokenBalance() public view returns (uint256) { return IERC20(paiToken).balanceOf(address(this)); }
}


