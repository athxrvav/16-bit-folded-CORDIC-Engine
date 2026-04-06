# 16-Iteration Folded CORDIC Trigonometric Engine

**Author:** Atharva Verma
**Institution:** Vellore Institute of Technology
**Target Node:** SkyWater 130nm Open-Source PDK (via Tiny Tapeout)
**Status:** Silicon-Ready (GDS Verified, Gate-Level Simulation Passed)

## Project Overview

This repository contains the register-transfer level (RTL) implementation of a highly optimized, 16-iteration CORDIC (Coordinate Rotation Digital Computer) trigonometric accelerator. Designed specifically for the VIT OPEN SILICON Microelectronic Bootcamp, this synthesisable Verilog core evaluates the sine and cosine of an input angle using purely multiplier-free arithmetic.

The primary engineering directive for this accelerator was extreme area optimization: the entire datapath and control logic had to fit within a strict 1,000 Gate Equivalent (GE) physical footprint for ASIC tapeout.

## The Engineering Trade-off: The < 1000 Gate Limit

To meet the aggressive sub-1000 GE area constraint, standard CORDIC features like high-throughput unrolled pipelining and full 360-degree quadrant mapping were intentionally discarded in favor of a folded architecture.

### The Input Limitation (+/- 57.29°)

This engine accepts inputs strictly in Radians utilizing a 16-bit Q1.15 fixed-point format (1 sign bit, 15 fractional bits, 0 integer bits). 

Because the Q1.15 format possesses zero integer bits, the hardware is mathematically bounded to values between -0.9999 and +0.9999 radians. Translating this to degrees, the absolute operational limit of this engine is +/- 57.29°. Providing an angle outside this range (such as 90° / 1.57 rad) requires an integer bit. Attempting to force 1.57 into the Q1.15 bus causes a two's complement overflow into the sign bit, resulting in aliasing. 

**Why not fix this?** Supporting a full 360° input range requires a quadrant pre-processor to map inputs into the first quadrant, track the original signs, and invert the final outputs. Synthesizing this pre- and post-processing logic would have easily shattered the 1,000 GE limit. Restricting the input to pure Q1.15 radians was a calculated, necessary trade-off to achieve a silicon-viable footprint within the project constraints.

## Mathematical Algorithm

The CORDIC algorithm iteratively calculates trigonometric functions using only addition, subtraction, bit-shifting, and static table lookups. For each iteration $i$ (from 0 to 15), the vector coordinates are updated as follows:

* $X_{i+1} = X_i - d_i \cdot (Y_i \gg i)$
* $Y_{i+1} = Y_i + d_i \cdot (X_i \gg i)$
* $Z_{i+1} = Z_i - d_i \cdot \arctan(2^{-i})$

*(Where $d_i$ is the direction of rotation, determined by the sign of the residual angle $Z_i$)*

### Intrinsic Gain & Pre-scaling

The algorithm introduces a cumulative magnitude gain of $K \approx 1.64676$. To avoid instantiating a massive hardware multiplier at the output to scale the results by $1/K \approx 0.60725$, this design pre-scales the initial X-vector. 
* Initial $X_0$ is seeded with 16'h4DBA (0.60725 in Q1.15).
* As the iterations process, the intrinsic gain naturally expands the vector back to a unit-circle magnitude, yielding native sine and cosine values.

## Hardware Architecture

### Folded Datapath

Instead of 16 distinct physical stages, a single unified combinational core (adders, subtractors, and variable barrel shifters) is instantiated. A central Finite State Machine (FSM) commands the datapath to cycle its outputs back into its own inputs exactly 16 times per computation.

### Synthesisable LUT

The pre-computed arctangent constants ($\arctan(2^{-i})$) are hardcoded using a basic synthesisable case statement, forcing the synthesizer to map them to dense standard logic cells rather than expensive SRAM macros.

### Multiplexed I/O

To interface with the limited bidirectional pins of the physical padframe:
* **Inputs:** The 16-bit angle is loaded sequentially over two clock cycles (MSB first, then LSB) via an 8-bit bus.
* **Outputs:** The internal 16-bit Q1.15 results are truncated to stable 8-bit Q1.7 integers. A multiplexer toggles the 8-bit output bus between Sine and Cosine via an external out_sel pin.

## Module Hierarchy

* `tt_um_cordic_engine.v`: Top-level physical boundary wrapper and output multiplexer.
* `cordic_engine.v`: Main integration controller, I/O buffering, and Arctangent LUT.
* `cordic_fsm.v`: Moore-style state machine ensuring deterministic 16-cycle execution and safe '0' reset initialization.
* `cordic_core_stage.v`: The purely combinational shift-and-add arithmetic core.

## Verification & Simulation

This core has been exhaustively verified against behavioral and physical models:
1.  **Behavioral RTL (Cocotb & Vivado):** Verified mathematically accurate Sine/Cosine outputs across all four valid operational quadrants (+/- 10°, +/- 20°, +/- 30°, +/- 45°, +/- 55°).
2.  **Gate-Level Simulation (GLS):** Passed strict Verilator timing simulations. The testbench environment dynamically injects standard cell power pins (VPWR, VGND), utilizes deterministic wait-cycles rather than aggressive polling, and prevents 'X' state propagation through deep, hard-coded FSM resets. 

### How to Run Vivado Testbench

A standalone Verilog testbench (`tb_vivado_cordic.v`) is included.
1.  Add the RTL files and the testbench to a Vivado Simulation Source set.
2.  Run Behavioral Simulation.
3.  In the Tcl Console, execute `run all`.
4.  The console will output a formatted breakdown comparing the hardware's 8-bit Q1.7 signed integers against theoretical targets.
