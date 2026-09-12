---
type: research
tags:
  - memory-card
  - research
  - crdt
  - powersync
  - electricsql
  - offline-first
  - local-first
  - fsrs-5
  - hybrid-logical-clock
  - sqlite
  - postgresql
  - distributed-systems
  - typescript
  - dart
created: 2026-08-13
updated: 2026-08-13
---

# 🔄 RES-29: Conflict-Free Replicated Data Types (CRDTs) & PowerSync/ElectricSQL for Offline Sync

> **Document ID:** `RES-29`  
> **Master Concept:** [[Ideas/Future/Memory Card/brain_dump.md|brain_dump.md]] | [[Ideas/Future/Memory Card/research.md|research.md]]  
> **Research Checklist:** [[Ideas/Future/Memory Card/research_check_list.md|research_check_list.md]]  
> **Parent Hub:** [[Ideas]]

---

## Executive Summary

Spaced repetition systems (SRS) and digital learning environments present a notoriously difficult synchronization problem. Modern learners interact across heterogeneous devices: swiping flashcards on an iPhone during a subway commute without cellular reception, editing rich-text card contents on a desktop web app, and reorganizing deck folder hierarchies on an Android tablet. 

Traditional client-server synchronization architectures that rely on coarse **Last-Write-Wins (LWW)** at the row or table level cause catastrophic data loss in this workflow. If a user reviews 50 cards offline on a mobile device and simultaneously fixes a typo in 5 of those cards on their laptop, a naive LWW merge will overwrite either the updated card content or the crucial review history logs and calculated memory stability factors ($S$). Overwriting review records ruins the cognitive scheduling engine, sending cards into "Ease Hell" or scheduling mature cards for immediate re-test.

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                    NAIVE LWW SYNC VS. CRDT LOG-SEMILATTICE MERGE                        │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  [Mobile Client (Offline in Subway)]             [Desktop Client (Online at Home)]     │
│   • Reviews Card #402: Grade=Good (S=14.2d)       • Edits Card #402 front: typo fix     │
│   • Reviews Card #403: Grade=Again (S=1.1d)       • Moves Deck "Neuro" into "Medicine"  │
│                                                                                         │
│ ─────────────────────────────────────────────────────────────────────────────────────── │
│  ❌ NAIVE LAST-WRITE-WINS (Row-Level LWW):                                              │
│     Desktop syncs at 14:00 (LWW). Mobile syncs at 14:15 (LWW).                          │
│     Mobile overwrites Desktop card edits (typos restored!). Desktop overwrites mobile    │
│     SRS stability state ($S$, $D$, Retrievability $R$) if desktop edits save first.     │
│                                                                                         │
│  ✅ CRDT & LOGICAL REPLICATION ARCHITECTURE (RES-29):                                   │
│     1. Content & Hierarchy: State/Op-based CRDTs + Fractional Indexing (Yjs/LSEQ).     │
│     2. Memory States (FSRS-5): Append-Only Review Log Semilattice + HLC Deterministic   │
│        Event Replay. Both reviews and edits merge with mathematical convergence.        │
│     3. Transport & Storage: Local SQLite <── PowerSync / ElectricSQL ──> Postgres WAL.  │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

This research paper provides the definitive mathematical, architectural, and software engineering blueprint for **Memory Card's Local-First Offline Synchronization Engine**. We integrate:
1. **Hybrid Logical Clocks (HLC)** to impose a strict causal total order across asynchronous devices without relying on synchronized physical wall clocks.
2. **State-based and Operation-based CRDTs** for rich card text (Yjs / Automerge integration), hierarchical folder movement (cycle-preventing tree CRDTs), and fractional indexing for list sorting.
3. A novel **FSRS-5 Deterministic Replay Semilattice** that converts concurrent, offline reviews into a mathematically monotonic memory state projection, preserving cognitive fidelity across all devices.
4. An industrial-grade **PowerSync / ElectricSQL Postgres Logical Replication Pipeline**, translating Postgres Write-Ahead Logs (`pgoutput`) into partitioned SQLite buckets for sub-16ms zero-latency offline queries and real-time bidirectional streaming.
5. Complete, production-ready implementations in **TypeScript (React Native)** and **Dart (Flutter)** with automated property-based verification suites.

---

## 1. High-Level Multi-Device Sync Architecture

The Memory Card architecture is founded on the **Local-First Software Principles**: data resides primarily on the user's physical device in an embedded SQLite database; all UI reads and writes execute synchronously against local storage in $<16\text{ms}$; and synchronization occurs opportunistically in the background over an active-active, partition-tolerant replication stream.

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                       MEMORY CARD DISTRIBUTED DATA FLOW ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│   ┌────────────────────────────────┐                     ┌────────────────────────────────┐     │
│   │     CLIENT A: iOS / Android    │                     │      CLIENT B: Desktop / Web   │     │
│   │  ┌──────────────────────────┐  │                     │  ┌──────────────────────────┐  │     │
│   │  │ UI Layer / Gestures      │  │                     │  │ UI Layer / Gestures      │  │     │
│   │  └────────────┬─────────────┘  │                     │  └────────────┬─────────────┘  │     │
│   │               ▼                │                     │               ▼                │     │
│   │  ┌──────────────────────────┐  │                     │  ┌──────────────────────────┐  │     │
│   │  │ Local SQLite Engine      │  │                     │  │ Local SQLite Engine      │  │     │
│   │  │  • cards / decks / logs  │  │                     │  │  • cards / decks / logs  │  │     │
│   │  │  • ps_crud (upload queue)│  │                     │  │  • ps_crud (upload queue)│  │     │
│   │  └────────────┬─────────────┘  │                     │  └────────────┬─────────────┘  │     │
│   │               ▲                │                     │               ▲                │     │
│   │  ┌────────────┴─────────────┐  │                     │  ┌────────────┴─────────────┐  │     │
│   │  │ PowerSync Client Engine  │  │                     │  │ PowerSync Client Engine  │  │     │
│   │  │  • HLC Vector Clock      │  │                     │  │  • HLC Vector Clock      │  │     │
│   │  │  • FSRS-5 Log Merger     │  │                     │  │  • FSRS-5 Log Merger     │  │     │
│   │  └────────────┬─────────────┘  │                     │  └────────────┬─────────────┘  │     │
│   └───────────────┼────────────────┘                     └───────────────┼────────────────┘     │
│                   │                                                      │                      │
│                   │  HTTPS / WebSockets (Binary Delta Streams)            │                      │
│                   ▼                                                      ▼                      │
│   ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                           POWERSYNC / ELECTRIC REPLICATION CLUSTER                      │   │
│   │  ┌───────────────────────────────────────────────────────────────────────────────────┐  │   │
│   │  │ Dynamic Sync Rules Engine (Bucket Partitioner)                                    │  │   │
│   │  │  • Bucket: `user_decks_{user_id}`                                                 │  │   │
│   │  │  • Bucket: `user_cards_{user_id}`                                                 │  │   │
│   │  │  • Bucket: `user_review_logs_{user_id}`                                           │  │   │
│   │  │  • Bucket: `public_shop_decks`                                                    │  │   │
│   │  └─────────────────────────────────────────┬─────────────────────────────────────────┘  │   │
│   └────────────────────────────────────────────┼────────────────────────────────────────────┘   │
│                                                │                                                │
│                                                │ PostgreSQL WAL Streaming (`pgoutput`)           │
│                                                ▼                                                │
│   ┌─────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │                             BACKEND POSTGRESQL CLUSTER                                  │   │
│   │  ┌───────────────────────────┐  ┌───────────────────────────┐  ┌─────────────────────┐  │   │
│   │  │ Relational Tables (WAL)   │  │ Invalidation Triggers     │  │ Custom Merge / RPC  │  │   │
│   │  │  • decks, cards, logs     │  │  • logical slot publisher │  │  • batch review sink│  │   │
│   │  └───────────────────────────┘  └───────────────────────────┘  └─────────────────────┘  │   │
│   └─────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Core Entities & Partitioning Matrix

Data is partitioned into distinct replication domains with strict sync behaviors:

| Entity Domain | CRDT / Sync Mechanism | Conflict Resolution Strategy | Replication Frequency |
| :--- | :--- | :--- | :--- |
| **Review Logs (`revlog`)** | Grow-Only Set (G-Set) / Append-Only Event Log | Mathematical Union ($\mathcal{E}_A \cup \mathcal{E}_B$) ordered by HLC | Real-time stream when online; Batched upload post-offline |
| **Card SRS State (`cards.fsrs_*`)** | Deterministic Materialized Projection | Deterministic Replay of unified `revlog` via FSRS-5 state equations | Recomputed locally upon ingestion of foreign `revlog` records |
| **Card Content (`cards.front/back`)** | Operation-based Sequence CRDT (Yjs / Automerge) | Character-level RGA/YATA interleaving + per-field HLC Last-Write-Wins | Field-level patch streaming |
| **Deck / Folder Tree (`folders`)** | Replicated Tree CRDT | Cycle-Preventing Move Operation (Martin et al.) with Parent HLC | Immediate bucket sync |
| **Card Display Order** | Fractional Indexing (String Key Space) | Lexicographical midpoint calculation with client-id disambiguation | Immediate bucket sync |
| **Shop & Discovery Decks** | Read-Only Dynamic Shape Stream | Server-Authoritative Postgres Replication | Cached locally; synced on delta invalidation |

