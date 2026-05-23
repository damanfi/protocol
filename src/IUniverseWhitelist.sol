// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @title IUniverseWhitelist. The wire-protocol for asset-universe screening on Daman.
/// @notice **This interface is the standard.** Daman's flagship deployment
///         screens against an asset-screening informed universe
///         sourced from HLAL (Wahed-FTSE-USA) ETF holdings, but the
///         interface is curation-agnostic. Other deployments may screen
///         against ESG indices, sector lists, sanctions lists, or any
///         other curation. The copy-bond contract calls `isEligible`
///         on every trade record; the screening logic lives entirely
///         in the implementation.
///
/// @dev Why an interface, not just a contract:
///        - **Curation diversity.** Same protocol, different universes.
///        - **List provenance.** Implementations may source from on-chain
///          oracles, off-chain attested lists, or hardcoded constants.
///          The interface is silent on provenance.
///        - **Mutability policy.** Some implementations may freeze the
///          list at deploy; others may update on each rebalance window.
///          The interface exposes the read shape only.
interface IUniverseWhitelist {
    /// @notice Emitted when an asset is added to the eligible universe.
    event AssetAdded(address indexed asset, bytes32 source);

    /// @notice Emitted when an asset is removed from the eligible universe.
    event AssetRemoved(address indexed asset, bytes32 reason);

    /// @notice Emitted when the curation source updates (rebalance, attestation, etc.).
    event UniverseUpdated(bytes32 indexed sourceTag, uint64 updatedAt);

    error AssetAlreadyListed(address asset);
    error AssetNotListed(address asset);
    error UnauthorizedCurator(address caller);

    /// @notice Returns true if `asset` is currently eligible for trading
    ///         under this universe's curation rules.
    function isEligible(address asset) external view returns (bool);

    /// @notice Returns the full set of currently-eligible assets. Implementations
    ///         backed by large universes may revert or paginate; consumers
    ///         should prefer `isEligible` for hot-path checks.
    function listAssets() external view returns (address[] memory);

    /// @notice Add an asset to the eligible universe. Implementations decide
    ///         curator policy: single owner, multisig, oracle-driven, etc.
    function addAsset(address asset, bytes32 source) external;

    /// @notice Remove an asset from the eligible universe.
    function removeAsset(address asset, bytes32 reason) external;

    /// @notice An opaque tag identifying the curation source (e.g.
    ///         `keccak256("HLAL_2026Q2")`). Lets consumers verify which
    ///         curation snapshot is in force without reading the full list.
    function sourceTag() external view returns (bytes32);

    /// @notice Timestamp of the most recent universe update.
    function lastUpdatedAt() external view returns (uint64);
}
