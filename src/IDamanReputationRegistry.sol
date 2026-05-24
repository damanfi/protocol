// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {IReputationRegistry} from "reverbprotocol/IReputationRegistry.sol";

/// @title IDamanReputationRegistry
/// @notice Daman-specific extension to the substrate `IReputationRegistry`.
///         Adds permissionless agent self-registration and a public
///         `lastActivity(address)` getter consumed by `DamanBenevolence`
///         for the active-but-bust credit-eligibility path.
///
///         Self-register declares existence and role. It does not write
///         reputation score: only authorized recorders can move score.
interface IDamanReputationRegistry is IReputationRegistry {
    event AgentRegistered(address indexed agent, bytes32 role);

    error AlreadyRegistered();

    /// @notice Permissionless self-register. Sets the role anchor and
    ///         initial activity timestamp. Idempotent reverts via
    ///         `AlreadyRegistered`.
    /// @param role  Free-form role identifier. Canonical values:
    ///              `keccak256("leader")`, `keccak256("follower")`,
    ///              `keccak256("watchdog")`, `keccak256("arbiter")`,
    ///              `keccak256("relief")`.
    function register(bytes32 role) external;

    /// @notice True iff `agent` has self-registered (role anchor set).
    function isRegistered(address agent) external view returns (bool);

    /// @notice Timestamp of the most recent activity. Updated on
    ///         self-register and on every authorized `recordUpheld` /
    ///         `recordRejected` call against the agent.
    function lastActivity(address agent) external view returns (uint256);
}