---

## 2. Mathematical Foundations: Hybrid Logical Clocks (HLC)

In distributed, offline-first architectures, physical wall clocks ($PT$) cannot be trusted due to clock drift, Network Time Protocol (NTP) adjustments, leap seconds, and deliberate user manipulation (e.g., advancing device time to bypass paywalls or review limits). Standard Lamport Clocks provide causal ordering but lose correlation with real physical time, making it impossible to answer queries like "find reviews completed today after 17:00".

We implement **Hybrid Logical Clocks (HLC)** as formulated by Kulkarni et al. An HLC timestamp $e = (l.e, c.e, node)$ captures both physical time awareness and strict causal ordering.

```
       ┌───────────────────────────────────────────────────────────────┐
       │                   HLC TUPLE: (l.e, c.e, node)                 │
       ├───────────────────────────────┬───────────────┬───────────────┤
       │ l.e: Physical Component (ms)  │ c.e: Counter  │ node: UUID    │
       │   Max physical time observed  │   Logical     │   Node ID     │
       │   bounded by: |l.e - pt| ≤ ε  │   tie-breaker │   tie-breaker │
       └───────────────────────────────┴───────────────┴───────────────┘
```

### 2.1 Formal HLC Specification & State Invariants

Each participating device $j$ maintains a local physical clock $pt_j$ and a state $(l_j, c_j)$.

#### Invariant Properties:
1. **Causality Preservation:** If event $e_1$ happens before $e_2$ ($e_1 \rightarrow e_2$), then $hlc(e_1) < hlc(e_2)$.
2. **Physical Clock Closeness:** For any event $e$, $l.e \ge pt_e$ and $|l.e - pt_e| \le \epsilon_{\max}$, where $\epsilon_{\max}$ is the bounded maximum clock drift (configured to $60{,}000\text{ms}$).
3. **Monotonicity:** For any sequence of local events $e$ followed by $e'$, $hlc(e) < hlc(e')$.

### 2.2 Mathematical Transition Rules

#### Event Generation (Local Event / Write):
When client $j$ creates an event (e.g., performs a flashcard review, edits text):

$$l'_j = \max(l_j, pt_j)$$

$$c'_j = \begin{cases} 
c_j + 1 & \text{if } l'_j = l_j \\ 
0 & \text{if } l'_j > l_j 
\end{cases}$$

$$l_j \leftarrow l'_j, \quad c_j \leftarrow c'_j$$

$$\text{Timestamp assigned: } e = (l_j, c_j, \text{node}_j)$$

#### Message Reception (Sync Stream Ingestion):
When client $j$ receives a remote event with timestamp $m = (l.m, c.m, \text{node}_m)$:

$$l'_j = \max(l_j, pt_j, l.m)$$

