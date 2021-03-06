//Legal Notice: (C)2006 Altera Corporation. All rights reserved. Your
//use of Altera Corporation's design tools, logic functions and other
//software and tools, and its AMPP partner logic functions, and any
//output files any of the foregoing (including device programming or
//simulation files), and any associated documentation or information are
//expressly subject to the terms and conditions of the Altera Program
//License Subscription Agreement or other applicable license agreement,
//including, without limitation, that your use is for the sole purpose
//of programming logic devices manufactured by Altera and sold by Altera
//or its authorized distributors.  Please refer to the applicable
//agreement for further details.

module CMD_Decode(	//	USB JTAG
					iRXD_DATA,oTXD_DATA,iRXD_Ready,iTXD_Done,oTXD_Start,
					//	LED
					//oLED_RED,oLED_GREEN,
					//	7-SEG
					//oSEG7_DIG,
					//	VGA
					//oOSD_CUR_EN,oCursor_X,oCursor_Y,
					//oCursor_R,oCursor_G,oCursor_B,			
					//	FLASH
					oFL_DATA,iFL_DATA,oFL_ADDR,iFL_Ready,oFL_Start,oFL_CMD,
					//	SDRAM
					oSDR_DATA,iSDR_DATA,oSDR_ADDR,iSDR_Done,oSDR_WR,oSDR_RD,
					//	SRAM
					oSR_DATA,iSR_DATA,oSR_ADDR,oSR_WE_N,oSR_OE_N,
					//	PS2
					//iPS2_ScanCode,iPS2_Ready,
					//	Async Port Select
					oSDR_Select,oFL_Select,oSR_Select,
					//	Control
					iCLK,iRST_n,
					/////////////////////////////////////////////////
					/////////////////////////////////////////////////
					//Added 24/11/2011
					iSD_ADDR,
					iSD_DATA_REQUEST,
					oSD_DATA,
					oSD_DATA_FINISHED_UPLOAD,
					oSD_DATA_READY,
					
					// Input/Output to send count data to PC (12/12/2011)
					iCountReady,
					iCountData,
					oRedLEDs,
					iSendData,
					oFinishedSendingData,
					iExperimentStop,
					iFreqChange,
					oFreqChangeComplete,
					oLasers,
					iExptLasers,
					iErrorSignal
				);
input [15:0] iErrorSignal;				
				
input [9:0] iExptLasers;
output [9:0] oLasers;	

	
input iFreqChange, iExperimentStop;
output reg oFreqChangeComplete = 0;		
				
output reg oFinishedSendingData = 0;
input iSendData;
				
input iCountReady;
input [31:0] iCountData;				
			
output [9:0] oRedLEDs;
	
		
//Added 24/11/2011				
input [21:0] iSD_ADDR;
input iSD_DATA_REQUEST;
output reg [31:0] oSD_DATA = 0;

output oSD_DATA_FINISHED_UPLOAD;
reg m_SD_DATA_FINISHED_UPLOAD = 0;
assign oSD_DATA_FINISHED_UPLOAD = m_SD_DATA_FINISHED_UPLOAD;

output reg oSD_DATA_READY = 0;

reg Count_Transmit_Start = 0;
reg [7:0] Count_Transmit_Data = 0;

reg sel_COUNT = 0;
				
//	USB JTAG
input [7:0] iRXD_DATA;
input iRXD_Ready,iTXD_Done;
output [7:0] oTXD_DATA;
output oTXD_Start;
//	LED
/*output reg [17:0] oLED_RED;
output reg [8:0]  oLED_GREEN;
//	7-SEG
output reg [31:0] oSEG7_DIG;
//	VGA
output reg [9:0] oCursor_X;
output reg [9:0] oCursor_Y;
output reg [9:0] oCursor_R;
output reg [9:0] oCursor_G;
output reg [9:0] oCursor_B;
output reg [1:0] oOSD_CUR_EN;*/
//	FLASH
input [7:0] iFL_DATA;
input iFL_Ready;
output reg [21:0] oFL_ADDR;
output reg [7:0] oFL_DATA;
output reg [2:0] oFL_CMD;
output reg oFL_Start;
//	SDRAM
input [15:0] iSDR_DATA;
input iSDR_Done;
output reg [21:0] oSDR_ADDR;
output reg [15:0] oSDR_DATA;
output oSDR_WR,oSDR_RD;
//	SRAM
input	[15:0]	iSR_DATA;
output	reg [15:0]	oSR_DATA;
output	reg	[17:0]	oSR_ADDR;
output	oSR_WE_N,oSR_OE_N;
//	PS2
//input [7:0] iPS2_ScanCode;
//input iPS2_Ready;
//	Async Port Select
output reg [1:0] oSDR_Select;
output reg [1:0] oFL_Select;
output reg [1:0] oSR_Select;
//	Control
input iCLK,iRST_n;

//	Internal Register
reg [63:0] CMD_Tmp;
reg [2:0] mFL_ST,mSDR_ST,mPS2_ST,mSR_ST,mLCD_ST;
//	SDRAM Control Register
reg mSDR_WRn,mSDR_Start;
//	SRAM Control Register
reg	mSR_WRn,mSR_Start;
//	Active Flag
reg f_SETUP,f_LED,f_SEG7,f_SDR_SEL,f_FL_SEL,f_SR_SEL;
reg	f_FLASH,f_SDRAM,f_PS2,f_SRAM,f_VGA;

