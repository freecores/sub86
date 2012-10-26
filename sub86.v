module sub86( CLK, RSTN, IA, ID, A, D, Q, WEN,BEN );
input         CLK;
input         RSTN;
output [31:0] IA;
input  [15:0] ID;
output [31:0] A;
input  [31:0] D;
output [31:0] Q;
output        WEN;
output  [1:0] BEN;
wire          nncry,neqF,ngF,nlF;
reg    [31:0] EAX,EBX,ECX,EDX,EBP,ESP,PC,regsrc,regdest,alu_out;
reg           eqF,gF,lF;
reg     [4:0] state,nstate;
reg     [2:0] src,dest;
reg           cry,ncry,prefx,nprefx,cmpr;
wire   [31:0] incPC,Sregsrc,Zregsrc,pc_jg,pc_jge,pc_jl,pc_jle,pc_eq,pc_jp,pc_neq;
wire   [63:0] mul_out;
wire signed [31:0] sft_in,sft_out,tst;
wire    [4:0] shtr;
wire   [32:0] adder_out;
wire   [32:0] sub_out;
`define fetch 5'b00000 
`define jmp   5'b00001
`define jmp2  5'b00010
`define jge   5'b00011
`define jge2  5'b00100
`define imm   5'b00101
`define imm2  5'b00110
`define lea   5'b00111
`define lea2  5'b01000
`define call  5'b01001
`define call2 5'b01010
`define ret   5'b01011
`define ret2  5'b01100
`define imul  5'b01101
`define shift 5'b01110
`define jg    5'b01111
`define jg2   5'b10000
`define jl    5'b10001
`define jl2   5'b10010
`define jle   5'b10011
`define jle2  5'b10100
`define je    5'b10101
`define je2   5'b10110
`define jne   5'b10111
`define jne2  5'b11000
 always @(posedge CLK or negedge RSTN)
   if(!RSTN) begin
      EAX <= 32'b0; EBX <= 32'b0; 
      ECX <= 32'b0; EDX <= 32'b0; 
      EBP <= 32'b0; ESP <= 32'b011111111; 
      PC  <= 32'b00000;
      eqF <= 1'b0; lF <= 1'b0; gF <= 1'b0;
      state <=5'b00000; prefx <= 1'b0;
      cry <= 1'b0;
      end
   else 
      begin	
       state <= nstate; prefx <= nprefx; cry <= ncry;
       case (cmpr) 
        1'b1   : begin eqF <= neqF ; lF <= nlF; gF <= ngF; end
        default: begin eqF <=  eqF ; lF <=  lF; gF <=  gF; end
       endcase      
       if ((state==`fetch) || (state==`ret))
        begin
         if (dest==3'b000) EAX <= alu_out; else EAX<=EAX;
         if (dest==3'b001) ECX <= alu_out; else ECX<=ECX;
         if (dest==3'b010) EDX <= alu_out; else EDX<=EDX;
         if (dest==3'b011) EBX <= alu_out; else EBX<=EBX;
         if (dest==3'b100) ESP <= alu_out; else ESP<=ESP;
         if (dest==3'b101) EBP <= alu_out; else EBP<=EBP;	 
        end 
       else
        begin
	 EBP<=EBP;
         EAX<=EAX;
         ECX<=ECX;
         EDX<=EDX;
         case(state)
          `jmp , `jg, `jge , `jl, `jle, `je, `jne, `imm, `call,
	  `lea    : EBX<={EBX[31:16],ID[7:0],ID[15:8]}; 
	  `imm2   : EBX<={ID[7:0],ID[15:8], EBX[15:0]};
	  `lea2   : EBX<={ID[7:0],ID[15:8], EBX[15:0]}+EBP;       
	  default : EBX<=EBX;
         endcase
         case(state)
          `call  : ESP<=ESP - 4'b0100;
	  `ret2  : ESP<=ESP + 4'b0100; 
	  default: ESP<=ESP;
         endcase
        end
       case(state)
        `jge2              : PC<=pc_jge;
	`jle2              : PC<=pc_jle;
        `jg2               : PC<=pc_jg ;
	`jl2               : PC<=pc_jl ;
	`je2               : PC<=pc_eq ;
	`jne2              : PC<=pc_neq;
	`jmp2,`call2       : PC<=pc_jp ;
	`ret2              : PC<=D     ;
	default            : PC<=incPC ;
       endcase
      end
// muxing for source selection, used in alu & moves
always@(src,EAX,ECX,EDX,EBX,ESP,EBP,D)
   case(src)
    3'b000 : regsrc = EAX;
    3'b001 : regsrc = ECX;
    3'b010 : regsrc = EDX;
    3'b011 : regsrc = EBX;
    3'b100 : regsrc = ESP;
    3'b101 : regsrc = EBP;
    3'b111 : regsrc = D;    
    default: regsrc = EBX;
   endcase 
// muxing for 2nd operand selection, used in alu only
always@(dest,EAX,ECX,EDX,EBX,ESP,EBP,D)
   case(dest)
    3'b000 : regdest = EAX;
    3'b001 : regdest = ECX;
    3'b010 : regdest = EDX;
    3'b011 : regdest = EBX;
    3'b100 : regdest = ESP;
    3'b101 : regdest = EBP;
    3'b111 : regdest = D  ;    
    default: regdest = EBX;
   endcase 
// alu
always@(regdest,regsrc,ID,cry,mul_out,Zregsrc,Sregsrc,sft_out)
 begin
  case (ID[15:10])
   6'b000000 : {ncry,alu_out} =             adder_out ; // ADD , carry generation
   6'b000010 : {ncry,alu_out} = {cry,regdest | regsrc}; // OR
   6'b000100 : {ncry,alu_out} =             adder_out ; // ADD , carry use
   6'b000110 : {ncry,alu_out} =               sub_out ; // SUB , carry use
   6'b001000 : {ncry,alu_out} = {cry,regdest & regsrc}; // AND
   6'b001010 : {ncry,alu_out} =               sub_out ; // SUB , carry generation
   6'b001100 : {ncry,alu_out} = {cry,regdest ^ regsrc}; // XOR
   6'b100010 : {ncry,alu_out} = {cry,          regsrc}; // MOVE
   6'b101101 : {ncry,alu_out} = {cry,         Zregsrc}; // MOVE
   6'b101111 : {ncry,alu_out} = {cry,         Sregsrc}; // MOVE
   6'b101011 : {ncry,alu_out} = {cry,   mul_out[31:0]}; // IMUL
   6'b110000 : {ncry,alu_out} = {cry,   sft_out[31:0]}; // SHIFT
   6'b110100 : {ncry,alu_out} = {cry,   sft_out[31:0]}; // SHIFT
   default   : {ncry,alu_out} = {cry,regdest         }; // DO NOTHING
  endcase
 end
// Main instruction decode
always @(ID,state)
 begin
   // One cycle instructions, operand selection
   if (state == `fetch)
    begin
     case ({ID[15:14],ID[9],ID[7]})
      4'b1000  : begin src=ID[5:3]; dest= 3'b111; end  // store into ram (x89 x00)
      4'b1010  : begin src= 3'b111; dest=ID[5:3]; end  // load from ram  (x8b x00)
      4'b1001  : begin src=ID[5:3]; dest=ID[2:0]; end  // reg2reg xfer   (x89 xC0)
      4'b1011  : begin src=ID[2:0]; dest=ID[5:3]; end  // reg2reg xfer   (x8b xC0) & imul
      4'b0001  : begin src=ID[5:3]; dest=ID[2:0]; end  // alu op
      4'b0011  : begin src=ID[2:0]; dest=ID[5:3]; end  // alu op
      default  : begin src=ID[5:3]; dest=ID[2:0]; end  // shift
     endcase
    end
   else if (state==`ret)
        begin src = 3'b011; dest = 3'b100; end
   else begin src = 3'b000; dest = 3'b000; end   
   // instructions that require more than one cycle to execute
   if (state == `fetch)    
   begin
    casex(ID)
     16'h90e9: nstate = `jmp;   
     16'h0f8f: nstate = `jg;
     16'h0f8e: nstate = `jle;
     16'h0f8d: nstate = `jge;
     16'h0f8c: nstate = `jl;
     16'h0f85: nstate = `jne;
     16'h0f84: nstate = `je;     
     16'h90bb: nstate = `imm;   
     16'h8d9d: nstate = `lea;
     16'h90e8: nstate = `call;
     16'h90c3: nstate = `ret;
     16'hc1xx: nstate = `shift;     
     default : nstate = `fetch;
    endcase
    if (ID       == 16'h9066) nprefx = 1'b1; else nprefx = 1'b0;
    if (ID[15:8] ==  8'h39  ) cmpr   = 1'b1; else cmpr   = 1'b0;
   end
   else 
   begin
        nprefx = 1'b0;
	cmpr   = 1'b0;
        if (state==`jmp)   nstate = `jmp2;  else if (state==`jmp2)  nstate = `fetch;
   else if (state==`jne)   nstate = `jne2;  else if (state==`jne2)  nstate = `fetch;
   else if (state==`je )   nstate = `je2 ;  else if (state==`je2 )  nstate = `fetch;
   else if (state==`jge)   nstate = `jge2;  else if (state==`jge2)  nstate = `fetch;
   else if (state==`jg )   nstate = `jg2 ;  else if (state==`jg2 )  nstate = `fetch;
   else if (state==`jle)   nstate = `jle2;  else if (state==`jle2)  nstate = `fetch;
   else if (state==`jl )   nstate = `jl2 ;  else if (state==`jl2 )  nstate = `fetch;
   else if (state==`imm)   nstate = `imm2;  else if (state==`imm2)  nstate = `fetch;
   else if (state==`lea)   nstate = `lea2;  else if (state==`lea2)  nstate = `fetch;
   else if (state==`call)  nstate = `call2; else if (state==`call2) nstate = `fetch;
   else if (state==`ret)   nstate = `ret2;  else if (state==`ret2)  nstate = `fetch;
   else if (state==`shift) nstate = `fetch;
   else                    nstate = `fetch;
   end   
 end
