module imread (
    din,
    hs_in,
    vs_in,
    clk,
    out_en,
    dout,
    star,
    out_valid,
    enable
);
input [7:0] din;
input [19:0] star;
input clk,hs_in,vs_in,out_en,enable;
output [47:0] dout;
output out_valid;

reg [4:0] addra1=0,addrb1=0;
reg [4:0] addra2=0,addrb2=0;
reg [4:0] addra3=0,addrb3=0;
reg [4:0] addra_res=0,addrb_res=0;
reg [5:0] data_count=0,star_change_count=0,star_still_count=0,star_still_count0=0;
reg [11:0] line_number=0,column_number=0;
reg wea1=0,enb1=0,wea00=0,wea01=0,wea=0,wea02=0;
reg enb2=0,xjb=0,vs_in0=0;
reg flag=0,sigma_valid=0,image_valid=0;
reg [9:0] pages=0,count_res=0;
reg [15:0] grey_sum_in0=0,grey_sum_in1=0;
reg [23:0] grey_sum_squad_0=0,grey_sum_squad_1=0,grey_squad_out=0;
reg [47:0] ram_in=0;//postion24+sum_aver8+sigma_aver16
reg [15:0] out=0,grey_sum_out=0;
reg [9:0] star_x=0,star_y=0,star_x0=0,star_y0=0;
reg [23:0] position_reg=0;

wire [15:0] grey_sum_out0,grey_sum_out1;
wire [23:0] grey_squad_out0,grey_squad_out1;
//wire [9:0] grey_count;
wire [23:0] position,position_out;
wire [23:0] grey_average;
wire [31:0] grey_squad_average;
wire div_fpn_out_valid,div_sigma_out_valid;

parameter WIDTH = 1024;
parameter HEIGHT = 1024;

assign position={line_number,column_number};
assign out_valid=div_fpn_out_valid & (addra_res==24);

blk_mem_gen_1 position_buff(
    .addra(addra1),
    .clka(clk),
    .dina(position),
    .wea(wea1),
    .addrb(addrb1),
    .clkb(clk),
    .enb(enb1),
    .doutb(position_out)
);//location of pixels that inside the border region

blk_mem_gen_2 grey_buff0(
    .addra(addra2),
    .clka(clk),
    .dina(grey_sum_in0),
    .wea(wea1 & (~flag)),
    .addrb(addrb2),
    .clkb(clk),
    .enb(flag),
    .doutb(grey_sum_out0)
);//pingpong buffer for summing up 

blk_mem_gen_2 grey_buff1(
    .addra(addra3),
    .clka(clk),
    .dina(grey_sum_in1),
    .wea(wea1 & flag),
    .addrb(addrb3),
    .clkb(clk),
    .enb(~flag),
    .doutb(grey_sum_out1)
);//same as the above

blk_mem_gen_3 grey_squad_buff0(
    .addra(addra2),
    .clka(clk),
    .dina(grey_sum_squad_0),
    .wea(wea1 & (~flag)),
    .addrb(addrb2),
    .clkb(clk),
    .enb(flag),
    .doutb(grey_squad_out0)
);

blk_mem_gen_3 grey_squad_buff1(
    .addra(addra3),
    .clka(clk),
    .dina(grey_sum_squad_1),
    .wea(wea1 & flag),
    .addrb(addrb3),
    .clkb(clk),
    .enb(~flag),
    .doutb(grey_squad_out1)
);

blk_mem_gen_5 result_buffer(
    .addra(addra_res),
    .clka(clk),
    .dina(ram_in),
    .wea(wea),
    .addrb(addrb_res),
    .clkb(clk),
    .enb(out_en),
    .doutb(dout)
);//

div_gen_0 fpn_div(
    .s_axis_divisor_tdata(star_still_count0),
    .s_axis_divisor_tvalid(enb1),
    .s_axis_dividend_tdata(grey_sum_out),
    .s_axis_dividend_tvalid(enb1),
    .m_axis_dout_tvalid(div_fpn_out_valid),
    .m_axis_dout_tdata(grey_average),
    .aclk(clk)
);

div_gen_1 sigma_div(
    .s_axis_divisor_tdata(star_still_count0),
    .s_axis_divisor_tvalid(enb1),
    .s_axis_dividend_tdata(grey_squad_out),
    .s_axis_dividend_tvalid(enb1),
    .m_axis_dout_tvalid(div_sigma_out_valid),
    .m_axis_dout_tdata(grey_squad_average),
    .aclk(clk)
); 

