# Security Review Notes

This document explains the main risk controls in the demo contract and the remaining work required before production deployment.

## Controls included

### Reentrancy protection

`deposit`, `withdrawShares`, `claimRewards`, and `addRewards` use `nonReentrant` because they perform external token calls.

### Checks before effects before interactions

Critical validation is performed before state updates and token transfers. User reward state is updated before share balances change.

### Explicit vault accounting

The vault uses `totalStaked` instead of relying on the raw ERC20 balance of the contract. This avoids accounting pollution from reward funding, donations, or unrelated token transfers.

### Fee cap

Fees are capped at `MAX_FEE_BPS = 200`, or 2%. This prevents a compromised or careless owner from setting extreme fees in this demo design.

### Two-step ownership transfer

Ownership transfer requires a pending owner to accept, reducing the risk of transferring ownership to a wrong address.

### Reward funding protection

`addRewards` reverts when there are no shares. This avoids accidentally trapping reward tokens before there are users to distribute them to.

### Reward accounting on share transfer

Both sender and receiver rewards are updated before share balances move. This prevents old rewards from being transferred incorrectly with shares.

## Known limitations

### Not audited

The contract is a demo and has not been audited.

### Token assumptions

The implementation assumes standard ERC20 behavior. Fee-on-transfer, rebasing, ERC777-style hooks, blacklisting tokens, or malicious tokens require additional handling.

### No timelock

Production admin changes should normally use a multisig and timelock.

### No upgradeability

The demo is intentionally not upgradeable. A production upgradeable version would need storage-layout tests and proxy-specific review.

### No emergency withdrawal policy

A production system should define an emergency withdrawal mechanism and its governance rules.

### No formal verification

The repo includes unit and fuzz-style tests, but not formal verification or exhaustive invariants.

## Suggested Slither review

Run:

```bash
slither . --config-file slither.config.json
```

Review findings manually. Static analyzers can report false positives, so every finding should be triaged with context.
