class driver #(parameter int DATA_WIDTH = 8);

//driver acts as a medium between our driver and the DUT, so we will access the tb modport here
transaction_object #(DATA_WIDTH) trans;
mailbox #(transaction_object #(DATA_WIDTH)) mbx;
virtual fifo_if.tb sf; //we use virtual object here because we cannot connect a physical interface here

//new construct again
function new (mailbox #(transaction_object #(DATA_WIDTH)) mbx, virtual fifo_if.tb sf);
	this.mbx = mbx;
	this.sf = sf;
endfunction

//task to perform the work of connecting the inputs by the generator to the actual hardware
task run();
	forever begin
		mbx.get(trans); //putting this inside the task function means that the driver will wait till it receives an object from generator
		
		@(posedge sf.clk);
		
		sf.wr_en <= trans.wr_en;
		sf.rd_en <= trans.rd_en;
		sf.data_in <= trans.data_in;
		$display("[Driver] has successfully received: wr_en : %d | rd_en : %d | data_in : %d", trans.wr_en, trans.rd_en, trans.data_in);
	end
endtask


endclass