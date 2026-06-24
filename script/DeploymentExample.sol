// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SecureStakingVault, IERC20Minimal} from "../src/SecureStakingVault.sol";

/// @title DeploymentExample
/// @notice Dependency-free deployment helper. For a real network deployment, wire this into
/// Foundry broadcast scripts or your preferred deployment pipeline.
contract DeploymentExample {
    event VaultDeployed(address indexed vault, address indexed asset, address indexed rewardToken, address owner);

    function deploy(
        address asset,
        address rewardToken,
        address owner,
        address feeRecipient
    ) external returns (SecureStakingVault vault) {
        vault = new SecureStakingVault(
            IERC20Minimal(asset),
            IERC20Minimal(rewardToken),
            "Secure Staking Vault Share",
            "svTOKEN",
            owner,
            feeRecipient
        );

        emit VaultDeployed(address(vault), asset, rewardToken, owner);
    }
}
