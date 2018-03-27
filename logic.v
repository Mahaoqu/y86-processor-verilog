// Logic modules in Fetch stage and Execute stage
//
// Split instruction byte into icode and ifun fields
module split(ibyte, icode, ifun);
    input  [7:0] ibyte;
    output [3:0] icode;
    output [3:0] ifun;
    assign       icode = ibyte[7:4];
    assign       ifun  = ibyte[3:0];
endmodule
// Extract immediate word from 9 bytes of instruction
module align(ibytes, need_regids, rA, rB, valC);
    input  [71:0] ibytes;
    input         need_regids;
    output [ 3:0] rA;
    output [ 3:0] rB;
    output [63:0] valC;
    assign rA = ibytes[7:4];
    assign rB = ibytes[3:0];
    assign valC = need_regids ? ibytes[71:8] : ibytes[63:0];
endmodule
// PC incrementer
module pc_increment(pc, need_regids, need_valC, valP);
    input  [63:0] pc;
    input         need_regids;
    input         need_valC;
    output [63:0] valP;
    assign        valP = pc + 1 + 8 * need_valC + need_regids;
endmodule

module alu(aluA, aluB, alufun, valE, new_cc);
    input  [63:0] aluA, aluB;
    input  [ 3:0] alufun;
    output [63:0] valE;
    output [ 2:0] new_cc;

    parameter ALUADD = 4’h0;
    parameter ALUSUB = 4’h1;
    parameter ALUAND = 4’h2;
    parameter ALUXOR = 4’h3;
    assign valE =
        alufun == ALUSUB ? aluB - aluA :
        alufun == ALUAND ? aluB & aluA :
        alufun == ALUXOR ? aluB ˆ aluA :
        aluB + aluA;
    assign new_cc[2] = (valE == 0);  // ZF
    assign new_cc[1] = valE[63];     // SF
    assign new_cc[0] =               // OF
        alufun == ALUADD ?
            (aluA[63] == aluB[63])  & (aluA[63] != valE[63]) :
        alufun == ALUSUB ?
            ( ̃aluA[63] == aluB[63]) & (aluB[63] != valE[63]) :
        0;
endmodule
