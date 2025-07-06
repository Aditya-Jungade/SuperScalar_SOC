module I_Fetch (
    input wire clk,
    input wire rst_n,

    // Inputs from EX/MEM stage
    input wire branch_taken_i,
    input wire [31:0] branch_target_address_i,

    // Stall and Flush signals
    input wire stall_i,
    input wire flush_i,

    // Outputs to Decode stage
    output wire [31:0] instr1_o,
    output wire [31:0] instr2_o,
    output wire [31:0] pc1_o,
    output wire [31:0] pc2_o,
    output wire fetch_valid_o,
    output wire [31:0] pc_out_o
);

    // Internal Components
    reg [31:0] pc_reg;
    // Instruction Memory (modeled as ROM)
    // You would typically use a 'readmemh' for initialization or synthesize a ROM.
    // Example: reg [31:0] instr_mem [0:MEM_DEPTH-1];

    // Instruction Buffer (Optional)
    reg [31:0] instr_buffer1;
    reg [31:0] instr_buffer2;
    reg instr_buffer_valid;

    // Incrementer / Branch Handler

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 32'h00000000;
            instr_buffer1 <= 32'b0;
            instr_buffer2 <= 32'b0;
            instr_buffer_valid <= 1'b0;
        end else if (flush_i) begin
            pc_reg <= branch_target_address_i;
            instr_buffer1 <= 32'b0;
            instr_buffer2 <= 32'b0;
            instr_buffer_valid <= 1'b0;
        end else if (!stall_i) begin
            if (branch_taken_i) begin
                pc_reg <= branch_target_address_i;
            end else begin
                pc_reg <= pc_reg + 32'd8;
            end
            // Fetch two instructions (modeling with direct assignment for simplicity)
            // In a real design, these would come from the instruction memory based on pc_reg and pc_reg+4
            instr_buffer1 <= instruction_memory_read(pc_reg); // Placeholder
            instr_buffer2 <= instruction_memory_read(pc_reg + 32'd4); // Placeholder
            instr_buffer_valid <= 1'b1;
        end else begin // Stalled
            // Hold PC
            // Do not fetch new instructions
            instr_buffer_valid <= 1'b0; // Or maintain based on buffer state
        end
    end

    // Assign outputs
    assign instr1_o = instr_buffer1;
    assign instr2_o = instr_buffer2;
    assign pc1_o = pc_reg;
    assign pc2_o = pc_reg + 32'd4;
    assign fetch_valid_o = instr_buffer_valid && !flush_i;
    assign pc_out_o = pc_reg;

    // Placeholder for instruction memory read function
    function [31:0] instruction_memory_read;
        input [31:0] addr;
        // In a real design, this would access your instr_mem array
        instruction_memory_read = 32'h00000013; // Example: lui x0, 0 (NOP)
    endfunction
endmodule