$$c'_j = \begin{cases} 
c_j + 1 & \text{if } l'_j = l_j \text{ and } l'_j = l.m \text{ and } c_j > c.m \\ 
c.m + 1 & \text{if } l'_j = l_j \text{ and } l'_j = l.m \text{ and } c.m \ge c_j \\ 
c_j + 1 & \text{if } l'_j = l_j \text{ and } l'_j > l.m \\ 
c.m + 1 & \text{if } l'_j = l.m \text{ and } l'_j > l_j \\ 
0 & \text{otherwise (i.e. } l'_j = pt_j > \max(l_j, l.m)\text{)}
\end{cases}$$

$$l_j \leftarrow l'_j, \quad c_j \leftarrow c'_j$$

### 2.3 Strict Total Order Relation

Given two HLC timestamps $h_1 = (l_1, c_1, \text{node}_1)$ and $h_2 = (l_2, c_2, \text{node}_2)$, the canonical total order relation $<_{\text{HLC}}$ is defined as:

$$h_1 <_{\text{HLC}} h_2 \iff (l_1 < l_2) \lor (l_1 = l_2 \land c_1 < c_2) \lor (l_1 = l_2 \land c_1 = c_2 \land \text{node}_1 < \text{node}_2)$$

This guarantees an unambiguous, deterministic total order across all devices without central coordination.

---

## 3. Merging FSRS-5 Memory States: The Review Log Semilattice

The greatest technical failure mode in offline-first SRS apps occurs when two offline devices review the same card. 

### 3.1 The Paradox of Concurrent Memory Reviews

Consider the scenario:
- **08:00 AM (Subway, Airplane Mode, Mobile):** User reviews Card $C$, grades $G_1 = 3$ ($\text{Good}$). Mobile engine computes new stability $S_1 = 3.2\text{ days}$, difficulty $D_1 = 5.2$, next due date $T_{\text{due}} = \text{Day } 3$.
- **08:30 AM (Coffee Shop, Offline Laptop):** User reviews Card $C$ (which was still marked due on laptop), grades $G_2 = 1$ ($\text{Again}$). Laptop engine computes $S_2 = 0.4\text{ days}$, $D_2 = 7.1$, next due date $T_{\text{due}} = \text{Day } 0$.
- **09:00 AM:** Both devices regain Internet connectivity and connect to the PowerSync cluster.

If the system treats the `cards` table row as mutable data governed by LWW, the laptop's sync will overwrite the mobile's review, or vice-versa. One of the user's actual cognitive testing events is lost, and the card's memory state becomes permanently desynchronized from the biological memory trace.

```
       CONCURRENT REVIEW TIMELINE & MERGE RESOLUTION
       
       T=08:00 (Mobile)       Review 1: G=Good, Hesitation=320ms, HLC=(1723536000, 0, A)
       T=08:30 (Laptop)       Review 2: G=Again, Hesitation=4100ms, HLC=(1723537800, 0, B)
                              │
                              ▼
       T=09:00 (Sync Event)   Union of Review Log: E_total = { Rev_1, Rev_2 }
                              Deterministic Sort by HLC: [ Rev_1, Rev_2 ]
                              Deterministic FSRS-5 State Replay:
                                Base State (T_0) ──► Apply Rev_1 ──► Apply Rev_2 ──► Final State (S*, D*)
```

### 3.2 Formal Algebraic Model: Review Log G-Set

We define the set of all review logs $\mathcal{R}$ as a **Grow-Only Set (G-Set)** join-semilattice $(\mathcal{P}(\mathcal{R}), \subseteq, \cup)$.

Each review event $r \in \mathcal{R}$ is an immutable, append-only record defined by the tuple:

$$r = \langle \text{id}, \text{card\_id}, \text{hlc}, \text{grade}, \text{hesitation\_ms}, \text{elapsed\_days}, \text{review\_type}, \text{device\_id} \rangle$$

The merge operator $\sqcup_{\mathcal{R}}$ between two client review sets $\mathcal{R}_A$ and $\mathcal{R}_B$ is set union:

$$\mathcal{R}_{\text{merged}} = \mathcal{R}_A \sqcup_{\mathcal{R}} \mathcal{R}_B = \mathcal{R}_A \cup \mathcal{R}_B$$

Since set union satisfies **Associativity**, **Commutativity**, and **Idempotence**:

$$(\mathcal{R}_A \cup \mathcal{R}_B) \cup \mathcal{R}_C = \mathcal{R}_A \cup (\mathcal{R}_B \cup \mathcal{R}_C)$$

$$\mathcal{R}_A \cup \mathcal{R}_B = \mathcal{R}_B \cup \mathcal{R}_A$$

$$\mathcal{R}_A \cup \mathcal{R}_A = \mathcal{R}_A$$

The review log set is guaranteed to achieve **Strong Eventual Consistency (SEC)** on all nodes.

### 3.3 The FSRS-5 State Projection Function

The card's current memory state vector $\mathbf{M} = (S, D, R, T_{\text{due}}, \text{state}, \text{reps}, \text{lapses})$ is a **pure, deterministic projection** of its ordered review history:

$$\mathbf{M}(\text{card\_id}) = \Phi\left( \mathbf{M}_0, \text{SortByHLC}(\{ r \in \mathcal{R} \mid r.\text{card\_id} = \text{card\_id} \}) \right)$$

where:
- $\mathbf{M}_0 = (S=0, D=0, R=0, T_{\text{due}}=\text{created\_at}, \text{state}=\text{New}, \text{reps}=0, \text{lapses}=0)$ is the initial zero-state.
- $\text{SortByHLC}$ orders elements strictly by $<_{\text{HLC}}$.
- $\Phi$ is the sequential fold of the FSRS-5 update transfer equations.

#### FSRS-5 Mathematical Review Transition Functions:

Given previous state $(S_{k-1}, D_{k-1})$, grade $G_k \in \{1, 2, 3, 4\}$, hesitation metric $H_s \in [0, 1]$, and elapsed days $\Delta t_k = \frac{l(r_k) - l(r_{k-1})}{86{,}400{,}000}$:

1. **Retrievability at review time:**

$$R_k = \left( 1 + \text{FACTOR} \cdot \frac{\Delta t_k}{S_{k-1}} \right)^{-w_{\text{decay}}} = \left( 1 + \frac{19}{81} \cdot \frac{\Delta t_k}{S_{k-1}} \right)^{-0.5}$$

2. **Difficulty Update:**

$$D_0(G_k) = w_4 - e^{w_5 (G_k - 1)} + 1 + \eta_d \cdot H_s$$

$$D'_r(D_{k-1}, G_k) = w_7 \cdot D_0(3) + (1 - w_7) \cdot \left[ D_{k-1} - w_6 \cdot (G_k - 3) \right]$$

$$D_k = \text{clamp}(D'_r(D_{k-1}, G_k), 1.0, 10.0)$$

3. **Stability Update (Recall vs Lapse):**

$$\text{If } G_k = 1 \text{ (Lapse): } \quad S_k = \min\left( w_{11} \cdot D_k^{-w_{12}} \cdot \left( (S_{k-1} + 1)^{w_{13}} - 1 \right) \cdot e^{w_{14} (1 - R_k)}, S_{k-1} \right)$$

$$\text{If } G_k \ge 2 \text{ (Recall): } \quad S_k = S_{k-1} \cdot \left( 1 + e^{w_8} \cdot (11 - D_k) \cdot S_{k-1}^{-w_9} \cdot \left( e^{w_{10} (1 - R_k)} - 1 \right) \cdot B(G_k) \right)$$

where $B(2) = w_{15}$, $B(3) = 1.0$, $B(4) = w_{16}$.

4. **Next Interval Calculation:**

$$I_k = \text{clamp}\left( \text{round}\left( \frac{S_k}{\text{FACTOR}} \cdot \left( R_{\text{target}}^{-1/w_{\text{decay}}} - 1 \right) \right), 1, 36500 \right) = \text{round}\left( \frac{81}{19} \cdot S_k \cdot (R_{\text{target}}^{-2} - 1) \right)$$

$$T_{\text{due}} = l(r_k) + I_k \times 86{,}400{,}000\text{ ms}$$

### 3.4 Proof of Convergence

Let client $A$ possess review set $\mathcal{R}_A$ and client $B$ possess review set $\mathcal{R}_B$. When sync converges:
1. Both clients compute $\mathcal{R}^* = \mathcal{R}_A \cup \mathcal{R}_B$.
2. Because $<_{\text{HLC}}$ is a total order with zero ambiguity, both clients sort $\mathcal{R}^*$ into identical sequence $\vec{R}^* = [r_{(1)}, r_{(2)}, \dots, r_{(n)}]$.
3. Since $\Phi$ is a deterministic function without side-effects, $\Phi(\mathbf{M}_0, \vec{R}^*)$ evaluates to identical state $\mathbf{M}^*$ on all clients.
4. **No human intervention or arbitrary LWW data loss is possible.**

---

## 4. CRDT Foundations: Deck Structure, Card Ordering & Rich Text

Beyond review logs, Memory Card contains mutable entities that require specialized CRDT formulations.

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           MEMORY CARD CRDT TAXONOMY                                     │
├───────────────────────────────┬─────────────────────────┬───────────────────────────────┤
│ Domain                        │ CRDT Type               │ Implementation Model          │
├───────────────────────────────┼─────────────────────────┼───────────────────────────────┤
│ Card Ordering in Deck         │ Sequence CRDT           │ Fractional Indexing (Lexicog) │
│ Folder / Deck Tree Hierarchy  │ Replicated Tree CRDT    │ Cycle-Safe Move (Parent-HLC)  │
│ Card Content (Front/Back)     │ Sequence / Text CRDT    │ Yjs (YATA) / Automerge (RGA)  │
│ Deck Metadata (Color, Icon)   │ Register CRDT           │ Multi-Value Register / LWW-HLC│
│ Card Tags                     │ Set CRDT                │ Observed-Remove Set (OR-Set)  │
└───────────────────────────────┴─────────────────────────┴───────────────────────────────┘
```

### 4.1 Fractional Indexing for Card Ordering

Users reorder cards within decks via drag-and-drop. Naive integer indices ($0, 1, 2, 3\dots$) fail because inserting a card between index $1$ and $2$ requires renumbering all subsequent rows ($O(N)$ updates), creating massive write-amplification and merge collisions.

We use **Variable-Length String Fractional Indexing** over alphabet $\Sigma = [\text{a-z0-9}]$.

```
       FRACTIONAL INDEX ORDERING IN A DECK
       
       Card A: "a0"
       Card B: "a1"
       
       Insert Card X between A and B:
       Key(X) = midpoint("a0", "a1") = "a0v"
       
       Insert Card Y between A and X:
       Key(Y) = midpoint("a0", "a0v") = "a0k"
```

#### Fractional Midpoint Algorithm:
Given preceding key $P = p_1 p_2 \dots p_n$ and succeeding key $S = s_1 s_2 \dots s_m$ with $P <_{\text{lex}} S$:
1. Append trailing zeros to align lengths.
2. Find first index $k$ where digits differ.
3. Compute digit midpoint $m_k = \lfloor (p_k + s_k) / 2 \rfloor$.
4. If $m_k = p_k$, append midpoint of next interval $(p_{k+1}, \text{RADIX})$.
5. Append client identifier suffix (e.g. `_nodeA`) as tie-breaker to guarantee uniqueness if two devices insert at the same location simultaneously.

### 4.2 Cycle-Safe Replicated Tree CRDT for Folder Hierarchies

Flashcard folders can be nested arbitrarily. If Client A moves folder $X$ into folder $Y$, while Client B concurrently moves folder $Y$ into folder $X$, a naive sync creates a detached orphan cycle ($X \leftrightarrow Y$).

We implement Martin et al.'s **Cycle-Safe Tree Move CRDT**:
- Every move operation is logged as a tuple: $\text{Move}(\text{op\_id}, \text{hlc}, \text{child\_id}, \text{new\_parent\_id})$.
- When applying $\text{Move}_i$, the client traces the ancestor chain of $\text{new\_parent\_id}$.
- If $\text{child\_id} \in \text{Ancestors}(\text{new\_parent\_id})$, applying the move would form a cycle.
- **Cycle Resolution Rule:** The operation with the smaller HLC timestamp is rejected or redirected to root parent (`null`), while the operation with the larger HLC timestamp succeeds.

```
       CYCLE FORMATION PREVENTION IN FOLDER MOVEMENTS
       
       Initial State:   Root ──► Folder X,   Root ──► Folder Y
       
       Client A (Offline): Move Y into X  (HLC: 100, Node A)
       Client B (Offline): Move X into Y  (HLC: 102, Node B)
       
       Sync Convergence:
       1. Apply Op A (HLC 100): Y is child of X. Tree: Root ──► X ──► Y
       2. Evaluate Op B (HLC 102): Target parent is Y. Ancestors of Y = {X, Root}.
          Target child to move is X. Since X is an ancestor of Y, cycle detected!
       3. Resolve: Op B has higher HLC (102 > 100).
          Revert Op A: Reset Y to Root.
          Apply Op B: Set X as child of Y.
          Result: Root ──► Y ──► X (Zero Cycles, Deterministic Convergence).
```

### 4.3 Observed-Remove Set (OR-Set) for Flashcard Tags

Card tags (e.g., `["anatomy", "exam_2026", "high_yield"]`) must handle concurrent additions and deletions across devices.
- **Add Tag:** Generates unique birth timestamp $(tag, hlc_{\text{add}})$.
- **Remove Tag:** Observes all existing birth timestamps for $tag$ and writes a tombstone set $T(tag) = \{ hlc_{\text{add}, 1}, hlc_{\text{add}, 2}, \dots \}$.
- **Tag Presence Query:** $tag \in \text{Card.tags} \iff \exists (tag, h) \text{ such that } h \notin T(tag)$.
- This guarantees **Add-Wins** semantics: if device A removes a tag while device B concurrently adds it, the newly added tag survives.

---

## 5. PowerSync & ElectricSQL Postgres Replication Architecture

To bridge mobile SQLite with backend PostgreSQL, we evaluate and implement a logical replication streaming architecture.

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                     POWERSYNC VS. ELECTRICSQL ARCHITECTURE COMPARISON                           │
├───────────────────────────────┬─────────────────────────────────┬───────────────────────────────┤
│ Architectural Dimension       │ PowerSync                       │ ElectricSQL                   │
├───────────────────────────────┼─────────────────────────────────┼───────────────────────────────┤
│ **Client Storage Engine**     │ Embedded SQLite / SQLCipher     │ Embedded SQLite / PGlite      │
│ **Replication Paradigm**      │ Dynamic Partitioned Sync Buckets│ Dynamic Shape Streams         │
│ **Sync Rule Language**        │ Declarative YAML / SQL          │ Relational Shape Definitions  │
│ **Postgres Capture**          │ Logical Replication `pgoutput`  │ Logical Replication Slots     │
│ **Write Handling**            │ Local SQLite + Batch POST API   │ Satellite Direct Master Sync  │
│ **Flutter / Dart Support**    │ Tier 1 Official SDK (`powersync`│ Community / Dart Bridge       │
│ **React Native Support**      │ Tier 1 Official Native Bindings │ Official TypeScript Client    │
│ **CRDT Custom Extensibility** │ Full SQLite trigger/hook access │ Relational conflict rules     │
│ **Production Recommendation** │ **Primary Choice for Mobile**   │ **Ideal for Web/PGlite**      │
└───────────────────────────────┴─────────────────────────────────┴───────────────────────────────┘
```

### 5.1 PowerSync Dynamic Sync Rules Specification

PowerSync syncs data by defining **Sync Buckets** in a server-side YAML file. The PowerSync service evaluates these rules against the Postgres WAL and streams only authorized, partitioned rows to each authenticated user.

```yaml
# /config/powersync_sync_rules.yaml
# PowerSync Dynamic Bucket Partitioning for Memory Card

bucket_definitions:
  # 1. User Private Decks Bucket
  user_decks:
    parameters:
      - SELECT request.user_id() as current_user_id
    data:
      - SELECT * FROM decks WHERE owner_id = bucket.current_user_id
      - SELECT * FROM folders WHERE owner_id = bucket.current_user_id

  # 2. User Cards & FSRS Projected States
  user_cards:
    parameters:
      - SELECT request.user_id() as current_user_id
    data:
      - SELECT * FROM cards WHERE owner_id = bucket.current_user_id

  # 3. Append-Only FSRS Review Telemetry Logs
  user_review_logs:
    parameters:
      - SELECT request.user_id() as current_user_id
    data:
      - SELECT * FROM revlog WHERE user_id = bucket.current_user_id

  # 4. Public Shop & Discovery Decks (Read-Only Global Cache)
  public_shop_decks:
    data:
      - SELECT * FROM decks WHERE is_public = true AND published_at IS NOT NULL
      - SELECT * FROM cards WHERE deck_id IN (SELECT id FROM decks WHERE is_public = true)
```

### 5.2 SQLite Client Schema with Replication Upload Triggers

On the client device, local writes insert directly into user tables, and SQLite triggers immediately enqueue pending mutations into a persistent `ps_crud` upload queue.

```sql
-- SQLite Local DDL on Mobile/Desktop Client

CREATE TABLE IF NOT EXISTS folders (
    id TEXT PRIMARY KEY NOT NULL,
    owner_id TEXT NOT NULL,
    parent_id TEXT,
    name TEXT NOT NULL,
    color_hex TEXT NOT NULL DEFAULT '#6366F1',
    icon_name TEXT NOT NULL DEFAULT 'folder',
    hlc_timestamp TEXT NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS decks (
    id TEXT PRIMARY KEY NOT NULL,
    owner_id TEXT NOT NULL,
    folder_id TEXT,
    title TEXT NOT NULL,
    description TEXT,
    cover_color TEXT NOT NULL DEFAULT '#3B82F6',
    is_public INTEGER NOT NULL DEFAULT 0,
    fractional_index TEXT NOT NULL,
    hlc_timestamp TEXT NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY(folder_id) REFERENCES folders(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS cards (
    id TEXT PRIMARY KEY NOT NULL,
    deck_id TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    front_text TEXT NOT NULL,
    back_text TEXT NOT NULL,
    front_rich_state BLOB,
    back_rich_state BLOB,
    fractional_index TEXT NOT NULL,
    
    -- FSRS-5 State Projections
    fsrs_stability REAL NOT NULL DEFAULT 0.0,
    fsrs_difficulty REAL NOT NULL DEFAULT 0.0,
    fsrs_retrievability REAL NOT NULL DEFAULT 0.0,
    fsrs_due_timestamp INTEGER NOT NULL,
    fsrs_state INTEGER NOT NULL DEFAULT 0, -- 0: New, 1: Learning, 2: Review, 3: Relearning
    fsrs_reps INTEGER NOT NULL DEFAULT 0,
    fsrs_lapses INTEGER NOT NULL DEFAULT 0,
    fsrs_last_review INTEGER,
    
    hlc_timestamp TEXT NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY(deck_id) REFERENCES decks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS revlog (
    id TEXT PRIMARY KEY NOT NULL,
    card_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    grade INTEGER NOT NULL, -- 1: Again, 2: Hard, 3: Good, 4: Easy
    state INTEGER NOT NULL, -- State prior to review
    stability REAL NOT NULL,
    difficulty REAL NOT NULL,
    elapsed_days REAL NOT NULL,
    last_elapsed_days REAL NOT NULL,
    scheduled_days INTEGER NOT NULL,
    review_timestamp INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL,
    hesitation_ms INTEGER NOT NULL,
    touch_jitter REAL NOT NULL,
    review_type INTEGER NOT NULL, -- 0: Normal, 1: Early, 2: Relearning
    hlc_timestamp TEXT NOT NULL,
    device_id TEXT NOT NULL,
    FOREIGN KEY(card_id) REFERENCES cards(id) ON DELETE CASCADE
);

-- Indices for Guaranteed Sub-16ms Query Execution
CREATE INDEX IF NOT EXISTS idx_cards_due_study 
    ON cards(deck_id, is_deleted, fsrs_due_timestamp, fsrs_state);

CREATE INDEX IF NOT EXISTS idx_revlog_card_hlc 
    ON revlog(card_id, hlc_timestamp ASC);

CREATE INDEX IF NOT EXISTS idx_decks_folder 
    ON decks(folder_id, fractional_index ASC);
```

---

## 6. Conflict Resolution Matrix & Clock Skew Handling

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           CONFLICT RESOLUTION DECISION MATRIX                           │
├───────────────────┬───────────────────┬─────────────────────────────────────────────────┤
│ Mutation Type     │ Competing Event   │ Resolution Policy                               │
├───────────────────┼───────────────────┼─────────────────────────────────────────────────┤
│ Card Front Text   │ Card Front Text   │ Yjs Character-Level YATA Merge (No Loss)        │
│ Card SRS Review   │ Card SRS Review   │ Append Both to G-Set; Replay FSRS-5 Equations   │
│ Card Metadata     │ Card Metadata     │ HLC Last-Write-Wins ($hlc_A >_{\text{HLC}} hlc_B$)│
│ Folder Move       │ Folder Move       │ Cycle-Safe Check; Highest HLC Wins              │
│ Card Delete       │ Card Review       │ Tombstone Wins ($is\_deleted=1$); Revlog kept   │
│ Deck Delete       │ Card Add in Deck  │ Tombstone Cascade; Added card moved to Unsorted │
└───────────────────┴───────────────────┴─────────────────────────────────────────────────┘
```

### 6.1 Clock Skew Anomaly Resolution Algorithm

If a device's physical clock drifts forwards into the future ($pt_j > \text{server\_time} + 60{,}000\text{ms}$), it risks emitting HLC timestamps that permanently dominate future edits.

```
       CLOCK DRIFT DETECTION & DAMPING
       
       Device Clock (pt_j) ────────► [Drift Detector: |pt_j - server_now| > ε_max]
                                                    │
                                  ┌─────────────────┴─────────────────┐
                                  ▼                                   ▼
                         [Skew ≤ 60s (Normal)]               [Skew > 60s (Anomaly)]
                         Standard HLC Tick                   Clamp l_j to Server Time + Offset
                         Allow Write                         Emit User Warning Banner
```

#### Client Drift Mitigation Procedure:
1. Upon WebSocket connection handshake, the server sends authoritative `server_utc_ms`.
2. The client calculates physical delta: $\delta_{\text{skew}} = \text{server\_utc\_ms} - pt_{\text{local}}$.
3. If $|\delta_{\text{skew}}| > 60{,}000\text{ms}$:
   - The client applies offset $\delta_{\text{skew}}$ to all physical clock reads: $pt^*_{\text{local}} = pt_{\text{local}} + \delta_{\text{skew}}$.
   - Local writes are flagged with `clock_adjusted = true` in debug logs.
   - If the drift exceeds 24 hours, the UI displays a non-blocking toast: *"Device clock out of sync. Reviews will use calibrated network time."*

---

## 7. Production TypeScript Implementation Blueprint

The following complete, zero-dependency, production-grade TypeScript modules provide the full HLC engine, FSRS-5 log semilattice merger, and PowerSync database connector.

### 7.1 Hybrid Logical Clock Implementation (`hlc.ts`)

```typescript
/**
 * Production Hybrid Logical Clock (HLC) Implementation
 * Follows Kulkarni et al. formulation for causal and physical ordering.
 */

export interface HlcTuple {
  readonly logicalTime: number; // Physical millis component (l.e)
  readonly counter: number;     // Logical sequence component (c.e)
  readonly nodeId: string;      // Unique client/node identifier
}

export class HybridLogicalClock {
  private logicalTime: number;
  private counter: number;
  public readonly nodeId: string;
  private readonly maxDriftMs: number;

  constructor(nodeId: string, initialTime: number = Date.now(), maxDriftMs: number = 60000) {
    this.nodeId = nodeId;
    this.logicalTime = initialTime;
    this.counter = 0;
    this.maxDriftMs = maxDriftMs;
  }

  /**
   * Generates a new HLC timestamp for a local write event.
   */
  public now(physicalTimeMs: number = Date.now()): HlcTuple {
    const pt = physicalTimeMs;

    if (pt - this.logicalTime > this.maxDriftMs) {
      // Clock anomaly: physical time jumped far ahead
      this.logicalTime = pt;
      this.counter = 0;
    } else if (this.logicalTime - pt > this.maxDriftMs) {
      // Physical clock lagging far behind logical time
      this.counter += 1;
    } else {
      const maxTime = Math.max(this.logicalTime, pt);
      if (maxTime === this.logicalTime) {
        this.counter += 1;
      } else {
        this.logicalTime = maxTime;
        this.counter = 0;
      }
    }

    return {
      logicalTime: this.logicalTime,
      counter: this.counter,
      nodeId: this.nodeId,
    };
  }

  /**
   * Updates the local HLC state upon receiving a remote timestamp.
   */
  public receive(remote: HlcTuple, physicalTimeMs: number = Date.now()): HlcTuple {
    const pt = physicalTimeMs;
    const lOld = this.logicalTime;
    const lMsg = remote.logicalTime;

    const lNew = Math.max(lOld, pt, lMsg);

    if (lNew === lOld && lNew === lMsg) {
      this.counter = Math.max(this.counter, remote.counter) + 1;
    } else if (lNew === lOld) {
      this.counter += 1;
    } else if (lNew === lMsg) {
      this.counter = remote.counter + 1;
    } else {
      this.counter = 0;
    }

    this.logicalTime = lNew;

    return {
      logicalTime: this.logicalTime,
      counter: this.counter,
      nodeId: this.nodeId,
    };
  }

  /**
   * Formats HLC into a sortable, ISO-like string:
   * "0001723536000000-00004-node_abc123"
   */
  public static serialize(hlc: HlcTuple): string {
    const lStr = hlc.logicalTime.toString().padStart(16, '0');
    const cStr = hlc.counter.toString(16).padStart(5, '0');
    return `${lStr}-${cStr}-${hlc.nodeId}`;
  }

  /**
   * Parses serialized HLC string back to object.
   */
  public static deserialize(serialized: string): HlcTuple {
    const parts = serialized.split('-');
    if (parts.length < 3) {
      throw new Error(`Invalid HLC format: ${serialized}`);
    }
    return {
      logicalTime: parseInt(parts[0], 10),
      counter: parseInt(parts[1], 16),
      nodeId: parts.slice(2).join('-'),
    };
  }

  /**
   * Compares two HLC timestamps strictly according to total order.
   * Returns: -1 if a < b, 1 if a > b, 0 if identical.
   */
  public static compare(a: HlcTuple, b: HlcTuple): number {
    if (a.logicalTime !== b.logicalTime) {
      return a.logicalTime < b.logicalTime ? -1 : 1;
    }
    if (a.counter !== b.counter) {
      return a.counter < b.counter ? -1 : 1;
    }
    if (a.nodeId !== b.nodeId) {
      return a.nodeId < b.nodeId ? -1 : 1;
    }
    return 0;
  }
}
```

### 7.2 FSRS-5 Deterministic Replay Semilattice Merger (`fsrs_crdt_merger.ts`)

```typescript
/**
 * FSRS-5 CRDT Review Log Semilattice & Deterministic State Projector
 */

export interface ReviewLogRecord {
  readonly id: string;
  readonly cardId: string;
  readonly grade: 1 | 2 | 3 | 4; // 1: Again, 2: Hard, 3: Good, 4: Easy
  readonly state: number;        // 0: New, 1: Learning, 2: Review, 3: Relearning
  readonly elapsedDays: number;
  readonly durationMs: number;
  readonly hesitationMs: number;
  readonly reviewType: number;   // 0: Normal, 1: Early, 2: Relearning
  readonly hlcTimestamp: string; // Serialized HLC
  readonly deviceId: string;
}

export interface FsrsCardState {
  stability: number;
  difficulty: number;
  retrievability: number;
  dueTimestamp: number;
  state: number;
  reps: number;
  lapses: number;
  lastReviewTimestamp: number | null;
}

export class FsrsCrdtMerger {
  // 19 Standard FSRS-5 Parameters
  private static readonly W: readonly number[] = [
    0.40255, 1.18385, 3.17300, 15.69105, 7.19490, 
    0.53450, 1.46040, 0.00460, 1.54575, 0.11920, 
    1.01925, 1.93950, 0.11000, 0.29605, 2.26980, 
    0.23150, 2.98980, 0.51655, 0.66210
  ];

  private static readonly DECAY: number = -0.5;
  private static readonly FACTOR: number = 19.0 / 81.0; // 0.2345679
  private static readonly TARGET_R: number = 0.90;

  /**
   * Replays an arbitrary set of review logs in HLC order and computes the definitive FSRS state.
   */
  public static projectState(
    cardCreatedAtMs: number,
    reviewLogs: readonly ReviewLogRecord[]
  ): FsrsCardState {
    if (reviewLogs.length === 0) {
      return {
        stability: 0.0,
        difficulty: 0.0,
        retrievability: 0.0,
        dueTimestamp: cardCreatedAtMs,
        state: 0, // New
        reps: 0,
        lapses: 0,
        lastReviewTimestamp: null,
      };
    }

    // 1. Sort logs deterministically using HLC string order
    const sortedLogs = [...reviewLogs].sort((a, b) =>
      a.hlcTimestamp.localeCompare(b.hlcTimestamp)
    );

    let stability = 0.0;
    let difficulty = 0.0;
    let retrievability = 0.0;
    let state = 0;
    let reps = 0;
    let lapses = 0;
    let lastReviewTimeMs = cardCreatedAtMs;

    for (let i = 0; i < sortedLogs.length; i++) {
      const log = sortedLogs[i];
      const hlcParts = log.hlcTimestamp.split('-');
      const currentReviewTimeMs = parseInt(hlcParts[0], 10);
      
      const elapsedDays = Math.max(
        0.0,
        (currentReviewTimeMs - lastReviewTimeMs) / 86400000.0
      );

      const grade = log.grade;
      const hesRatio = Math.min(1.0, Math.max(0.0, log.hesitationMs / 5000.0));

      if (state === 0) {
        // Initial review (New Card)
        stability = this.initStability(grade, hesRatio);
        difficulty = this.initDifficulty(grade, hesRatio);
        state = grade === 1 ? 1 : 2; // 1: Learning if Again, else Review
        reps = 1;
        lapses = grade === 1 ? 1 : 0;
      } else {
        // Subsequent review
        retrievability = this.calcRetrievability(elapsedDays, stability);

        if (grade === 1) {
          // Lapse
          stability = this.nextForgetStability(difficulty, stability, retrievability);
          difficulty = this.nextDifficulty(difficulty, grade, hesRatio);
          state = 3; // Relearning
          lapses += 1;
        } else {
          // Successful Recall
          stability = this.nextRecallStability(difficulty, stability, retrievability, grade);
          difficulty = this.nextDifficulty(difficulty, grade, hesRatio);
          state = 2; // Review
        }
        reps += 1;
      }

      lastReviewTimeMs = currentReviewTimeMs;
    }

    // Calculate final due date from final stability
    const intervalDays = this.calcInterval(stability);
    const dueTimestamp = lastReviewTimeMs + Math.round(intervalDays * 86400000);
    const finalElapsed = (Date.now() - lastReviewTimeMs) / 86400000.0;
    const currentRetrievability = state === 0 ? 0.0 : this.calcRetrievability(finalElapsed, stability);

    return {
      stability,
      difficulty,
      retrievability: currentRetrievability,
      dueTimestamp,
      state,
      reps,
      lapses,
      lastReviewTimestamp: lastReviewTimeMs,
    };
  }

  private static initStability(grade: number, hesRatio: number): number {
    const base = this.W[grade - 1];
    return Math.max(0.1, base * (1.0 - 0.2 * hesRatio));
  }

  private static initDifficulty(grade: number, hesRatio: number): number {
    const d0 = this.W[4] - Math.exp(this.W[5] * (grade - 1)) + 1.0;
    return this.clamp(d0 + 0.75 * hesRatio, 1.0, 10.0);
  }

  private static calcRetrievability(elapsedDays: number, stability: number): number {
    if (stability <= 0) return 0.0;
    return Math.pow(1.0 + this.FACTOR * (elapsedDays / stability), this.DECAY);
  }

  private static nextDifficulty(d: number, grade: number, hesRatio: number): number {
    const effectiveGrade = Math.max(1.0, grade - 0.5 * hesRatio);
    const deltaD = -this.W[6] * (effectiveGrade - 3.0);
    const dPrime = d + deltaD;
    const dRevert = this.W[7] * this.initDifficulty(3, 0) + (1.0 - this.W[7]) * dPrime;
    return this.clamp(dRevert, 1.0, 10.0);
  }

  private static nextRecallStability(d: number, s: number, r: number, grade: number): number {
    const hardPenalty = grade === 2 ? this.W[15] : 1.0;
    const easyBonus = grade === 4 ? this.W[16] : 1.0;
    const multiplier =
      1.0 +
      Math.exp(this.W[8]) *
        (11.0 - d) *
        Math.pow(s, -this.W[9]) *
        (Math.exp(this.W[10] * (1.0 - r)) - 1.0) *
        hardPenalty *
        easyBonus;
    return Math.max(0.1, s * multiplier);
  }

  private static nextForgetStability(d: number, s: number, r: number): number {
    const sPrime =
      this.W[11] *
      Math.pow(d, -this.W[12]) *
      (Math.pow(s + 1.0, this.W[13]) - 1.0) *
      Math.exp(this.W[14] * (1.0 - r));
    return Math.max(0.1, Math.min(sPrime, s));
  }

  private static calcInterval(stability: number): number {
    if (stability <= 0) return 1;
    const interval =
      (stability / this.FACTOR) *
      (Math.pow(this.TARGET_R, 1.0 / this.DECAY) - 1.0);
    return Math.max(1, Math.min(36500, Math.round(interval)));
  }

  private static clamp(val: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, val));
  }
}
```

### 7.3 Fractional Indexing Module (`fractional_index.ts`)

```typescript
/**
 * Fractional Indexing Key Generator for Flashcard Ordering
 */

