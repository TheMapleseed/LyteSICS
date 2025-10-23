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
 * SHA-256 Core RTL Implementation
 * 
 * High-performance SHA-256 implementation for Scrypt mining.
 * Compatible with MinerSICS architecture.
 * 
 * @author TheMapleseed
 * @version 1.0
 */

module sha256_core (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [511:0] data_in,
    input  logic [31:0]  data_length,
    output logic [255:0] hash_out,
    output logic        done,
    output logic        busy
);

    // SHA-256 constants
    localparam logic [31:0] K[0:63] = '{
        32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5,
        32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
        32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3,
        32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
        32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc,
        32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
        32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7,
        32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
        32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13,
        32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
        32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3,
        32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
        32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5,
        32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
        32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208,
        32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2
    };

    // Internal signals
    logic [31:0] h[0:7];
    logic [31:0] w[0:63];
    logic [31:0] a, b, c, d, e, f, g, h_reg;
    logic [5:0]  round;
    logic [2:0]  state;
    logic        process_block;
    logic        last_block;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        PROCESS,
        FINAL
    } state_t;
    
    state_t current_state, next_state;

    // SHA-256 functions
    function automatic logic [31:0] ch(input logic [31:0] x, y, z);
        ch = (x & y) ^ (~x & z);
    endfunction

    function automatic logic [31:0] maj(input logic [31:0] x, y, z);
        maj = (x & y) ^ (x & z) ^ (y & z);
    endfunction

    function automatic logic [31:0] sigma0(input logic [31:0] x);
        sigma0 = {x[1:0], x[31:2]} ^ {x[12:0], x[31:13]} ^ {x[21:0], x[31:22]};
    endfunction

    function automatic logic [31:0] sigma1(input logic [31:0] x);
        sigma1 = {x[5:0], x[31:6]} ^ {x[10:0], x[31:11]} ^ {x[24:0], x[31:25]};
    endfunction

    function automatic logic [31:0] gamma0(input logic [31:0] x);
        gamma0 = {x[6:0], x[31:7]} ^ {x[17:0], x[31:18]} ^ {x[2:0], x[31:3]};
    endfunction

    function automatic logic [31:0] gamma1(input logic [31:0] x);
        gamma1 = {x[16:0], x[31:17]} ^ {x[18:0], x[31:19]} ^ {x[9:0], x[31:10]};
    endfunction

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
                if (start) next_state = PROCESS;
            end
            PROCESS: begin
                if (round == 6'd63) next_state = FINAL;
            end
            FINAL: begin
                next_state = IDLE;
            end
        endcase
    end

    // Control signals
    assign busy = (current_state != IDLE);
    assign done = (current_state == FINAL);
    assign process_block = (current_state == PROCESS);

    // Initialize hash values
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h[0] <= 32'h6a09e667;
            h[1] <= 32'hbb67ae85;
            h[2] <= 32'h3c6ef372;
            h[3] <= 32'ha54ff53a;
            h[4] <= 32'h510e527f;
            h[5] <= 32'h9b05688c;
            h[6] <= 32'h1f83d9ab;
            h[7] <= 32'h5be0cd19;
        end else if (start) begin
            h[0] <= 32'h6a09e667;
            h[1] <= 32'hbb67ae85;
            h[2] <= 32'h3c6ef372;
            h[3] <= 32'ha54ff53a;
            h[4] <= 32'h510e527f;
            h[5] <= 32'h9b05688c;
            h[6] <= 32'h1f83d9ab;
            h[7] <= 32'h5be0cd19;
        end else if (process_block && round == 6'd63) begin
            h[0] <= h[0] + a;
            h[1] <= h[1] + b;
            h[2] <= h[2] + c;
            h[3] <= h[3] + d;
            h[4] <= h[4] + e;
            h[5] <= h[5] + f;
            h[6] <= h[6] + g;
            h[7] <= h[7] + h_reg;
        end
    end

    // Message schedule
    always_ff @(posedge clk) begin
        if (process_block) begin
            if (round < 16) begin
                w[round] <= data_in[511-round*32:480-round*32];
            end else begin
                w[round] <= w[round-16] + w[round-7] + gamma0(w[round-15]) + gamma1(w[round-2]);
            end
        end
    end

    // Round counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            round <= 6'd0;
        end else if (process_block) begin
            if (round == 6'd63) begin
                round <= 6'd0;
            end else begin
                round <= round + 1'b1;
            end
        end
    end

    // Hash computation
    always_ff @(posedge clk) begin
        if (process_block) begin
            if (round == 6'd0) begin
                a <= h[0];
                b <= h[1];
                c <= h[2];
                d <= h[3];
                e <= h[4];
                f <= h[5];
                g <= h[6];
                h_reg <= h[7];
            end else begin
                logic [31:0] t1, t2;
                t1 = h_reg + sigma1(e) + ch(e, f, g) + K[round] + w[round];
                t2 = sigma0(a) + maj(a, b, c);
                
                h_reg <= g;
                g <= f;
                f <= e;
                e <= d + t1;
                d <= c;
                c <= b;
                b <= a;
                a <= t1 + t2;
            end
        end
    end

    // Output hash
    assign hash_out = {h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]};

endmodule
