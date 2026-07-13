# 8-bit Parameterized Booth Multiplier

RTL implementation of a radix-2 Booth multiplier in Verilog, verified with a self-checking testbench and synthesized using Cadence Genus on a 90nm standard cell library.

---

## Architecture

The design uses a 3-state FSM to implement the iterative Booth algorithm:

```
IDLE → CALC → SHIFT → CALC → SHIFT → ... (N iterations) → IDLE
```

- **IDLE:** Waits for `start` signal. Loads multiplier into Q, multiplicand into M, clears accumulator A.
- **CALC:** Examines `{Q[0], q_prev}` (current and previous LSB). Adds or subtracts M from accumulator A based on Booth encoding.
- **SHIFT:** Performs arithmetic right shift on the `{A, Q}` register pair. Decrements counter. Asserts `done` and outputs product after N iterations.

### Key Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| Accumulator width | N+1 bits | Sign extension required to prevent overflow when both inputs are maximum negative (e.g. -128 × -128 in 8-bit) |
| Counter initialization | N-1 | Parameterized — scales correctly for any N |
| Done signal | Registered output | Clean handshaking for downstream logic |
| Product assembly | Pre-shift values with explicit shift | Non-blocking assignment semantics require final shift to be applied explicitly during product capture |

---

## The -8 × -8 Bug

The most significant bug found during verification: for N=8, the input -8 (`10000000`) is the most negative representable value in two's complement. When Booth encoding subtracts the multiplicand from the accumulator during intermediate steps, the N-bit accumulator overflows.

**Root cause:** Accumulator declared as `reg [N-1:0]` — same width as inputs — insufficient for intermediate results at extreme negative values.

**Fix:** Sign-extend accumulator to N+1 bits and sign-extend M during add/subtract operations:

```verilog
reg [N:0] A;  // N+1 bits

// In CALC state:
2'b10: A <= A - {{1{M[N-1]}}, M};  // sign-extended subtraction
2'b01: A <= A + {{1{M[N-1]}}, M};  // sign-extended addition
```

This bug produced incorrect results for all cases where intermediate partial products exceeded the N-bit signed range. Manual waveform inspection missed it — the self-checking testbench caught it immediately.

---

## Verification

Self-checking testbench with automatic PASS/FAIL comparison.

### Directed Test Cases (14 cases)

| A | B | Expected | Category |
|---|---|---|---|
| 6 | 3 | 18 | Both positive |
| 0 | 5 | 0 | Zero input |
| 1 | -1 | -1 | Mixed signs |
| -6 | 3 | -18 | Negative × positive |
| 6 | -3 | -18 | Positive × negative |
| -6 | -3 | 18 | Both negative |
| 7 | 7 | 49 | Near-maximum positive |
| **-8** | **-8** | **64** | **Maximum negative × maximum negative (overflow edge case)** |
| -8 | 7 | -56 | Maximum negative × positive |
| 127 | 127 | 16129 | Maximum positive × maximum positive |
| -1 | -1 | 1 | All-ones input |
| 0 | 0 | 0 | Both zero |
| -8 | 1 | -8 | Identity with negative |
| 1 | 1 | 1 | Identity |

### Random Test Cases
1000 random 8-bit signed inputs generated using `$random`.

### Result
```
RESULTS: 1014 passed, 0 failed
```

### Testbench Features
- Done-signal driven synchronization — no fixed delay waits
- Signed declarations on all test vectors to ensure correct port connection
- Absolute value comparison for signed difference calculation
- Parameterized N — testbench scales with design

---

## Synthesis Results

**Tool:** Cadence Genus 21.14  
**Technology:** 90nm standard cell library  
**Clock constraint:** 10ns (100MHz)

### Area

| Metric | Value |
|---|---|
| Standard cell count | 205 |
| Total area | 1642.47 µm² |

### Timing

| Corner | Critical Path | Slack | Fmax |
|---|---|---|---|
| Slow | 2.77 ns | 7.02 ns | 361 MHz |
| Fast | 0.76 ns | 9.16 ns | 1.31 GHz |

### Power (at 100MHz, default toggle rate)

| Corner | Leakage | Internal | Switching | Total |
|---|---|---|---|---|
| Slow | 8.14 µW | 102.9 µW | 17.4 µW | 128.4 µW |
| Fast | 16.13 µW | 133.7 µW | 27.7 µW | 177.5 µW |

### Critical Path Analysis

The critical path runs through the Booth accumulator's adder chain:

```
q_reg/Q → CLKINVX1 → MXI2XL → 6× ADDFX1 (carry chain) → ADDFXL → AOI222XL → INVXL → A_reg[7]/D
```

Six series full adders (ADDFX1) in the carry chain dominate timing at 2.77ns total. This is expected — the Booth algorithm's bottleneck is the N-bit accumulator addition, not the Booth encoding logic itself. Carry-select or carry-lookahead adder structures would reduce this at the cost of increased area.

---

## Repository Structure

```
booth-multiplier/
├── README.md
├── rtl/
│   └── bm.v
├── tb/
│   └── bm_ttb_self.v
├── constraints/
│   └── top.sdc
└── results/
    ├── area_slow.txt
    ├── timing_slow.txt
    ├── timing_fast.txt
    ├── power_slow.txt
    ├── power_fast.txt
    └── rtl.gif
```

---

## Tools

| Tool | Purpose |
|---|---|
| Verilog | RTL implementation |
| Vivado 2024.x | Simulation and functional verification |
| Cadence Genus 21.14 | Logic synthesis |
| 90nm PDK | Standard cell library (slow/fast corners) |

---

## Parameters

| Parameter | Default | Description |
|---|---|---|
| N | 8 | Operand bit width. Design scales to any power of 2. |