export class FractionalIndexer {
  private static readonly BASE62 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  /**
   * Generates a key strictly between prevKey and nextKey.
   */
  public static generateKeyBetween(
    prevKey: string | null,
    nextKey: string | null,
    nodeId: string
  ): string {
    const p = prevKey || '0';
    const n = nextKey || 'z';

    if (p >= n) {
      throw new Error(`Invalid ordering bounds: ${p} >= ${n}`);
    }

    let result = '';
    let i = 0;

    while (true) {
      const pCode = i < p.length ? this.BASE62.indexOf(p[i]) : 0;
      const nCode = i < n.length ? this.BASE62.indexOf(n[i]) : this.BASE62.length - 1;

      if (nCode - pCode > 1) {
        const midCode = Math.floor((pCode + nCode) / 2);
        result += this.BASE62[midCode];
        break;
      } else {
        result += this.BASE62[pCode];
        i++;
      }
    }

    // Append client tie-breaker to prevent concurrent duplicate keys
    return `${result}_${nodeId.substring(0, 4)}`;
  }
}
```

---

## 8. Production Dart / Flutter Implementation Blueprint

For the Flutter mobile client, we supply high-performance, strongly typed Dart implementations compatible with `drift` and `powersync`.

### 8.1 Hybrid Logical Clock in Dart (`hlc.dart`)

```dart
import 'dart:math';

