module sub86( CLK, RSTN, IA, ID, A, D, Q, WEN,BEN,CE,RD );
input         CLK,RSTN,CE;
output [31:0] IA;
input  [15:0] ID;
output [31:0] A;
input  [31:0] D;
output [31:0] Q;
output        WEN;
output        RD;
output  [1:0] BEN;
wire          nncry,neqF,ngF,nlF,naF,nbF,divF1,divF2;
reg    [31:0] EAX,EBX,ECX,EDX,EBP,ESP,PC,regsrc,regdest,alu_out;
reg     [5:0] state,nstate;
reg     [2:0] src,dest;
reg           RD,cry,ncry,prefx,nprefx,cmpr,eqF,gF,lF,aF,bF;
wire   [31:0] pc_ja,pc_jae,pc_jb,pc_jbe,pc_jg,pc_jge,pc_jl,pc_jle,pc_eq,pc_jp,pc_neq,pc_sh;
wire   [31:0] Sregsrc,Zregsrc,incPC,sft_out,smlEAX,smlECX;
wire   [32:0] adder_out,sub_out;
wire    [4:0] EBX_shtr; 
wire signed [31:0] ssregsrc, ssregdest;
`define fetch 6'b111111 
`define jmp   6'b000001
`define jmp2  6'b000010
`define jge   6'b000011
`define jge2  6'b000100
`define imm   6'b000101
`define imm2  6'b000110
`define lea   6'b000111
`define lea2  6'b001000
`define call  6'b001001
`define call2 6'b001010
`define ret   6'b001011
`define ret2  6'b001100
`define shift 6'b001110
`define jg    6'b001111
`define jg2   6'b010000
`define jl    6'b010001
`define jl2   6'b010010
`define jle   6'b010011
`define jle2  6'b010100
`define je    6'b010101
`define je2   6'b010110
`define jne   6'b010111
`define jne2  6'b011000
`define mul   6'b011001
`define mul2  6'b011010
`define shft2 6'b011011
`define jb    6'b011100
`define jb2   6'b011101
`define jbe   6'b011110
`define jbe2  6'b011111
`define ja    6'b100000
`define ja2   6'b100001
`define jae   6'b100010
`define jae2  6'b100011
`define sml1  6'b100100
`define sml2  6'b100101
`define sml3  6'b100110
`define sml4  6'b100111
`define sdv1  6'b101000
`define sdv2  6'b101001
`define sdv3  6'b101010
`define sdv4  6'b101011
`define div1  6'b101100
`define leas  6'b101101
`define calla 6'b101110
`define calla2 6'b101111
`define init  6'b000000

 always @(posedge CLK)
   if ((CE ==1'b1) || (RSTN ==1'b0))
     begin
      case (state) // cry control
         `sml1,`sdv1: cry <= EAX[31] ^ ECX[31];
	 `div1      : cry <= 1'b0;
	 default    : cry <= ncry & RSTN;
      endcase 
      prefx <= nprefx & RSTN;
      state <= nstate & {6{RSTN}};
      if (cmpr) begin eqF <= neqF & RSTN; lF <= nlF & RSTN; gF <= ngF & RSTN;
                      bF  <=  nbF & RSTN; aF <= naF & RSTN; end
           else begin eqF <=  eqF & RSTN; lF <=  lF & RSTN; gF <=  gF & RSTN; 
	              bF  <=   bF & RSTN; aF <=  aF & RSTN; end
      case(state)  // EAX control
        `init       : EAX <= 32'b0;
        `mul,`sml2  : EAX <= {EAX[30:0],1'b0};
	`mul2       : EAX <= EBX;
	`sml1       : EAX <= smlEAX;
	`sml3       : if (cry==1'b0) EAX <= EBX; else EAX <= ((~EBX) + 1'b1);
	`sdv1,`div1 : EAX <= 32'b0;
	`sdv3       : if (nlF==1'b0) EAX <= EAX + ( 1 << EBX_shtr); else EAX <=EAX;
	`sdv4       : if (cry==1'b1) EAX <= ((~EAX) + 1'b1); else EAX <= EAX;
	default: if (dest==3'b000) EAX <= alu_out; else EAX<=EAX;
      endcase
      case(state)  // EBX control
        `init       : EBX <= 32'b0;
        `jmp , `jg, `jge , `jl, `jle, `je, `jne, `imm, `call, `jb,`jbe,`ja,`jae,
	`lea        : EBX<={EBX[31:16],ID[7:0],ID[15:8]}; 
	`leas       : EBX<={ {24{ID[15]}} , ID[15:8]}+EBP; 
	`imm2       : EBX<={ID[7:0],ID[15:8], EBX[15:0]};
	`lea2       : EBX<={ID[7:0],ID[15:8], EBX[15:0]}+EBP;       
	`mul,`sml2  : if (ECX[0] == 1'b1) EBX <= EAX+EBX; else EBX <= EBX;
	`shift      : EBX<={EBX[31:5],EBX_shtr};
	`sdv1       : EBX<={EAX[31],ECX[31],EBX[29:0]};
	`div1       : EBX<={          2'b00,EBX[29:0]};
	`sdv2       : if (divF1==1'b0 ) EBX <= {EBX[31:5],(EBX[4:0]+1'b1)}; else EBX <= EBX;
	`sdv3       : if (divF1==1'b1 ) EBX <= {EBX[31:5],EBX_shtr}; else EBX <= EBX;
	default     : if (ID[15:8] == 8'hb3) EBX<= {EBX[31:24],ID[7:0]};
	         else if (dest==3'b011) EBX <= alu_out; else EBX <= EBX;
      endcase
      case(state)  // ECX control
        `init       : ECX <= 32'b0;
        `mul,`sml2  : ECX <= {1'b0,ECX[31:1]};
	`sml1,`sdv1 : ECX <= smlECX;
	`div1       : ECX <= ECX;
	`sdv2       : if (divF1==1'b0 ) ECX <= {ECX[30:0],1'b0}; else ECX<=ECX;
	`sdv3       : if((divF1==1'b1 ) && (divF2==1'b0)) ECX <= {1'b0,ECX[31:1]}; else ECX<=ECX;
        `sdv4       : if (EBX[30] == 1'b1) ECX <= ((~ECX) + 1); else ECX<=ECX;
	default     : if (dest==3'b001) ECX <= alu_out; else ECX<=ECX;
      endcase
      case(state)  // EDX control
        `init       : EDX <= 32'b0;
	`sdv1       : EDX <= smlEAX;
	`div1       : EDX <=    EAX;
	`sdv3       : if (nlF==1'b0) EDX <= EDX - ECX; else EDX <= EDX;
        `sdv4       : if (EBX[31] == 1'b1) EDX <= ((~EDX) + 1); else EDX<=EDX;
	default     : if (dest==3'b010) EDX <= alu_out; else EDX<=EDX;
      endcase     
      case(state)  // ESP control
        `init       : ESP <= 32'h01ff00;
        `call,`calla: ESP <= ESP - 4'b0100;
        `ret2       : ESP <= ESP + 4'b0100; 
       default: if (dest==3'b100) ESP <= alu_out; else ESP<=ESP;
      endcase
      if (dest==3'b101) EBP <= alu_out; else EBP<=EBP;	// EBP control 
      case(state)  // PC control
       `init        : PC<=32'h00;
       `jae2        : PC<=pc_jae;
       `jbe2        : PC<=pc_jbe;
       `ja2         : PC<=pc_ja ;
       `jb2         : PC<=pc_jb ;
       `jge2        : PC<=pc_jge;
       `jle2        : PC<=pc_jle;
       `jg2         : PC<=pc_jg ;
       `jl2         : PC<=pc_jl ;
       `je2         : PC<=pc_eq ;
       `jne2        : PC<=pc_neq;
       `jmp2,`call2 : PC<=pc_jp ;
       `calla2      : PC<=EBX;
       `ret2        : PC<=D	;
       `mul,`mul2,`sml1,`sml2,`sml3,`sml4,`sdv1,`sdv2,`sdv3,`sdv4,`div1,
       `shift       : PC<=PC	;
       default      : if (nstate == `shift) PC<=PC; 
                 else if (ID[15:8]==8'heb) PC <= pc_sh;
                 else if((ID[15:8]==8'h75) && (eqF==1'b0)) PC <= pc_sh;
                 else if((ID[15:8]==8'h74) && (eqF==1'b1)) PC <= pc_sh;
		 else PC<=incPC ;
      endcase
     end
// muxing for source selection, used in alu & moves
always@(src,EAX,ECX,EDX,EBX,ESP,EBP,D)
   case(src)
    3'b000 : regsrc = EAX;
    3'b001 : regsrc = ECX;
    3'b010 : regsrc = EDX;
    3'b100 : regsrc = ESP;
    3'b101 : regsrc = EBP;
    3'b110 : regsrc = 32'h04;
    3'b111 : regsrc = D;    
    default: regsrc = EBX;
   endcase 
// muxing for 2nd operand selection, used in alu only
always@(dest,EAX,ECX,EDX,EBX,ESP,EBP,D)
   case(dest)
    3'b000 : regdest = EAX;
    3'b001 : regdest = ECX;
    3'b010 : regdest = EDX;
    3'b100 : regdest = ESP;
    3'b101 : regdest = EBP;
    3'b110 : regdest = 32'h04;
    3'b111 : regdest = D  ;    
    default: regdest = EBX;
   endcase 
// alu
always@(state,regdest,regsrc,ID,cry,Zregsrc,Sregsrc,sft_out,adder_out,sub_out)
  if (state == `fetch )
  case (ID[15:10])
   6'b000000 : {ncry,alu_out} = 	    adder_out ;  // ADD , carry generation
   6'b000010 : {ncry,alu_out} = {cry,regdest | regsrc};  // OR
   6'b000100 : {ncry,alu_out} = 	    adder_out ;  // ADD , carry use
   6'b000110 : {ncry,alu_out} = 	      sub_out ;  // SUB , carry use
   6'b001000 : {ncry,alu_out} = {cry,regdest & regsrc};  // AND
   6'b001010 : {ncry,alu_out} = 	      sub_out ;  // SUB , carry generation
   6'b001100 : {ncry,alu_out} = {cry,regdest ^ regsrc};  // XOR
   6'b100010 : {ncry,alu_out} = {cry,	       regsrc};  // MOVE
   6'b101101 : {ncry,alu_out} = {cry,	      Zregsrc};  // MOVE
   6'b101111 : {ncry,alu_out} = {cry,	      Sregsrc};  // MOVE
   //6'b110000 : {ncry,alu_out} = {cry,	sft_out[31:0]};  // SHIFT
   //6'b110100 : {ncry,alu_out} = {cry,	sft_out[31:0]};  // SHIFT
   default   : {ncry,alu_out} = {cry,regdest	     };  // DO NOTHING
  endcase
  else if (state == `shift ) {ncry,alu_out} = {cry,sft_out	     };
  else {ncry,alu_out} = {cry,regdest	     };
// Main instruction decode
always @(ID,state,ECX,EBX_shtr,EAX,divF1,divF2)
 begin
   // One cycle instructions, operand selection
   if ((state == `fetch) || (state ==`shift))
     casex ({ID[15:14],ID[13],ID[9],ID[7]})
      5'b10x00  : begin RD=0; src=ID[5:3]; dest= 3'b111; end  // store into ram (x89 x00)
      5'b10010  : begin RD=1; src= 3'b111; dest=ID[5:3]; end  // load from ram  (x8b x00)
      5'b10110  : begin RD=0; src= 3'b111; dest=ID[5:3]; end  // load bl with immediate
      5'b10x11  : begin RD=0; src=ID[2:0]; dest=ID[5:3]; end  // reg2reg xfer   (x8b xC0)
      5'b00x11  : begin RD=0; src=ID[2:0]; dest=ID[5:3]; end  // alu op
      default   : begin RD=0; src=ID[5:3]; dest=ID[2:0]; end  // shift
     endcase
   else if (state==`ret)
        begin src = 3'b011; dest = 3'b100; RD=0; end
   else if (state==`sdv3)
        begin src = 3'b001; dest = 3'b010; RD=0; end
   else begin src = 3'b000; dest = 3'b000; RD=0; end   
   // instructions that require more than one cycle to execute
   if (state == `fetch)    
   begin
    casex(ID)
     16'h90e9: nstate = `jmp;   
     16'h0f87: nstate = `ja;
     16'h0f86: nstate = `jbe;
     16'h0f83: nstate = `jae;
     16'h0f82: nstate = `jb;
     16'h0f8f: nstate = `jg;
     16'h0f8e: nstate = `jle;
     16'h0f8d: nstate = `jge;
     16'h0f8c: nstate = `jl;
     16'h0f85: nstate = `jne;
     16'h0f84: nstate = `je;     
     16'h90bb: nstate = `imm;   
     16'h8d9d: nstate = `lea;
     16'h8d5d: nstate = `leas;
     16'h90e8: nstate = `call;
     16'h90c3: nstate = `ret;
     16'hc1xx: nstate = `shift; 
     16'hd3xx: nstate = `shift; 
     16'hf7e1: nstate = `mul; 
     16'hf7f9: nstate = `sdv1;   
     16'hf7f1: nstate = `div1;   
     16'hafc1: nstate = `sml1;    
     16'hffd3: nstate = `calla;    
     default : nstate = `fetch;
    endcase
    if (ID       == 16'h9066) nprefx = 1'b1; else nprefx = 1'b0;
    if (ID[15:8] ==  8'h39  ) cmpr   = 1'b1; else cmpr   = 1'b0;
   end
   else 
   begin
        nprefx = 1'b0; cmpr   = 1'b0;
	if((state==`mul)&&!(ECX==32'b0)) nstate=`mul;
   else if((state==`mul)&& (ECX==32'b0)) nstate=`mul2;
   else if (state==`mul2)  nstate = `fetch;   
   else if (state==`sml1)  nstate = `sml2;   
   else if((state==`sml2)&&!(ECX==32'b0)) nstate=`sml2;
   else if((state==`sml2)&& (ECX==32'b0)) nstate=`sml3;
   else if (state==`div1)  nstate = `sdv2;   
   else if (state==`sdv1)  nstate = `sdv2;   
   else if((state==`sdv2) && (divF1 == 1'b0) ) nstate=`sdv2;
   else if((state==`sdv2) && (divF1 == 1'b1) ) nstate=`sdv3;
   else if((state==`sdv3) && (divF2 == 1'b0) ) nstate=`sdv3;
   else if((state==`sdv3) && (divF2 == 1'b1) ) nstate=`sdv4;
   else if (state==`jmp)   nstate = `jmp2;  else if (state==`jmp2)  nstate = `fetch;
   else if (state==`jne)   nstate = `jne2;  else if (state==`jne2)  nstate = `fetch;
   else if (state==`je )   nstate = `je2 ;  else if (state==`je2 )  nstate = `fetch;
   else if (state==`jge)   nstate = `jge2;  else if (state==`jge2)  nstate = `fetch;
   else if (state==`jg )   nstate = `jg2 ;  else if (state==`jg2 )  nstate = `fetch;
   else if (state==`jle)   nstate = `jle2;  else if (state==`jle2)  nstate = `fetch;
   else if (state==`jl )   nstate = `jl2 ;  else if (state==`jl2 )  nstate = `fetch;
   else if (state==`jae)   nstate = `jae2;  else if (state==`jae2)  nstate = `fetch;
   else if (state==`ja )   nstate = `ja2 ;  else if (state==`ja2 )  nstate = `fetch;
   else if (state==`jbe)   nstate = `jbe2;  else if (state==`jbe2)  nstate = `fetch;
   else if (state==`jb )   nstate = `jb2 ;  else if (state==`jb2 )  nstate = `fetch;
   else if (state==`imm)   nstate = `imm2;  else if (state==`imm2)  nstate = `fetch;
   else if (state==`lea)   nstate = `lea2;  else if (state==`lea2)  nstate = `fetch;
   else if (state==`call)  nstate = `call2; else if (state==`call2) nstate = `fetch;
   else if (state==`calla) nstate = `calla2;else if (state==`calla2)nstate = `fetch;
   else if (state==`ret)   nstate = `ret2;  else if (state==`ret2)  nstate = `fetch;
   else if((state==`shift)&&!(EBX_shtr==5'b0)) nstate=`shift;
   else if((state==`shift)&& (EBX_shtr==5'b0)) nstate=`shft2;
   else                    nstate = `fetch;
   end   
 end
assign ssregsrc = regsrc;
assign ssregdest= regdest;
assign  IA      = PC                ;
assign  A       =((state == `call2)|(state == `calla2)) ?  ESP          : EBX      ;
assign  Q       =((state == `call2)|(state == `calla2)) ?  incPC        : regsrc   ;
assign  WEN     = (CE    ==   1'b0) ?  1'b1         :
                  ({ID[15:9],ID[7]}==8'h88)?  1'b0  :
                  (state == `call2) ?  1'b0         :
		  (state == `calla2)?  1'b0         : 1'b1     ;
assign  Sregsrc =       ID[8]       ? { {16{regsrc[15]}} , regsrc[15:0] } :
                                      { {24{regsrc[7] }} , regsrc[7:0]  } ;
assign  Zregsrc =       ID[8]       ? {  16'b0           , regsrc[15:0] } :
                                      {  24'b0           , regsrc[7:0]  } ;
assign      BEN = (state == `call2 )  ? 1'b1 : { prefx   , ID[8]        } ;
assign     neqF = (regsrc == regdest) ? 1'b1 : 1'b0;
assign      nbF = (regsrc  > regdest) ? 1'b1 : 1'b0;
assign      naF = ~(nlF | neqF );// (regsrc  < regdest) ? 1'b1 : 1'b0;
assign      nlF = (ssregsrc  > ssregdest) ? 1'b1 : 1'b0;
assign      ngF = ~(nbF | neqF );// (regsrc  < regdest) ? 1'b1 : 1'b0;
assign    incPC = PC + 3'b010;
assign   pc_jge = (eqF|gF) ? pc_jp : incPC;
assign   pc_jle = (eqF|lF) ? pc_jp : incPC;
assign   pc_jg  = (gF    ) ? pc_jp : incPC;
assign   pc_jl  = (lF    ) ? pc_jp : incPC;
assign   pc_jae = (eqF|aF) ? pc_jp : incPC;
assign   pc_jbe = (eqF|bF) ? pc_jp : incPC;
assign   pc_ja  = (aF    ) ? pc_jp : incPC;
assign   pc_jb  = (bF    ) ? pc_jp : incPC;
assign   pc_eq  = (eqF   ) ? pc_jp : incPC;
assign   pc_neq = (eqF   ) ? incPC : pc_jp;
assign   pc_jp  = incPC+{ID,EBX[15:0]};
assign   pc_sh  = incPC + { {24{ID[7]}} , ID[7:0] };
assign  sft_out = (src   == 3'b111) ? {regdest[31],regdest[31:1]} : //sar
                  (src   == 3'b101) ? {       1'b0,regdest[31:1]} : //shr
		                      {regdest[30:0],1'b0       } ; //shl
assign adder_out= nncry   + regsrc + regdest;
assign   sub_out= regdest - regsrc - nncry;
assign    nncry = (ID[12] ? cry : 1'b0);
assign EBX_shtr = EBX[4:0] - 1'b1;
assign   smlEAX = EAX[31] ? ((~EAX) + 1) : EAX;
assign   smlECX = ECX[31] ? ((~ECX) + 1) : ECX;
assign    divF1 = ({ECX[30:0],1'b0}  > EDX) ? 1'b1 : 1'b0;
assign    divF2 = (EBX_shtr == 5'b00000) ? 1'b1 : 1'b0;
endmodule
