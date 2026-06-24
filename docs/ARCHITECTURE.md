# Architecture Notes

## Goal

The goal is to provide a small but realistic staking vault that can be reviewed quickly during a hiring process.

The design favors explicit accounting over hidden abstraction so that reviewers can inspect how deposits, shares, withdrawals, fees, and rewards are calculated.

## Main components

### `SecureStakingVault.sol`

Core vault contract.

Responsibilities:

- accept staking asset deposits
- mint and burn transferable vault shares
- track net staked assets through `totalStaked`
- distribute funded rewards using accumulated reward-per-share accounting
- protect sensitive operations with access control
- protect external token-transfer flows with `nonReentrant`

### `MockERC20.sol`

Minimal test token used only by the local test suite.

### `SecureStakingVault.t.sol`

Dependency-free Foundry tests. The tests do not import `forge-std`, which keeps the repo small and self-contained.

## Accounting model

The vault uses a share-based accounting model:

```solidity
shares = assets * totalSupply / totalStaked
assets = shares * totalStaked / totalSupply
```

When the vault is empty, the initial exchange rate is 1 asset = 1 share.

`totalStaked` is intentionally separate from `asset.balanceOf(address(this))` because the contract may also hold reward tokens, accidentally transferred tokens, or assets not meant to be part of vault accounting.

## Reward model

Rewards use the standard accumulated reward-per-share pattern:

```solidity
accRewardPerShare += amount * 1e27 / totalSupply
pending = balanceOf[user] * accRewardPerShare / 1e27 - rewardDebt[user]
```

Before any user balance changes, `_updateRewards(user)` is called. This preserves pending rewards across deposits, withdrawals, and share transfers.

## Admin model

The owner can:

- pause deposits
- set reward manager
- set fee recipient
- set deposit/withdrawal fees within a hard cap
- start two-step ownership transfer

The reward manager can fund rewards. The owner can also fund rewards as an emergency/admin fallback.

## Non-goals

This demo intentionally does not include:

- validator lifecycle management
- slashing logic
- oracle pricing
- upgradeable proxy pattern
- liquid staking token exchange-rate logic
- ERC4626 compliance
- cross-chain messaging
- ZK circuits

Those are valuable production topics but would make this interview sample less focused.
