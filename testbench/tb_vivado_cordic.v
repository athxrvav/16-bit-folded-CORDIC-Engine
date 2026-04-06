`timescale 1ns / 1ps
`default_nettype none

module tb_vivado_cordic;

    // --- Inputs ---
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    reg       ena;
    reg       clk;
    reg       rst_n;

    // --- Outputs ---
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // --- Instantiate the Device Under Test (DUT) ---
    tt_um_cordic_engine uut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    // --- Clock Generation (10 MHz) ---
    always #50 clk = ~clk;

    // --- Reusable Task: Send Angle & Read Result ---
    // Note: expected_sin and expected_cos are now integers to allow negative numbers
    task test_angle;
        input [15:0] angle;
        input integer expected_sin; 
        input integer expected_cos;
        input [80*8:1] test_name; // Large string buffer
        begin
            $display("--------------------------------------------------");
            $display("Test: %s", test_name);
            $display("Input HEX: 16'h%04h", angle);
            
            // Cycle 1: Send MSB and assert Start pulse
            @(negedge clk);
            ui_in = angle[15:8];
            uio_in[0] = 1'b1; 

            // Cycle 2: Send LSB and clear Start pulse
            @(negedge clk);
            ui_in = angle[7:0];
            uio_in[0] = 1'b0;

            // Wait deterministically for the 16 iterations to finish
            repeat(25) @(negedge clk);

            // Read Sine Output (Default out_sel = 0)
            uio_in[1] = 1'b0;
            @(negedge clk);
            // $signed() forces Vivado to display the 8-bit wire as a negative number if the MSB is 1
            $display("Sine   : %0d \t| Expected: ~%0d", $signed(uo_out), expected_sin);

            // Toggle Multiplexer to Read Cosine (out_sel = 1)
            uio_in[1] = 1'b1;
            repeat(2) @(negedge clk); // Allow propagation delay
            $display("Cosine : %0d \t| Expected: ~%0d", $signed(uo_out), expected_cos);
            
            // Clear out_sel to reset for the next test
            uio_in[1] = 1'b0;
            repeat(5) @(negedge clk);
        end
    endtask

    // --- Main Simulation Sequence ---
    initial begin
        // 1. Initialize Inputs
        ui_in  = 8'd0;
        uio_in = 8'd0;
        ena    = 1'b1;
        clk    = 1'b0;
        rst_n  = 1'b0;

        // 2. Apply Deep Reset
        repeat(10) @(posedge clk);
        rst_n = 1'b1;
        repeat(10) @(posedge clk);

        $display("\n==================================================");
        $display("   STARTING VIVADO CORDIC VERIFICATION ENGINE     ");
        $display("==================================================\n");

        // -----------------------------------------------------------
        // 10 MATHEMATICALLY VERIFIED TEST VECTORS (Bounded +/- 57 deg)
        // -----------------------------------------------------------

        // Test 1: 0 Degrees
        // Note: Cosine is 1.0. In Q1.7, 1.0 = +128. But +128 overflows an 8-bit signed integer to -128.
        test_angle(16'h0000, 0, -128, "0 Degrees (Center)");

        // Test 2: +10 Degrees
        test_angle(16'h1657, 22, 126, "+10 Degrees");

        // Test 3: +20 Degrees
        test_angle(16'h2CB6, 44, 120, "+20 Degrees");

        // Test 4: +30 Degrees
        test_angle(16'h4305, 64, 111, "+30 Degrees");

        // Test 5: +45 Degrees
        test_angle(16'h6487, 90, 90, "+45 Degrees");

        // Test 6: +55 Degrees (Near the positive Q1.15 limit)
        test_angle(16'h7ADD, 105, 73, "+55 Degrees (Upper Bound limit)");

        // Test 7: -10 Degrees
        test_angle(16'hE9A9, -22, 126, "-10 Degrees");

        // Test 8: -20 Degrees
        test_angle(16'hD352, -44, 120, "-20 Degrees");

        // Test 9: -30 Degrees
        test_angle(16'hBCFB, -64, 111, "-30 Degrees");

        // Test 10: -45 Degrees
        test_angle(16'h9B78, -90, 90, "-45 Degrees");

        $display("--------------------------------------------------");
        $display("\n==================================================");
        $display("               SIMULATION COMPLETE                  ");
        $display("==================================================\n");
        
        $finish; 
    end

endmodule