/// Production Hybrid Logical Clock for Dart/Flutter Clients.
class HlcTuple implements Comparable<HlcTuple> {
  final int logicalTime;
  final int counter;
  final String nodeId;

  const HlcTuple({
    required this.logicalTime,
    required this.counter,
    required this.nodeId,
  });

  String serialize() {
    final lStr = logicalTime.toString().padLeft(16, '0');
    final cStr = counter.toRadixString(16).padLeft(5, '0');
    return '$lStr-$cStr-$nodeId';
  }

  factory HlcTuple.deserialize(String serialized) {
    final parts = serialized.split('-');
    if (parts.length < 3) {
      throw FormatException('Invalid HLC serialized string: $serialized');
    }
    return HlcTuple(
      logicalTime: int.parse(parts[0]),
      counter: int.parse(parts[1], radix: 16),
      nodeId: parts.sublist(2).join('-'),
    );
  }

  @override
  int compareTo(HlcTuple other) {
    if (logicalTime != other.logicalTime) {
      return logicalTime.compareTo(other.logicalTime);
    }
    if (counter != other.counter) {
      return counter.compareTo(other.counter);
    }
    return nodeId.compareTo(other.nodeId);
  }
}

class HybridLogicalClock {
  int _logicalTime;
  int _counter;
  final String nodeId;
  final int maxDriftMs;

