// The mode input specifies what the processer should be doing.The possible are:
// RUN: Execute instructions in the normal manner.
// RESET:    All registers are set to their initial values, clearing the pipline registers
//           and setting the program counter to 0;
// DOWNLOAD: The processer memory can be loaded using the udarrd address input and the 
//           idata data input to specity addresses and values. By this means, we can
//           load an program into the processer.
// UPLOAD:   Data can be extracted from the processor memory, using the address input uaddr
//           to specify an address and the odata output to provide the data stored at that 
//           address.
// STATUS:   Similar to UPLOAD mode, except that the values of the program registers, and
//           the conditions codes have associated addressed for this operation.

module processor(mode, udaddr, idata, odata, stat, clock);
    input   [ 2:0] mode;
    input   [63:0] udaddr;
    input   [63:0] idata;
    output  [ 2:0] stat;
    input          clock; 

// Define modes
    parameter RUN_MODE = 0;
    parameter RESET_MODE = 1;
    parameter DOWNLOAD_MODE = 2;
    parameter UPLOAD_MODE = 3;
    parameter STATUS_MODE = 4;

// Instruction codes
    parameter     IHALT      =     4'H0;
    parameter     INOP       =     4'H1;
    parameter     IRRMOVL    =     4'H2;
    parameter     IIRMOVL    =     4'H3;
    parameter     IRMMOVL    =     4'H4;
    parameter     IMRMOVL    =     4'H5;
    parameter     IOPL       =     4'H6;
    parameter     IJXX       =     4'H7;
    parameter     ICALL      =     4'H8;
    parameter     IRET       =     4'H9;
    parameter     IPUSHL     =     4'HA;
    parameter     IPOPL      =     4'HB;
    parameter     IIADDQ     =     4'HC;
    parameter     ILEAVE     =     4'HD;
    parameter     IPOP2      =     4'HE;

// Function codes
    parameter     FNONE      =     4'H0;

// Jump conditions
    parameter     UNCOND     =     4'H0;

// Register IDs
    parameter     RRSP       =     4'H4; 
    parameter     RRBP       =     4'H5;
    parameter     RNONE      =     4'HF;

// ALU operations
    parameter     ALUADD     =     4'H0;

// Status conditions
    parameter     SBUB       =     3'H0;
    parameter     SAOK       =     3'H1;
    parameter     SHLT       =     3'H2;
    parameter     SADR       =     3'H3;
    parameter     SINS       =     3'H4;
    parameter     SPIP       =     3'H5;

// Fetch stage singals
    wire [63:0] f_predPC, F_predPC, f_pc;
    wire        f_ok;
    wire        imem_error;
    wire [ 2:0] f_stat;
    wire [79:0] f_instr;
    wire [ 3:0] imem_icode;
    wire [ 3:0] imem_ifun;
    wire [ 3:0] f_icode;
    wire [ 3:0] f_ifun;
    wire [ 3:0] f_rA;
    wire [ 3:0] f_rB;
    wire [63:0] f_valC;
    wire [63:0] f_valP;
    wire        need_digits;
    wire        need_valC;
    wire        instr_vaild;
    wire        F_stall, F_bubble;

// Decode stage singnals
    wire [ 2:0] D_stat;
    wire [63:0] D_pc;
    wire [ 3:0] D_icode;
    wire [ 3:0] D_ifun;
    wire [ 3:0] D_rA;
    wire [ 3:0] D_rB;
    wire [63:0] D_valC;
    wire [63:0] D_valP;

    wire [63:0] d_valA;
    wire [63:0] d_valB;
    wire [63:0] d_rvalA;
    wire [63:0] d_rvalB;
    wire [ 3:0] d_dstE;
    wire [ 3:0] d_dstM;
    wire [ 3:0] d_srcA;
    wire [ 3:0] d_srcB;
    wire        D_stall, D_bubble;

