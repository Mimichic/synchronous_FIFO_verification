module top_testbench #(parameter int DATA_WIDTH = 8);
logic clk;
logic rst;

//clock generation
initial begin
	clk = 0;
	forever
		#5 clk = ~clk; 
end

fifo_if #(DATA_WIDTH) phy_if(); //actual physical interface is instatiated here

synchronous_FIFO #(DATA_WIDTH, 16) dut (
	.clk(phy_if.clk), 
	.rst(phy_if.reset),
	.rd_en(phy_if.rd_en),
	.wr_en(phy_if.wr_en),
	.data_in(phy_if.data_in),
	.data_out(phy_if.data_out),
	.full(phy_if.full),
	.empty(phy_if.empty)
	);

assign phy_if.clk = clk;
assign phy_if.reset = rst;

environment #(DATA_WIDTH) env;

initial begin
	rst = 1; #20; rst = 0;
	//let the environment do the heavy lifitng now 
	env = new(phy_if.tb);
	env.build_all();
	env.gen.total_tests = 50;
	env.run_all();
	#10000;
	$display("whoo! we made our first ever advanced testbench!");
	$finish;
end


endmodule