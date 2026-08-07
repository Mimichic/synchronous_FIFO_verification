class environment #(parameter int DATA_WIDTH = 8);

//here we essentially bind all our components together!
virtual fifo_if.tb sf;
generator #(DATA_WIDTH) gen;
driver #(DATA_WIDTH) dvr; 
monitor #(DATA_WIDTH) mtr;
scoreboard #(DATA_WIDTH) scr;

//we need two mailboxes that communicate from gen to driver and monitor to scoreboard
mailbox #(transaction_object #(DATA_WIDTH)) gen_to_drv;
mailbox #(transaction_object #(DATA_WIDTH)) mtr_to_scr;

function new(virtual fifo_if.tb sf); //to communicate to the top testbench
	this.sf = sf;
endfunction

task build_all();
	//first make a mailbox object
	gen_to_drv = new(1);
	mtr_to_scr = new(1);
	//assign all necessary inputs and create all instances of objects required
	gen = new(gen_to_drv);
	dvr = new(gen_to_drv, sf);
	mtr = new(mtr_to_scr, sf);
	scr = new(mtr_to_scr);
endtask

task run_all();
	fork
		gen.run();
		dvr.run();
		mtr.fetch();
		scr.scoring();
	join_any
endtask 

endclass