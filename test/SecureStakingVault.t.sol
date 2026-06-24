// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SecureStakingVault, IERC20Minimal} from "../src/SecureStakingVault.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract Actor {
    function approve(MockERC20 token, address spender, uint256 amount) external {
        token.approve(spender, amount);
    }

    function deposit(SecureStakingVault vault, uint256 assets, address receiver) external returns (uint256) {
        return vault.deposit(assets, receiver);
    }

    function withdrawShares(SecureStakingVault vault, uint256 shares, address receiver, address owner) external returns (uint256) {
        return vault.withdrawShares(shares, receiver, owner);
    }

    function claimRewards(SecureStakingVault vault, address receiver) external returns (uint256) {
        return vault.claimRewards(receiver);
    }

    function transferShares(SecureStakingVault vault, address to, uint256 amount) external returns (bool) {
        return vault.transfer(to, amount);
    }

    function setFees(SecureStakingVault vault, uint16 depositFeeBps, uint16 withdrawalFeeBps) external {
        vault.setFees(depositFeeBps, withdrawalFeeBps);
    }
}

contract SecureStakingVaultTest {
    uint256 internal constant WAD = 1e18;

    MockERC20 internal asset;
    MockERC20 internal reward;
    SecureStakingVault internal vault;
    Actor internal alice;
    Actor internal bob;
    Actor internal eve;
    address internal feeRecipient = address(0xFEE);

    function setUp() public {
        asset = new MockERC20("Mock Staked ETH", "mETH", 18);
        reward = new MockERC20("Mock Reward", "RWD", 18);
        vault = new SecureStakingVault(
            IERC20Minimal(address(asset)),
            IERC20Minimal(address(reward)),
            "Secure Staking Vault Share",
            "svETH",
            address(this),
            feeRecipient
        );
        alice = new Actor();
        bob = new Actor();
        eve = new Actor();
    }

    function testDepositMintsSharesAndTracksTotalStaked() public {
        asset.mint(address(alice), 100 * WAD);
        alice.approve(asset, address(vault), type(uint256).max);

        uint256 shares = alice.deposit(vault, 100 * WAD, address(alice));

        assertEq(shares, 100 * WAD, "shares");
        assertEq(vault.balanceOf(address(alice)), 100 * WAD, "alice shares");
        assertEq(vault.totalSupply(), 100 * WAD, "total supply");
        assertEq(vault.totalStaked(), 100 * WAD, "total staked");
        assertEq(asset.balanceOf(address(vault)), 100 * WAD, "vault asset balance");
    }

    function testRewardsAccrueProRataAndCanBeClaimed() public {
        _deposit(address(alice), alice, 100 * WAD);
        _deposit(address(bob), bob, 100 * WAD);

        reward.mint(address(this), 20 * WAD);
        reward.approve(address(vault), 20 * WAD);
        vault.addRewards(20 * WAD);

        assertEq(vault.pendingRewards(address(alice)), 10 * WAD, "alice pending");
        assertEq(vault.pendingRewards(address(bob)), 10 * WAD, "bob pending");

        alice.claimRewards(vault, address(alice));
        bob.claimRewards(vault, address(bob));

        assertEq(reward.balanceOf(address(alice)), 10 * WAD, "alice claimed");
        assertEq(reward.balanceOf(address(bob)), 10 * WAD, "bob claimed");
        assertEq(vault.pendingRewards(address(alice)), 0, "alice no pending");
        assertEq(vault.pendingRewards(address(bob)), 0, "bob no pending");
    }

    function testWithdrawBurnsSharesAndReturnsAssets() public {
        _deposit(address(alice), alice, 100 * WAD);

        alice.withdrawShares(vault, 40 * WAD, address(alice), address(alice));

        assertEq(vault.balanceOf(address(alice)), 60 * WAD, "remaining shares");
        assertEq(vault.totalSupply(), 60 * WAD, "remaining supply");
        assertEq(vault.totalStaked(), 60 * WAD, "remaining staked");
        assertEq(asset.balanceOf(address(alice)), 40 * WAD, "alice received assets");
    }

    function testFeesAreCappedAndAccounted() public {
        vault.setFees(50, 25); // 0.50% deposit fee, 0.25% withdrawal fee.
        _deposit(address(alice), alice, 100 * WAD);

        assertEq(asset.balanceOf(feeRecipient), 0.5 ether, "deposit fee");
        assertEq(vault.totalStaked(), 99.5 ether, "net staked");
        assertEq(vault.balanceOf(address(alice)), 99.5 ether, "net shares");

        alice.withdrawShares(vault, 99.5 ether, address(alice), address(alice));

        assertEq(vault.totalSupply(), 0, "supply after full withdraw");
        assertEq(vault.totalStaked(), 0, "staked after full withdraw");
        assertEq(asset.balanceOf(address(alice)), 99.25125 ether, "withdraw net assets");
        assertEq(asset.balanceOf(feeRecipient), 0.74875 ether, "total fees");
    }

    function testShareTransferPreservesRewardAccounting() public {
        _deposit(address(alice), alice, 100 * WAD);

        reward.mint(address(this), 20 * WAD);
        reward.approve(address(vault), 20 * WAD);
        vault.addRewards(10 * WAD);

        alice.transferShares(vault, address(bob), 40 * WAD);
        vault.addRewards(10 * WAD);

        assertEq(vault.pendingRewards(address(alice)), 16 * WAD, "alice pending after transfer");
        assertEq(vault.pendingRewards(address(bob)), 4 * WAD, "bob pending after transfer");
    }

    function testOnlyOwnerCanSetFees() public {
        bool reverted;
        try eve.setFees(vault, 1, 1) {
            reverted = false;
        } catch {
            reverted = true;
        }
        assertTrue(reverted, "non-owner should not set fees");

        vault.setFees(1, 1);
        assertEq(vault.depositFeeBps(), 1, "owner set deposit fee");
        assertEq(vault.withdrawalFeeBps(), 1, "owner set withdrawal fee");
    }

    function testFeeCapReverts() public {
        bool reverted;
        try this.ownerSetFees(201, 0) {
            reverted = false;
        } catch {
            reverted = true;
        }
        assertTrue(reverted, "fee cap should revert");
    }

    function testPausedDepositReverts() public {
        vault.setPaused(true);
        asset.mint(address(alice), 10 * WAD);
        alice.approve(asset, address(vault), type(uint256).max);

        bool reverted;
        try alice.deposit(vault, 10 * WAD, address(alice)) {
            reverted = false;
        } catch {
            reverted = true;
        }
        assertTrue(reverted, "deposit while paused should revert");
    }

    function testFuzzDepositWithdrawRoundTrip(uint96 rawAmount) public {
        uint256 amount = (uint256(rawAmount) % (1_000_000 * WAD)) + 1;
        _deposit(address(alice), alice, amount);

        uint256 shares = vault.balanceOf(address(alice));
        alice.withdrawShares(vault, shares, address(alice), address(alice));

        assertEq(vault.totalSupply(), 0, "empty supply");
        assertEq(vault.totalStaked(), 0, "empty staked");
        assertEq(asset.balanceOf(address(alice)), amount, "round trip assets");
    }

    function ownerSetFees(uint16 depositFeeBps, uint16 withdrawalFeeBps) external {
        vault.setFees(depositFeeBps, withdrawalFeeBps);
    }

    function _deposit(address account, Actor actor, uint256 amount) internal {
        asset.mint(account, amount);
        actor.approve(asset, address(vault), type(uint256).max);
        actor.deposit(vault, amount, account);
    }

    function assertEq(uint256 actual, uint256 expected, string memory message) internal pure {
        require(actual == expected, message);
    }

    function assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }
}
