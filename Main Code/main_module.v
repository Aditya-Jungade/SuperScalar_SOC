module main_module (
    input wire clk,
    input wire rst_n,

    // Example for external memory interface (optional)
    output wire [31:0] mem_address_o,
    input wire [31:0] mem_read_data_i,
    output wire [31:0] mem_write_data_o,
    output wire mem_read_en_o,
    output wire mem_write_en_o
);

    // Wires connecting modules
    // Fetch-Decode
    wire [31:0] fetch_instr1, fetch_instr2;
    wire [31:0] fetch_pc1, fetch_pc2;
    wire fetch_valid;
    wire fetch_stall;
    wire fetch_flush; // From EX/MEM (Branch misprediction)
    wire [31:0] fetch_pc_out;

    // Decode-FIFO
    wire [63:0] decoded_instr1, decoded_instr2;
    wire decoded_valid1, decoded_valid2;
    wire decode_stall;
    wire decode_flush; // From EX/MEM or internally generated

    // FIFO-Scheduler
    wire [63:0] fifo_out1, fifo_out2;
    wire fifo_valid1, fifo_valid2;
    wire fifo_empty, fifo_full;
    wire fifo_stall_to_decode;
    wire fifo_dequeue_en;

    // Scheduler-ALU/MEM
    wire [63:0] issue_instr1_to_alu, issue_instr2_to_alu;
    wire issue_valid1_to_alu, issue_valid2_to_alu;
    wire alu1_ready = 1'b1; // Simplified, in real design from ALU unit
    wire alu2_ready = 1'b1; // Simplified
    wire mem_unit_ready = 1'b1; // Simplified
    wire [4:0] retire_rd;
    wire retire_valid;
    wire scheduler_flush;

    // ALU-MEM
    wire [31:0] alu_result_to_mem1, alu_result_to_mem2;
    wire branch_decision1, branch_decision2;
    wire [4:0] alu_rd1, alu_rd2;
    wire [63:0] alu_instr_info1, alu_instr_info2;
    wire alu_valid1, alu_valid2;

    // MEM-WB
    wire [31:0] mem_data_out1, mem_data_out2;
    wire [4:0] mem_rd1, mem_rd2;
    wire mem_access_complete1, mem_access_complete2;
    wire [63:0] mem_instr_info1, mem_instr_info2;
    wire mem_valid1, mem_valid2;

    // WB-RegFile (and back to Scheduler for scoreboard clear)
    wire [4:0] wb_write_addr1, wb_write_addr2;
    wire [31:0] wb_write_data1, wb_write_data2;
    wire wb_write_en1, wb_write_en2;
    wire [4:0] wb_clear_rd_addr1, wb_clear_rd_addr2;
    wire wb_clear_valid1, wb_clear_valid2;
    wire wb_valid1, wb_valid2;

    // Register File (centralized)
    reg [31:0] general_purpose_registers [0:31];

    // Instantiate Modules

    // Register File (simplified, needs proper read/write logic)
    // This is just a conceptual representation. A real reg file would handle multiple reads/writes.
    assign mem_read_data_i = general_purpose_registers[0]; // Placeholder for external memory

    // Instruction Fetch
    InstructionFetch IF_module (
        .clk(clk),
        .rst_n(rst_n),
        .branch_taken_i(branch_decision1 || branch_decision2), // Assuming branch is handled in EX, feedback to IF
        .branch_target_address_i(alu_result_to_mem1), // Simplified, needs actual target from EX
        .stall_i(fetch_stall),
        .flush_i(fetch_flush),
        .instr1_o(fetch_instr1),
        .instr2_o(fetch_instr2),
        .pc1_o(fetch_pc1),
        .pc2_o(fetch_pc2),
        .fetch_valid_o(fetch_valid),
        .pc_out_o(fetch_pc_out)
    );

    // Instruction Decode
    InstructionDecode ID_module (
        .clk(clk),
        .rst_n(rst_n),
        .instr1_i(fetch_instr1),
        .instr2_i(fetch_instr2),
        .pc1_i(fetch_pc1),
        .pc2_i(fetch_pc2),
        .fetch_valid_i(fetch_valid),
        .stall_i(decode_stall),
        .flush_i(decode_flush),
        .decoded_instr1_o(decoded_instr1),
        .decoded_instr2_o(decoded_instr2),
        .decoded_valid1_o(decoded_valid1),
        .decoded_valid2_o(decoded_valid2),
        .stall_o(fetch_stall) // Stall signal from Decode to Fetch
    );

    // FIFO Queue
    FIFOQueue FIFO_module (
        .clk(clk),
        .rst_n(rst_n),
        .decoded_instr1_i(decoded_instr1),
        .decoded_instr2_i(decoded_instr2),
        .decoded_valid1_i(decoded_valid1),
        .decoded_valid2_i(decoded_valid2),
        .stall_from_scheduler_i(fifo_stall_to_decode),
        .flush_i(scheduler_flush), // Flush from scheduler or global flush
        .dequeue_en_i(fifo_dequeue_en),
        .fifo_out1_o(fifo_out1),
        .fifo_out2_o(fifo_out2),
        .fifo_valid1_o(fifo_valid1),
        .fifo_valid2_o(fifo_valid2),
        .fifo_empty_o(fifo_empty),
        .fifo_full_o(fifo_full),
        .stall_o(decode_stall) // Stall from FIFO to Decode
    );

    // Scheduler
    Scheduler SCHED_module (
        .clk(clk),
        .rst_n(rst_n),
        .fifo_out1_i(fifo_out1),
        .fifo_out2_i(fifo_out2),
        .fifo_valid1_i(fifo_valid1),
        .fifo_valid2_i(fifo_valid2),
        .fifo_empty_i(fifo_empty),
        .alu1_ready_i(alu1_ready),
        .alu2_ready_i(alu2_ready),
        .mem_unit_ready_i(mem_unit_ready),
        .retire_rd_i(wb_clear_rd_addr1), // Assuming one retire per cycle for simplicity
        .retire_valid_i(wb_clear_valid1),
        .flush_i(scheduler_flush),
        .issue_instr1_o(issue_instr1_to_alu),
        .issue_instr2_o(issue_instr2_to_alu),
        .issue_valid1_o(issue_valid1_to_alu),
        .issue_valid2_o(issue_valid2_to_alu),
        .fifo_stall_o(fifo_stall_to_decode),
        .dequeue_en_o(fifo_dequeue_en),
        .scoreboard_rd_update_o(retire_rd), // Connect to a placeholder, or directly update scoreboard
        .scoreboard_update_valid_o(retire_valid),
        .scoreboard_clear_rd_o(wb_clear_valid1),
        .scoreboard_rd_clear_addr_o(wb_clear_rd_addr1)
    );

    // Register Read & ALU Execution (Duplicated for 2-way issue, or a single unit handling both)
    RegReadALU ALU_module1 (
        .clk(clk),
        .rst_n(rst_n),
        .issue_instr_i(issue_instr1_to_alu),
        .issue_valid_i(issue_valid1_to_alu),
        .reg_file_read_data1_i(general_purpose_registers[issue_instr1_to_alu[19:15]]), // Assuming rs1_index is bits [19:15] of the instruction part within the bundle
        .reg_file_read_data2_i(general_purpose_registers[issue_instr1_to_alu[24:20]]), // Assuming rs2_index is bits [24:20] of the instruction part within the bundle
        .flush_i(scheduler_flush),
        .alu_result_o(alu_result_to_mem1),
        .branch_decision_o(branch_decision1),
        .rd_o(alu_rd1),
        .instruction_info_o(alu_instr_info1),
        .alu_valid_o(alu_valid1)
    );

    RegReadALU ALU_module2 (
        .clk(clk),
        .rst_n(rst_n),
        .issue_instr_i(issue_instr2_to_alu),
        .issue_valid_i(issue_valid2_to_alu),
        .reg_file_read_data1_i(general_purpose_registers[issue_instr2_to_alu[19:15]]), // Assuming rs1_index is bits [19:15] of the instruction part within the bundle
        .reg_file_read_data2_i(general_purpose_registers[issue_instr2_to_alu[24:20]]), // Assuming rs2_index is bits [24:20] of the instruction part within the bundle
        .flush_i(scheduler_flush),
        .alu_result_o(alu_result_to_mem2),
        .branch_decision_o(branch_decision2),
        .rd_o(alu_rd2),
        .instruction_info_o(alu_instr_info2),
        .alu_valid_o(alu_valid2)
    );

    // Memory (Can be a single unit handling requests from both, or duplicated)
    Memory MEM_module1 (
        .clk(clk),
        .rst_n(rst_n),
        .alu_result_i(alu_result_to_mem1),
        .rs2_val_i(general_purpose_registers[alu_instr_info1[24:20]]), // Assuming rs2_index is bits [24:20] of the instruction part within the bundle
        .mem_read_i(alu_instr_info1[32]), // Hypothetical bit for mem_read_bit in the bundle
        .mem_write_i(alu_instr_info1[33]), // Hypothetical bit for mem_write_bit in the bundle
        .rd_i(alu_rd1),
        .instruction_info_i(alu_instr_info1),
        .mem_stage_valid_i(alu_valid1),
        .flush_i(scheduler_flush),
        .mem_data_out_o(mem_data_out1),
        .rd_o(mem_rd1),
        .mem_access_complete_o(mem_access_complete1),
        .instruction_info_o(mem_instr_info1),
        .mem_valid_o(mem_valid1)
    );

    Memory MEM_module2 (
        .clk(clk),
        .rst_n(rst_n),
        .alu_result_i(alu_result_to_mem2),
        .rs2_val_i(general_purpose_registers[alu_instr_info2[24:20]]), // Assuming rs2_index is bits [24:20] of the instruction part within the bundle
        .mem_read_i(alu_instr_info2[32]), // Hypothetical bit for mem_read_bit in the bundle
        .mem_write_i(alu_instr_info2[33]), // Hypothetical bit for mem_write_bit in the bundle
        .rd_i(alu_rd2),
        .instruction_info_i(alu_instr_info2),
        .mem_stage_valid_i(alu_valid2),
        .flush_i(scheduler_flush),
        .mem_data_out_o(mem_data_out2),
        .rd_o(mem_rd2),
        .mem_access_complete_o(mem_access_complete2),
        .instruction_info_o(mem_instr_info2),
        .mem_valid_o(mem_valid2)
    );

    // Writeback (can be a single unit handling both writes or duplicated)
    Writeback WB_module1 (
        .clk(clk),
        .rst_n(rst_n),
        .rd_i(mem_rd1),
        .write_data_i(mem_data_out1), // If it's a load, otherwise alu_result directly (needs mux)
        .reg_write_i(mem_instr_info1[34]), // Hypothetical bit for reg_write_bit in the bundle
        .mem_to_reg_i(mem_instr_info1[35]), // Hypothetical bit for mem_to_reg_bit in the bundle
        .instruction_info_i(mem_instr_info1),
        .wb_stage_valid_i(mem_valid1),
        .flush_i(scheduler_flush),
        .reg_file_write_addr_o(wb_write_addr1),
        .reg_file_write_data_o(wb_write_data1),
        .reg_file_write_en_o(wb_write_en1),
        .scoreboard_clear_rd_addr_o(wb_clear_rd_addr1),
        .scoreboard_clear_valid_o(wb_clear_valid1),
        .wb_valid_o(wb_valid1)
    );

    Writeback WB_module2 (
        .clk(clk),
        .rst_n(rst_n),
        .rd_i(mem_rd2),
        .write_data_i(mem_data_out2),
        .reg_write_i(mem_instr_info2[34]), // Hypothetical bit for reg_write_bit in the bundle
        .mem_to_reg_i(mem_instr_info2[35]), // Hypothetical bit for mem_to_reg_bit in the bundle
        .instruction_info_i(mem_instr_info2),
        .wb_stage_valid_i(mem_valid2),
        .flush_i(scheduler_flush),
        .reg_file_write_addr_o(wb_write_addr2),
        .reg_file_write_data_o(wb_write_data2),
        .reg_file_write_en_o(wb_write_en2),
        .scoreboard_clear_rd_addr_o(wb_clear_rd_addr2),
        .scoreboard_clear_valid_o(wb_clear_valid2),
        .wb_valid_o(wb_valid2)
    );

    // Register File write logic (centralized)
    always @(posedge clk) begin
        if (wb_write_en1) begin
            general_purpose_registers[wb_write_addr1] <= wb_write_data1;
        end
        // If both write to the same register, Instr1 wins due to in-order
        if (wb_write_en2 && (wb_write_addr2 != wb_write_addr1)) begin
            general_purpose_registers[wb_write_addr2] <= wb_write_data2;
        end
    end

    // Hazard Control and Flush Signals (Simplified for illustration)
    // In a real pipeline, `fetch_flush`, `decode_flush`, `scheduler_flush` would be driven by:
    // - Branch Misprediction detection in EX/MEM stage
    // - Exceptions

    // Example of branch misprediction feedback
    assign fetch_flush = (branch_decision1 && alu_valid1) || (branch_decision2 && alu_valid2); // Simplified
    assign decode_flush = fetch_flush;
    assign scheduler_flush = fetch_flush; // Global flush

    // Placeholder for external memory interface
    assign mem_address_o = 32'b0;
    assign mem_write_data_o = 32'b0;
    assign mem_read_en_o = 1'b0;
    assign mem_write_en_o = 1'b0;


endmodule