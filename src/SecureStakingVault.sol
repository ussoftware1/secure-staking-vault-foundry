// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IERC20Minimal
/// @notice Minimal ERC20 interface used by the vault.
interface IERC20Minimal {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title SafeTransferLib
/// @notice Handles ERC20 tokens that either return a boolean or return no value.
library SafeTransferLib {
    error SafeTransferFailed();
    error SafeTransferFromFailed();

    function safeTransfer(IERC20Minimal token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert SafeTransferFailed();
    }

    function safeTransferFrom(IERC20Minimal token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, amount)
        );
        if (!ok || (data.length != 0 && !abi.decode(data, (bool)))) revert SafeTransferFromFailed();
    }
}

/// @title SecureStakingVault
/// @notice Self-contained Solidity demo for a security-focused ERC20 staking vault.
/// @dev This is a portfolio/interview sample, not audited production code.
contract SecureStakingVault {
    using SafeTransferLib for IERC20Minimal;

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error ZeroAddress();
    error ZeroAmount();
    error Paused();
    error NotOwner();
    error NotPendingOwner();
    error NotRewardManager();
    error FeeTooHigh();
    error NoShares();
    error InsufficientBalance();
    error InsufficientAllowance();
    error Reentrancy();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares, uint256 fee);
    event Withdraw(address indexed caller, address indexed owner, address indexed receiver, uint256 assets, uint256 shares, uint256 fee);
    event RewardsAdded(address indexed caller, uint256 amount, uint256 newAccRewardPerShare);
    event RewardsClaimed(address indexed account, address indexed receiver, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RewardManagerUpdated(address indexed previousRewardManager, address indexed newRewardManager);
    event FeeRecipientUpdated(address indexed previousFeeRecipient, address indexed newFeeRecipient);
    event FeesUpdated(uint16 depositFeeBps, uint16 withdrawalFeeBps);
    event PausedUpdated(bool paused);

    // ---------------------------------------------------------------------
    // Constants and immutable configuration
    // ---------------------------------------------------------------------

    uint256 public constant BPS = 10_000;
    uint256 public constant ACC_REWARD_PRECISION = 1e27;
    uint16 public constant MAX_FEE_BPS = 200; // 2% cap for this demo.

    IERC20Minimal public immutable asset;
    IERC20Minimal public immutable rewardToken;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // ---------------------------------------------------------------------
    // ERC20 share accounting
    // ---------------------------------------------------------------------

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ---------------------------------------------------------------------
    // Vault and reward accounting
    // ---------------------------------------------------------------------

    uint256 public totalStaked;
    uint256 public accRewardPerShare;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public accruedRewards;

    // ---------------------------------------------------------------------
    // Administration
    // ---------------------------------------------------------------------

    address public owner;
    address public pendingOwner;
    address public rewardManager;
    address public feeRecipient;
    uint16 public depositFeeBps;
    uint16 public withdrawalFeeBps;
    bool public paused;

    uint256 private locked = 1;

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRewardManager() {
        if (msg.sender != rewardManager && msg.sender != owner) revert NotRewardManager();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (locked != 1) revert Reentrancy();
        locked = 2;
        _;
        locked = 1;
    }

    constructor(
        IERC20Minimal asset_,
        IERC20Minimal rewardToken_,
        string memory name_,
        string memory symbol_,
        address owner_,
        address feeRecipient_
    ) {
        if (address(asset_) == address(0) || address(rewardToken_) == address(0)) revert ZeroAddress();
        if (owner_ == address(0) || feeRecipient_ == address(0)) revert ZeroAddress();

        asset = asset_;
        rewardToken = rewardToken_;
        name = name_;
        symbol = symbol_;
        owner = owner_;
        rewardManager = owner_;
        feeRecipient = feeRecipient_;

        emit OwnershipTransferred(address(0), owner_);
        emit RewardManagerUpdated(address(0), owner_);
        emit FeeRecipientUpdated(address(0), feeRecipient_);
    }

    // ---------------------------------------------------------------------
    // ERC20 share-token functions
    // ---------------------------------------------------------------------

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transferShares(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }

        _transferShares(from, to, amount);
        return true;
    }

    // ---------------------------------------------------------------------
    // User actions
    // ---------------------------------------------------------------------

    /// @notice Deposit staking assets and mint vault shares to receiver.
    /// @param assets Amount of underlying asset to transfer into the vault.
    /// @param receiver Address receiving vault shares.
    /// @return shares Amount of vault shares minted.
    function deposit(uint256 assets, address receiver)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        uint256 fee = (assets * depositFeeBps) / BPS;
        uint256 netAssets = assets - fee;
        shares = convertToShares(netAssets);
        if (shares == 0) revert NoShares();

        _updateRewards(receiver);

        asset.safeTransferFrom(msg.sender, address(this), assets);
        if (fee != 0) asset.safeTransfer(feeRecipient, fee);

        totalStaked += netAssets;
        _mintShares(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares, fee);
    }

    /// @notice Burn shares and withdraw the proportional amount of staking assets.
    /// @param shares Amount of shares to burn.
    /// @param receiver Address receiving the withdrawn assets.
    /// @param shareOwner Address whose shares are burned.
    /// @return assets Gross amount removed from vault accounting before withdrawal fee.
    function withdrawShares(uint256 shares, address receiver, address shareOwner)
        external
        nonReentrant
        returns (uint256 assets)
    {
        if (shares == 0) revert ZeroAmount();
        if (receiver == address(0) || shareOwner == address(0)) revert ZeroAddress();
        if (balanceOf[shareOwner] < shares) revert InsufficientBalance();

        if (msg.sender != shareOwner) {
            uint256 allowed = allowance[shareOwner][msg.sender];
            if (allowed != type(uint256).max) {
                if (allowed < shares) revert InsufficientAllowance();
                unchecked {
                    allowance[shareOwner][msg.sender] = allowed - shares;
                }
                emit Approval(shareOwner, msg.sender, allowance[shareOwner][msg.sender]);
            }
        }

        _updateRewards(shareOwner);

        assets = convertToAssets(shares);
        uint256 fee = (assets * withdrawalFeeBps) / BPS;
        uint256 netAssets = assets - fee;

        _burnShares(shareOwner, shares);
        totalStaked -= assets;

        asset.safeTransfer(receiver, netAssets);
        if (fee != 0) asset.safeTransfer(feeRecipient, fee);

        emit Withdraw(msg.sender, shareOwner, receiver, assets, shares, fee);
    }

    /// @notice Claim accrued reward tokens.
    /// @param receiver Address receiving the reward tokens.
    /// @return amount Amount claimed.
    function claimRewards(address receiver) external nonReentrant returns (uint256 amount) {
        if (receiver == address(0)) revert ZeroAddress();
        _updateRewards(msg.sender);

        amount = accruedRewards[msg.sender];
        if (amount == 0) revert ZeroAmount();
        accruedRewards[msg.sender] = 0;

        rewardToken.safeTransfer(receiver, amount);
        emit RewardsClaimed(msg.sender, receiver, amount);
    }

    // ---------------------------------------------------------------------
    // Reward funding
    // ---------------------------------------------------------------------

    /// @notice Fund rewards and distribute them pro-rata over current shares.
    /// @dev Reverts when there are no shares to avoid accidentally trapping rewards.
    function addRewards(uint256 amount) external nonReentrant onlyRewardManager {
        if (amount == 0) revert ZeroAmount();
        if (totalSupply == 0) revert NoShares();

        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        accRewardPerShare += (amount * ACC_REWARD_PRECISION) / totalSupply;

        emit RewardsAdded(msg.sender, amount, accRewardPerShare);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function convertToShares(uint256 assets_) public view returns (uint256) {
        if (assets_ == 0) return 0;
        if (totalSupply == 0 || totalStaked == 0) return assets_;
        return (assets_ * totalSupply) / totalStaked;
    }

    function convertToAssets(uint256 shares_) public view returns (uint256) {
        if (shares_ == 0) return 0;
        if (totalSupply == 0) return shares_;
        return (shares_ * totalStaked) / totalSupply;
    }

    function pendingRewards(address account) public view returns (uint256) {
        uint256 accumulated = (balanceOf[account] * accRewardPerShare) / ACC_REWARD_PRECISION;
        if (accumulated < rewardDebt[account]) return accruedRewards[account];
        return accruedRewards[account] + accumulated - rewardDebt[account];
    }

    // ---------------------------------------------------------------------
    // Owner functions
    // ---------------------------------------------------------------------

    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PausedUpdated(paused_);
    }

    function setRewardManager(address newRewardManager) external onlyOwner {
        if (newRewardManager == address(0)) revert ZeroAddress();
        emit RewardManagerUpdated(rewardManager, newRewardManager);
        rewardManager = newRewardManager;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0)) revert ZeroAddress();
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    function setFees(uint16 newDepositFeeBps, uint16 newWithdrawalFeeBps) external onlyOwner {
        if (newDepositFeeBps > MAX_FEE_BPS || newWithdrawalFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        depositFeeBps = newDepositFeeBps;
        withdrawalFeeBps = newWithdrawalFeeBps;
        emit FeesUpdated(newDepositFeeBps, newWithdrawalFeeBps);
    }

    function transferOwnership(address newPendingOwner) external onlyOwner {
        if (newPendingOwner == address(0)) revert ZeroAddress();
        pendingOwner = newPendingOwner;
        emit OwnershipTransferStarted(owner, newPendingOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        address previousOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, owner);
    }

    // ---------------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------------

    function _updateRewards(address account) internal {
        if (account == address(0)) return;

        uint256 accumulated = (balanceOf[account] * accRewardPerShare) / ACC_REWARD_PRECISION;
        uint256 debt = rewardDebt[account];
        if (accumulated > debt) {
            accruedRewards[account] += accumulated - debt;
        }
        rewardDebt[account] = accumulated;
    }

    function _mintShares(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        rewardDebt[to] = (balanceOf[to] * accRewardPerShare) / ACC_REWARD_PRECISION;
        emit Transfer(address(0), to, amount);
    }

    function _burnShares(address from, uint256 amount) internal {
        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }
        rewardDebt[from] = (balanceOf[from] * accRewardPerShare) / ACC_REWARD_PRECISION;
        emit Transfer(from, address(0), amount);
    }

    function _transferShares(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();

        _updateRewards(from);
        _updateRewards(to);

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }

        rewardDebt[from] = (balanceOf[from] * accRewardPerShare) / ACC_REWARD_PRECISION;
        rewardDebt[to] = (balanceOf[to] * accRewardPerShare) / ACC_REWARD_PRECISION;

        emit Transfer(from, to, amount);
    }
}