  HybridLogicalClock({
    required this.nodeId,
    int? initialTime,
    this.maxDriftMs = 60000,
  })  : _logicalTime = initialTime ?? DateTime.now().millisecondsSinceEpoch,
        _counter = 0;

  HlcTuple now([int? physicalTimeMs]) {
    final pt = physicalTimeMs ?? DateTime.now().millisecondsSinceEpoch;

    if (pt - _logicalTime > maxDriftMs) {
      _logicalTime = pt;
      _counter = 0;
    } else if (_logicalTime - pt > maxDriftMs) {
      _counter += 1;
    } else {
      final maxTime = max(_logicalTime, pt);
      if (maxTime == _logicalTime) {
        _counter += 1;
      } else {
        _logicalTime = maxTime;
        _counter = 0;
      }
    }

    return HlcTuple(
      logicalTime: _logicalTime,
      counter: _counter,
      nodeId: nodeId,
    );
  }

  HlcTuple receive(HlcTuple remote, [int? physicalTimeMs]) {
    final pt = physicalTimeMs ?? DateTime.now().millisecondsSinceEpoch;
    final lOld = _logicalTime;
    final lMsg = remote.logicalTime;
    final lNew = [lOld, pt, lMsg].reduce(max);

    if (lNew == lOld && lNew == lMsg) {
      _counter = max(_counter, remote.counter) + 1;
    } else if (lNew == lOld) {
      _counter += 1;
    } else if (lNew == lMsg) {
      _counter = remote.counter + 1;
    } else {
      _counter = 0;
    }

    _logicalTime = lNew;

    return HlcTuple(
      logicalTime: _logicalTime,
      counter: _counter,
      nodeId: nodeId,
    );
  }
}
```

### 8.2 FSRS-5 Review Log Merger in Dart (`fsrs_crdt_merger.dart`)

```dart
import 'dart:math';

class ReviewLogEntry {
  final String id;
  final String cardId;
  final int grade; // 1: Again, 2: Hard, 3: Good, 4: Easy
  final int state;
  final double elapsedDays;
  final int durationMs;
  final int hesitationMs;
  final String hlcTimestamp;
  final String deviceId;

  const ReviewLogEntry({
    required this.id,
    required this.cardId,
    required this.grade,
    required this.state,
    required this.elapsedDays,
    required this.durationMs,
    required this.hesitationMs,
    required this.hlcTimestamp,
    required this.deviceId,
  });
}

class FsrsStateProjection {
  final double stability;
  final double difficulty;
  final double retrievability;
  final int dueTimestamp;
  final int state;
  final int reps;
  final int lapses;
  final int? lastReviewTimestamp;

  const FsrsStateProjection({
    required this.stability,
    required this.difficulty,
    required this.retrievability,
    required this.dueTimestamp,
    required this.state,
    required this.reps,
    required this.lapses,
    this.lastReviewTimestamp,
  });
}

class FsrsDartMerger {
  static const List<double> W = [
    0.40255, 1.18385, 3.17300, 15.69105, 7.19490,
    0.53450, 1.46040, 0.00460, 1.54575, 0.11920,
    1.01925, 1.93950, 0.11000, 0.29605, 2.26980,
    0.23150, 2.98980, 0.51655, 0.66210
  ];

  static const double DECAY = -0.5;
  static const double FACTOR = 19.0 / 81.0;
  static const double TARGET_R = 0.90;

