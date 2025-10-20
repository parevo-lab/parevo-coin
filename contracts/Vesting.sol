// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Vesting is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IERC20 public immutable token;

    struct Schedule {
        uint256 total;
        uint256 released;
        uint64 start;
        uint64 cliff;
        uint64 duration;
        bool revocable;
        bool revoked;
    }

    mapping(address => Schedule) public schedules;

    event Created(address indexed beneficiary, uint256 total);
    event Released(address indexed beneficiary, uint256 amount);
    event Revoked(address indexed beneficiary, uint256 refund);

    constructor(address adminMultisig, IERC20 _token) {
        _grantRole(DEFAULT_ADMIN_ROLE, adminMultisig);
        _grantRole(OPERATOR_ROLE, adminMultisig);
        token = _token;
    }

    function create(address beneficiary, Schedule calldata s) external onlyRole(OPERATOR_ROLE) {
        require(schedules[beneficiary].total == 0, "exists");
        require(s.duration > 0 && s.cliff >= s.start && s.cliff <= s.start + s.duration, "params");
        schedules[beneficiary] = s;
        emit Created(beneficiary, s.total);
    }

    function vestedAmount(address beneficiary, uint64 timepoint) public view returns (uint256) {
        Schedule memory s = schedules[beneficiary];
        if (s.total == 0 || s.revoked) return 0;
        if (timepoint < s.cliff) return 0;
        if (timepoint >= s.start + s.duration) return s.total;
        uint256 elapsed = timepoint - s.start;
        return s.total * elapsed / s.duration;
    }

    function releasable(address beneficiary) public view returns (uint256) {
        Schedule memory s = schedules[beneficiary];
        uint256 vested = vestedAmount(beneficiary, uint64(block.timestamp));
        if (vested <= s.released) return 0;
        return vested - s.released;
    }

    function release() external nonReentrant {
        Schedule storage s = schedules[msg.sender];
        uint256 amount = releasable(msg.sender);
        require(amount > 0, "nothing");
        s.released += amount;
        token.safeTransfer(msg.sender, amount);
        emit Released(msg.sender, amount);
    }

    function revoke(address beneficiary) external onlyRole(OPERATOR_ROLE) nonReentrant {
        Schedule storage s = schedules[beneficiary];
        require(s.revocable && !s.revoked, "no");
        uint256 vested = vestedAmount(beneficiary, uint64(block.timestamp));
        uint256 refund = s.total - vested;
        s.revoked = true;
        if (refund > 0) token.safeTransfer(msg.sender, refund);
        emit Revoked(beneficiary, refund);
    }
}


