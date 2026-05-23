// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @title BondEconomics. Tier constants and slash math for slash-bonded copy-trading.
/// @notice Library, not a deployed contract. Implementations of `IDamanCopyBond`
///         import these constants and helpers so the bond-to-AUM ratio and
///         per-dispute slash ceiling stay uniform across protocol-conformant
///         deployments.
///
/// @dev The numbers below are basis points (1 bp = 0.01%). Tier ratios are
///      the share of self-reported AUM that the leader must post as USDC bond
///      before they can be advertised as active. The slash cap bounds the
///      fraction of currently-posted bond that any single dispute may seize.
///
///      Tier framework:
///        Retail:        leader claims AUM up to $250k. 10% bond.
///        Mid:           leader claims AUM up to $5M.   5%  bond.
///        Institutional: leader claims AUM above $5M.   2.5% bond floor (3% ceiling).
///
///      Implementations MAY override the AUM thresholds that map to tiers,
///      but the bond ratio and slash cap constants below are protocol-level
///      defaults; deviating from them produces a non-conformant deployment.
library BondEconomics {
    /// @notice Retail tier bond requirement, in basis points of claimed AUM. 10%.
    uint16 internal constant RETAIL_BOND_BPS = 1000;

    /// @notice Mid tier bond requirement, in basis points of claimed AUM. 5%.
    uint16 internal constant MID_BOND_BPS = 500;

    /// @notice Institutional tier bond floor, in basis points of claimed AUM. 2.5%.
    uint16 internal constant INSTITUTIONAL_BOND_BPS = 250;

    /// @notice Institutional tier bond ceiling, in basis points of claimed AUM. 3%.
    ///         Implementations may pick any value in `[INSTITUTIONAL_BOND_BPS, INSTITUTIONAL_BOND_BPS_CEIL]`.
    uint16 internal constant INSTITUTIONAL_BOND_BPS_CEIL = 300;

    /// @notice Maximum fraction of currently-posted bond that a single
    ///         dispute may slash, in basis points. 25%.
    uint16 internal constant SLASH_CAP_BPS = 2500;

    /// @notice Denominator for basis-point math. 100% == 10_000.
    uint16 internal constant BPS_DENOMINATOR = 10_000;

    /// @notice Tier identifier mirrored from `IDamanCopyBond.Tier`. Kept in
    ///         sync to let library callers compute requirements without
    ///         importing the full interface.
    enum Tier { Retail, Mid, Institutional }

    error TierInvalid();

    /// @notice Required bond, in the bond token's smallest unit, for a
    ///         leader at `tier` claiming `aum` (also in the bond token's
    ///         smallest unit). For institutional tier, returns the bond
    ///         floor; implementations may charge more up to the ceiling.
    function requiredBondFor(Tier tier, uint256 aum) internal pure returns (uint256) {
        uint16 bps;
        if (tier == Tier.Retail) {
            bps = RETAIL_BOND_BPS;
        } else if (tier == Tier.Mid) {
            bps = MID_BOND_BPS;
        } else if (tier == Tier.Institutional) {
            bps = INSTITUTIONAL_BOND_BPS;
        } else {
            revert TierInvalid();
        }
        return (aum * bps) / BPS_DENOMINATOR;
    }

    /// @notice Maximum slash amount allowed for a single dispute against
    ///         a bond of size `bond`.
    function maxSlashAmount(uint256 bond) internal pure returns (uint256) {
        return (bond * SLASH_CAP_BPS) / BPS_DENOMINATOR;
    }
}
