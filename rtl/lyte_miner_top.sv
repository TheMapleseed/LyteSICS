/**
 * LyteSICS Top-Level RTL Module
 * 
 * Complete Scrypt mining system compatible with MinerSICS architecture.
 * Implements multi-core mining with work distribution and result collection.
 * 
 * @author TheMapleseed
 * @version 1.0
 */

module lyte_miner_top (
    // System interface
    input  logic        clk,
    input  logic        rst_n,
    
    // Control interface
    input  logic        start_mining,
    input  logic        stop_mining,
    input  logic        reset_miner,
    
    // Configuration
    input  logic [31:0]  core_count,
    input  logic [31:0]  n_param,
    input  logic [31:0]  r_param,
    input  logic [31:0]  p_param,
    
    // Block header input
    input  logic [31:0]  version,
    input  logic [255:0] prev_block_hash,
    input  logic [255:0] merkle_root,
    input  logic [31:0]  timestamp,
    input  logic [31:0]  bits,
    
    // Difficulty target
    input  logic [255:0] difficulty_target,
    
    // Results
    output logic [31:0]  solution_nonce,
    output logic [255:0] solution_hash,
    output logic        solution_found,
    output logic        mining_active,
    output logic        miner_ready,
    
    // Performance monitoring
    output logic [31:0]  hash_rate,
    output logic [31:0]  active_cores,
    output logic [31:0]  total_hashes,
    
    // Status
    output logic [7:0]   status,
    output logic [31:0]  error_count
);

    // Internal signals
    logic [31:0]  core_nonce [0:15];
    logic [255:0] core_hash [0:15];
    logic [15:0]  core_valid;
    logic [15:0]  core_done;
    logic [15:0]  core_busy;
    logic [15:0]  core_start;
    logic [31:0]  core_nonce_start [0:15];
    logic [31:0]  core_nonce_end [0:15];
    
    logic [31:0]  nonce_range;
    logic [31:0]  current_nonce_offset;
    logic [31:0]  hash_counter;
    logic [31:0]  active_core_count;
    logic [2:0]   state;
    logic [31:0]  error_counter;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        INIT_CORES,
        MINING,
        COLLECT_RESULTS,
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
                if (start_mining) next_state = INIT_CORES;
            end
            INIT_CORES: begin
                next_state = MINING;
            end
            MINING: begin
                if (stop_mining || (|core_valid)) next_state = COLLECT_RESULTS;
            end
            COLLECT_RESULTS: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Control signals
    assign mining_active = (current_state == MINING);
    assign miner_ready = (current_state == IDLE);

    // Nonce range calculation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nonce_range <= 32'd0;
            current_nonce_offset <= 32'd0;
        end else if (current_state == INIT_CORES) begin
            nonce_range <= 32'hFFFFFFFF / core_count;
            current_nonce_offset <= 32'd0;
        end else if (current_state == MINING) begin
            // Increment nonce offset when all cores complete
            if (&core_done[core_count-1:0]) begin
                current_nonce_offset <= current_nonce_offset + nonce_range;
            end
        end
    end

    // Core nonce range assignment
    always_ff @(posedge clk) begin
        if (current_state == INIT_CORES) begin
            for (int i = 0; i < 16; i++) begin
                if (i < core_count) begin
                    core_nonce_start[i] <= current_nonce_offset + (i * nonce_range);
                    core_nonce_end[i] <= current_nonce_offset + ((i + 1) * nonce_range) - 1;
                end else begin
                    core_nonce_start[i] <= 32'd0;
                    core_nonce_end[i] <= 32'd0;
                end
            end
        end
    end

    // Core start signals
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            core_start[i] = (current_state == INIT_CORES) || 
                           (current_state == MINING && core_done[i] && !core_valid[i]);
        end
    end

    // Result collection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            solution_found <= 1'b0;
            solution_nonce <= 32'd0;
            solution_hash <= 256'd0;
        end else if (current_state == COLLECT_RESULTS) begin
            // Find the first valid solution
            solution_found <= 1'b0;
            for (int i = 0; i < 16; i++) begin
                if (core_valid[i]) begin
                    solution_found <= 1'b1;
                    solution_nonce <= core_nonce[i];
                    solution_hash <= core_hash[i];
                    break;
                end
            end
        end else if (current_state == IDLE) begin
            solution_found <= 1'b0;
            solution_nonce <= 32'd0;
            solution_hash <= 256'd0;
        end
    end

    // Hash rate calculation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hash_counter <= 32'd0;
            active_core_count <= 32'd0;
        end else if (mining_active) begin
            hash_counter <= hash_counter + core_count;
            active_core_count <= core_count;
        end else begin
            active_core_count <= 32'd0;
        end
    end

    assign hash_rate = hash_counter;
    assign active_cores = active_core_count;
    assign total_hashes = hash_counter;

    // Error counting
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_counter <= 32'd0;
        end else if (reset_miner) begin
            error_counter <= 32'd0;
        end else if (current_state == MINING && &core_done[core_count-1:0] && !(|core_valid)) begin
            // Increment error counter if no solution found after all cores complete
            error_counter <= error_counter + 1'b1;
        end
    end

    assign error_count = error_counter;

    // Status output
    always_ff @(posedge clk) begin
        status <= {5'd0, current_state};
    end

    // Generate mining cores
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : mining_cores
            lyte_miner_core core_inst (
                .clk(clk),
                .rst_n(rst_n),
                .start(core_start[i]),
                .stop(stop_mining),
                .nonce_start(core_nonce_start[i]),
                .nonce_end(core_nonce_end[i]),
                .version(version),
                .prev_block_hash(prev_block_hash),
                .merkle_root(merkle_root),
                .timestamp(timestamp),
                .bits(bits),
                .target(difficulty_target),
                .found_nonce(core_nonce[i]),
                .found_hash(core_hash[i]),
                .solution_found(core_valid[i]),
                .busy(core_busy[i]),
                .done(core_done[i])
            );
        end
    endgenerate

endmodule
