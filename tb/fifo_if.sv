//creating interfaces that we can later utilise
interface fifo_if #(parameter int DATA_WIDTH = 8);
logic clk;
logic reset;
logic wr_en;
logic rd_en;
logic [DATA_WIDTH-1:0] data_in;
logic [DATA_WIDTH-1:0] data_out;
logic full;
logic empty;

modport dut (
	input clk, reset, wr_en, rd_en, data_in,
	output full, empty, data_out
);

modport tb(
	input clk, reset, full, empty, data_out,
	output data_in, wr_en, rd_en
);
endinterface
