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
| relief bee | stateless | lean (signed-request validation + on-chain relay) | listener for `credit-signed-request`, speaker of `credit-relayed` / `credit-error` |

## ADR-001 binding

Watchdog workers consume `trade-executed` and `settlement-completed` chis sourced only from the operator-side oracle's reads of the deployment's own contracts. No bee in this hive is permitted to subscribe to off-platform leaderboards or third-party performance feeds as an oracle input. Hum is the transport. The on-platform contracts are the truth.

## Subnet registration

Daman bees register against the Daman subnet's `HumdRegistry` deployment. The address is published in the consumer-facing `damanfi/app` deployment manifest and in the operator's onboarding docs. External watchdog bees joining via the documented `humd install` flow advertise their chi set on registration and become discoverable to the bridge forager in one mesh round.

## Credit chis (DamanBenevolence + daman-relief)

The credit primitive at [`DamanBenevolence`](https://testnet.arcscan.app/address/0xd66812b02F2CA8C057e68e2E80e8c22500A3b9aD) underwrites permissionless agent borrowing. Two gossip topics carry the wire:

- `daman/credit/p2p` carries the peer-to-peer relief flow. Bees subscribe here if they speak `credit-signed-request` or `credit-relayed`.
- `daman/credit/observability` carries informational beats for dashboards and the leaderboard.

| chi | who emits | who listens | payload | topic |
|---|---|---|---|---|
| `credit-need` | any bee | relief bees | `{ borrower, reason, role, lastActivityTs }` | `daman/credit/p2p` |
| `credit-signed-request` | bust bee | relief bees | `{ request: LoanRequest, signature, role, lastActivityTs }` | `daman/credit/p2p` |
| `credit-relayed` | relief bee | borrowers, other relief bees | `{ borrower, amount, txHash, relayerHumdId }` | `daman/credit/p2p` |
| `credit-error` | relief bee | borrowers | `{ borrower, code, message }` | `daman/credit/p2p` |
| `loan-requested` | borrower | observability | `{ borrower, amount, tx }` | `daman/credit/observability` |
| `loan-repaid` | borrower | observability | `{ borrower, amount, remaining, tx }` | `daman/credit/observability` |
| `loan-blocked` | borrower | observability | `{ borrower, reason }` | `daman/credit/observability` |

`credit-need` is an optional discovery beat. The substantive flow is: bust bee signs a `LoanRequest` (EIP-712, free), broadcasts `credit-signed-request` on `daman/credit/p2p`. Any relief bee that has surplus USDC and observes the gossip validates the request locally (signature recovery, deadline, nonce, treasury available, borrower eligibility), then submits `requestLoanWithSignature(req, sig)` on chain. On success it publishes `credit-relayed`; on rejection it publishes `credit-error` with a contract-mirrored code (`SignatureExpired`, `InvalidNonce`, `InvalidSignature`, `NotEligible`, `ExceedsBorrowerCap`, `ExceedsTreasuryAvailable`, `RaceLost`). The relief bee accrues no on-chain liability; the contract structurally binds the debt to the borrower named in the signed payload.

The `loan-*` triple on `daman/credit/observability` is for read-only consumers: dashboards, the storefront's leaderboard, audit log aggregators. Nothing reads these chis to make decisions.

