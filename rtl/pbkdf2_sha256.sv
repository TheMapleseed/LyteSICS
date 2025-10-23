/**
 * PBKDF2-SHA256 RTL Implementation
 * 
 * Password-Based Key Derivation Function 2 using SHA-256.
 * Compatible with MinerSICS architecture.
 * 
 * @author TheMapleseed
 * @version 1.0
 */

module pbkdf2_sha256 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [255:0] password,
    input  logic [255:0] salt,
    input  logic [31:0]  iteration_count,
    input  logic [31:0]  key_length,
    output logic [255:0] derived_key,
    output logic        done,
    output logic        busy
);

    // Internal signals
    logic [255:0] hmac_key;
    logic [511:0] hmac_message;
    logic [31:0]  hmac_length;
    logic [255:0] hmac_result;
    logic         hmac_start;
    logic         hmac_done;
    logic         hmac_busy;
    logic [31:0]  counter;
    logic [31:0]  iteration;
    logic [255:0] u_prev;
    logic [255:0] u_current;
    logic [255:0] t_accumulator;
    logic [2:0]   state;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        INIT_ITERATION,
        HMAC_ITERATION,
        ACCUMULATE,
        FINAL_XOR,
        DONE
    } state_t;
    
    state_t current_state, next_state;

    // HMAC-SHA256 instance
    hmac_sha256 hmac_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(hmac_start),
        .key(hmac_key),
        .message(hmac_message),
        .message_length(hmac_length),
        .hmac_out(hmac_result),
        .done(hmac_done),
        .busy(hmac_busy)
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
                if (start) next_state = INIT_ITERATION;
            end
            INIT_ITERATION: begin
                next_state = HMAC_ITERATION;
            end
            HMAC_ITERATION: begin
                if (hmac_done) begin
                    if (iteration == 1) next_state = ACCUMULATE;
                    else next_state = HMAC_ITERATION;
                end
            end
            ACCUMULATE: begin
                if (counter == iteration_count) next_state = FINAL_XOR;
                else next_state = INIT_ITERATION;
            end
            FINAL_XOR: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Control signals
    assign busy = (current_state != IDLE && current_state != DONE);
    assign done = (current_state == DONE);
    assign hmac_start = (current_state == HMAC_ITERATION);

    // Counter management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 32'd1;
            iteration <= 32'd1;
        end else begin
            case (current_state)
                IDLE: begin
                    counter <= 32'd1;
                    iteration <= 32'd1;
                end
                INIT_ITERATION: begin
                    // No change to counters
                end
                HMAC_ITERATION: begin
                    if (hmac_done) begin
                        if (iteration == 1) begin
                            iteration <= iteration + 1'b1;
                        end else begin
                            iteration <= 32'd1;
                            counter <= counter + 1'b1;
                        end
                    end
                end
                ACCUMULATE: begin
                    // No change to counters
                end
                FINAL_XOR: begin
                    counter <= 32'd1;
                    iteration <= 32'd1;
                end
            endcase
        end
    end

    // HMAC input preparation
    always_comb begin
        hmac_key = password;
        hmac_message = {salt, counter[31:0], 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0, 32'd0};
        hmac_length = 32'd40; // 32 bytes salt + 4 bytes counter + 4 bytes padding
    end

    // U value management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_prev <= 256'd0;
            u_current <= 256'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    u_prev <= 256'd0;
                    u_current <= 256'd0;
                end
                HMAC_ITERATION: begin
                    if (hmac_done) begin
                        if (iteration == 1) begin
                            u_prev <= hmac_result;
                            u_current <= hmac_result;
                        end else begin
                            u_prev <= u_current;
                            u_current <= hmac_result;
                        end
                    end
                end
            endcase
        end
    end

    // T accumulator
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t_accumulator <= 256'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    t_accumulator <= 256'd0;
                end
                ACCUMULATE: begin
                    t_accumulator <= t_accumulator ^ u_current;
                end
                FINAL_XOR: begin
                    t_accumulator <= t_accumulator ^ u_current;
                end
            endcase
        end
    end

    // Output
    assign derived_key = t_accumulator;

endmodule