always @(posedge clk) begin
    if (enable==1) begin
        vs_in0<=vs_in;
        star_x<=star[19:10];
        star_y<=star[9:0];
        star_x0<=star_x;
        star_y0<=star_y;
        if (hs_in==1) begin
            column_number<=column_number+1;
        end
        if (column_number==WIDTH) begin
            line_number<=line_number+1;
            column_number<=0;
        end
        if (star_x!=star_x0 | star_y!=star_y0) begin
            star_change_count<=star_change_count+1;
            star_still_count<=0;
            star_still_count0<=star_still_count;
            if (star_change_count==5) begin
                star_change_count<=0;
            end
        end
        /*inter-page control*/
        if (vs_in0<vs_in) begin
            flag<=~flag;
            line_number<=0;
            pages<=pages+1;
            star_still_count<=star_still_count+1;
        end         
    end

end
/*positon ram control*/
always @(posedge clk) begin
    if (enable==1) begin
        if (((line_number==star_x-3 | line_number==star_x+3) & (column_number>star_y-4 & column_number<star_y+4))|
        ((column_number==star_y-3 | column_number==star_y+3) & (line_number<star_x+3 & line_number>star_x-3))) begin
            wea1<=1;
        end  
        else wea1<=0; 
        if (((line_number==star_x-3 | line_number==star_x+3) & (column_number>star_y-7 & column_number<star_y+1))|
        ((column_number==star_y-6 | column_number==star_y) & (line_number<star_x+3 & line_number>star_x-3))) begin
            xjb<=1;
        end
        else xjb<=0;
        if (star_still_count==0) begin
            grey_sum_in0<=din;
            grey_sum_in1<=din;
            grey_sum_squad_0<=din*din;
            grey_sum_squad_1<=din*din;
        end
        else begin
        grey_sum_in0<=din+grey_sum_out1;
        grey_sum_in1<=din+grey_sum_out0; 
        grey_sum_squad_0<=din*din+grey_squad_out1;
        grey_sum_squad_1<=din*din+grey_squad_out0;
        end        
    end

end
/* ram ping-pang*/
always @(posedge clk) begin
    if (enable==1) begin
        position_reg<=position_out;
        if ((star_x!=star_x0 | star_y!=star_y0) & pages!=0) begin
            enb1<=1;
        end
        if (vs_in0<vs_in) begin
            enb1<=0;addra_res<=0;addrb_res<=0;
            addra1<=0;addra2<=0;addra3<=0;
            addrb1<=0;addrb2<=0;addrb3<=0;
            count_res<=0;
        end
        if (xjb==1 & flag==1 & addrb2<23 ) begin
            addrb2<=addrb2+1;
        end
        else if (xjb==1 & flag==0 & addrb3<23) begin
            addrb3<=addrb3+1;
        end
        if (wea1==1) begin
            addra1<=addra1+1;
            if (flag==1) begin
                addra3<=addra3+1;
            end
            else addra2<=addra2+1;
        end
        /* ram output*/
        if (star_still_count==0 & enb1==1) begin
            if (addrb1!=23 & div_fpn_out_valid==1) begin
            addrb1<=addrb1+1; 
            end
        end
        if (star_still_count==0 & enb1==1) begin
            if (flag==1) begin
                grey_sum_out<=grey_sum_out0;  
                grey_squad_out<=grey_squad_out0;
                if (div_fpn_out_valid==1) begin
                    ram_in<={position_reg,grey_average[15:8],grey_squad_average[23:8]};                
                end
                if (addrb2!=23) begin
                    addrb2<=addrb2+1;
                end
            end
            else begin
                grey_sum_out<=grey_sum_out1;
                grey_squad_out<=grey_squad_out1;
                if (div_fpn_out_valid==1) begin
                    ram_in<={position_reg,grey_average[15:8],grey_squad_average[23:8]};   
                end
                if (addrb3!=23) begin
                    addrb3<=addrb3+1;
                end
            end
            wea01<=wea00;wea02<=wea01;wea<=wea02;
            if (div_fpn_out_valid==1 & count_res!=24) begin
                wea00<=1;
            end
            else wea00<=0;
        end
        if (wea==1 & count_res!=24) begin
            addra_res<=addra_res+1;
            count_res<=count_res+1;
        end
        if (out_en==1 & addrb_res!=24 & addra_res==24) begin
            addrb_res<=addrb_res+1;
        end        
    end

end 
endmodule