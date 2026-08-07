module synchronous_FIFO #(parameter int DATA_WIDTH = 8, parameter int DEPTH = 16) 
(
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic clk,
    input  logic rst,
    input  logic rd_en,
    input  logic wr_en,
    
    output logic full,
    output logic empty,
    output logic [DATA_WIDTH-1:0] data_out 
);

    logic [DATA_WIDTH-1:0] data_register [DEPTH-1:0];
    logic [$clog2(DEPTH)-1:0] read;
    logic [$clog2(DEPTH)-1:0] write;
    logic [$clog2(DEPTH):0] tracker; 

    always_ff @(posedge clk) begin
        if (rst) begin
            read    <= 0; 
            write   <= 0; 
            tracker <= 0;
        end
        else begin
            case({wr_en && !full, rd_en && !empty})
                2'b10: begin
                    data_register[write] <= data_in;
                    write <= write + 1; 
                    tracker <= tracker + 1; 
                end 
                2'b01: begin
                    read <= read + 1; 
                    tracker <= tracker - 1; 
                end
                2'b11: begin
                    data_register[write] <= data_in;
                    read <= read + 1; 
                    write <= write + 1; 
                end        
            endcase
        end
    end

    assign data_out = data_register[read];
    assign full = (tracker == DEPTH) ? 1'b1 : 1'b0;
    assign empty = (tracker == 0) ? 1'b1 : 1'b0;

endmodule