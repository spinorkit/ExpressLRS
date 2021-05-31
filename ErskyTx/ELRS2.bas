rem -- This script requires ErskTx R223A6 or later. 
rem -- See https://openrcforums.com/forum/viewtopic.php?f=7&t=4676&sid=25e7416b867f2c94a6382fbff922d082

rem -- Note: ErskyTx uses 400000 baud to talk to crossfire modules, and therefore ELRS.
rem -- If you have a 2018 R9M module (with the ACCST logo on the back), you need the 
rem -- resistor mod for reliable communuication:
rem -- https://github.com/AlessandroAU/ExpressLRS/wiki/Inverter-Mod-for-R9M-2018

array byte rxBuf[64]
array byte transmitBuffer[64]

array byte paramNames[96]
array params[16]
array paramMaxs[16]
array paramMins[16]

array validAirRates127[8]
array validAirRates128[8]
array validAirRates[8]

if init = 0
   init = 1

   rem -- try to detect e.g. Taranis style Tx
   isTaranisStyle = sysflags() & 0x20

   eventLeft = EVT_LEFT_FIRST
   eventRight = EVT_RIGHT_FIRST
   eventUp = EVT_UP_FIRST
   eventDown = EVT_DOWN_FIRST

   eventLeftRept = EVT_LEFT_REPT
   eventRightRept = EVT_RIGHT_REPT
   eventUpRept = EVT_UP_REPT
   eventDownRept = EVT_DOWN_REPT

   if isTaranisStyle # 0
      eventLeft = EVT_UP_FIRST
      eventRight = EVT_DOWN_FIRST
      eventUp = EVT_MENU_BREAK
      eventDown = EVT_LEFT_FIRST

      eventLeftRept = EVT_UP_REPT
      eventRightRept = EVT_DOWN_REPT
      eventUpRept = eventUp
      eventDownRept = eventDown
   end

   pktsRead = 0
   pktsSent = 0
   pktsGood = 0
   elrsPkts = 0
   kMinCommandInterval10ms = 100
   lastChangeTime = gettime()


   PARAMETER_WRITE = 0x2D

   rem -- Note: list indexes must match to param handling in tx_main!
   rem -- list = {AirRate, TLMinterval, MaxPower, RFfreq, Bind, WebServer},


   rem -- max param name len is 11 = 10 + null

   kAirRateParamIdx = 0
   kTLMintervalParamIdx = 1
   kMaxPowerParamIdx = 2
   kRFfreqParamIdx = 3
   kNParams = 4

   kMaxParamNameLen = 11
   strtoarray(paramNames,"Pkt Rate:\0\0TLM Ratio:\0Power:\0\0\0\0\0RF freq:")

   paramMins[kAirRateParamIdx] = 0
   paramMaxs[kAirRateParamIdx] = 3
   paramMins[kTLMintervalParamIdx] = 0
   paramMaxs[kTLMintervalParamIdx] = 7
   paramMins[kMaxPowerParamIdx] = 0
   paramMaxs[kMaxPowerParamIdx] = 7


   rem -- 433/868/915 (SX127x) '25 Hz', '50 Hz', '100 Hz', '200 Hz'
   kNSX127Rates = 4
   validAirRates127[0] = 6
   validAirRates127[1] = 5
   validAirRates127[2] = 4
   validAirRates127[3] = 2

   rem -- 2.4 GHz (SX128x) '50 Hz', '150 Hz', '250 Hz'
   kNSX128Rates = 4
   validAirRates128[0] = 6
   validAirRates128[1] = 5
   validAirRates128[2] = 3
   validAirRates128[3] = 1

   band24GHz = 0
   nValidAirRates = kNSX127Rates

   i = 0
   while i < kNParams
      params[i]  = -1
      i += 1
   end


   bindMode = 0
   wifiupdatemode = 0

   UartGoodPkts = 0
   UartBadPkts = 0

   StopUpdate = 0

   kNumEditParams = 3

   selectedParam = 0

   incDecParam = 0

   kInitializing = 0
   kReceivedParams = 1
   kWaitForUpdate = 2
   state = kInitializing

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
   if state # kReceivedParams then return
   rem -- if gettime() - lastChangeTime < kMinCommandInterval10ms then return

   origValue = params[selectedParam]
   if selectedParam = kAirRateParamIdx
      rem -- find the index of the current value
      AirRateIdx = params[kAirRateParamIdx]
      i = 0
      if band24GHz = 1
         nValidAirRates = kNSX128Rates
         while i < nValidAirRates
            validAirRates[i] = validAirRates128[i]
            i += 1
         end
      else
         nValidAirRates = kNSX127Rates
         while i < nValidAirRates
            validAirRates[i] = validAirRates127[i]
            i += 1
         end
      end
      i = 0
      while i < nValidAirRates
         if validAirRates[i] = AirRateIdx then break
         i += 1
      end
      i += incDecParam
      if i >= nValidAirRates
         i = nValidAirRates-1
      elseif i < 0
         i = 0
      end
      value = validAirRates[i]
   else
      value = params[selectedParam]
      value += incDecParam
      if value > paramMaxs[selectedParam]
         value = paramMaxs[selectedParam]
      elseif value < paramMins[selectedParam]
         value = paramMins[selectedParam]
      end
   end

   if value = origValue then return

   sendCommand = PARAMETER_WRITE
   sendLength = 4
   transmitBuffer[0]=0xEE
   transmitBuffer[1]=0xEA
   transmitBuffer[2]=selectedParam+1
   transmitBuffer[3]=value

   state = kWaitForUpdate
   lastChangeTime = gettime()
