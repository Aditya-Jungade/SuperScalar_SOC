module WB_ (
    input wire clk,
    input wire rst_n,

    // Inputs from ALU or Memory stage
    input wire [4:0] rd_i,                 // Destination register address
    input wire [31:0] write_data_i,       // Result from ALU or Data Memory
    input wire reg_write_i,                // Control signal
    input wire mem_to_reg_i,               // Selects between ALU result and memory data
    input wire [63:0] instruction_info_i, // Full instruction context
    input wire wb_stage_valid_i,           // Validity of instruction for WB

    // Flush signal
    input wire flush_i,

    // Outputs to Register File
    output wire [4:0] reg_file_write_addr_o,
    output wire [31:0] reg_file_write_data_o,
    output wire reg_file_write_en_o,

    // Outputs to Scoreboard (Scheduler)
    output wire [4:0] scoreboard_clear_rd_addr_o,
    output wire scoreboard_clear_valid_o,
    output wire wb_valid_o                      // Indicates successful commit
);

    // Register File (write port logic)
    // The actual reg file instance would be external and connected to all modules.
    // This module generates the signals for it.

    // Writeback Mux
    wire [31:0] final_write_data = mem_to_reg_i ? write_data_i : write_data_i; // Simplified as write_data_i already selected

    reg wb_valid_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_valid_reg <= 1'b0;
        end else if (flush_i) begin
            wb_valid_reg <= 1'b0;
        end else if (wb_stage_valid_i && reg_write_i && (rd_i != 5'b0)) begin
            // Perform the write to register file
            // reg_file_instance.write_port_data <= final_write_data;
            // reg_file_instance.write_port_addr <= rd_i;
            // reg_file_instance.write_port_en <= 1'b1;
            wb_valid_reg <= 1'b1;
        end else begin
            wb_valid_reg <= 1'b0;
        end
    end

    // Outputs to external Register File
    assign reg_file_write_addr_o = rd_i;
    assign reg_file_write_data_o = final_write_data;
    assign reg_file_write_en_o = wb_stage_valid_i && reg_write_i && (rd_i != 5'b0) && !flush_i;

    // Outputs to Scoreboard
    assign scoreboard_clear_rd_addr_o = rd_i;
    assign scoreboard_clear_valid_o = wb_valid_reg;
    assign wb_valid_o = wb_valid_reg;
endmodule