// Execute stage singals
    wire [ 2:0] E_stat;
    wire [63:0] E_pc;
    wire [ 3:0] E_icode;
    wire [ 3:0] E_ifun;
    wire [63:0] E_valC;
    wire [63:0] E_valA;
    wire [63:0] E_valB;
    wire [ 3:0] E_dstE;
    wire [ 3:0] E_dstM;
    wire [ 3:0] E_srcA;
    wire [ 3:0] E_srcB;

    wire [63:0] aluA;
    wire [63:0] aluB;
    wire        set_cc;
    wire [ 2:0] cc;
    wire [ 2:0] new_cc;
    wire [ 3:0] alufun;
    wire        e_Cnd;
    wire [63:0] e_valE;
    wire [63:0] e_valA;
    wire [ 3:0] e_dstE;
    wire        E_stall, E_bubble;

// Memory Stage
    wire [ 2:0] M_stat;
    wire [63:0] M_pc;
    wire [ 3:0] M_icode;
    wire [ 3:0] M_ifun;
    wire        M_Cnd;
    wire [63:0] M_valE;
    wire [63:0] M_valA;
    wire [ 3:0] M_dstE;
    wire [ 3:0] M_dstM;

    wire [ 2:0] m_stat;
    wire [63:0] mem_addr;
    wire [63:0] mem_data;
    wire        mem_read;
    wire        mem_write;
    wire [63:0] m_valM;
    wire        M_stall, M_bubble;
    wire        m_ok;

// Write-back stage
    wire [ 2:0] W_stat;
    wire [63:0] W_pc;
    wire [ 3:0] W_icode;
    wire [63:0] W_valE;
    wire [63:0] W_valM;
    wire [ 3:0] W_dstE;
    wire [ 3:0] W_dstM;
    wire [63:0] w_valE;
    wire [63:0] w_valM;
    wire [ 3:0] w_dstE;
    wire [ 3:0] w_dstM;

    wire        W_stall, W_bubble;

// Global status
    wire [ 2:0] Stat;

// Debugging logic
    wire [63:0] rax, rcx, rdx, rbx, rsp, rbp, rdi, rsi,
                r8, r9, r10, r11, r12, r13, r14;
    wire zf = cc[2];
    wire sf = cc[1];
    wire of = cc[0];

// Controls singnals
    wire resetting = (mode == RESET_MODE);
    wire uploading = (mode == UPLOAD_MODE);
    wire downloading = (mode == DOWNLOAD_MODE);
    wire running = (mode == RUN_MODE);
    wire getting_info = (mode == STATUS_MODE);

// Logic to control resetting of pipeline registers
    wire F_reset = F_bubble | resetting;
    wire D_reset = D_bubble | resetting;
    wire E_reset = E_bubble | resetting;
    wire M_reset = M_bubble | resetting;
    wire W_reset = W_bubble | resetting;

// Processor status
    assign stat = Stat;
// Output data
    assign odata = 
            getting_info ?
            (uaddr ==  0 ? rax :
             uaddr ==  8 ? rcx :
             uaddr == 16 ? rdx :
             uaddr == 24 ? rbx :
             uaddr == 32 ? rsp :
             uaddr == 40 ? rbp :
             uaddr == 48 ? rsi :
             uaddr == 56 ? rdi :
             uaddr == 64 ? r8  :
             uaddr == 72 ? r9  :
             uaddr == 80 ? r10 :
             uaddr == 88 ? r11 :
             uaddr == 96 ? r12 :
             uaddr ==104 ? r13 :
             uaddr ==112 ? r14 :
             uaddr ==120 ? rcc :
             uaddr ==128 ? W_pc: 0)
             : m_valM;

// Pipeline registers
// All pipeline registers are implemented with module
//  preg(out, in, stall, bubbleval, clock)

// F Register
    preg #(64) F_predPC_reg  (F_predPC, f_predPC, F_stall, F_reset, 64'h0, clock);
