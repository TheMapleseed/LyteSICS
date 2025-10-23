# LyteSICS - Scrypt Mining RTL

LyteSICS is a process node agnostic RTL implementation of a Scrypt-based cryptocurrency mining ASIC, compatible with the MinerSICS architecture. This project provides a clean, efficient RTL design for Scrypt mining that can be synthesized on any process node.

## Features

- **MinerSICS Compatible**: Follows MinerSICS RTL architecture patterns
- **Process Node Agnostic**: Works on any standard ASIC process
- **Scrypt Algorithm**: Complete RTL implementation of Scrypt proof-of-work
- **Multi-Core Architecture**: Up to 64 parallel mining cores (like Bitcoin MinerSICS)
- **Clean RTL Design**: Optimized for synthesis and verification

## Architecture

### RTL Modules

- **`lyte_miner_top.sv`**: Top-level module with up to 64-core mining
- **`lyte_miner_core.sv`**: Individual mining core for Scrypt
- **`scrypt_hash.sv`**: Scrypt algorithm implementation
- **`pbkdf2_sha256.sv`**: PBKDF2 key derivation function
- **`romix_memory.sv`**: Memory-hard ROMix function
- **`hmac_sha256.sv`**: HMAC-SHA256 for PBKDF2
- **`sha256_core.sv`**: SHA-256 hash function

### Directory Structure

```
rtl/
├── lyte_miner_top.sv          # Top-level mining system
├── lyte_miner_core.sv         # Individual mining core
├── scrypt_hash.sv             # Scrypt algorithm
├── pbkdf2_sha256.sv           # PBKDF2 implementation
├── romix_memory.sv            # ROMix memory function
├── hmac_sha256.sv             # HMAC-SHA256
└── sha256_core.sv             # SHA-256 core

constraints/
└── timing.sdc                 # Process agnostic timing constraints

scripts/
└── rtl_synthesize.tcl         # RTL synthesis script
```

## Scrypt Algorithm

The Scrypt algorithm is implemented in three main stages:

1. **PBKDF2 Stage**: Uses HMAC-SHA256 for key derivation
2. **ROMix Stage**: Memory-intensive mixing function
3. **Final Derivation**: Combines outputs to produce final hash

### Scrypt Parameters

- **N**: CPU/memory cost parameter (default: 1024)
- **R**: Block size parameter (default: 1)
- **P**: Parallelization parameter (default: 1)

## Usage

### Synthesis

```bash
# Using Synopsys Design Compiler
dc_shell -f scripts/rtl_synthesize.tcl

# Using Cadence Genus
genus -f scripts/rtl_synthesize.tcl
```

### Simulation

```bash
# Using ModelSim/QuestaSim
vsim -c -do "run -all" lyte_miner_top

# Using VCS
vcs -sverilog -debug_all lyte_miner_top.sv
```

## Design Features

- **Process Agnostic**: No hard-coded process-specific constraints
- **Parameterizable**: Configurable core count and Scrypt parameters
- **Synthesis Ready**: Optimized for standard ASIC synthesis tools
- **MinerSICS Compatible**: Follows established RTL patterns

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Copyright

Copyright (C) 2025 The Mapleseed Inc.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

## References

- [Scrypt Algorithm Specification](https://tools.ietf.org/html/rfc7914)
- [Litecoin Protocol](https://github.com/litecoin-project/litecoin)
- [SystemVerilog IEEE 1800-2017](https://ieeexplore.ieee.org/document/8299595)
