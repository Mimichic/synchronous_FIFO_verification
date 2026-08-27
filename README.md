# Synchronous FIFO — Design and Class-Based Verification

Hihi! Thanks for checking out this repository! The project here aims at the implementation of a parameterizable, synchronous FIFO (First In First Out) Register using SystemVerilog and follows it up with verification
using a testbench with all the good stuff! a generator, scoreboard, driver, monitor and a self checking scoreboard, all interacting via mailboxes and virtual interfaces. This was my attempt at putting
my systemVerilog skills to good use ^^


## Table of Contents

- [Problem Statement](#problem-statement)
- [FIFO Design](#fifo-design)
  - [Parameters and Ports](#parameters-and-ports)
  - [Internal Behavior](#internal-behavior)
- [Verification Methodology](#verification-methodology)
  - [Testbench Architecture](#testbench-architecture)
  - [Component Walkthrough](#component-walkthrough)
  - [A Cycle-by-Cycle Example](#a-cycle-by-cycle-example)
- [Repository Layout](#repository-layout)
- [Running the Simulation](#running-the-simulation)
- [Sample Output](#sample-output)
- [Limitations and Possible Extensions](#limitations-and-possible-extensions)

## Problem Statement

A register remains as the most common building block when talking about digital design. It is employed for a simple RISC V processor as well as an accelerator and still remains
one of the most significant, yet simple pieces of digital logic one should ideally master. Thus this makes the technical know how of building a synchronous register extremely important. It is also important that 
the said register passes through several edge cases to prove its functional correctness. Naturally, it becomes one of the first things a verification engineer is expected to know
how to verify thoroughly.

The problem this project addresses are as follows:

1. **Design** A synchronous FIFO that passes edge cases like writing when the register is full or reading when register is empty, and also the part where one decides to read and write at the same time.
2. **Verify** that design without relying on a handful of hand-picked directed tests. Instead,
   the testbench generates randomized, weighted-probability read/write traffic and checks
   every single transaction against an independent reference model, so that confidence in the
   design comes from volume and coverage of stimulus rather than a few examples the designer
   happened to think of.

## FIFO Design

The DUT lives in [`rtl/synchronous_FIFO.sv`](rtl/synchronous_FIFO.sv). It's a single-clock-domain,
register-array-based FIFO — no dual-port memory or Gray-coded pointers are needed here since
both the read and write sides share one clock.

### Parameters and Ports

| Parameter    | Default | Description                     |
|--------------|---------|----------------------------------|
| `DATA_WIDTH` | 8       | Width of `data_in` / `data_out`  |
| `DEPTH`      | 16      | Number of storage slots          |

| Signal      | Direction | Width          | Description                     |
|-------------|-----------|----------------|-----------------------------------|
| `clk`       | input     | 1              | System clock                      |
| `rst`       | input     | 1              | Synchronous, active-high reset    |
| `wr_en`     | input     | 1              | Write enable                      |
| `rd_en`     | input     | 1              | Read enable                       |
| `data_in`   | input     | `DATA_WIDTH`   | Write data                        |
| `data_out`  | output    | `DATA_WIDTH`   | Read data (combinationally reflects the word at the read pointer) |
| `full`      | output    | 1              | Asserted when the FIFO holds `DEPTH` entries |
| `empty`     | output    | 1              | Asserted when the FIFO holds zero entries |

### Internal Behavior

Storage is a plain register array, `data_register[DEPTH-1:0]`, indexed by a `read` pointer and
a `write` pointer, each `$clog2(DEPTH)` bits wide. Rather than the classic "one extra pointer
bit" trick for distinguishing full from empty, this design keeps a separate `tracker` counter
(`$clog2(DEPTH)+1` bits wide) that always holds the current occupancy:

- `full` is simply `tracker == DEPTH`.
- `empty` is simply `tracker == 0`.

On every clock edge, the design looks at `{wr_en && !full, rd_en && !empty}` as a 2-bit case
selector:

| `wr_en && !full` | `rd_en && !empty` | Action |
|:---:|:---:|---|
| 0 | 0 | No-op — pointers and `tracker` hold |
| 1 | 0 | Write only — `data_in` is stored at `write`, `write++`, `tracker++` |
| 0 | 1 | Read only — `read++`, `tracker--` |
| 1 | 1 | Simultaneous read + write — both pointers advance, `tracker` is unchanged |

This last row is the interesting corner case: if the FIFO is neither full nor empty and both
enables are asserted in the same cycle, one word is written and one is read in the same clock,
and the occupancy stays flat. If the FIFO *is* full, only the read half of that row can
actually happen (since `wr_en && !full` evaluates to 0), and vice versa for empty — which is
exactly the kind of edge case the testbench below is designed to hit repeatedly through random
stimulus rather than a single directed test.

`data_out` is a continuous read of `data_register[read]` — it's combinational, not registered,
so it reflects the oldest unread entry as soon as the read pointer moves.

## Verification Methodology

The verification environment lives in [`tb/`](tb) and follows a layered structure that will be
familiar to anyone who has worked with UVM, but is written directly in SystemVerilog classes,
mailboxes, and a virtual interface — no verification library is required to compile or run it.

### Testbench Architecture

```
                     ┌─────────────┐
                     │  generator  │  randomizes transaction_object,
                     │             │  weighted 70% wr_en / 70% rd_en
                     └──────┬──────┘
                            │ mailbox (gen_to_drv)
                            ▼
                     ┌─────────────┐
                     │   driver    │  drives wr_en/rd_en/data_in
                     │             │  onto fifo_if.tb @ posedge clk
                     └──────┬──────┘
                            │
                            ▼
                  ┌───────────────────┐
                  │  synchronous_FIFO │   ← DUT
                  │       (rtl/)      │
                  └─────────┬─────────┘
                            │
                            ▼
                     ┌─────────────┐
                     │   monitor   │  passively samples the interface
                     │             │  every clock edge
                     └──────┬──────┘
                            │ mailbox (mtr_to_scr)
                            ▼
                     ┌─────────────┐
                     │ scoreboard  │  reference-model queue;
                     │             │  compares expected vs. actual
                     └─────────────┘
```

All of the above is instantiated and wired together by `environment`, which itself is
instantiated by `top_testbench`, the simulation's top-level module.

### Component Walkthrough

| Verification concept | Where it appears here |
|---|---|
| DUT/testbench signal boundary, split by direction | [`fifo_if.sv`](tb/fifo_if.sv) — a `dut` modport and a `tb` modport on the same interface |
| Randomizable stimulus item | [`transaction.sv`](tb/transaction.sv) — `rand` fields for `wr_en`, `rd_en`, `data_in`, plus captured outputs `data_out`, `full`, `empty` |
| Weighted constrained-random stimulus | `signal_probability` constraint in `transaction.sv` — a `dist` clause biases both `wr_en` and `rd_en` to 70% asserted, so back-to-back writes/reads and the simultaneous-access corner case above are exercised often, not just occasionally |
| Stimulus generation, decoupled from driving | [`generator.sv`](tb/generator.sv) — randomizes `total_tests` transactions and hands each one off through a mailbox |
| Pin-level wiggling of the DUT | [`driver.sv`](tb/driver.sv) — pulls a transaction from the mailbox and drives it through the `tb` modport, synchronized to `posedge clk` |
| Passive observation | [`monitor.sv`](tb/monitor.sv) — samples the interface every clock edge (inputs *and* the DUT's resulting outputs) and forwards a filled-in transaction to the scoreboard |
| Self-checking, independent reference model | [`scoreboard.sv`](tb/scoreboard.sv) — maintains its own SystemVerilog queue (`logic [DATA_WIDTH-1:0] ideal_fifo [$]`) as a golden FIFO; on every observed transaction it pops on a read and compares against `data_out`, then pushes on a write, flagging any mismatch with `$error` |
| Environment integration | [`environment.sv`](tb/environment.sv) — instantiates generator, driver, monitor, and scoreboard, builds the two mailboxes connecting them, and runs all four concurrently with `fork ... join_any` |
| Top-level test | [`top_testbench.sv`](tb/top_testbench.sv) — generates the clock, applies reset, instantiates the DUT and `environment`, and sets `env.gen.total_tests = 50` |

A couple of implementation details worth calling out:

- The **driver** uses a non-blocking assignment (`<=`) when it drives `wr_en`/`rd_en`/`data_in`
  onto the interface, so the values land cleanly after the clock edge, matching what the
  synchronous DUT expects to sample.
- The **monitor**, by contrast, samples with a blocking assignment one time step after the
  clock edge (`@(posedge sf.clk); #1;`), which lets it capture the DUT's *combinational*
  outputs (`data_out`, `full`, `empty`) only after they've settled in response to that same
  edge — avoiding a race between the DUT's own always block and the monitor's read of its
  outputs.
- The **scoreboard** deliberately checks the read *before* processing the write within the same
  transaction, mirroring the DUT's own read-before-conflicts-with-write ordering when both
  `wr_en` and `rd_en` are asserted together.

### A Cycle-by-Cycle Example

To make the flow concrete, here's what happens for a single randomized transaction where the
generator happens to produce `wr_en=1, rd_en=0, data_in=8'hA5`, with the FIFO neither full nor
empty:

1. **Generator** creates a `transaction_object`, calls `randomize()`, and gets back
   `wr_en=1, rd_en=0, data_in=0xA5`. It pushes this object into `gen_to_drv`.
2. **Driver** pulls it out of the mailbox, waits for `posedge clk`, and drives
   `sf.wr_en <= 1; sf.rd_en <= 0; sf.data_in <= 8'hA5;` onto the physical interface.
3. **DUT** sees `wr_en && !full` on the following evaluation, so it stores `0xA5` at
   `data_register[write]`, increments `write`, and increments `tracker`.
4. **Monitor**, one time step after that same clock edge, samples `wr_en=1`, `rd_en=0`,
   `data_in=0xA5`, and the DUT's current `data_out`/`full`/`empty`, and pushes this into
   `mtr_to_scr`.
5. **Scoreboard** pulls the observed transaction: since `rd_en` is 0 there's nothing to check
   against `ideal_fifo`, but since `wr_en` is 1 and `full` was 0, it pushes `0xA5` onto its own
   `ideal_fifo` queue — keeping its golden model in lockstep with what the DUT should now
   contain.

Later, when a transaction with `rd_en=1` comes through, the scoreboard pops `0xA5` back off the
front of `ideal_fifo` and checks it against the DUT's `data_out`, reporting a `$display` on a
match or an `$error` on a mismatch.

## Repository Layout

```
synchronous_FIFO_verification/
├── rtl/
│   └── synchronous_FIFO.sv     DUT: parameterized synchronous FIFO
│
└── tb/
    ├── fifo_if.sv               interface with dut/tb modports
    ├── transaction.sv           randomizable transaction (stimulus) object
    ├── generator.sv             generates randomized transactions
    ├── driver.sv                 drives transactions onto the DUT interface
    ├── monitor.sv                samples DUT interface, packages observed transactions
    ├── scoreboard.sv             reference model + self-checking comparison
    ├── environment.sv            instantiates and connects gen/drv/mon/scb
    └── top_testbench.sv          top-level: clock/reset, DUT instance, environment
```

## Running the Simulation

This testbench uses SystemVerilog classes, mailboxes, and a virtual interface, so it needs a
simulator with reasonably complete class-based SystemVerilog support (e.g. Questa/ModelSim,
VCS, or Xcelium). Compile the RTL and all testbench files together, with `top_testbench` as
the top module. File order matters — `fifo_if.sv` and `transaction.sv` must be compiled before
the classes/modules that reference them.

**Questa / ModelSim**
```bash
vlog rtl/synchronous_FIFO.sv tb/fifo_if.sv tb/transaction.sv tb/generator.sv tb/driver.sv tb/monitor.sv tb/scoreboard.sv tb/environment.sv tb/top_testbench.sv
vsim -c top_testbench -do "run -all; quit"
```

**VCS**
```bash
vcs -sverilog -full64 rtl/synchronous_FIFO.sv tb/*.sv -top top_testbench -R
```

**Xcelium**
```bash
xrun -sv rtl/synchronous_FIFO.sv tb/*.sv -top top_testbench
```

To change the number of randomized transactions per run, edit `env.gen.total_tests` in
`tb/top_testbench.sv`. To change FIFO sizing, edit the `DATA_WIDTH` parameter (and the
hardcoded depth of `16`) passed to the `synchronous_FIFO` instance in the same file.

## Sample Output

A run prints one line per generated transaction, one line per driven transaction, one line per
monitored sample, and a pass/fail line from the scoreboard for every checked read:

```
randomization successful! generated 1 out of 50 packets

[Driver] has successfully received: wr_en :   1 | rd_en :   0 | data_in : 165
[MONITOR]: data in: 165 | data out:   0 | full: 0 | empty: 0
...
Yay, Correct output! expected: [165] and received: [165]
...
whoo! we made our first ever advanced testbench!
```

Any mismatch between the DUT and the scoreboard's reference queue is reported as a simulator
`$error`, e.g. `Uh oh! Check your device, expected: [X] and received: [Y]`.

## Limitations and Possible Extensions

- **No functional coverage yet.** A `covergroup` sampling `full`, `empty`, and the
  simultaneous-read-write case would give a quantitative answer to "how thoroughly did 50
  random transactions actually exercise the DUT," rather than relying on the `dist` weighting
  alone.
- **No assertions (SVA).** Properties on pointer wraparound, `full`/`empty` mutual exclusivity,
  and no-write-while-full / no-read-while-empty would catch protocol violations even without a
  scoreboard mismatch.
- **Fixed depth at the top level.** `DEPTH` is hardcoded to `16` in `top_testbench.sv` rather
  than being parameterized alongside `DATA_WIDTH`.
- **No waveform dumping.** Adding `$dumpfile`/`$dumpvars` (or the simulator-native equivalent)
  would make it easier to debug a scoreboard mismatch by inspecting the actual DUT behavior.
- **Single test scenario.** `total_tests` runs one constrained-random scenario; splitting this
  into named test cases (e.g. "fill-then-drain," "always full," "simultaneous access stress")
  would make it easier to reason about which scenario found a given bug.
