`timescale 1ns / 1ps

module bm_ttb_self();
parameter N = 8;

reg signed [N-1:0] q, m;
reg st, clk, rst;
wire signed [2*N-1:0] prod;
wire [$clog2(N):0] co;
wire done;

integer pass_count, fail_count;
reg signed [2*N-1:0] expected;
integer i;
reg signed [N-1:0] rand_a, rand_b;

bm uut(
    .multiplicand(m),
    .multiplier(q),
    .clk(clk),
    .rst(rst),
    .start(st),
    .prod(prod),
    .co(co),
    .done(done)
);

initial clk = 0;
always #5 clk = ~clk;

task apply_and_check;
    input signed [N-1:0] a, b;
    begin
        // reset cleanly
        rst = 1; st = 0;
        #30 rst = 0;
        q = a; m = b;
        #10 st = 1;
        #10 st = 0;

        // wait for done instead of fixed delay
        @(posedge done);
        #1; // tiny settling margin

        expected = a * b;
        if (prod === expected) begin
            $display("PASS: %0d x %0d = %0d", a, b, prod);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: %0d x %0d expected %0d, got %0d", a, b, expected, prod);
            fail_count = fail_count + 1;
        end

        #20; // gap between tests
    end
endtask

initial begin
    pass_count = 0;
    fail_count = 0;

    rst = 1; q = 0; m = 0; st = 0;
    #30 rst = 0;
    
    apply_and_check(6,    3);
    apply_and_check(0,    5);
    apply_and_check(1,   -1);
    apply_and_check(-6,   3);
    apply_and_check(6,   -3);
    apply_and_check(-6,  -3);
    apply_and_check(7,    7);
    apply_and_check(-8,  -8);
    apply_and_check(-8,   7);
    apply_and_check(127, 127);
    apply_and_check(-1,  -1);
    apply_and_check(0,    0);
    apply_and_check(-8,   1);
    apply_and_check(1,    1);

    for (i = 0; i < 1000; i = i + 1) begin
    rand_a = $random;
    rand_b = $random;
    apply_and_check(rand_a, rand_b);
    end

    $display("-----------------------------");
    $display("RESULTS: %0d passed, %0d failed", pass_count, fail_count);
    $display("-----------------------------");

    $finish;
end

endmodule