assign  IA      = PC                ;
assign  A       = (state == `call2) ?  ESP :
		                       EBX ;
assign  mul_out = regsrc * regdest  ;
assign  sft_in  = regdest           ;
assign  shtr    =       ID[12]      ?  ECX[4:0]     : EBX[4:0] ;
assign  Q       = (state == `call2) ?  incPC        : regsrc   ;
assign  WEN     = (ID[15:8]==8'h90) ?  1'b1         :
                  (state == `call2) ?  1'b0         :
                  (dest  == 3'b111) ?  1'b0         :
	                               1'b1         ;
assign      tst = sft_in >>> (shtr);
assign  sft_out = (src   == 3'b111) ? tst                : //sar
                  (src   == 3'b101) ? (sft_in >>  shtr ) : //shr
		                      (sft_in <<  shtr ) ; //shl
assign  Sregsrc =       ID[8]       ? { {16{regsrc[15]}} , regsrc[15:0] } :
                                      { {24{regsrc[7] }} , regsrc[7:0]  } ;
assign  Zregsrc =       ID[8]       ? {  16'b0           , regsrc[15:0] } :
                                      {  24'b0           , regsrc[7:0]  } ;
assign      BEN = (state == `call2 )  ? 1'b1 :
                   {  prefx           , ID[8]        } ;
assign     neqF = (regsrc == regdest) ? 1'b1 : 1'b0;
assign      nlF = (regsrc  > regdest) ? 1'b1 : 1'b0;
assign      ngF = (regsrc  < regdest) ? 1'b1 : 1'b0;
assign    incPC = PC + 3'b010;
assign   pc_jge = ( eqF|gF) ? pc_jp : incPC;
assign   pc_jle = ( eqF|lF) ? pc_jp : incPC;
assign   pc_jg  = ( gF    ) ? pc_jp : incPC;
assign   pc_jl  = ( lF    ) ? pc_jp : incPC;
assign   pc_eq  = ( eqF   ) ? pc_jp : incPC;
assign   pc_neq = ( eqF   ) ? incPC : pc_jp;
assign   pc_jp  = incPC+{ID,EBX[15:0]};
assign adder_out= nncry   + regsrc + regdest;
assign   sub_out= regdest - regsrc - nncry;
assign    nncry = ID[12] ? cry : 1'b0;
endmodule
