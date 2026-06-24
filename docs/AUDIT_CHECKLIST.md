# Audit Checklist

## Access control

- [x] Owner-only functions use `onlyOwner`
- [x] Reward funding uses `onlyRewardManager`
- [x] Ownership transfer is two-step
- [ ] Production owner should be a multisig
- [ ] Production admin changes should be timelocked

## Accounting

- [x] `totalStaked` is separated from raw token balance
- [x] deposits mint shares based on pre-deposit exchange rate
- [x] withdrawals burn shares and reduce `totalStaked`
- [x] deposit and withdrawal fees are accounted explicitly
- [x] fee values are capped
- [ ] production version should define behavior for fee-on-transfer tokens
- [ ] production version should add stronger invariant tests

## Rewards

- [x] reward debt is updated before balance changes
- [x] rewards are distributed pro-rata
- [x] reward funding reverts when no shares exist
- [x] share transfer preserves existing pending rewards
- [ ] production version should consider reward-token insolvency monitoring

## External calls

- [x] ERC20 transfers use safe low-level calls
- [x] external token-transfer functions are non-reentrant
- [ ] production version should review non-standard token compatibility

## Testing

- [x] deposit test
- [x] withdrawal test
- [x] fee test
- [x] reward claim test
- [x] share transfer reward test
- [x] access-control test
- [x] pause test
- [x] fuzzed round-trip test
- [ ] add invariant suite
- [ ] add fork tests
- [ ] add gas snapshots

## Deployment

- [x] dependency-free deployment example included
- [ ] add verified network deployment script
- [ ] add multisig ownership handoff script
- [ ] add runbook for emergency/admin actions
