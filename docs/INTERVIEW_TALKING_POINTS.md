# Interview Talking Points

## Why no OpenZeppelin imports?

For a hiring sample, I wanted reviewers to inspect the complete logic quickly. In production, I would normally use audited primitives from OpenZeppelin, Solady, or an internally audited library set.

## Why track `totalStaked` separately?

Raw token balances can be polluted by accidental transfers, reward funding, or unrelated token balances. Vault accounting should depend on explicit state transitions, not only on `asset.balanceOf(address(this))`.

## Why update rewards before share transfers?

Rewards earned before a transfer should stay with the original holder. After `_updateRewards(from)` and `_updateRewards(to)`, the new balances start earning from the current `accRewardPerShare`.

## What are the key edge cases?

- first deposit when `totalSupply == 0`
- rounding to zero shares
- full withdrawal
- reward funding when there are no shares
- reward accounting after share transfer
- fees on deposits and withdrawals
- non-owner admin calls
- paused deposits

## What would I add for a production DeFi protocol?

- external audit
- stronger invariant tests
- fork tests
- gas snapshots
- multisig and timelock
- monitoring and alerting
- incident runbooks
- storage layout checks for upgradeable deployments
- formal review of non-standard tokens
- ERC4626 compliance if the product requires standard vault integrations

## How this maps to protocol work

The repository is intentionally small, but the same principles apply to larger DeFi systems:

- explicit accounting
- limited trust assumptions
- separation of roles
- clear events
- security-first tests
- clean documentation
- careful review of edge cases
