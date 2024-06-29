`timescale 1ns/10ps
module geofence (clk,reset,X,Y,valid,is_inside);
input			clk;
input			reset;
input	[9:0]	X;
input	[9:0]	Y;
output			valid;
output			is_inside;

localparam READ_INIT = 3'd0;
localparam READ = 3'd1;
localparam SORT_INIT = 3'd2;
localparam SORT = 3'd3;
localparam CHK = 3'd4;
localparam FINISH = 3'd5;


reg [2:0] currentState;
reg [2:0] nextState;

reg [2:0] cnt;
reg [9:0] x_list [0:6], y_list [0:6];
reg [9:0] obj_x, obj_y;
reg [9:0] left_x, left_y;
reg signed [10:0] sort_list [0:6];
reg sort_index;

reg signed [10:0] vectorA_x, vectorA_y, vectorB_x, vectorB_y;
reg [2:0] chk_cnt;
reg inside_flag;

integer i;

wire [19:0] ans0, ans1;
reg inside_;
wire msb0, msb1;

multiply mul0(.clk(clk), .reset(reset), .a(vectorA_x), .b(vectorB_y), .ans(ans0), .carry(msb0));
multiply mul1(.clk(clk), .reset(reset), .a(vectorA_y), .b(vectorB_x), .ans(ans1), .carry(msb1));

always @(*) begin
    case ({msb0, msb1})
        2'b10: inside_ = 1'b0;
        2'b01: inside_ = 1'b1;
        2'b00: inside_ = ans0 > ans1;
        2'b11: inside_ = ans1 > ans0; 
        default: inside_ = 1'b0;
    endcase
end

assign valid = (currentState == FINISH);
assign is_inside = inside_flag;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        currentState <= READ_INIT;
    end
    else currentState <= nextState;
end

always @(*) begin
    case (currentState)
	READ_INIT: nextState = READ;
        READ: nextState = (cnt == 3'd6)? SORT_INIT : READ;
        SORT_INIT: nextState = SORT;
        SORT: nextState = (cnt == 3'd6)? CHK : SORT;
        CHK: nextState = (cnt == 3'd6 || (~inside_ && chk_cnt > 1))? FINISH : CHK;
        FINISH: nextState = READ_INIT; 
        default: nextState = READ_INIT;
    endcase
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt <= 0;
        left_x <= 10'd1023;
        left_y <= 0;
        sort_index <= 0;
	vectorA_x <= 0;
	vectorA_y <= 0;
	vectorB_x <= 0;
	vectorB_y <= 0;
	chk_cnt <= 0;
	inside_flag <= 0;
    end

    else begin
        case (currentState)
	    READ_INIT: begin
                obj_x <= X;
                obj_y <= Y;
	    end
            READ: begin
		cnt <= cnt + 3'd1;
                
                x_list[cnt] <= X;
                y_list[cnt] <= Y;

                if (X < left_x) begin
                    left_x <= X;
                    left_y <= Y;
                end                
            end
            SORT_INIT: begin
		cnt <= 0;
                for (i = 0; i < 7; i = i + 1) begin
                    sort_list[i] <= (y_list[i] < left_y)? ~x_list[i] + 11'd1 : x_list[i];
                end
            end
            SORT: begin
                cnt <= (cnt == 3'd6)? 3'd0 : cnt + 3'd1;
                sort_index <= ~sort_index;
                if (sort_index) begin
                    for (i = 0; i < 5; i = i + 2) begin
                        sort_list[i] <= (sort_list[i] > sort_list[i + 1])? sort_list[i + 1] : sort_list[i];
                        x_list[i] <= (sort_list[i] > sort_list[i + 1])? x_list[i + 1] : x_list[i];
                        y_list[i] <= (sort_list[i] > sort_list[i + 1])? y_list[i + 1] : y_list[i];

                        sort_list[i + 1] <= (sort_list[i] > sort_list[i + 1])? sort_list[i] : sort_list[i + 1];
                        x_list[i + 1] <= (sort_list[i] > sort_list[i + 1])? x_list[i] : x_list[i + 1];
                        y_list[i + 1] <= (sort_list[i] > sort_list[i + 1])? y_list[i] : y_list[i + 1];
                    end
                end
                else begin
                    for (i = 1; i < 6; i = i + 2) begin
                        sort_list[i] <= (sort_list[i] > sort_list[i + 1])? sort_list[i + 1] : sort_list[i];
                        x_list[i] <= (sort_list[i] > sort_list[i + 1])? x_list[i + 1] : x_list[i];
                        y_list[i] <= (sort_list[i] > sort_list[i + 1])? y_list[i + 1] : y_list[i];

                        sort_list[i + 1] <= (sort_list[i] > sort_list[i + 1])? sort_list[i] : sort_list[i + 1];
                        x_list[i + 1] <= (sort_list[i] > sort_list[i + 1])? x_list[i] : x_list[i + 1];
                        y_list[i + 1] <= (sort_list[i] > sort_list[i + 1])? y_list[i] : y_list[i + 1];
                    end
                end
            end
	    CHK: begin 
		chk_cnt <= (chk_cnt == 6)? chk_cnt : chk_cnt + 3'd1;
		vectorB_x <= x_list[chk_cnt] - obj_x;
		vectorB_y <= y_list[chk_cnt] - obj_y;
		vectorA_x <= (chk_cnt == 3'd6)? x_list[0] - x_list[chk_cnt] : x_list[chk_cnt + 1] - x_list[chk_cnt];
		vectorA_y <= (chk_cnt == 3'd6)? y_list[0] - y_list[chk_cnt] : y_list[chk_cnt + 1] - y_list[chk_cnt];
		cnt <= (chk_cnt > 1)? cnt + 3'd1 : cnt;
		inside_flag <= inside_;
	    end
            FINISH: begin
		cnt <= 0;
                left_x <= 10'd1023;
                chk_cnt <= 0;
            end  
        endcase
    end
end

endmodule



module multiply (
	clk,
	reset,
	a,
	b,
	ans,
    carry
);
parameter  MUL_WIDTH  = 11;
parameter  MUL_RESULT = 21;

input                    clk;
input                  reset;
input [MUL_WIDTH-1:0]      a;
input [MUL_WIDTH-1:0]      b;
output [MUL_RESULT-2:0]  ans;
output                 carry;

reg                             msb;
reg [MUL_RESULT-2:0]            add;

wire [MUL_WIDTH-1:0]      mul_a_reg;
wire [MUL_WIDTH-1:0]      mul_b_reg;

wire [MUL_WIDTH-2:0]   inv_a, inv_b;

wire [9:0]   stored0, stored2, stored4, stored6, stored8;
wire [9:0]   stored1, stored3, stored5, stored7, stored9;

assign inv_a = ~a[9:0] + 10'd1;
assign inv_b = ~b[9:0] + 10'd1;

assign mul_a_reg = (a[10] == 0)? a : {1'b1, inv_a};
assign mul_b_reg = (b[10] == 0)? b : {1'b1, inv_b};
 
assign ans = add;
assign carry = msb;

assign stored0 = mul_b_reg[0]? mul_a_reg[9:0] : 10'b0;
assign stored1 = mul_b_reg[1]? mul_a_reg[9:0] : 10'b0;

assign stored2 = mul_b_reg[2]? mul_a_reg[9:0] : 10'b0;
assign stored3 = mul_b_reg[3]? mul_a_reg[9:0] : 10'b0;

assign stored4 = mul_b_reg[4]? mul_a_reg[9:0] : 10'b0;
assign stored5 = mul_b_reg[5]? mul_a_reg[9:0] : 10'b0;

assign stored6 = mul_b_reg[6]? mul_a_reg[9:0] : 10'b0;
assign stored7 = mul_b_reg[7]? mul_a_reg[9:0] : 10'b0;

assign stored8 = mul_b_reg[8]? mul_a_reg[9:0] : 10'b0;
assign stored9 = mul_b_reg[9]? mul_a_reg[9:0] : 10'b0;

always @(posedge clk or posedge reset) begin
	if (reset) begin		
	    msb<=0;
	    add<=0;	
	end

	else begin
	    msb <= a[10] ^ b[10];
		
	    add <= ((({stored1, 1'b0} + stored0) + {({stored3, 1'b0} + stored2), 2'b0}) + 
                   {(({stored5, 1'b0} + stored4) + {({stored7, 1'b0} + stored6),2'b0}), 4'b0}) + 
                   {({stored9, 1'b0} + stored8), 8'b0};
	end
end

endmodule
