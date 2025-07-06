module I_Decode (
    input wire clk,
    input wire rst_n,

    // Inputs from Fetch stage
    input wire [31:0] instr1_i,
    input wire [31:0] instr2_i,
    input wire [31:0] pc1_i,
    input wire [31:0] pc2_i,
    input wire fetch_valid_i,

    // Stall and Flush signals
    input wire stall_i,
    input wire flush_i,

    // Outputs to FIFO Queue
    output wire [63:0] decoded_instr1_o, // (bundled info)
    output wire [63:0] decoded_instr2_o, // (bundled info)
    output wire decoded_valid1_o,
    output wire decoded_valid2_o,

    output wire stall_o // For backpressure to Fetch if decode is stalled.
);

    // Internal Components
    // Instruction Field Extractors - CHANGED FROM wire TO reg
    reg [6:0] opcode1, opcode2;
    reg [2:0] funct3_1, funct3_2;
    reg [6:0] funct7_1, funct7_2;
    reg [4:0] rd1, rd2, rs1_1, rs1_2, rs2_1, rs2_2;
    reg [31:0] immediate1, immediate2;

    // Control Unit signals - CHANGED FROM wire TO reg
    reg mem_read1, mem_write1, branch1, reg_write1;
    reg mem_read2, mem_write2, branch2, reg_write2;
    // ... other control signals

    // Dependency Checker (optional)

    reg [63:0] decoded_instr1_reg;
    reg [63:0] decoded_instr2_reg;
    reg decoded_valid1_reg;
    reg decoded_valid2_reg;


    // Combinational Logic for decoding
    always @(*) begin
        // For Instr1
        opcode1 = instr1_i[6:0];
        funct3_1 = instr1_i[14:12];
        funct7_1 = instr1_i[31:25];
        rd1 = instr1_i[11:7];
        rs1_1 = instr1_i[19:15];
        rs2_1 = instr1_i[24:20];

        // Immediate generation (simplified example, needs full R/I/S/B/U/J logic)
        immediate1 = {{20{instr1_i[31]}}, instr1_i[31:20]}; // Example for I-type (placeholder)

        // Control Unit (simplified, usually a large case statement)
        case (opcode1)
            7'b0110011: begin // R-type
                mem_read1 = 1'b0; mem_write1 = 1'b0; branch1 = 1'b0; reg_write1 = 1'b1;
            end
            7'b0000011: begin // Load (I-type)
                mem_read1 = 1'b1; mem_write1 = 1'b0; branch1 = 1'b0; reg_write1 = 1'b1;
            end
            // ... add cases for other instruction types
            default: begin
                mem_read1 = 1'b0; mem_write1 = 1'b0; branch1 = 1'b0; reg_write1 = 1'b0;
            end
        endcase

        // For Instr2 (similar logic, duplicated)
        opcode2 = instr2_i[6:0];
        funct3_2 = instr2_i[14:12];
        funct7_2 = instr2_i[31:25];
        rd2 = instr2_i[11:7];
        rs1_2 = instr2_i[19:15];
        rs2_2 = instr2_i[24:20];
        immediate2 = {{20{instr2_i[31]}}, instr2_i[31:20]}; // Placeholder

        case (opcode2)
            7'b0110011: begin
                mem_read2 = 1'b0; mem_write2 = 1'b0; branch2 = 1'b0; reg_write2 = 1'b1;
            end
            7'b0000011: begin
                mem_read2 = 1'b1; mem_write2 = 1'b0; branch2 = 1'b0; reg_write2 = 1'b1;
            end
            default: begin
                mem_read2 = 1'b0; mem_write2 = 1'b0; branch2 = 1'b0; reg_write2 = 1'b0;
            end
        endcase

        // Bundle information for Instr1
        decoded_instr1_reg = {
            pc1_i,
            opcode1, funct3_1, funct7_1, // Control fields
            rd1, rs1_1, rs2_1,           // Register addresses
            immediate1,                  // Immediate value
            // ... other control signals (encode into bits)
            mem_read1, mem_write1, branch1, reg_write1
        };

        // Bundle information for Instr2
        decoded_instr2_reg = {
            pc2_i,
            opcode2, funct3_2, funct7_2,
            rd2, rs1_2, rs2_2,
            immediate2,
            mem_read2, mem_write2, branch2, reg_write2
        };

        // Determine validity
        decoded_valid1_reg = fetch_valid_i && !flush_i;
        decoded_valid2_reg = fetch_valid_i && !flush_i; // Basic validity
        // Add logic for illegal instructions or RAW between instr1/instr2
        // For RAW: if (decoded_valid1_reg && decoded_valid2_reg && (rs1_2 == rd1 || rs2_2 == rd1)) decoded_valid2_reg = 1'b0; // Simple stall/drop
    end

    // Outputs
    assign decoded_instr1_o = decoded_instr1_reg;
    assign decoded_instr2_o = decoded_instr2_reg;
    assign decoded_valid1_o = decoded_valid1_reg;
    assign decoded_valid2_o = decoded_valid2_reg;
    assign stall_o = stall_i; // Propagate stall upstream if decode cannot accept more.
endmodule