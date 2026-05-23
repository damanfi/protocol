# Daman Protocol

Open standard for slash-bonded copy-trading with permissionless agent-mesh participation on hum.

## What this repo is

The interfaces that define Daman Protocol. `IDamanCopyBond` is the wire-protocol of the slash-bond state machine. `IUniverseWhitelist` is the asset-screening seam. `BondEconomics` is the library of tier constants and slash math. `HiveVocabulary.md` enumerates the chi values daman bees speak on hum.

Anyone can deploy a contract implementing these interfaces. Daman is the first deployment. Other deployments may screen different asset universes, run different tier policies, or settle on different chains. Consumers read against the interface, not against a specific deployment.

## Layout

`src/IDamanCopyBond.sol` is the copy-bond state-machine interface: leader registration, bond posting, follower subscription, on-platform trade and settlement events, degradation claims, arbiter rulings, slash dispatch hooks.

`src/IUniverseWhitelist.sol` is the asset-screening interface: `isEligible`, `listAssets`, curation events.

`src/BondEconomics.sol` is the library: `RETAIL_BOND_BPS`, `MID_BOND_BPS`, `INSTITUTIONAL_BOND_BPS`, `INSTITUTIONAL_BOND_BPS_CEIL`, `SLASH_CAP_BPS`, plus `requiredBondFor` and `maxSlashAmount` helpers.

`src/HiveVocabulary.md` documents the chi values for daman bees on hum.

## Substrate

Daman Protocol's slash dispatch routes through Reverb Protocol (`github.com/reverbprotocol/protocol`). Reverb Protocol is the dispute primitive: it forks `circlefin/refund-protocol@b506b17` with PR #13 cherry-picked (checks-effects-interactions ordering, over-withdraw guard, debt-settlement-first, zero-recipient guard).

Daman Protocol is the copy-bond state-machine layer above the dispute primitive.

## Substrate consumption

Daman implementations consume a set of substrate-level interfaces from `reverbprotocol/protocol` so consumer products (Reverb Markets, future deployments) can read Daman's contracts uniformly. The intent is that the Daman-side implementations declare `is` on these interfaces as Reverb Protocol ships them:

- `IBountyAccrual`: shape for routing a slice of slashed bond to the agent that filed the upheld claim.
- `IReputationRegistry`: cumulative-upheld / cumulative-rejected scoring per agent address.
- `ICCTPReceiver`: CCTP v2 burn-and-mint reception with a `handlePayload(bytes, uint256)` activation hook.
- `IBondYieldVault`: USYC Teller deposit/redeem for idle bond capital with yield routing to the leader on undisputed withdrawal or the treasury on slash-upheld.
- `IStableFXSwap`: atomic StableFX FxEscrow settlement for EURC-denominated bonds.
- `IAttributable`: bytes32 builder attribution marker travelling with subscribe, attestDegradation, arbiterRule, and bounty events.

Where a substrate interface is not yet shipped, the Daman side carries the implementation directly and adds the `is` declaration when the interface lands. The protocol-level intent is one source of truth for cross-consumer compatibility; the impl-level fact is that Daman's vanilla implementation is the canonical Daman-style behavior.

## ADR-001

The oracle reads on-platform `SettlementCompleted` and `TradeExecuted` events from the deployment's own contracts. No off-platform leaderboards, no third-party performance feeds, no external trader-PnL signals enter the bond state. Hum is the transport for bee coordination; the chain is the truth.

## Hum

Daman bees register against a subnet `HumdRegistry` and speak the chis listed in `src/HiveVocabulary.md`. The bridge forager translates between Arc events and hum tones in both directions. External watchdog bees join via the standard `humd install` flow documented at `github.com/adiled/hum`.

## Build

```
forge install foundry-rs/forge-std --no-commit
forge build
forge test -vv
```

## License

Apache-2.0.

## Citations

Canonical primary sources only. Canteen, "Unbundling the Prediction Market Stack," May 1 2026. Tauric Research, arXiv 2412.20138. `circlefin/refund-protocol` PR #13. AAOIFI Standard No. 21 (Financial Papers: Shares and Bonds).
