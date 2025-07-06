module RegReadALU (
    input wire clk,
    input wire rst_n,

    // Inputs from Scheduler
    input wire [63:0] issue_instr_i, // Bundled instruction from scheduler
    input wire issue_valid_i,        // Validity of the instruction

    // Register File (assuming shared access)
    input wire [31:0] reg_file_read_data1_i, // Data for rs1
    input wire [31:0] reg_file_read_data2_i, // Data for rs2

    // Flush signal
    input wire flush_i,

    // Outputs to Memory or Writeback Stage
    output wire [31:0] alu_result_o,
    output wire branch_decision_o,
    output wire [4:0] rd_o,
    output wire [63:0] instruction_info_o, // Full bundle to next stage
    output wire alu_valid_o          // Indicates valid result
);

    // Internal Components
    // Register File (read ports here, write port in Writeback)
    // ALU Unit
    // Branch Logic Unit

    // Decode instruction bundle
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    wire [31:0] immediate;
    wire [31:0] pc_val;
    wire [3:0] alu_op;                      // Placeholder for actual ALU_Op encoding
    wire is_branch, is_load, is_store, is_alu_reg_write; // Placeholder for Instruction_Type

    // Example unpacking (adjust indices based on your bundle definition)
    // NOTE: This unpacking assumes issue_instr_i is wide enough to contain all these fields.
    // Based on previous modules, if issue_instr_i is 64-bit (PC + Instruction),
    // then 'immediate' and control signals 'is_load', etc., would need to be derived
    // from the raw instruction. If they are truly part of the bundle, the bundle needs to be wider.
    // Assuming for now that the bundle is wide enough and these fields are present as intended by previous 'InstructionDecode' module.
    assign {
        pc_val, // Assuming 32 bits
        /*opcode (7 bits)*/, /*funct3 (3 bits)*/, /*funct7 (7 bits)*/, // These should be unpacked into actual wires if used
        rd_addr, rs1_addr, rs2_addr, // Assuming 5 bits each
        immediate, // Assuming 32 bits
        is_load, is_store, is_branch, is_alu_reg_write // Assuming 1 bit each
    } = issue_instr_i; // The total width of this unpacked bundle should match issue_instr_i

    reg [31:0] alu_result_reg;
    reg branch_decision_reg;
    reg alu_valid_reg;

    always @(*) begin
        alu_result_reg = 32'b0;
        branch_decision_reg = 1'b0;
        alu_valid_reg = issue_valid_i && !flush_i;

        if (issue_valid_i && !flush_i) begin
            case (1'b1) // Use instruction type/opcode to determine operation
                is_alu_reg_write: begin // R-type, I-type ALU ops
                    case (alu_op) // This needs a proper ALU_Op decoding from your control unit
                        // Example:
                        4'd0: alu_result_reg = reg_file_read_data1_i + reg_file_read_data2_i; // ADD
                        4'd1: alu_result_reg = reg_file_read_data1_i + immediate;            // ADDI
                        // ... other ALU operations
                        default: alu_result_reg = 32'b0;
                    endcase
                end
                is_store: begin // S-type: Compute address
                    alu_result_reg = reg_file_read_data1_i + immediate;
                end
                is_load: begin // I-type: Compute address
                    alu_result_reg = reg_file_read_data1_i + immediate;
                end
                is_branch: begin // Branch evaluation
                    // Example BEQ
                    if (reg_file_read_data1_i == reg_file_read_data2_i) begin
                        branch_decision_reg = 1'b1;
                    end
                    // ... other branch conditions
                end
                default: begin
                    alu_result_reg = 32'b0;
                    branch_decision_reg = 1'b0;
                end
            endcase
        end
    end

    // Outputs
    assign alu_result_o = alu_result_reg;
    assign branch_decision_o = branch_decision_reg;
    assign rd_o = rd_addr;
    assign instruction_info_o = issue_instr_i;
    assign alu_valid_o = alu_valid_reg;
endmodule