//	USB JTAG TXD Output
reg oFL_TXD_Start,oSDR_TXD_Start,oPS2_TXD_Start,oSR_TXD_Start;
reg [7:0] oFL_TXD_DATA,oSDR_TXD_DATA,oPS2_TXD_DATA,oSR_TXD_DATA;
//	TXD Output Select Register
reg sel_FL,sel_SDR,sel_PS2,sel_SR = 0;


wire [7:0]	CMD_Action	=	CMD_Tmp[63:56];
wire [7:0]	CMD_Target	=	CMD_Tmp[55:48];
wire [23:0]	CMD_ADDR	=	CMD_Tmp[47:24];
wire [15:0]	CMD_DATA	=	CMD_Tmp[23: 8];
wire [7:0]	CMD_MODE	=	CMD_Tmp[ 7: 0];
wire [7:0] 	Pre_Target	=	CMD_Tmp[47:40];

`include "RS232_Command.h"
`include "Flash_Command.h"



reg f_LaserControls = 0;
reg [9:0] m_Lasers = 0;

assign oRedLEDs = m_Lasers;
assign oLasers = m_Lasers;

reg mResetFPGA = 0;
reg f_ResetFPGA = 0;
/////////////////////////////////////////////////////////
////////////////	 Soft-Reset detect   /////////////////
always@(posedge iCLK or negedge iRST_n)
begin
	if(!iRST_n)
	begin			
		f_ResetFPGA <= 0;		
		mResetFPGA <= 0;
	end
	else
	begin
		if(iRXD_Ready && (Pre_Target == RESETFPGA) && (f_FileUpload == 0) )
		begin
			f_ResetFPGA <= 1;			
		end
		
		if(f_ResetFPGA)
		begin		
			if( (CMD_Action == SETUP) && (CMD_Target == RESETFPGA) 
					&& (CMD_Tmp[47:0] ==  48'hFFFFFFFFFFFF)   ) 
			begin					
					mResetFPGA <= 1'b1;
					f_ResetFPGA <=0;
			end
			else
			begin
					f_ResetFPGA <= 0;
			end
		end
		else
		begin
				mResetFPGA <= 0;
		end
	end
end


/////////////////////////////////////////////////////////
////////////////	 LaserCommand detect   /////////////////
always@(posedge iCLK /*or negedge iRST_n*/)
begin

	if(mResetFPGA)
	begin			
		f_LaserControls<=0;	
	end
	else
	begin
		if(iRXD_Ready && (Pre_Target == LASER_CMD) && (f_FileUpload == 0) )
		begin
			f_LaserControls <= 1;			
		end
			
		if(f_LaserControls)
		begin		
			if( (CMD_Action == LASER_SETUP) && (CMD_Target == LASER_CMD) 
					&& (CMD_ADDR ==  24'hFFFFFF) && (CMD_MODE == 8'hFF) && (CMD_DATA[15:10] == 6'b111111) ) 
					begin		
					m_Lasers <= CMD_DATA[9:0];
					f_LaserControls<=0;
			end
			else
			begin
					f_LaserControls<=0;
			end
		end
		
			if(m_SD_DATA_FINISHED_UPLOAD == 1'b1)
			begin
				m_Lasers <= 0;	
			end
			else
			begin
				if(m_ExperimentFinish)
				begin
					m_Lasers <= iExptLasers;// input from laser_controller
				end
			end
	end
end




reg f_SETUPFINISH = 0;

/////////////////////////////////////////////////////////
////////////////	 SETUPFINISH detect   /////////////////
always@(posedge iCLK ) //this is based on LED controller
begin
	// This happens when a reset signal has been sent from the PC
	if(mResetFPGA)
	begin			
		m_SD_DATA_FINISHED_UPLOAD <= 0;		
	end
	else
	// First of all, one byte is send into "Pre_Target", and we check if this byte is "SETUPFINISH".  This means we're good to go, as long as a file is not being uploaded.
	begin
		if(iRXD_Ready && (Pre_Target == SETUPFINISH) && (f_FileUpload == 0) )
		begin
			f_SETUPFINISH <= 1;			
		end
		// f_SETUPFINISH will be set at the end of the clock cycle after we've just loaded the SETUPFINISH command into the Pre_Target byte
		if(f_SETUPFINISH)
		begin		
			if( (CMD_Action == SETUP) && (CMD_Target == SETUPFINISH) 
					&& (CMD_Tmp[47:0] ==  48'hFFFFFFFFFFFF)   ) //only our setup finish signal should ever be able to generate this data. This prevents false 'setupfinish' signals from being detected.
			begin					
					m_SD_DATA_FINISHED_UPLOAD <= 1'b1;
					f_SETUPFINISH<=0;
			end
			else
			begin
					f_SETUPFINISH<=0;
			end
		end
		
		if(m_ExperimentFinish)
		begin
			m_SD_DATA_FINISHED_UPLOAD <= 0;		
		end		
	end
end



reg f_ReadingFinished = 0;
/////////////////////////////////////////////////////////
////////////////	 READINGFINISH detect   /////////////////
always@(posedge iCLK ) //this is based on LED controller
begin
	if(mResetFPGA)
	begin			
		f_ReadingFinished <= 0;		
		mReadingFinished <= 0;
	end
	else
	begin
		if(iRXD_Ready && (Pre_Target == READINGFINISH) && (f_FileUpload == 0) )
		begin
			f_ReadingFinished <= 1;			
		end
		
		if(f_ReadingFinished)
		begin		
			if( (CMD_Action == SETUP) && (CMD_Target == READINGFINISH) 
					&& (CMD_Tmp[47:0] ==  48'hFFFFFFFFFFFF)   ) 
			begin					
					mReadingFinished <= 1'b1;
					f_ReadingFinished <=0;
			end
			else
			begin
					f_ReadingFinished <= 0;
			end
		end
		else
		begin
				mReadingFinished <= 0;
		end
	end
end

reg mFreqFinished = 0;
reg f_FreqFinished = 0;
/////////////////////////////////////////////////////////
////////////////	 FREQUENCYFINISH detect   /////////////////
always@(posedge iCLK ) //this is based on LED controller
begin
	if(mResetFPGA)
	begin			
		f_FreqFinished <= 0;		
		mFreqFinished <= 0;
	end
	else
	begin
		if(iRXD_Ready && (Pre_Target == FREQFINISH) && (f_FileUpload == 0) )
		begin			
			f_FreqFinished <= 1;			
		end
		
		if(f_FreqFinished)
		begin		
			if( (CMD_Action == SETUP) && (CMD_Target == FREQFINISH) 
					&& (CMD_Tmp[47:0] ==  48'hFFFFFFFFFFFF)   ) 
			begin						
					mFreqFinished <= 1'b1;
					f_FreqFinished <=0;					
			end
			else
			begin
					f_FreqFinished <= 0;
			end
		end
		else
		begin
				mFreqFinished <= 0;
		end
	end
end

////////////////	 SDRAM Select	/////////////////////
always@(posedge iCLK )
begin
	if(mResetFPGA)
	begin
		oSDR_Select	<=0;
		f_SDR_SEL	<=0;
	end
	else
	begin
		if(iRXD_Ready && (Pre_Target == SDRSEL) )
		f_SDR_SEL<=1;
		if(f_SDR_SEL)
		begin
			if( (CMD_Action	== SETUP) && (CMD_MODE	== OUTSEL) && 
				(CMD_ADDR == 24'h123456) )
			oSDR_Select<=CMD_DATA[1:0];
			f_SDR_SEL<=0;
		end
	end
end
/////////////////////////////////////////////////////////
////////////////	 FLASH Select	/////////////////////
always@(posedge iCLK )
begin
	if(mResetFPGA)
	begin
		oFL_Select	<=0;
		f_FL_SEL	<=0;
	end
	else
	begin
		if(iRXD_Ready && (Pre_Target == FLSEL) )
		f_FL_SEL<=1;
		if(f_FL_SEL)
		begin
			if( (CMD_Action	== SETUP) && (CMD_MODE	== OUTSEL) && 
				(CMD_ADDR == 24'h123456) )
			oFL_Select<=CMD_DATA[1:0];
			f_FL_SEL<=0;
		end
	end
end
/////////////////////////////////////////////////////////
////////////////	 SRAM Select	/////////////////////
always@(posedge iCLK )
begin
	if(mResetFPGA)
	begin
		oSR_Select	<=0;
		f_SR_SEL	<=0;
	end
	else
	begin
		if(iRXD_Ready && (Pre_Target == SRSEL) && (f_FileUpload == 0) )
		f_SR_SEL<=1;
		if(f_SR_SEL)
		begin
			if( (CMD_Action	== SETUP) && (CMD_MODE	== OUTSEL) && 
				(CMD_ADDR == 24'h123456) )
			oSR_Select<=CMD_DATA[1:0];
			f_SR_SEL<=0;
		end
	end
end

reg sel_Info = 0;
reg oInfo_TXD_Start = 0;
reg [7:0] oInfo_TXD_DATA = 0;

reg f_RequestInfo = 0;
reg [5:0] RequestInfo_State = 0;
/////////////////////////////////////////////////////////
////////////////	 REQUESTINFO detect   /////////////////
always@(posedge iCLK ) //this is based on LED controller
begin
	if(mResetFPGA)
	begin			
		f_RequestInfo <= 0;	
		oInfo_TXD_Start <= 0;
		oInfo_TXD_DATA <= 0;
	end
	else
	begin
		if((iRXD_Ready) && (Pre_Target == INFOREQUEST) && (sel_Info == 1'b1) && (f_FileUpload == 0))
		begin			
			f_RequestInfo <= 1;			
		end
		
		if(f_RequestInfo)
		begin	
				case(RequestInfo_State)
				0:	begin
						if( (CMD_Action == SETUP) && (CMD_Target == INFOREQUEST) 
								&& (CMD_Tmp[47:0] ==  48'hFFFFFFFFFFFF)   ) 
						begin	
							oInfo_TXD_Start	<=1;
							oInfo_TXD_DATA <= {InfoBuffer[7:0]}; 
							RequestInfo_State			<=1	;						
						end
						else
						begin	
							RequestInfo_State <= 0;
							f_RequestInfo <=0;
						end
					end
				1: begin
						oInfo_TXD_Start	<=0;
						if(iTXD_Done)
						begin									
							oInfo_TXD_Start	<=0;
							RequestInfo_State			<=2;	
						end
					end
				2: begin
						oInfo_TXD_Start	<=1;
						oInfo_TXD_DATA <= {InfoBuffer[15:8]}; 
						RequestInfo_State			<=3;
					end
				3: begin
						oInfo_TXD_Start	<=0;
						if(iTXD_Done)
						begin							
							oInfo_TXD_Start	<=0;
							RequestInfo_State			<=4;	
						end
					end
				4: begin
						oInfo_TXD_Start	<=1;
						oInfo_TXD_DATA <= {InfoBuffer[23:16]}; 
						RequestInfo_State			<=5;
					end
				5: begin
						oInfo_TXD_Start	<=0;
						if(iTXD_Done)
						begin							
							oInfo_TXD_Start	<=0;
							RequestInfo_State			<=6;	
						end
					end
				6: begin
						oInfo_TXD_Start	<=1;
						oInfo_TXD_DATA <= {InfoBuffer[31:24]}; 
						RequestInfo_State			<=7;
					end
				7: begin
						oInfo_TXD_Start	<=0;
						if(iTXD_Done)
						begin							
							oInfo_TXD_Start	<=0;
							RequestInfo_State			<=0;
							f_RequestInfo		<=0;							
						end
					end
				endcase
		end
	end
end

reg f_FinishRequest = 0;
reg m_FinishRequest = 0;
/////////////////////////////////////////////////////////
////////////////	 FinishRequest detect   /////////////////
always@(posedge iCLK ) //this is based on LED controller
begin

	if(mResetFPGA)
	begin			
		f_FinishRequest <= 0;	
		m_FinishRequest <= 0;
	end
	else
	begin
		if(iRXD_Ready && (Pre_Target == FINISHREQUEST) && (f_FileUpload == 0) )
		begin
			f_FinishRequest <= 1;
		end
		
		if(f_FinishRequest)
		begin		
			if( (CMD_Action == SETUP) && (CMD_Target == FINISHREQUEST) 
					&& (CMD_Tmp[47:0] ==  48'hFFFFFFFFFFFF)   )
			begin		
					f_FinishRequest<=0;
					m_FinishRequest <= 1;
			end
			else
			begin					
					f_FinishRequest<=0;
			end
		end
		else
		begin		
			m_FinishRequest <= 0;
		end
	end
end



/////////////////////////////////////////////////////////
/////////////////	TXD	Output Select		/////////////
always@(posedge iCLK )
begin
	if(mResetFPGA)
	begin
		sel_FL<=0;
		sel_SDR<=0;
		sel_PS2<=0;
		//sel_SR<=0; //this is now controlled in select count data block below
		sel_COUNT<=0;
		f_SETUP<=0;		
	end
	else
	begin
		if(m_SD_DATA_FINISHED_UPLOAD == 1'b1) //if we have recieved upload finish signal then JTAG usb output is Count data otherwise it's access to the SDRam
		begin
			sel_COUNT <= 1;	
			sel_SDR  <= 0;
		end
		else
		begin
			sel_COUNT <= 0;	
			sel_SDR  <= 1;
		end
		/*if(iRXD_Ready && (Pre_Target == SET_REG) )
		f_SETUP<=1;
		if(f_SETUP)
		begin
			if( (CMD_Action	== SETUP) && (CMD_MODE	== OUTSEL) &&
				(CMD_ADDR == 24'h123456) )
			begin
				case(CMD_DATA[7:0])
				FLASH:	begin
							sel_FL	<=1;
							sel_SDR	<=0;
							sel_PS2	<=0;
							sel_SR	<=0;
						end
				SDRAM:	begin
							sel_FL	<=0;
							sel_SDR	<=1;
							sel_PS2	<=0;
							sel_SR	<=0;
						end
				PS2:	begin
							sel_FL	<=0;
							sel_SDR	<=0;
							sel_PS2	<=1;
							sel_SR	<=0;
						end
				SRAM:	begin
							sel_FL	<=0;
							sel_SDR	<=0;
							sel_PS2	<=0;
							sel_SR	<=1;
						end
				endcase
			end
			f_SETUP<=0;
		end*/
		
	end
end

assign oTXD_Start	= 		(sel_Info)	?	oInfo_TXD_Start:
								(sel_SR)		?	oSR_TXD_Start	:
								(sel_SDR)	?	oSDR_TXD_Start	:						
											Count_Transmit_Start	;
										
assign oTXD_DATA	=	(sel_Info)	?	oInfo_TXD_DATA	:
							(sel_SR)		?	oSR_TXD_DATA	:
							(sel_SDR)	?	oSDR_TXD_DATA	:						
										Count_Transmit_Data	;


/*
//Old code!
assign oTXD_Start	= 	(sel_FL)	?	oFL_TXD_Start	:
						(sel_SDR)	?	oSDR_TXD_Start	:
						(sel_SR)	?	oSR_TXD_Start	:
										oPS2_TXD_Start	;
assign oTXD_DATA	=	(sel_FL)	?	oFL_TXD_DATA	:
						(sel_SDR)	?	oSDR_TXD_DATA	:
						(sel_SR)	?	oSR_TXD_DATA	:
										oPS2_TXD_DATA	;*/
										
/////////////////////////////////////////////////////////
///////		Send Count Data						/////////////	
reg [7:0] Count_state = 0;	
reg [7:0] Final_state = 0;	
reg f_SendCount = 0;		
reg [31:0] InfoBuffer = 0;	
reg m_ExperimentFinish = 0;
		
always@(posedge iCLK )
begin
	//oRedLEDs[5] <= 0;	
	if(mResetFPGA)
	begin
		Count_Transmit_Start<=0;
		f_SendCount<=0;
		Count_state<=0;
		sel_SR <= 0;
		sel_Info <= 0;
		m_ExperimentFinish <= 0;
		Final_state <= 0;
	end
	else
	begin
			
		if( (m_SD_DATA_FINISHED_UPLOAD) && (f_SendCount == 1'b0) )
		begin
			if(iSendData && f_StoreCount == 1'b0)
			begin
				f_SendCount<=1;				
				InfoBuffer <= {8'b10110101, 6'b000000, NumDataStored[17:0]};
			   Final_state	<= 9;					
			end
			else if( iFreqChange )
			begin
				f_SendCount<=1;				
				InfoBuffer <= {8'b01001101, 24'hAB25FC};
			   Final_state	<= 11;			
			end
			else if(iExperimentStop)
			begin
				f_SendCount<=1;				
				InfoBuffer <= {8'b10101101, 24'hFC32DA};
			   Final_state	<= 13;
			end
		end
							
		if(f_SendCount) //make sure we're not storing data to SRam while doing this
		begin
			case(Count_state)
			0:	begin
					Count_Transmit_Start	<=1;
					Count_Transmit_Data <= InfoBuffer[7:0];//8'hFF;//{3'b001,InfoBuffer[4:0]}; //first 3 bits are a label so that no byte that is sent = zero. and we can order them properly on the PC
					Count_state			<=1;
				end
			1:	begin
					Count_Transmit_Start <= 0;
					if(iTXD_Done)
					begin						
						Count_Transmit_Start	<=0;
						Count_state			<=2;	
					end
				end
			2:	begin
					Count_Transmit_Start	<=1;
					Count_Transmit_Data <= InfoBuffer[15:8];//8'hFF;//{3'b010,InfoBuffer[9:5]};
					Count_state			<=3;					
				end
			3:	begin
					Count_Transmit_Start <= 0;
					if(iTXD_Done)
					begin
						Count_Transmit_Start	<=0;
						Count_state			<=4;	
					end
				end
			4:	begin
					Count_Transmit_Start	<=1;
					Count_Transmit_Data <= InfoBuffer[23:16];//8'hFF;//{3'b011,InfoBuffer[14:10]};
					Count_state			<=5;					
				end
			5:	begin
					Count_Transmit_Start <= 0;
					if(iTXD_Done)
					begin
						Count_Transmit_Start	<=0;
						Count_state			<=6;
					end
				end
			6:	begin
					Count_Transmit_Start	<=1;
					Count_Transmit_Data <= InfoBuffer[31:24];//{3'b100,InfoBuffer[19:15]};
					Count_state			<=7;					
				end
			7:	begin
					Count_Transmit_Start <= 0;
					if(iTXD_Done)
					begin
						Count_Transmit_Start	<=0;
						sel_Info <= 1;						
						Count_state			<= 8;		
					end
				end	
			 8: begin
						if(m_FinishRequest == 1'b1) //wait for computer to confirm that it's recieved the signal.
						begin							
							sel_Info <= 0;
							Count_state			<= Final_state;
						end
				 end
			 9: begin						
						sel_SR <= 1;
						if(mReadingFinished)
						begin							
							oFinishedSendingData <= 1;
							Count_state <= 10;
							sel_SR <= 0;
						end			
				 end
			 10: begin						
						if(iSendData == 1'b0)
						begin
							oFinishedSendingData <= 0;
							InfoBuffer <= 0;
							f_SendCount <= 0;
							Count_state <= 0;
						end
				 end
			 11: begin		
						if(mFreqFinished)
						begin							
							oFreqChangeComplete <= 1;
							Count_state <= 12;
						end			
				 end
			 12: begin						
						if(iFreqChange == 1'b0)
						begin
							oFreqChangeComplete <= 0;
							InfoBuffer <= 0;
							f_SendCount <= 0;
							Count_state <= 0;
						end
				 end
			  13: begin
						m_ExperimentFinish <= 1; //pulse this high for two clock cycles only
						sel_SR <= 1; //allow access to sram for now.
						Count_state <= 14;
					end
			  14: begin
						Count_state <= 15;
					end
			  15: begin
						m_ExperimentFinish <= 0;
						InfoBuffer <= 0;
						f_SendCount <= 0;
						Count_state <= 0;
					end
			endcase
		end	
	end
	
end										
										
										
										
/////////////////////////////////////////////////////////
///////		Shift Register For Command Temp	/////////////
//The USB port outputs one byte at a time and this is pushed through to the 64 bit command buffer. We can't wait for all 64 bits 
//to come through as on USB connection and at various other signals 'other' bytes get sent along too so aligning along 64 bits
//will mean you sometimes won't pick up an instruction from the PC
always@(posedge iCLK )
begin
	if(mResetFPGA)
		CMD_Tmp<=0;
	else
	begin
		if(iRXD_Ready)
		CMD_Tmp<={CMD_Tmp[55:0],iRXD_DATA};
	end
end


/////////////////////////////////////////////////////////
////////////////	Flash Control	/////////////////////
always@(posedge iCLK )
begin
	if(mResetFPGA)
	begin
		oFL_TXD_Start	<=0;
		oFL_Start		<=0;
		f_FLASH			<=0;
		mFL_ST			<=0;
	end
	else
	begin
		if( CMD_Action == READ )
		oFL_CMD		<=	CMD_READ;
		else if( CMD_Action == WRITE )
		oFL_CMD		<=	CMD_WRITE;
		else if( CMD_Action == ERASE )
		oFL_CMD		<=	CMD_CHP_ERA;
		else
		oFL_CMD		<=	3'b000;
		
		if(iRXD_Ready && (Pre_Target == FLASH))
		f_FLASH<=1;
		if(f_FLASH)
		begin
			case(mFL_ST)
			0:	begin
					if( (CMD_MODE	== NORMAL) && (CMD_Target == FLASH) && (CMD_DATA[15:10] == 6'b111111) )
					begin
						oFL_ADDR	<=	CMD_ADDR;
						oFL_DATA	<=	CMD_DATA;
						oFL_Start<=	1;
						mFL_ST	<=	1;
					end
					else
					begin
						mFL_ST	<=	0;
						f_FLASH	<=	0;
					end
				end	
			1:	begin
					if(iFL_Ready)
					begin
						mFL_ST<=2;
						oFL_Start<=0;
					end	
				end
			2:	begin
					oFL_Start<=1;
					mFL_ST<=3;
				end
			3:	begin
					if(iFL_Ready)
					begin
						mFL_ST<=4;
						oFL_Start<=0;
					end	
				end
			4:	begin
					oFL_Start<=1;
					mFL_ST<=5;
				end			
			5:	begin
					if(iFL_Ready)
					begin
						if( (oFL_CMD == CMD_READ) )
							mFL_ST	<=	6;
						else
						begin
							mFL_ST	<=	0;
							f_FLASH	<=	0;							
						end
						oFL_Start	<=	0;
					end				
				end
			6:	begin
					oFL_TXD_DATA	<=	iFL_DATA;
					oFL_TXD_Start	<=	1;
					mFL_ST			<=	7;
				end
			7:	begin
					if(iTXD_Done)
					begin
						oFL_TXD_Start<=0;
						mFL_ST	<=	0;
						f_FLASH	<=	0;
					end
				end
			endcase
		end
	end
end

/////////////////////////////////////////////////////////
////////////////	Sdram Control	/////////////////////
reg [4:0] m_SDDataIO_ST;
reg f_SD_READ_REQUEST;

reg [21:0] NumInstructions = 0;
reg [21:0] NumInstructionsStored = 0;
reg f_FileUpload = 0;
reg [7:0] InstructionBuffer = 0;
reg f_InstructionBuffered = 0;

always@(posedge iCLK )
begin
	if(mResetFPGA)
	begin
		oSDR_TXD_Start	<=0;
		mSDR_WRn		<=0;
		mSDR_Start		<=0;
		f_SDRAM			<=0;
		mSDR_ST			<=0;
		m_SDDataIO_ST	<=0;
		oSD_DATA			<=0;
		oSD_DATA_READY <=0;
		f_SD_READ_REQUEST <=0;
		NumInstructions <= 0;
		f_FileUpload <= 0;
		InstructionBuffer <= 0;
		f_InstructionBuffered <= 0;
	end
	else
	begin
	// This all happens when the experiment is not running, and we are in "live" mode
	// When m_SD_DATA_FINISHED_UPLOAD is clear, we are in "live" mode.  When it's set we are in experiment mode
	if(m_SD_DATA_FINISHED_UPLOAD == 0) //if setup finish has not been sent then give PC access to SDRam otherwise only send count data back.
		begin
		
			if( CMD_Action == READ )
			mSDR_WRn	<=	1'b0; //Read ie NOT write.
			else if( CMD_Action == WRITE )
			mSDR_WRn	<=	1'b1;
			
			
			if(iRXD_Ready && (Pre_Target == SDRAM) && (f_FileUpload == 0) )
			f_SDRAM<=1;
			if(f_SDRAM)
			begin
				case(mSDR_ST)
				0:	begin	// Check if the command coming from the PC is the command to use the SDRAM
						if( (CMD_MODE	== NORMAL) && (CMD_Target == SDRAM) )
						begin							
							oSDR_ADDR	<=	CMD_ADDR[21:0];
							oSDR_DATA	<=	CMD_DATA;
							mSDR_Start	<= 	1;
							mSDR_ST		<=	1;							
						end
						else
						begin
							if(CMD_MODE	== FILEUPLOAD && (CMD_Target == SDRAM)) // This command mode is for sending a whole file to the SDRAM
							begin								
								NumInstructions <= CMD_ADDR[21:0];	// NumInstructions is the size of the file to be sent
								f_FileUpload <=1;	
								f_SDRAM	<=	0;
								mSDR_ST	<=	0;
							end
							else
							begin						
								mSDR_ST	<=	0;
								f_SDRAM	<=	0;
							end
						end
					end
				1:	begin	// Wait for the SDRAM to finish doing whatever it was doing
						if(iSDR_Done)
						begin
							if(mSDR_WRn == 1'b0) //if this was a read command send data to PC
								mSDR_ST	<=	2;		// READ
							else
							begin
								mSDR_ST	<=	0;		// WRITE
								f_SDRAM	<=	0;							
								mSDR_Start	<=	0;
							end
						end				
					end
				2:	begin	// Start sending the data to the PC (READ)
						oSDR_TXD_DATA	<= iSDR_DATA[7:0];	// Send the first byte
						oSDR_TXD_Start	<=	1;
						mSDR_ST			<=	3;
					end
				3:	begin	// Finished sending the first byte
						oSDR_TXD_Start	<=	0;	// Set "Output SDRAM Transmit" to zero to tell the system to stop transmitting the data from the SDRAM
						if(iTXD_Done)
						begin
							oSDR_TXD_Start<=0;
							mSDR_ST	<=	4;
						end											
					end
				4:	begin	// Send the second byte
						oSDR_TXD_DATA	<= 	iSDR_DATA[15:8];
						oSDR_TXD_Start	<=	1;
						mSDR_ST			<=	5;
					end
				5:	begin	// Finished sending the second byte
						oSDR_TXD_Start	<=	0;
						if(iTXD_Done)
						begin	// Reset reset reset
							mSDR_Start	<=	0;
							oSDR_TXD_Start<=0;
							mSDR_ST	<=	0;
							f_SDRAM	<=	0;
						end				
					end
				endcase
			end
		
			// Take a file which is being transmitted from the PC and put it into the SDRAM
			if(f_FileUpload)
			begin
				if(NumInstructionsStored == NumInstructions)
				begin
					f_FileUpload <= 0;
					NumInstructionsStored <= 0;
					f_InstructionBuffered <= 0;
					mSDR_Start	<= 	0;
				end
				else
				begin
					if(iRXD_Ready)	// This is set by uart after the entire byte iRXD_DATA has been clocked in
					begin
						if(f_InstructionBuffered == 0)
						begin
							mSDR_Start	<= 	0;
							InstructionBuffer <= iRXD_DATA;	// First 8 bits
							f_InstructionBuffered <= 1;
						end	
						else
						begin
							mSDR_WRn	<=	1'b1;
							oSDR_ADDR	<=	NumInstructionsStored;
							oSDR_DATA	<=	{InstructionBuffer,iRXD_DATA};	// Attach the second 8 bits.  oSDR_DATA is a 16 bit word.
							mSDR_Start	<= 	1;
							f_InstructionBuffered <= 0;
							NumInstructionsStored <= NumInstructionsStored + 1;
						end
					end
				end
			end
		
		end //m_SD_DATA_FINISHED_UPLOAD
		// This is when the experiment is running
	else if(m_SD_DATA_FINISHED_UPLOAD == 1)
		begin
			if(iSD_DATA_REQUEST == 1) //Data request goes high during the request and goes low afer.
			begin
				f_SD_READ_REQUEST <= 1'b1;
			end
			else
				oSD_DATA_READY <= 1'b0; //set to zero so that when request comes in we don't report that data is ready.
			begin
				
			end
			if(f_SD_READ_REQUEST == 1'b1)
			begin								
					case(m_SDDataIO_ST)
						0: begin
								oSD_DATA_READY <= 1'b0;
								oSDR_ADDR	<=	iSD_ADDR; //send outputs to SDRAM controller
								//oSDR_DATA	<=	16'b0000000000000000; //probably don't need this line as reading from sdram just throws this data away.
								mSDR_WRn	<=	1'b0; //NOT write operation (therefore a READ)
								mSDR_Start	<= 	1; //tell the sdram controller that there is a command
								m_SDDataIO_ST		<=	1;
							end
						1:	begin
								if(iSDR_Done)
								begin												
										m_SDDataIO_ST <= 2;
										mSDR_Start	<=	0;										
								end
							end
						2: begin
								oSD_DATA[31:16] <= iSDR_DATA;
								m_SDDataIO_ST <= 3;
							end
						3: begin
								oSDR_ADDR	<=	iSD_ADDR + 22'd1; //read the first 16 bits then the next 16 bits at Address + 1								
								mSDR_WRn	<=	1'b0; 
								mSDR_Start	<= 1; 						
								m_SDDataIO_ST <= 4;
							end
						4: begin
								if(iSDR_Done)
								begin													
										mSDR_Start	<=	0;	
										m_SDDataIO_ST <= 5;
								end								
							end
						5: begin
								oSD_DATA[15:0] <= iSDR_DATA;
								oSD_DATA_READY <= 1'b1;
								//f_SD_READ_REQUEST <= 0;
								m_SDDataIO_ST <= 6;
							end
						6: begin
								oSD_DATA_READY <= 1'b0;
								m_SDDataIO_ST <= 7; //we do need these extra stages so that we don't fetch the instruction twice
							end
						7: begin
								f_SD_READ_REQUEST <= 0;
								m_SDDataIO_ST <= 0;
							end
					endcase
			end	
		end
	end
end
assign	oSDR_WR	=	mSDR_WRn & mSDR_Start;
assign	oSDR_RD	=	~mSDR_WRn & mSDR_Start;


reg mReadingFinished = 0;

reg [18:0] NumDataStored = 0; //change back to 17??

reg [18:0] DataAddrToSend = 0; //change back to 17??
reg [15:0] DataToSend = 0;

reg [3:0] f_DataState = 0;
reg f_StoreCount = 0;
/////////////////////////////////////////////////////////
////////////////	SRAM Control	/////////////////////
always@(posedge iCLK )
begin
	
	if(mResetFPGA)
	begin
		oSR_TXD_Start	<=0;
		mSR_WRn			<=0;
		mSR_Start		<=0;
		f_SRAM			<=0;
		mSR_ST			<=0;
		NumDataStored  <= 0;
		f_DataState    <= 0;
		f_StoreCount   <= 0;
		DataAddrToSend <= 0;
		DataToSend <= 0;
		//mReadingFinished <= 0;
	end
	else
	begin		
	
		if(iSendData == 1 && iCountReady == 1'b0 && f_StoreCount == 1'b0 && (f_FileUpload == 0) 
			&& sel_SR == 1 && mReadingFinished == 0 ) //if sending data, allow PC access. Dont switch to this if we need to store data or currently busy
		begin	
	
			mSR_WRn	<=	1'b0;
			
			if(DataAddrToSend != (NumDataStored))
			begin	
				case(mSR_ST)
					0:	begin						
								oSR_ADDR	<=	DataAddrToSend;							
								mSR_Start	<= 	1;
								mSR_ST		<=	1;							
						end
					1:	begin
							if(mSR_WRn == 1'b0)
								mSR_ST	<=	2;
							else
							begin //don't think we need these three lines
								mSR_ST	<=	0;
								f_SRAM	<=	0;							
								mSR_Start	<=	0;
							end
						end
					2:	begin
							oSR_TXD_DATA	<= 	iSR_DATA[7:0];
							oSR_TXD_Start	<=	1;
							mSR_ST			<=	3;
						end
					3:	begin
							oSR_TXD_Start <= 0;
							if(iTXD_Done)
							begin
								oSR_TXD_Start<=0;
								mSR_ST	<=	4;
							end											
						end
					4:	begin
							oSR_TXD_DATA	<= 	iSR_DATA[15:8];
							oSR_TXD_Start	<=	1;
							mSR_ST			<=	5;
						end
					5:	begin
							oSR_TXD_Start <= 0;
							if(iTXD_Done)
							begin
								mSR_Start	<=	0;
								oSR_TXD_Start<=	0;
								mSR_ST		<=	0;	
								DataAddrToSend <= DataAddrToSend + 1;
							end				
						end
				endcase
			end
			else
			begin
				//mReadingFinished <= 1;	
				//DataAddrToSend <= 0;
			end
	
			/*if( CMD_Action == READ )
			mSR_WRn	<=	1'b0;
			else if( CMD_Action == WRITE )
			mSR_WRn	<=	1'b1; //Todo: Don't allow PC to send write command
		
			if(iRXD_Ready && (Pre_Target == SRAM))
			begin
				f_SRAM<=1;
			end
			
			if(f_SRAM)
			begin
				case(mSR_ST)
				0:	begin
						if( (CMD_MODE	== NORMAL) && (CMD_Target == SRAM) )
						begin
							oSR_ADDR	<=	CMD_ADDR;
							oSR_DATA	<=	CMD_DATA;
							mSR_Start	<= 	1;
							mSR_ST		<=	1;
						end
						else
						begin
							mSR_ST	<=	0;
							f_SRAM	<=	0;
						end
					end
				1:	begin
						if(mSR_WRn == 1'b0)
							mSR_ST	<=	2;
						else
						begin
							mSR_ST	<=	0;
							f_SRAM	<=	0;							
							mSR_Start	<=	0;
						end
					end
				2:	begin
						oSR_TXD_DATA	<= 	iSR_DATA[7:0];
						oSR_TXD_Start	<=	1;
						mSR_ST			<=	3;
					end
				3:	begin
						oSR_TXD_Start <= 0;
						if(iTXD_Done)
						begin
							oSR_TXD_Start<=0;
							mSR_ST	<=	4;
						end											
					end
				4:	begin
						oSR_TXD_DATA	<= 	iSR_DATA[15:8];
						oSR_TXD_Start	<=	1;
						mSR_ST			<=	5;
					end
				5:	begin
						oSR_TXD_Start <= 0;
						if(iTXD_Done)
						begin
							mSR_Start	<=	0;
							oSR_TXD_Start<=	0;
							mSR_ST		<=	0;
							f_SRAM		<=	0;
						end				
					end
				endcase
			end //if(f_SRAM)*/
		end 	
		else //(if iSendData == 0) write count readings to memory
		begin
			if(iCountReady)
			begin
				f_StoreCount <= 1;
				mSR_WRn <= 1;
			end //if(iCountReady)
			
			if(f_StoreCount)
			begin
				case(f_DataState)
				0:	begin			
							oSR_ADDR	<=	NumDataStored;
							oSR_DATA	<=	iCountData;
							mSR_Start	<= 	1;
							f_DataState		<=	1;						
					end
				1:	begin		// This is an extra step to giv ourselves 1 clock cycles worth of leeway
							f_DataState	<=	2;
							//f_StoreCount	<=	0;							
							mSR_Start	<=	0;
							//NumDataStored <= NumDataStored + 1;
					end
				2:	begin		
							f_DataState	<=	3;													
							oSR_ADDR	<=	NumDataStored + 1;
							oSR_DATA	<=	iErrorSignal;
							mSR_Start	<= 	1;
							//NumDataStored <= NumDataStored + 1;
					end
				3:	begin		
							f_DataState	<=	0;
							f_StoreCount	<=	0;							
							mSR_Start	<=	0;
							NumDataStored <= NumDataStored + 2; // This is add 2 becuase there are 2 16 bit numbers per interegation
					end
				endcase
			end			
		end //if(iSendData == 1) else
	
		if(mReadingFinished)
		begin
			NumDataStored <= 0;
			DataAddrToSend <= 0;
			//mReadingFinished <= 0;
		end
		
	end //reset
end

assign	oSR_OE_N	=	~(~mSR_WRn & mSR_Start );
assign	oSR_WE_N	=	~( mSR_WRn & mSR_Start );

/////////////////////////////////////////////////////////

endmodule 