// D Register
    preg #(3)  D_stat_reg    (D_stat  , f_stat  , D_stall, D_reset, SBUB , clock);
    preg #(64) D_pc_reg      (D_pc    , f_pc    , D_stall, D_reset, 64'b0, clock);
    preg #(4)  D_icode_reg   (D_icode , f_icode , D_stall, D_reset, INOP , clock);
    preg #(4)  D_ifun_reg    (D_ifun  , f_ifun  , D_stall, D_reset, FNONE, clock);
    preg #(4)  D_rA_reg      (D_rA    , f_rA    , D_stall, D_reset, RNONE, clock);
    preg #(4)  D_rB_reg      (D_rB    , f_rB    , D_stall, D_reset, RNONE, clock);
    preg #(64) D_valC_reg    (D_valC  , f_valC  , D_stall, D_reset, 64'b0, clock);
    preg #(64) D_valP_reg    (D_valP  , f_valP  , D_stall, D_reset, 64'b0, clock);
// E Register
    preg #(3)  E_stat_reg    (E_stat  , D_stat  , E_stall, E_reset, SBUB , clock);
    preg #(64) E_pc_reg      (E_pc    , D_pc    , E_stall, E_reset, 64'b0, clock);
    preg #(4)  E_icode_reg   (E_icode , D_icode , E_stall, E_reset, INOP , clock);
    preg #(4)  E_ifun_reg    (E_ifun  , D_ifun  , E_stall, E_reset, FNONE, clock);
    preg #(64) E_valC_reg    (E_valC  , D_valC  , E_stall, E_reset, 64'b0, clock);
    preg #(64) E_valA_reg    (E_valA  , d_valA  , E_stall, E_reset, 64'b0, clock);
    preg #(64) E_valB_reg    (E_valB  , d_valB  , E_stall, E_reset, 64'b0, clock);
    preg #(4)  E_dstE_reg    (E_dstE  , d_dstE  , E_stall, E_reset, RNONE, clock);
    preg #(4)  E_dstM_reg    (E_dstM  , d_dstM  , E_stall, E_reset, RNONE, clock);
    preg #(4)  E_srcA_reg    (E_srcA  , d_srcA  , E_stall, E_reset, RNONE, clock);
    preg #(4)  E_srcB_reg    (E_srcB  , d_srcB  , E_stall, E_reset, RNONE, clock);
// M Register
    preg #(3)  M_stat_reg    (M_stat  , E_stat  , M_stall, M_reset, SBUB , clock);
    preg #(64) M_pc_reg      (M_pc    , E_pc    , M_stall, M_reset, 64'b0, clock);
    preg #(4)  M_icode_reg   (M_icode , E_icode , M_stall, M_reset, INOP , clock);
    preg #(4)  M_ifun_reg    (M_ifun  , E_ifun  , M_stall, M_reset, FNONE, clock);
    preg #(1)  M_Cnd_reg     (M_Cnd   , e_Cnd   , M_stall, M_reset, 1'b0 , clock);
    preg #(64) M_valE_reg    (M_valE  , e_valE  , M_stall, M_reset, 64'b0, clock);
    preg #(64) M_valA_reg    (M_valA  , e_valA  , M_stall, M_reset, 64'b0, clock);
    preg #(4)  M_dstE_reg    (M_dstE  , e_dstE  , M_stall, M_reset, RNONE, clock);
    preg #(4)  M_dstM_reg    (M_dstM  , E_dstM  , M_stall, M_reset, RNONE, clock);
// W Register
    preg #(3)  W_stat_reg    (W_stat  , m_stat  , W_stall, W_reset, SBUB , clock);
    preg #(64) W_pc_reg      (W_pc    , M_pc    , W_stall, W_reset, 64'b0, clock);
    preg #(4)  W_icode_reg   (W_icode , M_icode , W_stall, W_reset, INOP , clock);
    preg #(64) W_valE_reg    (W_valE  , M_valE  , W_stall, W_reset, 64'b0, clock);
    preg #(64) W_valM_reg    (W_valM  , m_valM  , W_stall, W_reset, 64'b0, clock);
    preg #(4)  W_dstE_reg    (W_dstE  , M_dstE  , W_stall, W_reset, RNONE, clock);
    preg #(4)  W_dstM_reg    (W_dstM  , M_dstM  , W_stall, W_reset, RNONE, clock);

