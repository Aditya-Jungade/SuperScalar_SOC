module FIFOQueue (
    input wire clk,
    input wire rst_n,

    // Inputs from Decode stage
    input wire [63:0] decoded_instr1_i,
    input wire [63:0] decoded_instr2_i,
    input wire decoded_valid1_i,
    input wire decoded_valid2_i,

    // Inputs from Scheduler
    input wire stall_from_scheduler_i,
    input wire flush_i,
    input wire dequeue_en_i,

    // Outputs to Scheduler
    output wire [63:0] fifo_out1_o,
    output wire [63:0] fifo_out2_o,
    output wire fifo_valid1_o,
    output wire fifo_valid2_o,
    output wire fifo_empty_o,
    output wire fifo_full_o,

    // Output for backpressure to Decode
    output wire stall_o
);

    parameter FIFO_DEPTH = 8;
    parameter INSTR_BUNDLE_WIDTH = 64; // Adjust based on your bundled instruction size

    reg [INSTR_BUNDLE_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [3:0] head_ptr; // Assuming FIFO_DEPTH <= 16
    reg [3:0] tail_ptr;
    reg fifo_empty_reg;
    reg fifo_full_reg;
    reg [3:0] current_size;

    wire enqueue_en1 = decoded_valid1_i && !stall_from_scheduler_i && !fifo_full_reg;
    wire enqueue_en2 = decoded_valid2_i && !stall_from_scheduler_i && !fifo_full_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head_ptr <= 4'd0;
            tail_ptr <= 4'd0;
            fifo_empty_reg <= 1'b1;
            fifo_full_reg <= 1'b0;
            current_size <= 4'd0;
        end else if (flush_i) begin
            head_ptr <= 4'd0;
            tail_ptr <= 4'd0;
            fifo_empty_reg <= 1'b1;
            fifo_full_reg <= 1'b0;
            current_size <= 4'd0;
        end else begin
            reg [3:0] next_head_ptr = head_ptr;
            reg [3:0] next_tail_ptr = tail_ptr;
            reg [3:0] next_current_size = current_size;
            reg next_fifo_empty = fifo_empty_reg;
            reg next_fifo_full = fifo_full_reg;

            // Dequeue Logic
            if (dequeue_en_i && !fifo_empty_reg) begin
                next_head_ptr = (head_ptr == FIFO_DEPTH - 1) ? 4'd0 : head_ptr + 4'd1;
                next_current_size = current_size - 4'd1;
                next_fifo_full = 1'b0;
                if (next_head_ptr == next_tail_ptr) next_fifo_empty = 1'b1;
            end

            // Enqueue Logic
            if (enqueue_en1) begin // Enqueue Instr1
                fifo_mem[tail_ptr] <= decoded_instr1_i;
                next_tail_ptr = (tail_ptr == FIFO_DEPTH - 1) ? 4'd0 : tail_ptr + 4'd1;
                next_current_size = current_size + 4'd1;
                next_fifo_empty = 1'b0;
                if (next_tail_ptr == next_head_ptr) next_fifo_full = 1'b1;
            end
            if (enqueue_en2 && enqueue_en1) begin // Enqueue Instr2 if Instr1 also enqueued
                fifo_mem[next_tail_ptr] <= decoded_instr2_i;
                next_tail_ptr = (next_tail_ptr == FIFO_DEPTH - 1) ? 4'd0 : next_tail_ptr + 4'd1;
                next_current_size = current_size + 4'd2; // Assuming both enqueued
                next_fifo_empty = 1'b0;
                if (next_tail_ptr == next_head_ptr) next_fifo_full = 1'b1;
            end else if (enqueue_en2 && !enqueue_en1) begin // Enqueue Instr2 alone (less common for superscalar)
                 // This scenario is tricky for preserving pairing
                 // For true in-order, you might only enqueue one if the other isn't valid or if there's a dependency.
                 // A simple approach is to only enqueue two if both are valid.
            end


            head_ptr <= next_head_ptr;
            tail_ptr <= next_tail_ptr;
            fifo_empty_reg <= next_fifo_empty;
            fifo_full_reg <= next_fifo_full;
            current_size <= next_current_size;
        end
    end

    // Outputs
    assign fifo_out1_o = fifo_mem[head_ptr];
    assign fifo_valid1_o = !fifo_empty_reg;
    assign fifo_out2_o = (current_size >= 2) ? fifo_mem[(head_ptr == FIFO_DEPTH - 1) ? 0 : head_ptr + 1] : {INSTR_BUNDLE_WIDTH{1'b0}};
    assign fifo_valid2_o = (current_size >= 2);

    assign fifo_empty_o = fifo_empty_reg;
    assign fifo_full_o = fifo_full_reg;
    assign stall_o = fifo_full_reg;
endmodule