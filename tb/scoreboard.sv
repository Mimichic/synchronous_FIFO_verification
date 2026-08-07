class scoreboard #(parameter int DATA_WIDTH = 8);
    transaction_object #(DATA_WIDTH) trans;
    mailbox #(transaction_object #(DATA_WIDTH)) mbx;

    // Create a queue (ideal FIFO would behave like a queue)
    logic [DATA_WIDTH-1:0] ideal_fifo [$];

    function new (mailbox #(transaction_object #(DATA_WIDTH)) mbx);
        this.mbx = mbx;
    endfunction

    task scoring();
        forever begin
            mbx.get(trans);
            
            // 1. Process READ first (if read was enabled and queue has data)
            if (trans.rd_en && (ideal_fifo.size() > 0)) begin 
                logic [DATA_WIDTH-1:0] expected_data = ideal_fifo.pop_front();

                if (expected_data == trans.data_out)
                    $display("Yay, Correct output! expected: [%0d] and received: [%0d]\n", expected_data, trans.data_out);
                else 
                    $error("Uh oh! Check your device, expected: [%0d] and received: [%0d]\n", expected_data, trans.data_out);
            end

            // 2. Process WRITE second (if write was enabled and queue wasn't full)
            if (trans.wr_en && !trans.full) begin
                ideal_fifo.push_back(trans.data_in);
            end
        end
    endtask
endclass