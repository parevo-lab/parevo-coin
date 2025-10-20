// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Staking is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IERC20 public immutable stakeToken; // PAI
    IERC20 public immutable rewardToken; // PAI (same) or other stable if desired

    uint256 public rewardRatePerSecond; // tokens per second per 1e18 staked
    uint256 public lockupDuration; // seconds

    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt; // accumulated till last update
        uint64 lastUpdate;
        uint64 lockStart;
    }

    mapping(address => StakeInfo) public stakes;

    uint256 public accRewardPerShare; // scaled by 1e18
    uint256 public lastRewardTime;
    uint256 public totalStaked;

    uint256 private constant ACC_SCALE = 1e18;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event Harvest(address indexed user, uint256 reward);
    event ParamsUpdated(uint256 rewardRatePerSecond, uint256 lockupDuration);

    constructor(
        address adminMultisig,
        IERC20 _stakeToken,
        IERC20 _rewardToken,
        uint256 _rewardRatePerSecond,
        uint256 _lockupDuration
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, adminMultisig);
        _grantRole(OPERATOR_ROLE, adminMultisig);
        stakeToken = _stakeToken;
        rewardToken = _rewardToken;
        rewardRatePerSecond = _rewardRatePerSecond;
        lockupDuration = _lockupDuration;
        lastRewardTime = block.timestamp;
    }

    function setParams(uint256 _rate, uint256 _lock) external onlyRole(OPERATOR_ROLE) {
        _updatePool();
        rewardRatePerSecond = _rate;
        lockupDuration = _lock;
        emit ParamsUpdated(_rate, _lock);
    }

    function pendingReward(address user) public view returns (uint256) {
        StakeInfo memory s = stakes[user];
        uint256 _acc = accRewardPerShare;
        if (block.timestamp > lastRewardTime && totalStaked > 0) {
            uint256 delta = block.timestamp - lastRewardTime;
            uint256 reward = delta * rewardRatePerSecond;
            _acc += reward * ACC_SCALE / totalStaked;
        }
        return s.amount * _acc / ACC_SCALE - s.rewardDebt;
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "amount=0");
        _updatePool();
        StakeInfo storage s = stakes[msg.sender];
        if (s.amount > 0) {
            uint256 pending = s.amount * accRewardPerShare / ACC_SCALE - s.rewardDebt;
            if (pending > 0) {
                rewardToken.safeTransfer(msg.sender, pending);
                emit Harvest(msg.sender, pending);
            }
        }
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
        totalStaked += amount;
        s.amount += amount;
        s.rewardDebt = s.amount * accRewardPerShare / ACC_SCALE;
        s.lastUpdate = uint64(block.timestamp);
        if (s.lockStart == 0) s.lockStart = uint64(block.timestamp);
        emit Staked(msg.sender, amount);
    }

    function harvest() external nonReentrant {
        _updatePool();
        StakeInfo storage s = stakes[msg.sender];
        uint256 pending = s.amount * accRewardPerShare / ACC_SCALE - s.rewardDebt;
        require(pending > 0, "no rewards");
        s.rewardDebt = s.amount * accRewardPerShare / ACC_SCALE;
        rewardToken.safeTransfer(msg.sender, pending);
        emit Harvest(msg.sender, pending);
    }

    function unstake(uint256 amount) external nonReentrant {
        StakeInfo storage s = stakes[msg.sender];
        require(amount > 0 && amount <= s.amount, "bad amount");
        require(block.timestamp >= s.lockStart + lockupDuration, "locked");
        _updatePool();
        uint256 pending = s.amount * accRewardPerShare / ACC_SCALE - s.rewardDebt;
        s.amount -= amount;
        totalStaked -= amount;
        s.rewardDebt = s.amount * accRewardPerShare / ACC_SCALE;
        if (pending > 0) {
            rewardToken.safeTransfer(msg.sender, pending);
            emit Harvest(msg.sender, pending);
        }
        stakeToken.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount, pending);
    }

    function fundRewards(uint256 amount) external onlyRole(OPERATOR_ROLE) {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function _updatePool() internal {
        if (block.timestamp <= lastRewardTime) return;
        if (totalStaked == 0) { lastRewardTime = block.timestamp; return; }
        uint256 delta = block.timestamp - lastRewardTime;
        uint256 reward = delta * rewardRatePerSecond;
        accRewardPerShare += reward * ACC_SCALE / totalStaked;
        lastRewardTime = block.timestamp;
    }
}


