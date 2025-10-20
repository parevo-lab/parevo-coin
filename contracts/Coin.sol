// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Coin is ERC20, ERC20Burnable, Pausable, AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    constructor(string memory name_, string memory symbol_, address adminMultisig, uint256 initialSupply) ERC20(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, adminMultisig);
        _grantRole(OPERATOR_ROLE, adminMultisig);
        _grantRole(TREASURY_ROLE, adminMultisig);
        _mint(adminMultisig, initialSupply);
    }

    function pause() external onlyRole(OPERATOR_ROLE) { _pause(); }
    function unpause() external onlyRole(OPERATOR_ROLE) { _unpause(); }

    function mint(address to, uint256 amount) external onlyRole(TREASURY_ROLE) {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        require(!paused(), "PAI: paused");
        super._update(from, to, value);
    }
}