// Fetch stage Logic
    spilt spilt(f_instr[7:0], imem_icode, imem_ifun);
    align align(f_instr[79:8], need_digits, f_rA, f_rB, f_valC);
    pc_increment pci(f_pc, need_digits, need_valC, f_valP);

// Decode stage 
    regfile regf(w_dstE, w_valE, w_dstM, w_valM,
                 d_srcA, d_rvalA, d_srcB, d_rvalB, resetting, clock,
                 rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi,
                 r8, r9, r10, r11, r12, r13, r14);

// Execute stage
    alu alu(aluA, aluB, alufun, e_valE, new_cc);
    cc ccreg(cc, new_cc, running & set_cc, resetting, clock); 
    // Only update CC when everything is runnning nomally
    cond cond_check(E_ifun, cc, e_Cnd);

// Memory stage
    //TODO:

    assign imem_error = ~f_ok;

// Write-back stage 

// Control Logic

// -------------------
// Generated by hcl2v
// -------------------
    assign f_pc = 
        (((M_icode == IJXX) & ~M_Cnd) ? M_valA : (W_icode == IRET) ? W_valM : 
        F_predPC);

    assign f_icode = 
        (imem_error ? INOP : imem_icode);

    assign f_ifun = 
        (imem_error ? FNONE : imem_ifun);

    assign instr_valid = 
        (f_icode == INOP | f_icode == IHALT | f_icode == IRRMOVQ | f_icode == 
        IIRMOVQ | f_icode == IRMMOVQ | f_icode == IMRMOVQ | f_icode == IOPQ
        | f_icode == IJXX | f_icode == ICALL | f_icode == IRET | f_icode == 
        IPUSHQ | f_icode == IPOPQ);

    assign f_stat = 
        (imem_error ? SADR : ~instr_valid ? SINS : (f_icode == IHALT) ? SHLT : 
        SAOK);

    assign need_regids = 
        (f_icode == IRRMOVQ | f_icode == IOPQ | f_icode == IPUSHQ | f_icode == 
        IPOPQ | f_icode == IIRMOVQ | f_icode == IRMMOVQ | f_icode == IMRMOVQ)
        ;

    assign need_valC = 
        (f_icode == IIRMOVQ | f_icode == IRMMOVQ | f_icode == IMRMOVQ | f_icode
        == IJXX | f_icode == ICALL);

    assign f_predPC = 
        ((f_icode == IJXX | f_icode == ICALL) ? f_valC : f_valP);

    assign d_srcA = 
        ((D_icode == IRRMOVQ | D_icode == IRMMOVQ | D_icode == IOPQ | D_icode
            == IPUSHQ) ? D_rA : (D_icode == IPOPQ | D_icode == IRET) ? RRSP : 
        RNONE);

    assign d_srcB = 
        ((D_icode == IOPQ | D_icode == IRMMOVQ | D_icode == IMRMOVQ) ? D_rB : (
            D_icode == IPUSHQ | D_icode == IPOPQ | D_icode == ICALL | D_icode
            == IRET) ? RRSP : RNONE);

    assign d_dstE = 
        ((D_icode == IRRMOVQ | D_icode == IIRMOVQ | D_icode == IOPQ) ? D_rB : (
            D_icode == IPUSHQ | D_icode == IPOPQ | D_icode == ICALL | D_icode
            == IRET) ? RRSP : RNONE);

    assign d_dstM = 
        ((D_icode == IMRMOVQ | D_icode == IPOPQ) ? D_rA : RNONE);

    assign d_valA = 
        ((D_icode == ICALL | D_icode == IJXX) ? D_valP : (d_srcA == e_dstE) ? 
        e_valE : (d_srcA == M_dstM) ? m_valM : (d_srcA == M_dstE) ? M_valE : 
        (d_srcA == W_dstM) ? W_valM : (d_srcA == W_dstE) ? W_valE : d_rvalA);

    assign d_valB = 
        ((d_srcB == e_dstE) ? e_valE : (d_srcB == M_dstM) ? m_valM : (d_srcB
            == M_dstE) ? M_valE : (d_srcB == W_dstM) ? W_valM : (d_srcB == 
            W_dstE) ? W_valE : d_rvalB);

    assign aluA = 
        ((E_icode == IRRMOVQ | E_icode == IOPQ) ? E_valA : (E_icode == IIRMOVQ
            | E_icode == IRMMOVQ | E_icode == IMRMOVQ) ? E_valC : (E_icode == 
            ICALL | E_icode == IPUSHQ) ? -8 : (E_icode == IRET | E_icode == IPOPQ
            ) ? 8 : 0);

    assign aluB = 
        ((E_icode == IRMMOVQ | E_icode == IMRMOVQ | E_icode == IOPQ | E_icode
            == ICALL | E_icode == IPUSHQ | E_icode == IRET | E_icode == IPOPQ)
        ? E_valB : (E_icode == IRRMOVQ | E_icode == IIRMOVQ) ? 0 : 0);

    assign alufun = 
        ((E_icode == IOPQ) ? E_ifun : ALUADD);

    assign set_cc = 
        (((E_icode == IOPQ) & ~(m_stat == SADR | m_stat == SINS | m_stat == 
            SHLT)) & ~(W_stat == SADR | W_stat == SINS | W_stat == SHLT));

    assign e_valA = 
        E_valA;

    assign e_dstE = 
        (((E_icode == IRRMOVQ) & ~e_Cnd) ? RNONE : E_dstE);

    assign mem_addr = 
        ((M_icode == IRMMOVQ | M_icode == IPUSHQ | M_icode == ICALL | M_icode
            == IMRMOVQ) ? M_valE : (M_icode == IPOPQ | M_icode == IRET) ? 
        M_valA : 0);

    assign mem_read = 
        (M_icode == IMRMOVQ | M_icode == IPOPQ | M_icode == IRET);

    assign mem_write = 
        (M_icode == IRMMOVQ | M_icode == IPUSHQ | M_icode == ICALL);

    assign m_stat = 
        (dmem_error ? SADR : M_stat);

    assign w_dstE = 
        W_dstE;

    assign w_valE = 
        W_valE;

    assign w_dstM = 
        W_dstM;

    assign w_valM = 
        W_valM;

    assign Stat = 
        ((W_stat == SBUB) ? SAOK : W_stat);

    assign F_bubble = 
        0;

    assign F_stall = 
        (((E_icode == IMRMOVQ | E_icode == IPOPQ) & (E_dstM == d_srcA | E_dstM
            == d_srcB)) | (IRET == D_icode | IRET == E_icode | IRET == 
            M_icode));

    assign D_stall = 
        ((E_icode == IMRMOVQ | E_icode == IPOPQ) & (E_dstM == d_srcA | E_dstM
            == d_srcB));

    assign D_bubble = 
        (((E_icode == IJXX) & ~e_Cnd) | (~((E_icode == IMRMOVQ | E_icode == 
                IPOPQ) & (E_dstM == d_srcA | E_dstM == d_srcB)) & (IRET == 
            D_icode | IRET == E_icode | IRET == M_icode)));

    assign E_stall = 
        0;

    assign E_bubble = 
        (((E_icode == IJXX) & ~e_Cnd) | ((E_icode == IMRMOVQ | E_icode == IPOPQ
            ) & (E_dstM == d_srcA | E_dstM == d_srcB)));

    assign M_stall = 
        0;

    assign M_bubble = 
        ((m_stat == SADR | m_stat == SINS | m_stat == SHLT) | (W_stat == SADR
            | W_stat == SINS | W_stat == SHLT));

    assign W_stall = 
        (W_stat == SADR | W_stat == SINS | W_stat == SHLT);

    assign W_bubble = 
        0;

// ------------------------------
// End of code generated by hcl2v
// ------------------------------

endmodule