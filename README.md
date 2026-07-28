# QUISA: QR-UOV-based Instruction-Set Coprocessor Architecture


## Disclaimer
This project is intended for research purposes only. 
The authors assume no responsibility for any bugs, errors, or failures arising from the use of this code outside its intended scope. 

---

## How to Configure the QUISA for different security levels 
To run the behavioral simulations, simply set the SECAP signal in the top module (qruov_top.v) according to the desired security level.
1. SECAP = 1 (for SL-I)
2. SECAP = 5 (for SL-III)
3. SECAP = 9 (for SL-V)

-- No additional changes are required. 


## Overview

**QUISA** is a flexible and unified instruction-set coprocessor architecture for the QR-UOV post-quantum digital signature scheme. It supports key generation, signing, and verification across all NIST-defined security levels (SL-I, SL-III, SL-V) within a fixed hardware footprint, scaling only in clock cycles.

This repository contains the complete RTL implementation accompanying the paper:

> **"QUISA: A Compact, Flexible and Unified Instruction-Set Coprocessor for QR-UOV Signature"**  
> Will be added later.  
> Submitted to IEEE Transactions on Computers (TC), 2026.  
> DOI: *(to be added upon publication)*

---

## Repository Structure 

```
QUISA/
├── rtl/  -> All the files are located in the "rtl". The following hierarchy just shows the relevant files for the corresponding functional module.
│   ├── qruov_top.v 								# top module of the QUISA 
│   ├── Palallel pseudorandom sampling and packing unit (PPSPU) --> it comprises the following RTL files
│   	├── shake_wrapper.v 						# SHAKE-128/256 warapper (top file) 
│   		├── keccak.vhd	 						# keccak top
│   			├── keccak_round.vhd 				# keccak round 
│   			├── keccak_round_constants_gen.vhd 	# keccak round constants
│   			├── keccak_buffer.vhd 				# keccak buffer
│   	├── rejsamp.v 		 						# rejection sampling 
│   		├── rejsamp_and_q.v 					# generating elements over F_q and F_q^m
│   		├── eight_bytes_reordering.v 			# reordering eight bytes and their corresponding valid flags (Bytes Selector Unit of the manuscript)                 
│   	├── op_format_block_rejsamp.v 				# output format block (OFB) to write 24-bit words on memory units
│   	├── byte_stream_unit.v 						# byte stream unit to support Hash operations 
│   ├── Arithmetic Unit (AU) --> it includes the following RTL files
│   	├── arithmetic_unit.v 				        # top file (generating read/write addresses for V-V, V-M and M-M operations)
│   		├── mac_tile.v 							# mac tile 
│   		├── mod_add.v 							# modular adder (supporting 3 lanes) 
│   		├── mod_sub.v 							# modular subtractor (supporting 3 lanes) 
│   ├── Linear Sample Solver (LSS) --> it comprises the following RTL files
│   	├── s_solution.v 				            # Sample solution unit (S-Sol)
│   	├── lu_decompose.v 				            # lu decompose block (LUB)
│   	├── copy_words.v 				            # copy words block
│   ├── compare.v 					                # compare unit for signature verification 
│   ├── memory.v 					                # This file is for MEM-3 (for MEM-1 and MEM-2 generate true dual-port BRAMs IPs from Vivado) 
│   ├── qruov_parameters.v 					        # QR-UOV parameters (QUISA operates on 1, 5 and 9 for SL-I, SL-III and SL-V) 
├── header_files/                     			    # Header files
│   ├── signal_sizes.vh 							# defining signal lengths
├── coefficient_files/		                        # Coefficient files 
│   ├── INT_MEM_SL_I.coe 	 						# coefficient file regarding SL-I containing Pi,3 matrix for signature verification operation
│   ├── INT_MEM_SL_III.coe 	 						# coefficient file regarding SL-III containing Pi,3 matrix for signature verification operation
│   ├── INT_MEM_SL_V.coe 	 						# coefficient file regarding SL-V containing Pi,3 matrix for signature verification operation
├── tb/                         					# Testbench files
│   ├── TB_KG_SL1.v 	 	 						# key generation SL-I
│   ├── TB_KG_SL3.v 	 	 						# key generation SL-III
│   ├── TB_KG_SL5.v 	 	 						# key generation SL-V
│   ├── TB_SIGN_SL1.v 	 	 						# signing for SL-I
│   ├── TB_SIGN_SL3.v 	 	 						# signing for SL-III
│   ├── TB_SIGN_SL5.v 	 	 						# signing for SL-V
│   ├── TB_VERIFY_SL1.v 	 	 					# verification for SL-I
│   ├── TB_VERIFY_SL3.v 	 	 					# verification for SL-III
│   ├── TB_VERIFY_SL5.v 	 	 					# verification for SL-V
├── constraints/              				# Xilinx XDC constraint files (Artix-7)
│   ├── constraints.xdc  	 						# constraints file
├── docs/              				# Xilinx XDC constraint files (Artix-7)
│   ├── rejsamp_modification.png  	 						# figure explaining the changes we made in the round-2 reference C/C++ code
└── README.md
```

---

## Target Platform

| Property        | Details                        |
|-----------------|--------------------------------|
| FPGA            | Artix-7 (XC7A200T) 			       |
| Tool            | Vivado (2023.2)                |
| Evaluation      | Post-place-and-route (Post-PAR)|
| Clock Frequency | 80 MHz                         |

---

## QR-UOV Parameter Sets

| Security Level | q   | v   | m   | ℓ |
|----------------|-----|-----|-----|---|
| SL-I           | 127 | 156 | 54  | 3 |
| SL-III         | 127 | 228 | 78  | 3 |
| SL-V           | 127 | 306 | 105 | 3 |

---

## FPGA Resource Utilization (Artix-7, Post-PAR) (supporting SL-I to SL-V security levels)

| Resource  	| Utilization |
|-------------|-------------|
| Slices    	| 11,144      |
| LUTs      	| 35,248      |
| FFs       	| 18,375      |
| DSPs      	| 0 	        |
| BRAM Tiles  | 221 	      |

---

## Performance (in terms of clock cycles) Summary (at 80 MHz)

| Operation      | SL-I 		 | SL-III 		| SL-V 		 |
|----------------|---------------|--------------|------------|
| Key Generation | 5,330,536 	 | 535,697      | 399,777    |
| Signing        | 22,594,572    | 1,607,428    | 1,194,832  |
| Verification   | 30,415,770    | 3,809,819    | 2,801,059  |

---

## Key Features

- Supports all three NIST security levels (SL-I, SL-III, SL-V) within a **fixed hardware footprint**
- Instruction-set-driven coprocessor with shared functional units across all operations
- Complete linear system solver over the prime field F_127 with partial pivoting
- Hardware-oriented constant-time rejection sampling using a fixed-size auxiliary-byte window
- Parallel SHAKE-128/256 wrapper supporting PRG and Hash operations

---

## Implementation Notes

## Hardware-Oriented Rejection Sampling

<p align="center">
  <img src="docs/rejsamp_sampling.jpg" width="850">
</p>

<p align="center">
<b>Fig. 1.</b> Reference QR-UOV Round-2 implementation of
<code>rejsamp_rejection_with_aux()</code> (top) and the modified QUISA implementation (bottom).
</p>

## Reference Specification

The implementation is based on the QR-UOV round-2 specification:

> Furue, H. et al. *QR-UOV Specification Document*, Round 2, February 2025.  
> Available at: https://csrc.nist.gov/csrc/media/Projects/pqc-dig-sig/documents/qruov-spec-round2-web.pdf

---

## License

This project is licensed under the MIT License.

