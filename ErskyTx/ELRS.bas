array byte rxBuf[64]
array byte transmitBuffer[64]


if init = 0
   init = 1

   responseTimeout = 0
   waitForResponse = 0

   pktsRead = 0
   pktsSent = 0
   pktsGood = 0
   elrsPkts = 0
   rxBuf2 = 0;

   PARAMETER_WRITE = 0x2D


   PARAMETER_TIMEOUT = 20
   PARAMETER_REFETCH_TIMEOUT = 300
   SET_PARAMETER_TIMEOUT = 100
   SEND_FAIL_TIMEOUT = 10

   kMaxMenuItems = 16

   AirRateIdx = 0
   TLMintervalIdx = 8
   MaxPowerIdx = 0
   RFfreqIdx = 6

   kNumEditParams = 4
   selectedParam = 0

   isSendIncParam = 0

   kStateWaitingForParams = 0
   kHaveParams = 1
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
        responseTimeout = time + sendTimeout
    else
        responseTimeout = time + SEND_FAIL_TIMEOUT
    end
    return

   sendPingPacket:
   rem -- crossfireTelemetryPush(0x2D, {0xEE, 0xEA, 0x00, 0x00}) ping until we get a resp
   sendCommand = 0x2D
   sendLength = 4
   transmitBuffer[0]=0xEE
   transmitBuffer[1]=0xEA
   transmitBuffer[2]=0x00
   transmitBuffer[3]=0x00
    sendTimeout = PARAMETER_TIMEOUT
    waitForResponse = 1

   gosub sendPacket
   return

   sendParamIncDecPacket:
   sendCommand = 0x2D
   sendLength = 4
   transmitBuffer[0]=0xEE
   transmitBuffer[1]=0xEA
   transmitBuffer[2]=selectedParam+1
   transmitBuffer[3]=isSendIncParam
    sendTimeout = PARAMETER_TIMEOUT
    waitForResponse = 1

   gosub sendPacket
   return

   return

sendNextPacket:
    rem -- if we're waiting for a response, retransmit the previous
    rem -- packet after a timeout
    if waitForResponse = 1 & responseTimeout > 0
        if time > responseTimeout
            gosub sendPacket
        end
        return
    end

    rem -- should we refresh any parameters?
    rem -- don't bother if we're in the device list page

    rem -- should we refresh devices?
    rem -- nah.

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
         state = kHaveParams
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
    attr = 0
    xValPos = 60
    ypos = 0
    ygap = 10
    drawtext(0, ypos*ygap, "ELRS Setup", INVERS)
    if ypos = selectedParam then attr = INVERS
    ypos += 1
    drawtext(0, ypos*ygap, "Pkt Rate:")
    drawtext(xValPos,ypos*ygap,"------\0AUTO  \0 500Hz\0 250Hz\0 200Hz\0 150Hz\0 100Hz\0  50Hz\0  25Hz\0   4Hz"[AirRateIdx*7],attr)
    attr = 0
    if ypos = selectedParam then attr = INVERS
    ypos += 1
    drawtext(0, ypos*ygap, "TLM Ratio:")
    drawtext(xValPos,ypos*ygap,"   Off\0 1:128\0  1:64\0  1:32\0  1:16\0   1:8\0   1:4\0   1:2\0------"[TLMintervalIdx*7],attr)
    attr = 0
    if ypos = selectedParam then attr = INVERS
    ypos += 1
    drawtext(0, ypos*ygap, "Power:")
    drawtext(xValPos,ypos*ygap,"------ \0  10 mW\0  25 mW\0  50 mW\0 100 mW\0 250 mW\0 500 mW\0    1 W\0    2 W"[MaxPowerIdx*8],attr)
    attr = 0
    if ypos = selectedParam then attr = INVERS
    ypos += 1
    drawtext(0, ypos*ygap, "RF freq:")
    drawtext(xValPos,ypos*ygap," 915 AU \0 915 FCC\0 868 EU \0 433 AU \0 433 EU \0 2G4 ISM\0------"[RFfreqIdx*9],attr)
    ypos += 1

    attr = 0
    drawtext(0,ypos*ygap,"elrsPkts:")
    drawnumber(xValPos,ypos*ygap,elrsPkts)


    rem gosub sendNextPacket
    stop

exit:
    finish