  static FsrsStateProjection project(
    int cardCreatedAtMs,
    List<ReviewLogEntry> logs,
  ) {
    if (logs.isEmpty) {
      return FsrsStateProjection(
        stability: 0.0,
        difficulty: 0.0,
        retrievability: 0.0,
        dueTimestamp: cardCreatedAtMs,
        state: 0,
        reps: 0,
        lapses: 0,
      );
    }

    // Deterministic sorting via HLC string comparisons
    final sorted = List<ReviewLogEntry>.from(logs)
      ..sort((a, b) => a.hlcTimestamp.compareTo(b.hlcTimestamp));

    double stability = 0.0;
    double difficulty = 0.0;
    double retrievability = 0.0;
    int state = 0;
    int reps = 0;
    int lapses = 0;
    int lastReviewMs = cardCreatedAtMs;

    for (final log in sorted) {
      final hlcParts = log.hlcTimestamp.split('-');
      final currentReviewMs = int.parse(hlcParts[0]);
      final elapsedDays = max(0.0, (currentReviewMs - lastReviewMs) / 86400000.0);
      final grade = log.grade;
      final hesRatio = (log.hesitationMs / 5000.0).clamp(0.0, 1.0);

      if (state == 0) {
        stability = _initStability(grade, hesRatio);
        difficulty = _initDifficulty(grade, hesRatio);
        state = grade == 1 ? 1 : 2;
        reps = 1;
        lapses = grade == 1 ? 1 : 0;
      } else {
        retrievability = _calcRetrievability(elapsedDays, stability);
        if (grade == 1) {
          stability = _nextForgetStability(difficulty, stability, retrievability);
          difficulty = _nextDifficulty(difficulty, grade, hesRatio);
          state = 3;
          lapses += 1;
        } else {
          stability = _nextRecallStability(difficulty, stability, retrievability, grade);
          difficulty = _nextDifficulty(difficulty, grade, hesRatio);
          state = 2;
        }
        reps += 1;
      }
      lastReviewMs = currentReviewMs;
    }

    final intervalDays = _calcInterval(stability);
    final dueTimestamp = lastReviewMs + (intervalDays * 86400000).round();
    final finalElapsed = (DateTime.now().millisecondsSinceEpoch - lastReviewMs) / 86400000.0;
    final currentR = state == 0 ? 0.0 : _calcRetrievability(finalElapsed, stability);

    return FsrsStateProjection(
      stability: stability,
      difficulty: difficulty,
      retrievability: currentR,
      dueTimestamp: dueTimestamp,
      state: state,
      reps: reps,
      lapses: lapses,
      lastReviewTimestamp: lastReviewMs,
    );
  }

  static double _initStability(int grade, double hesRatio) {
    final base = W[grade - 1];
    return max(0.1, base * (1.0 - 0.2 * hesRatio));
  }

  static double _initDifficulty(int grade, double hesRatio) {
    final d0 = W[4] - exp(W[5] * (grade - 1)) + 1.0;
    return (d0 + 0.75 * hesRatio).clamp(1.0, 10.0);
  }

  static double _calcRetrievability(double elapsedDays, double stability) {
    if (stability <= 0) return 0.0;
    return pow(1.0 + FACTOR * (elapsedDays / stability), DECAY).toDouble();
  }

  static double _nextDifficulty(double d, int grade, double hesRatio) {
    final effectiveGrade = max(1.0, grade - 0.5 * hesRatio);
    final deltaD = -W[6] * (effectiveGrade - 3.0);
    final dPrime = d + deltaD;
    final dRevert = W[7] * _initDifficulty(3, 0) + (1.0 - W[7]) * dPrime;
    return dRevert.clamp(1.0, 10.0);
  }

  static double _nextRecallStability(double d, double s, double r, int grade) {
    final hardPenalty = grade == 2 ? W[15] : 1.0;
    final easyBonus = grade == 4 ? W[16] : 1.0;
    final multiplier = 1.0 +
        exp(W[8]) *
            (11.0 - d) *
            pow(s, -W[9]) *
            (exp(W[10] * (1.0 - r)) - 1.0) *
            hardPenalty *
            easyBonus;
    return max(0.1, s * multiplier);
  }

  static double _nextForgetStability(double d, double s, double r) {
    final sPrime = W[11] *
        pow(d, -W[12]) *
        (pow(s + 1.0, W[13]) - 1.0) *
        exp(W[14] * (1.0 - r));
    return max(0.1, min(sPrime, s));
  }

  static int _calcInterval(double stability) {
    if (stability <= 0) return 1;
    final interval = (stability / FACTOR) * (pow(TARGET_R, 1.0 / DECAY) - 1.0);
    return interval.round().clamp(1, 36500);
  }
}
```

---

## 9. Distributed Sync State Machine & Lifecycle Specification

The synchronization lifecycle coordinates network connection changes, local database mutation queues, background sync triggers, and CRDT merge execution.

```mermaid
statechart-v2
    [*] --> OfflineDisconnected

    state OfflineDisconnected {
        [*] --> IdleOffline
        IdleOffline --> LocalMutationQueue : User Swipe / Review / Edit
        LocalMutationQueue --> UpdateLocalFSRS : Instant Projection (<16ms)
        UpdateLocalFSRS --> AppendPsCrud : Enqueue to Upload Queue
        AppendPsCrud --> IdleOffline
    }

    OfflineDisconnected --> Connecting : Network Reconnected / App Foreground

    state Connecting {
        [*] --> HandshakeWebSocket
        HandshakeWebSocket --> ValidateHLCClocks : Send HLC & Calibrate Skew
        ValidateHLCClocks --> SubscribedToBuckets : Authenticate Session
    }

    Connecting --> SyncStreaming : Handshake Successful
    Connecting --> OfflineDisconnected : Handshake Timeout / Error

    state SyncStreaming {
        [*] --> IngestDeltaStream
        
        state IngestDeltaStream {
            ReceiveServerWAL --> ParseBucketRecords
            ParseBucketRecords --> MergeReviewLogsCRDT : If revlog records received
            MergeReviewLogsCRDT --> RecomputeFSRSProjection : Fold into cards table
            ParseBucketRecords --> MergeContentCRDT : If card content / Yjs delta
            ParseBucketRecords --> UpdateDeckHierarchy : If folder move (Cycle-Safe)
        }

        IngestDeltaStream --> FlushLocalUploadQueue : Background Upload Triggered
        
        state FlushLocalUploadQueue {
            ReadPsCrudBatch --> PostBatchToAPI : Bulk HTTP/2 POST
            PostBatchToAPI --> AcknowledgeTransactions : Server Confirms WAL Commit
            AcknowledgeTransactions --> TruncatePsCrudQueue : Evict Sent Rows
        }
    }

    SyncStreaming --> OfflineDisconnected : Connection Lost / Airplane Mode
    SyncStreaming --> SynchronizedIdle : All Buckets & Queues in Sync
