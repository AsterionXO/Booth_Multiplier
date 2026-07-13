`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.04.2026 17:13:40
// Design Name: 
// Module Name: bm
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bm #(parameter N = 8)
    (
    input wire signed[N-1:0] multiplier,multiplicand,
    input wire clk,rst,start,
    output reg [2*N-1:0] prod,
    output reg [$clog2(N):0] co,
    output reg done
    );
    reg [N:0] A; //Accumulator
    reg q;       //Q[-1]
    reg [N-1:0] Q; //Multiplier
    reg [N-1:0] M; //Multiplicand
    reg [$clog2(N):0] c; //Count
    reg [1:0] state;
    
    parameter idle = 2'b00;
    parameter calc = 2'b01;
    parameter shift = 2'b10;
    
    always@(posedge clk) begin
    if (rst) begin //reset condition
    A <= 0;
    Q <= 0;
    M <= 0;
    q <= 0;
    c <= 0;
    co <= 0;
    prod <= 0;
    done <= 0;
    state <= idle;
    end
    else begin
    case (state)
        idle:      
        begin
            if (start) 
            begin
                A <= 0;             //initialise values
                Q <= multiplier;
                M <= multiplicand;
                q <= 0;
                done <= 0;
                c <= N-1;
                state <= calc;
            end
        end
        calc:
        begin
            case ({Q[0],q})        //cperation part
                2'b10:A <= A-{{1{M[N-1]}}, M};
                2'b01:A <= A+{{1{M[N-1]}}, M};
                default:A <= A; 
            endcase 
            state <= shift; 
        end
        shift:
        begin
            q <= Q[0];             //arithmetic right shift
            Q <= {A[0],Q[N-1:1]};
            A <= {A[N], A[N:1]};
            co <= c;
            c <= c-1;
            if (c == 0)
            begin
                prod <= {A[N], A[N:1], A[0], Q[N-1:1]};
                done <= 1;
                state <= idle;
            end
            else state <= calc;
        end
    endcase
    end
    end
    
endmodule
