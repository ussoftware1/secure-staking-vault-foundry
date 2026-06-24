# Secure Staking Vault — Foundry Solidity Demo

A compact, security-focused Solidity repository prepared as a portfolio sample for senior smart-contract roles.

The project demonstrates how I structure, implement, document, and test a staking/vault-style smart contract without hiding the core logic behind external dependencies.

> Status: interview / portfolio demo. Not audited. Do not deploy as-is to mainnet.

## Why this repository exists

This sample is designed to show skills relevant to DeFi smart-contract engineering roles:

- Solidity and EVM-first implementation
- clean vault/share accounting
- reward distribution with `accRewardPerShare`
- custom errors, events, NatSpec comments, and explicit invariants
- access control with two-step ownership transfer
- non-reentrancy protection
- pausing and fee caps
- no OpenZeppelin imports, so reviewers can inspect the complete implementation directly
- Foundry tests, including a fuzz-style round-trip test
- security notes and audit checklist

## Contract overview

`SecureStakingVault` accepts an ERC20 staking asset and mints ERC20-like vault shares. A reward manager can fund a separate reward token. Rewards are distributed pro-rata to current share holders.

Main user actions:

- `deposit(assets, receiver)`
- `withdrawShares(shares, receiver, shareOwner)`
- `claimRewards(receiver)`
- `transfer(...)` / `transferFrom(...)` for vault shares

Main admin actions:

- `setPaused(...)`
- `setRewardManager(...)`
- `setFeeRecipient(...)`
- `setFees(...)`
- `transferOwnership(...)` / `acceptOwnership()`

## Repository structure

```text
.
├── src/
│   ├── SecureStakingVault.sol
│   └── mocks/MockERC20.sol
├── test/
│   └── SecureStakingVault.t.sol
├── script/
│   └── DeploymentExample.sol
├── docs/
│   ├── ARCHITECTURE.md
│   ├── SECURITY_REVIEW.md
│   ├── AUDIT_CHECKLIST.md
│   ├── INTERVIEW_TALKING_POINTS.md
│   └── PROPOSAL_SNIPPET.md
├── .github/workflows/ci.yml
├── foundry.toml
├── slither.config.json
├── Makefile
└── README.md
```

## Quick start

Install Foundry first, then run:

```bash
git clone <your-repo-url>
cd secure-staking-vault-foundry
forge build
forge test -vvv
```

Optional static analysis:

```bash
slither . --config-file slither.config.json
```

## Test coverage highlights

The test suite covers:

- deposit and share minting
- withdrawal and share burning
- fee accounting and fee caps
- pro-rata reward accrual and claiming
- reward accounting across share transfers
- access-control restrictions
- paused deposit behavior
- fuzzed deposit/withdraw round trip

## Security assumptions

This repository intentionally focuses on a small and inspectable scope. Important assumptions:

- staking asset and reward token are standard ERC20-compatible tokens
- owner is expected to be a multisig in production
- fee cap is intentionally low for user protection
- reward funding reverts when no shares exist to avoid trapped rewards
- oracle pricing, liquidations, slashing, validator lifecycle, and upgradeability are intentionally out of scope

See [`docs/SECURITY_REVIEW.md`](docs/SECURITY_REVIEW.md) and [`docs/AUDIT_CHECKLIST.md`](docs/AUDIT_CHECKLIST.md).

## Interview discussion points

This repo is useful for discussing:

- why `totalStaked` is tracked separately from raw token balance
- why reward debt must be updated before mint/burn/transfer
- why fee caps and two-step ownership reduce governance risk
- how rounding affects share accounting
- what would change for ERC4626 compatibility
- what additional work is required before production deployment

## Production hardening ideas

Before production use, I would add:

- full ERC4626 compatibility, if required
- OpenZeppelin or Solady audited primitives
- formal invariant tests
- integration tests on a fork
- multisig ownership and timelock
- emergency withdrawal design review
- external audit
- deployment scripts with deterministic verification
- monitoring, alerting, and admin runbooks

## License

MIT