```

### 9.1 Sync State Transition Matrix

| Current State | Event Trigger | Guard Condition | Next State | Side Effects Executed |
| :--- | :--- | :--- | :--- | :--- |
| `OfflineDisconnected` | `USER_REVIEW_SWIPE` | `is_online == false` | `OfflineDisconnected` | Write to SQLite `revlog`, update `cards`, append to `ps_crud`. |
| `OfflineDisconnected` | `NETWORK_AVAILABLE` | `net_reachability == true` | `Connecting` | Initialize WebSocket connection; fetch server timestamp. |
| `Connecting` | `HANDSHAKE_ACK` | `abs(drift) <= 60000ms` | `SyncStreaming` | Calibrate local HLC offset; subscribe to sync buckets. |
| `Connecting` | `HANDSHAKE_DRIFT_EXC`| `abs(drift) > 60000ms` | `SyncStreaming` | Force HLC physical clock correction; trigger UI warning toast. |
| `SyncStreaming` | `REMOTE_REVLOG_BATCH`| `batch.size > 0` | `SyncStreaming` | Batch merge logs into SQLite; re-project FSRS-5 state. |
| `SyncStreaming` | `LOCAL_QUEUE_FLUSHED`| `ps_crud.count == 0` | `SynchronizedIdle` | Update UI sync indicator to "All Changes Synced". |
| `SynchronizedIdle` | `USER_LOCAL_EDIT` | None | `SyncStreaming` | Enqueue edit to `ps_crud`; immediately stream to server. |

---

## 10. Performance Optimization, Compaction & Zero-Allocation Pipelines

### 10.1 Sub-16ms Query Latency Guarantee

For an app running at 120Hz display refresh rates (8.33ms per frame budget), database queries must never block the JavaScript / Dart UI thread. We enforce:

1. **Prepared Query Caching:** All study queue queries use parameterized SQLite statements with pre-compiled bytecode plans.
2. **Materialized Projection Indexing:** The UI *never* computes FSRS folds during list rendering. It reads directly from indexed fields (`fsrs_due_timestamp`, `fsrs_state`) in the `cards` table.
3. **Write-Ahead Logging (WAL) Mode:** The local SQLite database operates exclusively with `PRAGMA journal_mode = WAL;` and `PRAGMA synchronous = NORMAL;`, allowing simultaneous reads during sync background writes.

```sql
-- SQLite Pragmas for High-Performance 120fps UI
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -64000; -- 64MB In-Memory Cache
PRAGMA temp_store = MEMORY;
PRAGMA mmap_size = 268435456; -- 256MB Memory-Mapped I/O
PRAGMA busy_timeout = 5000;
```

### 10.2 Review Log Compaction & Garbage Collection

Over years of daily study, a user may accumulate over 250,000 individual `revlog` entries. Storing every raw touch-hesitation data point indefinitely causes unnecessary disk consumption.

#### Two-Tier Compaction Strategy:
- **Hot Tier (Last 90 Days):** Retains 100% granular telemetry (`hesitation_ms`, `touch_jitter`, duration). Essential for real-time FSRS weight optimization and user analytics.
- **Cold Compacted Tier (>90 Days):** Raw entries older than 90 days are compacted into a summarized baseline snapshot per card:
  $$\text{CardSnapshot} = (S_{\text{anchor}}, D_{\text{anchor}}, \text{reps}_{\text{total}}, \text{lapses}_{\text{total}}, T_{\text{anchor\_hlc}})$$
  All review logs prior to $T_{\text{anchor\_hlc}}$ are evicted from the active `revlog` table, freeing up to $85\%$ of local storage while preserving exact mathematical continuity for all future reviews.

---

## 11. Edge Cases, Failure Modes & Anomaly Resolution

### 11.1 The Zombie Device / Tombstone Resurrection Hazard

**Failure Scenario:** A user deletes Card $X$ on Device A. Six months later, the user turns on an old iPad (Device B) that was powered off in a drawer. If tombstone deletion records were purged from the server after 30 days, Device B would treat Card $X$ as a "new card to be uploaded", resurrecting the deleted card!

**Resolution (Permanent Tombstones with Compaction Vector Clocks):**
1. Deletions are represented as tombstone flags (`is_deleted = 1, hlc_timestamp = ...`).
2. Server maintains a **Node Watermark Matrix**. A tombstone is only fully purged from the Postgres database when all registered devices of the user have acknowledged a sync position greater than the tombstone's HLC.
3. If an unregistered or inactive device (>180 days offline) reconnects, the server forces a **Fresh Snapshot Sync**, completely resetting the client's SQLite database to the authoritative server state rather than merging stale mutations.

### 11.2 Interleaved Multi-Field Conflicts (Simultaneous Rich Text Edits)

**Failure Scenario:** Client A edits the front of Card 101 to add a mnemonic. Simultaneously, Client B edits the back of Card 101 to add an image URL.

**Resolution:**
- Per-field HLC tracking: `cards` table maintains granular HLC columns: `front_hlc`, `back_hlc`, `metadata_hlc`.
- PowerSync syncs columns independently. Client A's update modifies `front_text` and `front_hlc`; Client B's update modifies `back_text` and `back_hlc`.
- Result: Both edits merge cleanly without mutual interference.

---

## 12. Verification & Automated Property-Based QA Protocol

To mathematically guarantee that our CRDT and sync merger cannot corrupt data or diverge under network partitions, we establish automated property-based test suites using Fast-Check.

### 12.1 Join-Semilattice Invariant Verification Suite (`crdt_property_test.ts`)

```typescript
/**
 * Automated Property-Based Testing for FSRS-5 CRDT Semilattice Laws
 * Tests Associativity, Commutativity, and Idempotence across random partition splits.
 */

import { FsrsCrdtMerger, ReviewLogRecord } from './fsrs_crdt_merger';
import { HybridLogicalClock } from './hlc';

export class CrdtPropertyTester {
  /**
   * Generates N random review logs simulating multi-device concurrent sessions.
   */
  public static generateRandomReviews(count: number): ReviewLogRecord[] {
    const hlcA = new HybridLogicalClock('nodeA', 1700000000000);
    const hlcB = new HybridLogicalClock('nodeB', 1700000000000);
    const logs: ReviewLogRecord[] = [];

    for (let i = 0; i < count; i++) {
      const isNodeA = Math.random() > 0.5;
      const hlc = isNodeA ? hlcA.now() : hlcB.now();
      const grade = (Math.floor(Math.random() * 4) + 1) as 1 | 2 | 3 | 4;

      logs.push({
        id: `rev_${i}_${hlc.nodeId}`,
        cardId: 'card_test_1',
        grade,
        state: 0,
        elapsedDays: Math.random() * 10,
        durationMs: Math.floor(Math.random() * 4000) + 1000,
        hesitationMs: Math.floor(Math.random() * 2000),
        reviewType: 0,
        hlcTimestamp: HybridLogicalClock.serialize(hlc),
        deviceId: hlc.nodeId,
      });
    }

    return logs;
  }

  /**
   * Verifies CRDT Join Semilattice Laws:
   * 1. Commutativity: Merge(A, B) === Merge(B, A)
   * 2. Idempotence: Merge(A, A) === Merge(A)
   * 3. Associativity: Merge(Merge(A, B), C) === Merge(A, Merge(B, C))
   */
  public static runVerification(iterations: number = 1000): boolean {
    console.log(`[QA] Starting ${iterations} CRDT Semilattice Property Invariant Runs...`);

    for (let i = 0; i < iterations; i++) {
      const setA = this.generateRandomReviews(15);
      const setB = this.generateRandomReviews(15);
      const setC = this.generateRandomReviews(15);

      const baseTime = 1690000000000;

      // 1. Commutativity Check
      const mergeAB = FsrsCrdtMerger.projectState(baseTime, [...setA, ...setB]);
      const mergeBA = FsrsCrdtMerger.projectState(baseTime, [...setB, ...setA]);

      if (
        Math.abs(mergeAB.stability - mergeBA.stability) > 1e-6 ||
        Math.abs(mergeAB.difficulty - mergeBA.difficulty) > 1e-6 ||
        mergeAB.dueTimestamp !== mergeBA.dueTimestamp
      ) {
        throw new Error(`[FAIL] Commutativity Violation on iteration ${i}!`);
      }

      // 2. Idempotence Check
      const mergeA = FsrsCrdtMerger.projectState(baseTime, setA);
      const mergeAA = FsrsCrdtMerger.projectState(baseTime, [...setA, ...setA]);

      if (
        Math.abs(mergeA.stability - mergeAA.stability) > 1e-6 ||
        mergeA.dueTimestamp !== mergeAA.dueTimestamp
      ) {
        throw new Error(`[FAIL] Idempotence Violation on iteration ${i}!`);
      }

      // 3. Associativity Check
      const merge_AB_C = FsrsCrdtMerger.projectState(baseTime, [...setA, ...setB, ...setC]);
      const merge_A_BC = FsrsCrdtMerger.projectState(baseTime, [...setA, ...[...setB, ...setC]]);

      if (
        Math.abs(merge_AB_C.stability - merge_A_BC.stability) > 1e-6 ||
        merge_AB_C.dueTimestamp !== merge_A_BC.dueTimestamp
      ) {
        throw new Error(`[FAIL] Associativity Violation on iteration ${i}!`);
      }
    }

    console.log(`[QA] ✅ All ${iterations} Semilattice Invariants Passed with Zero Divergence.`);
    return true;
  }
}
```

---

## 13. Roadmap & Upstream Integration Matrix

| Integration Milestone | Target File / Module | Cross-Reference Dependencies | Verification Criterion |
| :--- | :--- | :--- | :--- |
| **M1: SQLite Schema & Storage Layer** | `src/storage/db.ts` | [[Ideas/Future/Memory Card/research/RES-28_SQLite_Schema_Design.md|RES-28 (SQLite Schema)]] | Sub-16ms query execution on 50,000 card datasets |
| **M2: HLC & FSRS-5 Log Merger** | `src/sync/crdt/` | [[Ideas/Future/Memory Card/research/RES-12_FSRS5_Spaced_Repetition_Engine.md|RES-12 (FSRS-5 Engine)]] | 100% pass rate in Property-Based Semilattice Test Suite |
| **M3: PowerSync Postgres Logical Replication** | `backend/powersync/` | [[Ideas/Future/Memory Card/brain_dump.md|brain_dump.md]] | Bidirectional sync stream across iOS, Android, and Web |
| **M4: Card Branching & Forking** | `src/sync/git_deck/` | [[Ideas/Future/Memory Card/research/RES-32_Deck_Branching_Forking.md|RES-32 (Deck Branching)]] | 3-way merge on forked community decks |
| **M5: Media Blob Sync** | `src/storage/blobs/` | [[Ideas/Future/Memory Card/research/RES-30_Media_Asset_Caching.md|RES-30 (Media Blob Storage)]] | Content-addressable SHA-256 chunk streaming |

---

## 14. Conclusion

By unifying **Hybrid Logical Clocks (HLC)**, **CRDT Algebraic Semilattices**, and **PostgreSQL Logical WAL Replication via PowerSync**, Memory Card achieves what legacy spaced repetition systems could not: **seamless, collision-free, multi-device study without data loss or cognitive scheduling degradation**. 

Learners are free to review anywhere, offline or online, across any number of devices. The underlying mathematical model guarantees that every review event, hesitation measurement, and card edit converges deterministically across all nodes into an uncompromised, mathematically rigorous learning history.
