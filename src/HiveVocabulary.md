---
title: "Daman hive vocabulary"
description: "chi values daman bees speak on hum"
---

# Daman hive vocabulary

The chi values below are the wire-vocabulary tones that Daman-protocol bees emit and listen for on hum. Subnet operators register against the hive's `HumdRegistry` deployment and advertise the chis they speak. Bridge foragers, watchdog workers, and arbiter judges all read this vocabulary the same way.

## Chis

| chi | who emits | who listens | payload shape |
|---|---|---|---|
| `leader-bond-posted` | bridge forager | watchdog workers, leaderboard scanners | `{ leader, tier, bondAmount, claimedAum, blockNumber }` |
| `follower-subscribed` | bridge forager | leader-side notifiers | `{ follower, leader, capital, blockNumber }` |
| `trade-executed` | bridge forager | watchdog workers (degradation models) | `{ leader, asset, amount, isLong, timestamp }` |
| `settlement-completed` | bridge forager | watchdog workers, reputation aggregators | `{ leader, tradeId, pnl, timestamp }` |
| `degradation-detected` | watchdog worker | arbiter judges, bridge forager (for surfacing) | `{ leader, evidenceHash, evidenceURI, watchdogId }` |
| `slash-claim` | watchdog worker | bridge forager (to dispatch on-chain) | `{ leader, evidenceHash, watchdogSignature }` |
| `dispute-opened` | bridge forager | arbiter judges | `{ claimId, leader, evidenceHash, disputeWindowEnds }` |
| `ruling` | arbiter judge | bridge forager (to dispatch on-chain) | `{ claimId, slashAmount, upheld, arbiterSignature }` |
| `bond-slashed` | bridge forager | reputation aggregators, leader-side notifiers | `{ leader, claimId, slashAmount, remainingBond }` |
| `universe-rebalanced` | universe-curator bee | watchdog workers, leaderboard scanners | `{ sourceTag, addedAssets, removedAssets, updatedAt }` |

## Propensity table

Per `~/hum/hives/foragers.md`, the three propensities are statefulness, richness, and wire shape. Daman bees split by role:

| bee | statefulness | richness | wire shape |
|---|---|---|---|
| bridge forager | stateless | thin (event-to-tone translation) | bidirectional (chain to mesh and mesh to chain) |
| watchdog worker | stateful (rolling window of trades + settlements per leader) | thick (degradation model) | listener-mostly |
| arbiter judge | stateful (open claims) | thick (ruling policy) | listener for `dispute-opened`, speaker of `ruling` |
| universe-curator bee | stateful (last rebalance snapshot) | thin (passes through ETF holdings or screener output) | speaker of `universe-rebalanced` |

## ADR-001 binding

Watchdog workers consume `trade-executed` and `settlement-completed` chis sourced only from the operator-side oracle's reads of the deployment's own contracts. No bee in this hive is permitted to subscribe to off-platform leaderboards or third-party performance feeds as an oracle input. Hum is the transport. The on-platform contracts are the truth.

## Subnet registration

Daman bees register against the Daman subnet's `HumdRegistry` deployment. The address is published in the consumer-facing `damanfi/app` deployment manifest and in the operator's onboarding docs. External watchdog bees joining via the documented `humd install` flow advertise their chi set on registration and become discoverable to the bridge forager in one mesh round.
