// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @title IDamanCredit
/// @notice Permissionless agent credit primitive. Registered agents at
///         (low or zero) USDC balance may borrow a small amount of USDC
///         from a benevolent treasury. Zero interest. Per-borrower cap.
///         Repaid from earned bounty.
///
///         Two entry points:
///         - `requestLoan(amount)`: borrower self-submits and pays gas.
///         - `requestLoanWithSignature(req, signature)`: any relayer
///           (typically a `daman-relief` bee) submits an EIP-712 signed
///           request on behalf of a bee that has gone fully bust. The
///           debt anchors to `req.borrower`; the relayer is invisible
///           to the debt model and pays only gas.
///
///         The signed-request path is a wakala arrangement structurally:
///         the relayer is a procuration agent for the borrower, not a
///         guarantor. The contract enforces this by binding the debt
///         to the signed payload's `borrower` field, never to
///         `msg.sender`.
interface IDamanCredit {
    struct LoanRequest {
        address borrower;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
    }

    event LoanRequested(address indexed borrower, uint256 amount, uint256 totalDebt);
    event LoanRequestedViaRelief(
        address indexed borrower,
        address indexed relayer,
        uint256 amount,
        uint256 totalDebt
    );
    event LoanRepaid(address indexed borrower, uint256 amount, uint256 remainingDebt);
    event TreasuryFunded(address indexed funder, uint256 amount);

    error NotRegistered();
    error NotEligible();
    error ExceedsBorrowerCap();
    error ExceedsTreasuryAvailable();
    error NoActiveDebt();
    error AmountExceedsDebt();
    error SignatureExpired();
    error InvalidNonce();
    error InvalidSignature();
    error ZeroAmount();

    function requestLoan(uint256 amount) external;

    function requestLoanWithSignature(LoanRequest calldata req, bytes calldata signature)
        external;

    function repay(uint256 amount) external;

    function debtOf(address borrower) external view returns (uint256);

    function nonceOf(address borrower) external view returns (uint256);

    function isEligible(address candidate) external view returns (bool);

    function treasuryAvailable() external view returns (uint256);
}