elrsPkts += 1

   gosub sendPacket
   return

checkForPackets:
   command = 0
   count = 0

   result = crossfirereceive(count, command, rxBuf)
   while result = 1
      if (command = 0x2D) & (rxBuf[0] = 0xEA) & (rxBuf[1] = 0xEE)
         pktsRead += 1

         if ((rxBuf[2] = 0xFF) & (count >= 11))
            bindMode = (rxBuf[3] & 1)
            wifiupdatemode = (rxBuf[3] & 2)

            if StopUpdate = 0
               params[kAirRateParamIdx] = rxBuf[4]
               params[kTLMintervalParamIdx] = rxBuf[5]
               params[kMaxPowerParamIdx] = rxBuf[6]
               params[kRFfreqParamIdx] = rxBuf[7]-1

               band24GHz = 0
               if rxBuf[7] = 6
                  band24GHz = 1
               end

               state = kReceivedParams
               rem -- elrsPkts += 1
            end

				UartBadPkts = rxBuf[8]
				UartGoodPkts = rxBuf[9] * 256 + rxBuf[10] 

         elseif ((rxBuf[2] = 0xFE) & (count = 9))
            rem -- First half of commit sha
         end
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
incDecParam = -1;
gosub sendParamIncDecPacket
return

incrementParameter:
incDecParam = 1;
gosub sendParamIncDecPacket
return

main:
   gosub checkForPackets

 	if state = kInitializing 
		rem -- crossfireTelemetryPush(0x2D, {0xEE, 0xEA, 0x00, 0x00}) -- ping until we get a resp
      gosub sendPingPacket
	end

   if (Event = eventDown) | (Event = eventDownRept)
      gosub nextParameter
   elseif (Event = eventUp) | (Event = eventUpRept)
      gosub previousParameter
   elseif (Event = eventLeft) | (Event = eventLeftRept)
      gosub decrementParameter
   elseif (Event = eventRight) | (Event = eventRightRept)
      gosub incrementParameter
   end

   drawclear()
   valueXPos = 60
   ygap = 10
   yPos = 0
   drawtext(0, yPos, "ELRS", INVERS)
   if wifiupdatemode = 1
      drawtext(30, yPos, "http://10.0.0.1")
   elseif bindMode = 1
      drawtext(30, yPos, "Bind not needed")
   else
      drawnumber(50,yPos, UartBadPkts)
      drawtext(50, yPos, ":")
      drawnumber(70,yPos, UartGoodPkts)
   end
   rem if param = selectedParam then attr = INVERS

   param = 0
   idx = params[param]+1
   yPos = (param+1)*ygap
   drawtext(0, yPos, "Pkt Rate:")
   rem -- drawtext(valueXPos,yPos,"------\0AUTO  \0 500Hz\0 250Hz\0 200Hz\0 150Hz\0 100Hz\0  50Hz\0  25Hz\0   4Hz"[AirRateIdx*7],(param=selectedParam)*INVERS)
   drawtext(valueXPos,yPos,"------\0 500Hz\0 250Hz\0 200Hz\0 150Hz\0 100Hz\0  50Hz\0  25Hz\0   4Hz"[idx*7],(param=selectedParam)*INVERS)

   param += 1
   idx = params[param]+1
   yPos = (param+1)*ygap
   drawtext(0, yPos, "TLM Ratio:")
   drawtext(valueXPos,yPos,"------\0   Off\0 1:128\0  1:64\0  1:32\0  1:16\0   1:8\0   1:4\0   1:2"[idx*7],(param=selectedParam)*INVERS)

   param += 1
   idx = params[param]+1
   yPos = (param+1)*ygap
   drawtext(0, yPos, "Power:")
   drawtext(valueXPos,yPos,"------ \0  10 mW\0  25 mW\0  50 mW\0 100 mW\0 250 mW\0 500 mW\0    1 W\0    2 W"[idx*8],(param=selectedParam)*INVERS)

   param += 1
   idx = params[param]+1
   yPos = (param+1)*ygap
   drawtext(0, yPos, "RF freq:")
   drawtext(valueXPos,yPos,"------\0 915 AU \0 915 FCC\0 868 EU \0 433 AU \0 433 EU \0 2G4 ISM"[idx*9],(param=selectedParam)*INVERS)

   param += 1
   yPos = (param+1)*ygap
   drawtext(0,yPos,"elrsPkts:")
   drawnumber(valueXPos+15,yPos,elrsPkts)

   stop

exit:
   finish
