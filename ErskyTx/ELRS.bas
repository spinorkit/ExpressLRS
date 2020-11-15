rem -- This script requires ErskTx R223A6 or later. 
rem -- See https://openrcforums.com/forum/viewtopic.php?f=7&t=4676&sid=25e7416b867f2c94a6382fbff922d082

rem -- Note: ErskyTx uses 400000 baud to talk to crossfire modules, and therefore ELRS.
rem -- If you have a 2018 R9M module (with the ACCST logo on the back), you need the 
rem -- resistor mod for reliable communuication:
rem -- https://github.com/AlessandroAU/ExpressLRS/wiki/Inverter-Mod-for-R9M-2018

array byte rxBuf[64]
array byte transmitBuffer[64]
rem -- array byte paramNames[96]


if init = 0
   init = 1

   pktsRead = 0
   pktsSent = 0
   pktsGood = 0
   elrsPkts = 0
   rxBuf2 = 0;

   PARAMETER_WRITE = 0x2D

   rem -- max param name is 11 = 10 + null
   kMaxParamNameLen = 11
   rem -- strtoarray(paramNames,"Pkt Rate:\0\0TLM Ratio:\0Power:\0\0\0\0\0RF freq:")

   AirRateIdx = 0
   TLMintervalIdx = 8
   MaxPowerIdx = 0
   RFfreqIdx = 6

   kNumEditParams = 4

   selectedParam = 0

   isSendIncParam = 0

   kStateWaitingForParams = 0
   kReceivedParams = 1
   state = kWaitingForParams

   rem -- purge the crossfire packet fifo
   result = crossfirereceive(count, command, rxBuf)
   while result = 1
   result = crossfirereceive(count, command, rxBuf)
   end

   rem gosub requestDeviceData
end
goto main

sendPacket:
   result = crossfiresend(sendCommand, sendLength, transmitBuffer)
   if result = 1
      pktsSent += 1
   end
   return

sendPingPacket:
   rem -- crossfireTelemetryPush(0x2D, {0xEE, 0xEA, 0x00, 0x00}) ping until we get a resp
   sendCommand = PARAMETER_WRITE
   sendLength = 4
   transmitBuffer[0]=0xEE
   transmitBuffer[1]=0xEA
   transmitBuffer[2]=0x00
   transmitBuffer[3]=0x00

   gosub sendPacket
   return

sendParamIncDecPacket:
   sendCommand = PARAMETER_WRITE
   sendLength = 4
   transmitBuffer[0]=0xEE
   transmitBuffer[1]=0xEA
   transmitBuffer[2]=selectedParam+1
   transmitBuffer[3]=isSendIncParam

   gosub sendPacket
   return

checkForPackets:
   command = 0
   count = 0

   result = crossfirereceive(count, command, rxBuf)
   while result = 1
      if (command = 0x2D) & (rxBuf[0] = 0xEA) & (rxBuf[1] = 0xEE)
         pktsRead += 1
         if (rxBuf[2] # 0xFF)
            rxBuf2 = rxBuf[2]
         end
         if (rxBuf[2] = 0xFF)
            bindMode = (rxBuf[3] = 1)
         elseif (rxBuf[2] = 0xFE)
         elseif (rxBuf[2] = 0xF0)
         elseif (rxBuf[2] = 0xF1)
         else
            elrsPkts += 1
            AirRateIdx = rxBuf[2]-1
            TLMintervalIdx = rxBuf[3]-1
            MaxPowerIdx = rxBuf[4]-1
            RFfreqIdx = rxBuf[5]-1
         end
         state = kReceivedParams
      end

      result = crossfirereceive(count, command, rxBuf)
   end
   return

nextParameter:
   selectedParam += 1
   if selectedParam >= kNumEditParams then selectedParam = 0 
return

previousParameter:
   selectedParam -= 1
   if selectedParam < 0 then selectedParam = kNumEditParams - 1
return

decrementParameter:
isSendIncParam = 0;
gosub sendParamIncDecPacket
return

incrementParameter:
isSendIncParam = 1;
gosub sendParamIncDecPacket
return

main:
   time = gettime()
   gosub checkForPackets

 	if state = kWaitingForParams 
		rem -- crossfireTelemetryPush(0x2D, {0xEE, 0xEA, 0x00, 0x00}) -- ping until we get a resp
      gosub sendPingPacket
	end

   if (Event = EVT_DOWN_FIRST) | (Event = EVT_DOWN_REPT)
      gosub nextParameter
   elseif (Event = EVT_UP_FIRST) | (Event = EVT_UP_REPT)
      gosub previousParameter
   elseif (Event = EVT_LEFT_FIRST) | (Event = EVT_LEFT_REPT)
      gosub decrementParameter
   elseif (Event = EVT_RIGHT_FIRST) | (Event = EVT_RIGHT_REPT)
      gosub incrementParameter
   end

   drawclear()
   valueXPos = 60
   ygap = 10
   yPos = 0
   drawtext(0, yPos, "ELRS Setup", INVERS)
   rem if param = selectedParam then attr = INVERS

   param = 0
   yPos = (param+1)*ygap
   drawtext(0, yPos, "Pkt Rate:")
   drawtext(valueXPos,yPos,"------\0AUTO  \0 500Hz\0 250Hz\0 200Hz\0 150Hz\0 100Hz\0  50Hz\0  25Hz\0   4Hz"[AirRateIdx*7],(param=selectedParam)*INVERS)

   param += 1
   yPos = (param+1)*ygap
   drawtext(0, yPos, "TLM Ratio:")
   drawtext(valueXPos,yPos,"   Off\0 1:128\0  1:64\0  1:32\0  1:16\0   1:8\0   1:4\0   1:2\0------"[TLMintervalIdx*7],(param=selectedParam)*INVERS)

   param += 1
   yPos = (param+1)*ygap
   drawtext(0, yPos, "Power:")
   drawtext(valueXPos,yPos,"------ \0  10 mW\0  25 mW\0  50 mW\0 100 mW\0 250 mW\0 500 mW\0    1 W\0    2 W"[MaxPowerIdx*8],(param=selectedParam)*INVERS)

   param += 1
   yPos = (param+1)*ygap
   drawtext(0, yPos, "RF freq:")
   drawtext(valueXPos,yPos," 915 AU \0 915 FCC\0 868 EU \0 433 AU \0 433 EU \0 2G4 ISM\0------"[RFfreqIdx*9],(param=selectedParam)*INVERS)

   param += 1
   yPos = (param+1)*ygap
   drawtext(0,yPos,"elrsPkts:")
   drawnumber(valueXPos,yPos,elrsPkts)

   stop

exit:
   finish
