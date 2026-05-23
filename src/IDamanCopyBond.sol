// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @title IDamanCopyBond. The wire-protocol of slash-bonded copy-trading on Daman.
/// @notice **This interface is the standard.** Anyone can deploy a contract
///         implementing it (vanilla, allowlisted, alternate-screening,
///         alternate-bond-tier, whatever) and Daman bees and consumers can
///         read it the same way. There is no canonical Daman-maintainer
///         deployment of an implementation that the protocol requires.
///
/// @dev Lifecycle:
///        1. Leader registers and posts a USDC bond proportional to claimed AUM
///           (10% retail / 5% mid / 2-3% institutional per `BondEconomics`).
///        2. Followers subscribe with delegated capital.
///        3. The implementation records on-platform trade events
///           (`TradeExecuted`) and settlement events (`SettlementCompleted`),
///           and only those. No off-platform feeds inform the bond.
///        4. A watchdog reads on-platform events and may attest degradation;
///           an attestation files a claim against the leader's bond.
///        5. The leader has a dispute window to contest the attestation.
///        6. An arbiter rules on contested claims; ruling either upholds
///           and slashes (capped at 25% per dispute) or rejects.
///        7. After a lockup, the leader may withdraw remaining bond.
///
///      Slash dispatch routes through a separate dispute primitive (see
///      `reverbprotocol/protocol::IRefundProtocol`). This interface
///      describes the copy-bond state machine, not the dispute primitive.
///
///      Why an interface, not just a contract:
///        - **Curation diversity.** Different deployments may screen
///          different asset universes (HLAL-shaped, ESG-shaped, sector-
///          specific) without forking the protocol.
///        - **Tier policy.** Bond-to-AUM ratios live in `BondEconomics`;
///          implementations may extend or replace tier definitions.
///        - **Subnet isolation.** Hum bees in one subnet read against
///          this interface; other subnets do the same against their own
///          deployment.
interface IDamanCopyBond {
    /// @notice Bond tier classifying leader admission and bond ratio.
    enum Tier { Retail, Mid, Institutional }

    /// @notice Claim lifecycle state.
    enum ClaimStatus { None, Filed, Disputed, Upheld, Rejected }

    /// @notice One record per registered leader.
    struct Leader {
        address addr;
        Tier tier;
        uint256 bondAmount;       // currently-posted USDC bond
        uint256 claimedAum;       // self-reported, gates the required bond
        uint64 registeredAt;
        uint64 bondLockedUntil;   // earliest withdraw timestamp
        bool active;
    }

    /// @notice One record per (follower, leader) subscription.
    struct Subscription {
        address follower;
        address leader;
        uint256 capital;          // delegated capital, in USDC
        uint64 since;
    }

    /// @notice One record per degradation claim.
    struct Claim {
        uint256 id;
        address leader;
        address watchdog;
        bytes32 evidenceHash;     // keccak256 of off-chain evidence payload
        uint64 filedAt;
        uint64 disputeWindowEnds;
        ClaimStatus status;
        uint256 slashAmount;      // populated after ruling
    }

    // --- Events ----------------------------------------------------------

    event LeaderRegistered(address indexed leader, Tier tier, uint256 claimedAum, uint256 requiredBond);
    event LeaderBondPosted(address indexed leader, uint256 amount, uint256 totalBond);
    event LeaderDeactivated(address indexed leader, string reason);

    event FollowerSubscribed(address indexed follower, address indexed leader, uint256 capital);
    event FollowerUnsubscribed(address indexed follower, address indexed leader);

    /// @notice On-platform trade event recorded by the operator-side oracle.
    ///         Per ADR-001, the implementation records only trades it executed
    ///         itself; it never imports off-platform trader-performance data.
    event TradeExecuted(
        address indexed leader,
        address indexed asset,
        uint256 amount,
        bool isLong,
        uint64 timestamp
    );

    /// @notice On-platform settlement event recorded by the operator-side oracle.
    event SettlementCompleted(
        address indexed leader,
        uint256 indexed tradeId,
        int256 pnl,
        uint64 timestamp
    );

