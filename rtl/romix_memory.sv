/**
 * ROMix Memory RTL Implementation
 * 
 * Memory-hard function for Scrypt algorithm.
 * Compatible with MinerSICS architecture.
 * 
 * @author TheMapleseed
 * @version 1.0
 */

module romix_memory (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [255:0] input_data,
    input  logic [31:0]  n_param,
    input  logic [31:0]  r_param,
    output logic [255:0] output_data,
    output logic        done,
    output logic        busy
);

    // Memory parameters
    localparam int MEMORY_DEPTH = 1024;
    localparam int MEMORY_WIDTH = 1024;

    // Internal signals
    logic [MEMORY_WIDTH-1:0] memory_array [0:MEMORY_DEPTH-1];
    logic [MEMORY_WIDTH-1:0] memory_data_in;
    logic [MEMORY_WIDTH-1:0] memory_data_out;
    logic [31:0]             memory_addr;
    logic                    memory_write_en;
    logic                    memory_read_en;
    logic [255:0]            x_current;
    logic [255:0]            x_next;
    logic [31:0]             i_counter;
    logic [31:0]             j_counter;
    logic [31:0]             n_minus_1;
    logic [2:0]              state;
    logic                    salsa_start;
    logic                    salsa_done;
    logic                    salsa_busy;
    logic [1023:0]           salsa_input;
    logic [1023:0]           salsa_output;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        INIT_MEMORY,
        MEMORY_WRITE,
        MEMORY_READ,
        SALSA_MIX,
        FINAL_XOR,
        DONE
    } state_t;
    
    state_t current_state, next_state;

    // Salsa20/8 core
    salsa20_core salsa_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(salsa_start),
        .data_in(salsa_input),
        .data_out(salsa_output),
        .done(salsa_done),
        .busy(salsa_busy)
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
                if (start) next_state = INIT_MEMORY;
            end
            INIT_MEMORY: begin
                if (i_counter == n_param) next_state = MEMORY_READ;
                else next_state = MEMORY_WRITE;
            end
            MEMORY_WRITE: begin
                if (salsa_done) next_state = INIT_MEMORY;
            end
            MEMORY_READ: begin
                if (j_counter == n_param) next_state = FINAL_XOR;
                else next_state = SALSA_MIX;
            end
            SALSA_MIX: begin
                if (salsa_done) next_state = MEMORY_READ;
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
    assign salsa_start = (current_state == MEMORY_WRITE || current_state == SALSA_MIX);
    assign memory_write_en = (current_state == MEMORY_WRITE && salsa_done);
    assign memory_read_en = (current_state == MEMORY_READ);

    // Counter management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_counter <= 32'd0;
            j_counter <= 32'd0;
            n_minus_1 <= 32'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    i_counter <= 32'd0;
                    j_counter <= 32'd0;
                    n_minus_1 <= n_param - 1'b1;
                end
                INIT_MEMORY: begin
                    if (i_counter < n_param) begin
                        i_counter <= i_counter + 1'b1;
                    end
                end
                MEMORY_READ: begin
                    if (j_counter < n_param) begin
                        j_counter <= j_counter + 1'b1;
                    end
                end
                FINAL_XOR: begin
                    i_counter <= 32'd0;
                    j_counter <= 32'd0;
                end
            endcase
        end
    end

    // Memory address management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            memory_addr <= 32'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    memory_addr <= 32'd0;
                end
                MEMORY_WRITE: begin
                    memory_addr <= i_counter;
                end
                MEMORY_READ: begin
                    memory_addr <= j_counter;
                end
            endcase
        end
    end

    // X value management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_current <= 256'd0;
            x_next <= 256'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    x_current <= input_data;
                    x_next <= 256'd0;
                end
                MEMORY_WRITE: begin
                    if (salsa_done) begin
                        x_current <= salsa_output[255:0];
                        x_next <= salsa_output[255:0];
                    end
                end
                SALSA_MIX: begin
                    if (salsa_done) begin
                        x_current <= salsa_output[255:0];
                        x_next <= salsa_output[255:0];
                    end
                end
            endcase
        end
    end

    // Memory array management
    always_ff @(posedge clk) begin
        if (memory_write_en) begin
            memory_array[memory_addr] <= memory_data_in;
        end
    end

    always_comb begin
        memory_data_out = memory_array[memory_addr];
    end

    // Salsa input preparation
    always_comb begin
        case (current_state)
            MEMORY_WRITE: begin
                salsa_input = {x_current, 768'd0};
            end
            SALSA_MIX: begin
                salsa_input = {x_current ^ memory_data_out[255:0], memory_data_out[1023:256]};
            end
            default: begin
                salsa_input = 1024'd0;
            end
        endcase
    end

    // Memory data input
    always_comb begin
        memory_data_in = salsa_output;
    end

    // Output
    assign output_data = x_current;

endmodule

/**
 * Salsa20/8 Core RTL
 * 
 * Salsa20/8 implementation for ROMix function.
 */
module salsa20_core (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [1023:0] data_in,
    output logic [1023:0] data_out,
    output logic        done,
    output logic        busy
);

    // Internal signals
    logic [31:0] x[0:15];
    logic [31:0] y[0:15];
    logic [4:0]  round;
    logic [2:0]  state;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        PROCESS,
        FINAL
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
                if (start) next_state = PROCESS;
            end
            PROCESS: begin
                if (round == 5'd7) next_state = FINAL;
            end
            FINAL: begin
                next_state = IDLE;
            end
        endcase
    end

    // Control signals
    assign busy = (current_state != IDLE);
    assign done = (current_state == FINAL);

    // Round counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            round <= 5'd0;
        end else if (current_state == PROCESS) begin
            if (round == 5'd7) begin
                round <= 5'd0;
            end else begin
                round <= round + 1'b1;
            end
        end
    end

    // Input data parsing
    always_ff @(posedge clk) begin
        if (start) begin
            for (int i = 0; i < 16; i++) begin
                x[i] <= data_in[1023-i*32:992-i*32];
            end
        end
    end

    // Salsa20 quarterround function
    function automatic logic [31:0] quarterround(
        input logic [31:0] a, b, c, d
    );
        logic [31:0] temp;
        temp = a + d;
        temp = {temp[6:0], temp[31:7]} ^ b;
        b = b + temp;
        b = {b[16:0], b[31:17]} ^ c;
        c = c + b;
        c = {c[8:0], c[31:9]} ^ d;
        d = d + c;
        d = {d[0], d[31:1]} ^ a;
        a = a + d;
        quarterround = a;
    endfunction

    // Salsa20 processing
    always_ff @(posedge clk) begin
        if (current_state == PROCESS) begin
            // Column rounds
            y[0] <= quarterround(x[0], x[4], x[8],  x[12]);
            y[5] <= quarterround(x[5], x[9], x[13], x[1]);
            y[10] <= quarterround(x[10], x[14], x[2], x[6]);
            y[15] <= quarterround(x[15], x[3], x[7], x[11]);
            
            // Row rounds
            y[1] <= quarterround(x[1], x[5], x[9],  x[13]);
            y[6] <= quarterround(x[6], x[10], x[14], x[2]);
            y[11] <= quarterround(x[11], x[15], x[3], x[7]);
            y[12] <= quarterround(x[12], x[0], x[4], x[8]);
            
            // Copy other values
            y[2] <= x[2];
            y[3] <= x[3];
            y[4] <= x[4];
            y[7] <= x[7];
            y[8] <= x[8];
            y[9] <= x[9];
            y[13] <= x[13];
            y[14] <= x[14];
        end
    end

    // Output data formatting
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            data_out[1023-i*32:992-i*32] = y[i];
        end
    end

endmodule
