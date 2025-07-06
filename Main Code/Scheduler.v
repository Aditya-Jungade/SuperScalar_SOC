module Scheduler (
    input wire clk,
    input wire rst_n,

    // Inputs from FIFO Queue
    input wire [63:0] fifo_out1_i,
    input wire [63:0] fifo_out2_i,
    input wire fifo_valid1_i,
    input wire fifo_valid2_i,
    input wire fifo_empty_i,         // For control

    // Inputs from Execution Units and Writeback
    input wire alu1_ready_i,
    input wire alu2_ready_i,
    input wire mem_unit_ready_i,
    input wire [4:0] retire_rd_i,
    input wire retire_valid_i,

    // Flush signal
    input wire flush_i,

    // Outputs to Execution stage
    output wire [63:0] issue_instr1_o,
    output wire [63:0] issue_instr2_o,
    output wire issue_valid1_o,
    output wire issue_valid2_o,

    // Outputs to FIFO Queue
    output wire fifo_stall_o,
    output wire dequeue_en_o,        // Signal to FIFO to dequeue

    // Output to Scoreboard
    output wire [4:0] scoreboard_rd_update_o,
    output wire scoreboard_update_valid_o,
    output wire scoreboard_clear_rd_o, // Signal to clear RD on writeback
    output wire [4:0] scoreboard_rd_clear_addr_o // Address to clear
);

    // Internal Components
    reg [31:0] reg_status_table; // 32-bit array tracking availability of each register

    // Unpack the 64-bit bundle: Assuming it contains {PC (32-bit), Instruction (32-bit)}
    wire [31:0] pc_from_fifo1;
    wire [31:0] instr_from_fifo1;
    wire [31:0] pc_from_fifo2;
    wire [31:0] instr_from_fifo2;

    assign {pc_from_fifo1, instr_from_fifo1} = fifo_out1_i;
    assign {pc_from_fifo2, instr_from_fifo2} = fifo_out2_i;

    // Decode instruction fields from the unpacked raw instruction
    wire [6:0] opcode1, opcode2;
    wire [2:0] funct3_1, funct3_2;
    wire [6:0] funct7_1, funct7_2;
    wire [4:0] rd1_fifo, rd2_fifo, rs1_1_fifo, rs1_2_fifo, rs2_1_fifo, rs2_2_fifo;

    assign opcode1 = instr_from_fifo1[6:0];
    assign funct3_1 = instr_from_fifo1[14:12];
    assign funct7_1 = instr_from_fifo1[31:25];
    assign rd1_fifo = instr_from_fifo1[11:7];
    assign rs1_1_fifo = instr_from_fifo1[19:15];
    assign rs2_1_fifo = instr_from_fifo1[24:20];

    assign opcode2 = instr_from_fifo2[6:0];
    assign funct3_2 = instr_from_fifo2[14:12];
    assign funct7_2 = instr_from_fifo2[31:25];
    assign rd2_fifo = instr_from_fifo2[11:7];
    assign rs1_2_fifo = instr_from_fifo2[19:15];
    assign rs2_2_fifo = instr_from_fifo2[24:20];

    // Re-derive control signals here based on the instruction fields
    wire mem_read1, mem_write1, branch1, reg_write1;
    wire mem_read2, mem_write2, branch2, reg_write2;

    // Simplified control logic (similar to what was in InstructionDecode)
    assign mem_read1 = (opcode1 == 7'b0000011); // Load
    assign mem_write1 = (opcode1 == 7'b0100011); // Store
    assign branch1 = (opcode1 == 7'b1100011); // Branch
    assign reg_write1 = (opcode1 == 7'b0110011 || opcode1 == 7'b0000011 || opcode1 == 7'b0010011 || opcode1 == 7'b0110111 || opcode1 == 7'b0010111 || opcode1 == 7'b1101111 || opcode1 == 7'b1100111); // R-type, Load, I-type (arith), U-type (LUI), AUIPC, JAL, JALR

    assign mem_read2 = (opcode2 == 7'b0000011);
    assign mem_write2 = (opcode2 == 7'b0100011);
    assign branch2 = (opcode2 == 7'b1100011);
    assign reg_write2 = (opcode2 == 7'b0110011 || opcode2 == 7'b0000011 || opcode2 == 7'b0010011 || opcode2 == 7'b0110111 || opcode2 == 7'b0010111 || opcode2 == 7'b1101111 || opcode2 == 7'b1100111);

    wire rs1_1_ready = !reg_status_table[rs1_1_fifo];
    wire rs2_1_ready = !reg_status_table[rs2_1_fifo];
    wire rs1_2_ready = !reg_status_table[rs1_2_fifo];
    wire rs2_2_ready = !reg_status_table[rs2_2_fifo];

    // Changed from wire to reg
    reg instr1_can_issue;
    reg instr2_can_issue;

    // Issue Logic
    always @(*) begin
        // Instr1 can issue if its source registers are ready and a functional unit is free
        instr1_can_issue = fifo_valid1_i && rs1_1_ready && rs2_1_ready &&
                           ((reg_write1 && alu1_ready_i) || ((mem_read1 || mem_write1) && mem_unit_ready_i));

        // Instr2 can issue only if Instr1 has issued or is independent, no data hazard with Instr1,
        // and its source registers are ready, and a functional unit is free.
        instr2_can_issue = fifo_valid2_i &&
                           !reg_status_table[rs1_2_fifo] && !reg_status_table[rs2_2_fifo] &&
                           ((reg_write2 && alu2_ready_i) || ((mem_read2 || mem_write2) && mem_unit_ready_i)) &&
                           !(rs1_2_fifo == rd1_fifo && reg_write1 && instr1_can_issue) && // No RAW with Instr1.rd (only if Instr1 writes)
                           !(rs2_2_fifo == rd1_fifo && reg_write1 && instr1_can_issue) && // No RAW with Instr1.rd (only if Instr1 writes)
                           (instr1_can_issue || (rs1_1_fifo != rs1_2_fifo && rs2_1_fifo != rs2_2_fifo && rs1_1_fifo != rs2_2_fifo && rs2_1_fifo != rs1_2_fifo)); // Independent or Instr1 issues

        // If Instr1 is stalled, Instr2 must wait
        if (!instr1_can_issue) begin
            instr2_can_issue = 1'b0;
        end
    end


    // Scoreboard Update Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_status_table <= 32'h0; // All registers available
        end else begin
            // Clear register on writeback
            if (retire_valid_i) begin
                reg_status_table[retire_rd_i] <= 1'b0;
            end

            // Mark destination registers busy on issue
            if (issue_valid1_o && reg_write1 && rd1_fifo != 5'b0) begin // x0 cannot be written
                reg_status_table[rd1_fifo] <= 1'b1;
            end
            if (issue_valid2_o && reg_write2 && rd2_fifo != 5'b0) begin // x0 cannot be written
                reg_status_table[rd2_fifo] <= 1'b1;
            end
        end
    end

    // Outputs
    assign issue_instr1_o = fifo_out1_i; // Pass original bundle (PC + Instruction)
    assign issue_valid1_o = instr1_can_issue && !flush_i;
    assign issue_instr2_o = fifo_out2_i; // Pass original bundle (PC + Instruction)
    assign issue_valid2_o = instr2_can_issue && !flush_i;

    assign fifo_stall_o = !instr1_can_issue && !fifo_empty_i; // Stall FIFO if we can't issue
    assign dequeue_en_o = (issue_valid1_o && issue_valid2_o) ? 2'b11 :
                          (issue_valid1_o || issue_valid2_o) ? 2'b01 : 2'b00; // Dequeue based on how many issued

    assign scoreboard_rd_update_o = (issue_valid1_o) ? rd1_fifo : rd2_fifo; // Simplified, handle both
    assign scoreboard_update_valid_o = issue_valid1_o || issue_valid2_o;

    assign scoreboard_clear_rd_o = retire_valid_i;
    assign scoreboard_rd_clear_addr_o = retire_rd_i;
endmodule