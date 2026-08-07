class monitor #(parameter int DATA_WIDTH = 8);
//monitor doesn't push values in the dut, just observes them and sends it to the scoreboard for evaluation
transaction_object #(DATA_WIDTH) trans;
mailbox #(transaction_object #(DATA_WIDTH)) mbx;
virtual fifo_if.tb sf;

function new (mailbox #(transaction_object #(DATA_WIDTH)) mbx, virtual fifo_if.tb sf);
	this.mbx = mbx;
	this.sf = sf;
endfunction

task fetch();
	forever begin
		trans = new();
		@(posedge sf.clk);
		#1;
		trans.rd_en = sf.rd_en; //notice how we are not using the non-blocking assignment
		trans.wr_en = sf.wr_en;
		trans.data_in = sf.data_in;
		
		trans.data_out = sf.data_out;
		trans.full = sf.full;
		trans.empty = sf.empty;

		mbx.put(trans);

		$display("[MONITOR]: data in: %d | data out: %d | full: %d | empty: %d ", trans.data_in, trans.data_out, trans.full, trans.empty);
	end	
endtask
endclass