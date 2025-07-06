module Memory (
    input wire clk,
    input wire rst_n,

    // Inputs from ALU stage
    input wire [31:0] alu_result_i,       // Memory address
    input wire [31:0] rs2_val_i,          // Store data
    input wire mem_read_i,
    input wire mem_write_i,
    input wire [4:0] rd_i,
    input wire [63:0] instruction_info_i, // Full bundle
    input wire mem_stage_valid_i,          // Valid signal from previous stage

    // Flush signal
    input wire flush_i,

    // Outputs to Writeback Stage
    output wire [31:0] mem_data_out_o,     // Data read from memory
    output wire [4:0] rd_o,                // Destination register
    output wire mem_access_complete_o,     // Ready/valid signal
    output wire [63:0] instruction_info_o, // Full bundle to WB
    output wire mem_valid_o                // Indicates valid operation
);

    parameter DATA_MEM_SIZE = 1024; // Example size (in words)
    reg [31:0] data_mem [0:DATA_MEM_SIZE-1];

    reg [31:0] mem_data_out_reg;
    reg mem_access_complete_reg;
    reg mem_valid_reg;

    initial begin
        // Initialize memory (optional, for simulation)
        $readmemh("data_memory.mem", data_mem); // Example
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_data_out_reg <= 32'b0;
            mem_access_complete_reg <= 1'b0;
            mem_valid_reg <= 1'b0;
        end else if (flush_i) begin
            mem_data_out_reg <= 32'b0;
            mem_access_complete_reg <= 1'b0;
            mem_valid_reg <= 1'b0;
        end else if (mem_stage_valid_i) begin
            // Check for alignment faults
            if (alu_result_i[1:0] != 2'b00) begin
                // Handle alignment fault (e.g., raise exception or stall)
                mem_access_complete_reg <= 1'b0;
                mem_valid_reg <= 1'b0;
            end else begin
                if (mem_read_i) begin // Load operation
                    mem_data_out_reg <= data_mem[alu_result_i[31:2]]; // Word-addressed memory
                    mem_access_complete_reg <= 1'b1;
                    mem_valid_reg <= 1'b1;
                end else if (mem_write_i) begin // Store operation
                    data_mem[alu_result_i[31:2]] <= rs2_val_i;
                    mem_data_out_reg <= 32'b0; // No data out for stores
                    mem_access_complete_reg <= 1'b1;
                    mem_valid_reg <= 1'b1;
                end else begin // Not a memory operation
                    mem_data_out_reg <= 32'b0;
                    mem_access_complete_reg <= 1'b0;
                    mem_valid_reg <= 1'b0;
                end
            end
        end else begin
            mem_data_out_reg <= 32'b0;
            mem_access_complete_reg <= 1'b0;
            mem_valid_reg <= 1'b0;
        end
    end

    // Outputs
    assign mem_data_out_o = mem_data_out_reg;
    assign rd_o = rd_i;
    assign mem_access_complete_o = mem_access_complete_reg;
    assign instruction_info_o = instruction_info_i;
    assign mem_valid_o = mem_valid_reg;
endmodule