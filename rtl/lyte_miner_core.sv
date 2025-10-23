/**
 * LyteSICS - Scrypt Mining RTL
 * Copyright (C) 2025 TheMapleseed
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * LyteSICS Mining Core RTL
 * 
 * Scrypt-based mining core compatible with MinerSICS architecture.
 * Implements Scrypt algorithm for Lyte coin mining.
 * 
 * @author TheMapleseed
 * @version 1.0
 */

module lyte_miner_core (
    // Clock and reset
    input  logic        clk,
    input  logic        rst_n,
    
    // Control interface
    input  logic        start,
    input  logic        stop,
    input  logic [31:0]  nonce_start,
    input  logic [31:0]  nonce_end,
    
    // Block data input
    input  logic [31:0]  version,
    input  logic [255:0] prev_block_hash,
    input  logic [255:0] merkle_root,
    input  logic [31:0]  timestamp,
    input  logic [31:0]  bits,
    
    // Difficulty target
    input  logic [255:0] target,
    
    // Results
    output logic [31:0]  found_nonce,
    output logic [255:0] found_hash,
    output logic        solution_found,
    output logic        busy,
    output logic        done
);

    // Internal signals
    logic [31:0]  current_nonce;
    logic [255:0] current_hash;
    logic         hash_valid;
    logic [2:0]   state;
    logic         scrypt_start;
    logic         scrypt_done;
    logic         scrypt_busy;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        MINING,
        FOUND,
        DONE
    } state_t;
    
    state_t current_state, next_state;

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = MINING;
            end
            MINING: begin
                if (stop) next_state = DONE;
                else if (hash_valid) next_state = FOUND;
                else if (current_nonce >= nonce_end) next_state = DONE;
            end
            FOUND: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Control signals
    assign busy = (current_state == MINING);
    assign done = (current_state == DONE);
    assign solution_found = (current_state == FOUND);

    // Nonce counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_nonce <= 32'd0;
        end else if (current_state == IDLE && start) begin
            current_nonce <= nonce_start;
        end else if (current_state == MINING && !hash_valid) begin
            current_nonce <= current_nonce + 1'b1;
        end
    end

    // Scrypt core instance
    scrypt_hash scrypt_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(scrypt_start),
        .block_header({version, prev_block_hash, merkle_root, timestamp, bits, current_nonce}),
        .hash_out(current_hash),
        .done(scrypt_done),
        .busy(scrypt_busy)
    );

    // Scrypt control
    assign scrypt_start = (current_state == MINING);

    // Hash validation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hash_valid <= 1'b0;
        end else if (scrypt_done) begin
            hash_valid <= (current_hash < target);
        end else begin
            hash_valid <= 1'b0;
        end
    end

    // Outputs
    assign found_nonce = current_nonce;
    assign found_hash = current_hash;

endmodule

/**
 * Scrypt Hash Module
 * 
 * Implements Scrypt algorithm for Lyte coin mining.
 */
module scrypt_hash (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [639:0] block_header,  // 80 bytes
    output logic [255:0] hash_out,
    output logic        done,
    output logic        busy
);

    // Internal signals
    logic [255:0] password;
    logic [255:0] salt;
    logic [255:0] derived_key;
    logic         pbkdf2_start;
    logic         pbkdf2_done;
    logic         pbkdf2_busy;
    logic [255:0] romix_input;
    logic [255:0] romix_output;
    logic         romix_start;
    logic         romix_done;
    logic         romix_busy;
    logic [2:0]   state;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        PBKDF2_STAGE,
        ROMIX_STAGE,
        FINAL_PBKDF2,
        DONE
    } state_t;
    
    state_t current_state, next_state;

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = PBKDF2_STAGE;
            end
            PBKDF2_STAGE: begin
                if (pbkdf2_done) next_state = ROMIX_STAGE;
            end
            ROMIX_STAGE: begin
                if (romix_done) next_state = FINAL_PBKDF2;
            end
            FINAL_PBKDF2: begin
                if (pbkdf2_done) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Control signals
    assign busy = (current_state != IDLE && current_state != DONE);
    assign done = (current_state == DONE);
    assign pbkdf2_start = (current_state == PBKDF2_STAGE) || (current_state == FINAL_PBKDF2);
    assign romix_start = (current_state == ROMIX_STAGE);

    // Input preparation
    assign password = block_header[255:0];
    assign salt = block_header[511:256];

    // PBKDF2 instance
    pbkdf2_sha256 pbkdf2_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(pbkdf2_start),
        .password(password),
        .salt(salt),
        .iteration_count(32'd1),
        .key_length(32'd32),
        .derived_key(derived_key),
        .done(pbkdf2_done),
        .busy(pbkdf2_busy)
    );

    // ROMix input
    assign romix_input = derived_key;

    // ROMix instance
    romix_memory romix_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(romix_start),
        .input_data(romix_input),
        .n_param(32'd1024),
        .r_param(32'd1),
        .output_data(romix_output),
        .done(romix_done),
        .busy(romix_busy)
    );

    // Final hash
    assign hash_out = derived_key;

endmodule
