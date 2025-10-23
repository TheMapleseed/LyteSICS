/**
 * HMAC-SHA256 RTL Implementation
 * 
 * Hash-based Message Authentication Code using SHA-256.
 * Compatible with MinerSICS architecture.
 * 
 * @author TheMapleseed
 * @version 1.0
 */

module hmac_sha256 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [255:0] key,
    input  logic [511:0] message,
    input  logic [31:0]  message_length,
    output logic [255:0] hmac_out,
    output logic        done,
    output logic        busy
);

    // Internal signals
    logic [255:0] key_padded;
    logic [255:0] opad_key;
    logic [255:0] ipad_key;
    logic [511:0] inner_data;
    logic [511:0] outer_data;
    logic [255:0] inner_hash;
    logic [255:0] outer_hash;
    logic [31:0]  inner_length;
    logic [31:0]  outer_length;
    logic         inner_start;
    logic         inner_done;
    logic         inner_busy;
    logic         outer_start;
    logic         outer_done;
    logic         outer_busy;
    logic         key_process_done;
    logic [2:0]   state;

    // HMAC constants
    localparam logic [7:0] IPAD = 8'h36;
    localparam logic [7:0] OPAD = 8'h5c;
    localparam logic [31:0] BLOCK_SIZE = 32'd64; // 512 bits

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        KEY_PROCESS,
        INNER_HASH,
        OUTER_HASH
    } state_t;
    
    state_t current_state, next_state;

    // SHA-256 instances
    sha256_core inner_sha (
        .clk(clk),
        .rst_n(rst_n),
        .start(inner_start),
        .data_in(inner_data),
        .data_length(inner_length),
        .hash_out(inner_hash),
        .done(inner_done),
        .busy(inner_busy)
    );

    sha256_core outer_sha (
        .clk(clk),
        .rst_n(rst_n),
        .start(outer_start),
        .data_in(outer_data),
        .data_length(outer_length),
        .hash_out(outer_hash),
        .done(outer_done),
        .busy(outer_busy)
    );

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
                if (start) next_state = KEY_PROCESS;
            end
            KEY_PROCESS: begin
                if (key_process_done) next_state = INNER_HASH;
            end
            INNER_HASH: begin
                if (inner_done) next_state = OUTER_HASH;
            end
            OUTER_HASH: begin
                if (outer_done) next_state = IDLE;
            end
        endcase
    end

    // Control signals
    assign busy = (current_state != IDLE);
    assign done = (current_state == OUTER_HASH && outer_done);
    assign inner_start = (current_state == INNER_HASH);
    assign outer_start = (current_state == OUTER_HASH);

    // Key processing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_process_done <= 1'b0;
            opad_key <= 256'd0;
            ipad_key <= 256'd0;
        end else if (current_state == KEY_PROCESS) begin
            // Pad key to block size
            if (key[255:248] != 8'd0) begin
                key_padded <= key;
            end else begin
                key_padded <= {key, 256'd0};
            end
            
            // Create inner and outer padding keys
            for (int i = 0; i < 32; i++) begin
                opad_key[i*8 +: 8] <= key_padded[i*8 +: 8] ^ OPAD;
                ipad_key[i*8 +: 8] <= key_padded[i*8 +: 8] ^ IPAD;
            end
            
            key_process_done <= 1'b1;
        end else if (current_state == IDLE) begin
            key_process_done <= 1'b0;
        end
    end

    // Inner hash data preparation
    always_comb begin
        inner_data = {ipad_key, message};
        inner_length = 32'd96; // 32 bytes key + message length
    end

    // Outer hash data preparation
    always_comb begin
        outer_data = {opad_key, inner_hash};
        outer_length = 32'd64; // 32 bytes key + 32 bytes hash
    end

    // Output
    assign hmac_out = outer_hash;

endmodule
