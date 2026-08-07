class transaction_object #(parameter int DATA_WIDTH = 8);
	//rand logic for the input to our generators
	rand logic wr_en;
	rand logic rd_en;
	rand logic [DATA_WIDTH-1:0] data_in;
	//logic for the outputs that we will be observing
	logic [DATA_WIDTH-1:0] data_out;
	logic full;
	logic empty;

	constraint signal_probability {
	 wr_en dist {1 :/ 70 , 0 :/ 30}; //seventy percent probability the write and read functions are enabled
	 rd_en dist {1 :/ 70 , 0 :/30};
	}

	function void display(string name);
		$display("-----%s----- \n", name);
		$display("inputs:  rd_en: %d | wr_en: %d | data_in : %d", rd_en, wr_en, data_in);
		$display("outputs:  data_out: %d | full: %d | empty: %d", data_out, full, empty);
	endfunction
endclass