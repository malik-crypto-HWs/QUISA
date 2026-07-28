# QUISA: QR-UOV-based Instruction-Set Coprocessor Architecture

## Disclaimer

This project is intended for research purposes only. The authors assume
no responsibility for any bugs, errors, or failures arising from the use
of this code outside its intended scope.

------------------------------------------------------------------------

## How to Configure QUISA for Different Security Levels

To run the behavioral simulations, simply set the `SECAP` signal in the
top module (`qruov_top.v`) according to the desired security level.

1.  `SECAP = 1` (SL-I)
2.  `SECAP = 5` (SL-III)
3.  `SECAP = 9` (SL-V)

No additional changes are required.

------------------------------------------------------------------------

## Overview

**QUISA** is a flexible and unified instruction-set coprocessor
architecture for the QR-UOV post-quantum digital signature scheme. It
supports key generation, signing, and verification across all
NIST-defined security levels (SL-I, SL-III, and SL-V) within a fixed
hardware footprint, scaling only in clock cycles.

This repository contains the complete RTL implementation accompanying
the paper:

> **QUISA: A Compact, Flexible and Unified Instruction-Set Coprocessor
> for QR-UOV Signature**\
> *(Bibliographic information and DOI will be added upon publication.)*

------------------------------------------------------------------------

## Repository Structure

``` text
QUISA/
├── rtl/
│   ├── qruov_top.v                          # Top module
│   ├── Parallel Pseudorandom Sampling and Packing Unit (PPSPU)
│   │   ├── shake_wrapper.v
│   │   ├── keccak.vhd
│   │   ├── keccak_round.vhd
│   │   ├── keccak_round_constants_gen.vhd
│   │   ├── keccak_buffer.vhd
│   │   ├── rejsamp.v
│   │   ├── rejsamp_and_q.v
│   │   ├── eight_bytes_reordering.v
│   │   ├── op_format_block_rejsamp.v
│   │   └── byte_stream_unit.v
│   ├── Arithmetic Unit (AU)
│   │   ├── arithmetic_unit.v
│   │   ├── mac_tile.v
│   │   ├── mod_add.v
│   │   └── mod_sub.v
│   ├── Linear Sample Solver (LSS)
│   │   ├── s_solution.v
│   │   ├── lu_decompose.v
│   │   └── copy_words.v
│   ├── compare.v
│   ├── memory.v
│   └── qruov_parameters.v
├── header_files/
├── coefficient_files/
├── tb/
├── constraints/
├── docs/
│   └── rejsamp_modification.png
└── README.md
```

------------------------------------------------------------------------

## Target Platform

  Property          Details
  ----------------- ---------------------------------
  FPGA              Artix-7 (XC7A200T)
  Tool              Vivado 2023.2
  Evaluation        Post-place-and-route (Post-PAR)
  Clock Frequency   80 MHz

------------------------------------------------------------------------

## QR-UOV Parameter Sets

  Security Level       q     v     m   ℓ
  ---------------- ----- ----- ----- ---
  SL-I               127   156    54   3
  SL-III             127   228    78   3
  SL-V               127   306   105   3

------------------------------------------------------------------------

## FPGA Resource Utilization (Artix-7, Post-PAR)

  Resource       Utilization
  ------------ -------------
  Slices              11,144
  LUTs                35,248
  FFs                 18,375
  DSPs                     0
  BRAM Tiles             221

------------------------------------------------------------------------

## Performance (Clock Cycles @ 80 MHz)

  Operation                SL-I      SL-III        SL-V
  ---------------- ------------ ----------- -----------
  Key Generation      5,330,536     535,697     399,777
  Signing            22,594,572   1,607,428   1,194,832
  Verification       30,415,770   3,809,819   2,801,059

------------------------------------------------------------------------

## Key Features

-   Supports all three NIST security levels within a fixed hardware
    footprint.
-   Instruction-set-driven coprocessor with shared functional units.
-   Complete linear system solver over **F127** with partial pivoting.
-   Hardware-oriented constant-time rejection sampling using a
    fixed-size auxiliary-byte window.
-   Parallel SHAKE-128/256 wrapper supporting both PRG and hash
    operations.

------------------------------------------------------------------------

## Implementation Notes

## Hardware-Oriented Rejection Sampling

The QR-UOV Round-2 reference implementation performs rejection sampling in two stages: `rejsamp_and_q()` and `rejsamp_rejection_with_aux()`. The former is used without modification in QUISA, whereas the latter is minimally modified to facilitate efficient hardware implementation.

In the reference implementation, the pseudorandom byte stream is divided into **main** and **auxiliary** regions. During rejection sampling, invalid candidates (`= QRUOV_q`) in the main region are replaced with valid candidates from the auxiliary region. Although suitable for software, this replacement mechanism introduces irregular memory accesses and sequential dependencies, making it difficult to execute the pseudorandom generator (PRG) and rejection sampling in parallel.

QUISA modifies only `rejsamp_rejection_with_aux()`. Instead of replacing invalid candidates from the auxiliary region, the proposed implementation first compacts all valid candidates from the main region using a single sequential scan. The auxiliary region is accessed only when additional valid samples are required to reach the desired output length. This small modification enables regular memory accesses and parallel execution of the SHAKE-based PRG and rejection sampling hardware while preserving the functionality of the original QR-UOV algorithm.

<p align="center">
  <img src="docs/rejsamp_modification.png" width="850">
</p>

<p align="center">
<b>Fig. 1.</b> Reference QR-UOV Round-2 implementation of
<code>rejsamp_rejection_with_aux()</code> (top) and the modified QUISA implementation (bottom).
</p>

------------------------------------------------------------------------

## Reference Specification

The implementation follows the QR-UOV Round-2 specification:

> Furue, H. et al. *QR-UOV Specification Document*, Round 2, February
> 2025.

https://csrc.nist.gov/csrc/media/Projects/pqc-dig-sig/documents/qruov-spec-round2-web.pdf

------------------------------------------------------------------------

## License

This project is licensed under the MIT License.