    event DegradationFlagged(
        uint256 indexed claimId,
        address indexed leader,
        address indexed watchdog,
        bytes32 evidenceHash
    );
    event DisputeOpened(uint256 indexed claimId, address indexed leader);
    event ArbiterRuled(uint256 indexed claimId, uint256 slashAmount, bool upheld);
    event BondSlashed(address indexed leader, uint256 amount, uint256 indexed claimId);
    event BondWithdrawn(address indexed leader, uint256 amount);

    // --- Errors ----------------------------------------------------------

    error NotLeader();
    error NotArbiter();
    error NotWatchdog();
    error AlreadyRegistered();
    error InsufficientBond(uint256 required, uint256 posted);
    error TierInvalid();
    error BondLocked(uint64 unlocksAt);
    error SubscriptionNotFound();
    error AssetNotEligible(address asset);
    error ClaimNotFound(uint256 claimId);
    error DisputeWindowClosed(uint256 claimId);
    error AlreadyDisputed(uint256 claimId);
    error AlreadyRuled(uint256 claimId);
    error SlashCapExceeded(uint16 capBps);
    error ZeroAddress();
    error LeverageNotPermitted();
    error ShortNotPermitted();

    // --- Leader lifecycle ------------------------------------------------

    /// @notice Register as a leader, declaring tier and claimed AUM.
    ///         Bond must be posted in a subsequent call (or atomically by
    ///         the implementation) before the leader is considered active.
    function registerLeader(Tier tier, uint256 claimedAum) external;

    /// @notice Post additional bond. The implementation MUST verify the
    ///         caller has approved the USDC transfer beforehand.
    function postBond(uint256 amount) external;

    /// @notice Withdraw unbonded amount. Implementations MUST enforce the
    ///         per-leader lockup; the `BondLocked` error fires before
    ///         `bondLockedUntil`.
    function withdrawBond(uint256 amount) external;

    // --- Follower lifecycle ----------------------------------------------

    /// @notice Subscribe to a leader's strategy with delegated capital.
    function subscribe(address leader, uint256 capital) external;

    /// @notice End a subscription. Implementations MUST settle any
    ///         pending follower-side capital atomically.
    function unsubscribe(address leader) external;

    // --- Operator-side oracle entry points -------------------------------

    /// @notice Record an on-platform trade. Restricted to the
    ///         operator-side oracle address; the implementation determines
    ///         the access policy.
    function recordTrade(address leader, address asset, uint256 amount, bool isLong) external;

    /// @notice Record an on-platform settlement (PnL). Restricted to the
    ///         operator-side oracle address.
    function recordSettlement(address leader, uint256 tradeId, int256 pnl) external;

    // --- Degradation flow ------------------------------------------------

    /// @notice File a degradation claim against a leader. Returns claim ID.
    ///         The implementation MAY require a watchdog bond or registry
    ///         membership; the interface is silent on watchdog policy.
    function attestDegradation(address leader, bytes32 evidenceHash) external returns (uint256 claimId);

    /// @notice Contest a filed claim. Callable only by the leader named
    ///         in the claim, only before the dispute window closes.
    function disputeAttestation(uint256 claimId) external;

    /// @notice Rule on a contested claim. Restricted to the arbiter address.
    ///         `slashAmount` MUST NOT exceed `BondEconomics.maxSlashAmount(bond)`.
    function arbiterRule(uint256 claimId, uint256 slashAmount, bool upheld) external;

    // --- View accessors --------------------------------------------------

    function getLeader(address leader) external view returns (Leader memory);
    function getClaim(uint256 claimId) external view returns (Claim memory);
    function getSubscription(address follower, address leader) external view returns (Subscription memory);
    function bondBalance(address leader) external view returns (uint256);

    /// @notice Address of the universe whitelist this deployment screens against.
    function universe() external view returns (address);

    /// @notice Address of the dispute primitive (IRefundProtocol-conformant).
    function refundProtocol() external view returns (address);

    /// @notice Address of the USDC token used for bonds and subscriptions.
    function fiatToken() external view returns (address);

    /// @notice Address of the arbiter that may rule on claims.
    function arbiter() external view returns (address);
}
