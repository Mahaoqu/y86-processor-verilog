// ----------------------------------------------------
// module RAM 
// A dual-port of memory, with 512K words
// Use 16 ram banks to make memory structure
// ----------------------------------------------------
module ram(clock, addrA, wEnA, wDatA, rEnA, rDatA,
            addrB, wEnB, wDatB, rEnB, rDatB);

    parameter wordsize = 8; // Number of bits per word
    parameter wordcount = 512; // Number of words in memory

    parameter addrsize = 9;

    input clock;
    //Port A
    input [addrsize-1:0] addrA;     // Read/Write Address
    input wEnA;                     // Write Enable
    input [wordsize-1:0] wDatA;     // Write Data
    input rEnA;                     // Read Enable
    output reg [wordsize-1:0] rDatA;// Read Data

    //Port B
    input [addrsize-1:0] addrB;     // Read/Write Address
    input wEnB;                     // Write Enable
    input [wordsize-1:0] wDatB;     // Write Data
    input rEnB;                     // Read Enable
    output reg [wordsize-1:0] rDatB;// Read Data

    reg [wordsize-1:0] mem[wordcount-1:0]; // Storage

    always @(negedge clock)
    begin
    if (wEnA) 
        mem[addrA] <= wDatA;
    if (rEnA)
        rDatA <= mem[addrA];
    end

    always @(negedge clock)
    begin
    if (wEnB) 
        mem[addrB] <= wDatB;
    if (rEnB)
        rDatB <= mem[addrB];
    end

endmodule // ram

module bmemory(
    
);

endmodule // bmemory