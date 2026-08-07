class generator #(parameter int DATA_WIDTH = 8);
    // our generator does the simple job of handing out values to the driver via a mailbox
    transaction_object #(DATA_WIDTH) trans;
    mailbox #(transaction_object#(DATA_WIDTH)) mbx;

    int total_tests; // total number of tests

    function new(mailbox #(transaction_object#(DATA_WIDTH)) mbx);
        this.mbx = mbx;
    endfunction

    task run();
        for (int i = 0; i < total_tests; i++) begin
            trans = new();

            if (!trans.randomize())
                $display("Oops! randomization of your transaction object failed!");
            else begin
                mbx.put(trans);
                $display("randomization successful! generated %d out of %d packets \n", i+1, total_tests);
            end 
        end 
    endtask

endclass