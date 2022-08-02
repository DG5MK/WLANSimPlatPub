% function to simulate CSMA/SR and CSMA/SDMSR based on basic CSMA/CA for HE MU packets
% version to cover decentral SDM access, each AP may join a TX SDM slot defined by SRRTS of lead AP
function [stats,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,...
    SINRcalc,OSCHAP,OSCHSTA,TRPsumMCS,LT] = WorkOnEvent_A2B_CSMA_SDMSRV1(approach,stats,all_bss,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,...
    txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,all_pathloss_STA_DL,all_pathloss_AP_DL,tgaxSTA_DL,tgaxAP_DL,all_pathloss_STA_UL,all_pathloss_AP_UL,tgaxSTA_UL,tgaxAP_UL,awgnChannel,simulation,cfgSimu,saveCFG,...
    APSTATE,APCNT,APSTACNT,SINRest,SINRcalc,OSCHAP,OSCHSTA,TRPsumMCS,fid,PL2TXSU,PL2TXMU,LT)

SLOTTIME = simulation.SLOTTIME;
SIFS = simulation.SIFS;
DIFS = simulation.DIFS;
EIFS = simulation.EIFS;
SRIFSBase = simulation.SRIFSBase;
CWMIN = simulation.CWMIN;
CWMAX = simulation.CWMAX;
CWVector = simulation.CWVector;
CCA_ED = simulation.CCA_ED;
diag = simulation.diag;
ACCTime = simulation.AccSimuTime;   % same as idxTime
OLDTime = simulation.OldSimuTime;

switch approach
    
    case 'A'
%         simulation.DRC = simulation.A.DRC;
        simulation.NOINT = simulation.A.NOINT;
%         simulation.ESTSINR = simulation.A.ESTSINR;
        simulation.BEAMFORMING = simulation.A.BEAMFORMING;
        simulation.SchedAllocMethod = simulation.A.SchedAllocMethod;

        
    case 'B'
%         simulation.DRC = simulation.B.DRC;
        simulation.NOINT = simulation.B.NOINT;
%         simulation.ESTSINR = simulation.B.ESTSINR;
        simulation.BEAMFORMING = simulation.B.BEAMFORMING;
        simulation.SchedAllocMethod = simulation.B.SchedAllocMethod;
        
end  

NewEvent = GEQ(1,:);    % next event is subtable, just one row
idxTime = NewEvent.(1);
idxAP = NewEvent.(2);
idxSTA = NewEvent.(3);
EventType = NewEvent.(4);


switch EventType

    case 'APCycle'
        
    % First version of CSMA/SDM acting as a virtual switch to transmit multiple APs in parallel on
    % different streams with HE-MU PPDUs. The flow is the same as CSMA/SR V2 with lead AP configuring
    % the TX slot for all eligible APs after contention win:
    % 1) Normal CCA with DIFS drives AP to send SRRTS packet (TPmax, MCSmax, TXdur, StreamID). Virtual packet receive 
    %    drives all APs to join TX slot up to defined maximum TP, MCS and duration or move to IDLE Mode.
    % 2) TX slot starts one slottime after end of SRRTS packet.
    % 2) All transmitting AP start transmission.
    
    % AP cycle based on Slottime and AP state:
    %
    % States move from Idle to CCA to IFS to CCA/BO to SRRTS to APTX/Idle to RX to Idle
    %
    % 'APIdle': any data on queues? 
    %   NO: 'APIdle' + 'IDLE time'1ST + new slottime cycle/jump after next event 
    %   YES: Channel free?
    %       NO: 'APCCA' + 'WAIT time'1ST + new slottime cycle
    %       YES: 'APIFS' + 'IFS time'1ST + new slottime cycle + set cnt IFS
    % 'APCCA': channel free?
    %   NO: 'APCCA' + 'WAIT time'1ST + new slottime cycle
    %   YES: 'APIFS' + 'IFS time'1ST + new slottime cycle + set cnt IFS
    % 'APIFS': channel still free?
    %   NO: 'APCCA' + 'wait time'1ST + new slottime cycle
    %   YES: cnt IFS = 0?
    %       YES: 'APBO' + 'IFS time'1ST + new slottime cycle + set cnt BO, if zero
    %       NO: 'APIFS' + 'IFS time'1ST + new slottime cycle + dec cnt IFS-1ST;
    %   'APBO': channel still free?
    %   NO: 'APCCA' + 'wait time'1ST + new slottime cycle
    %   YES: cnt BO = 0?
    %       YES 'APBO': any data on queues? 
    %           YES: 'APSRRTS' + 'SRRTS time'1ST + set APLead + new RTS event current time
    %           NO: 'APIdle' + 'IDLE time'1ST + new slottime cycle/jump after next event
    %       NO: 'APBO' + 'BO time'1ST + new slottime cycle + dec cnt BO-1ST;
    % 'APSRRTS': evaluate SDM, send SRRTS packet, virtually set all AP's maxTP, maxMCS, TXdur, streamID
    %       Any AP: any data on queue and allowed to join TX-slot?
    %           YES:'APTX' + 'SRRTS time' + new TX event current time
    %           NO: 'APIdle' + 'wait time' + new slottime cycle/jump after next event
    % 'APTX': transmit: select data round robin, put pending queue, send packet, reset all AP vars,
    %                   'APRX' + 'header/data time' + new RX event end of packet
    % 'APRX': receive: PE?
    %       YES: note PE, data queue handling etc., 'APACK' new slottime cycle
    %       No: TP note, data queue handling etc., 'APIdle' new slottime cycle
    % 'APACK': put ACK on channel after packet without PE + ACK time + new event
    
        switch APSTATE(idxAP)
            
            case "APIdle"

                % 'APIdle': any data on queues?
                numSTAs = size(all_bss{idxAP}.STAs_pos,1);
                flagData = false;
                for idxSTA = 1:numSTAs
                    if DATAQ(idxAP,idxSTA) > 0
                        flagData = true;
                    end
                end

                if flagData == false
                    % NO: 'APIdle' + 'idle time'1ST + new slottime cycle/jump after next event
                    APSTATE(idxAP) = "APIdle";
                    if height(GEQ) > 1  % 2nd next event available?
                        nextEventTime = GEQ(2,:).(1);
                        stats.TimeIdle(idxAP) = stats.TimeIdle(idxAP) + (nextEventTime-idxTime) + SLOTTIME*1e-6;
                        newevent = {nextEventTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                    else
                        stats.TimeIdle(idxAP) = stats.TimeIdle(idxAP) + SLOTTIME*1e-6;
                        newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                    end
                    GEQ = [GEQ;newevent];
                    logF(fid,idxTime,stats,idxAP,0,'APIdle-DQEmpty        ','',0,'',0,'',0,'',0,'',0,simulation);
                else
                    % YES: Channel free?
                    idxSample = round(idxTime/simulation.Ts);
                    idxCH = all_bss{idxAP}.ch;
                    actAPSigLevel_dBm = CheckAPSignalLevel(idxAP,idxCH,CHAP,idxSample,simulation,OSCHAP);               
                    if actAPSigLevel_dBm < CCA_ED
                        % YES: 'APIFS' + 'IFS time'1ST + new slottime cycle + set cnt IFS
                        APSTATE(idxAP) = "APIFS";
                        stats.TimeIFS(idxAP) = stats.TimeIFS(idxAP) + SLOTTIME*1e-6;
                        newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                        GEQ = [GEQ;newevent];
                        APCNT{idxAP}.IFS = getIFScnt(APCNT,idxAP,simulation);
                        logF(fid,idxTime,stats,idxAP,0,'APIdle-CHIdle         ','APSigL',actAPSigLevel_dBm,...
                            '',0,'',0,'',0,'',0,simulation);
                    else
                        % NO: 'APCCA' + 'wait time'1ST + new slottime cycle
                        APSTATE(idxAP) = "APCCA";
                        stats.TimeWait(idxAP) = stats.TimeWait(idxAP) + SLOTTIME*1e-6;
                        newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                        GEQ = [GEQ;newevent];
                        logF(fid,idxTime,stats,idxAP,0,'APIdle-CHBusy         ','APSigL',actAPSigLevel_dBm,...
                            '',0,'',0,'',0,'',0,simulation);
                    end
                end

            case "APCCA"

                % 'APCCA': channel free?
                idxSample = round(idxTime/simulation.Ts);
                idxCH = all_bss{idxAP}.ch;
                actAPSigLevel_dBm = CheckAPSignalLevel(idxAP,idxCH,CHAP,idxSample,simulation,OSCHAP);               
                if (actAPSigLevel_dBm < CCA_ED)  && (CheckAPCycle(APCNT) == 0)
                    % YES: 'APIFS' + 'IFS time'1ST + new slottime cycle + set cnt IFS
                    APSTATE(idxAP) = "APIFS";
                    stats.TimeIFS(idxAP) = stats.TimeIFS(idxAP) + SLOTTIME*1e-6;
                    newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                    GEQ = [GEQ;newevent];
                    APCNT{idxAP}.IFS = getIFScnt(APCNT,idxAP,simulation);
                    logF(fid,idxTime,stats,idxAP,0,'APCCA-CHIdle          ','APSigL',actAPSigLevel_dBm,...
                        '',0,'',0,'',0,'',0,simulation);
                else
                    % NO: 'APCCA' + 'wait time'1ST + new slottime cycle
                    APSTATE(idxAP) = "APCCA";
                    stats.TimeWait(idxAP) = stats.TimeWait(idxAP) + SLOTTIME*1e-6;
                    newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                    GEQ = [GEQ;newevent];
                    if (CheckAPCycle(APCNT) == 0)
                        logF(fid,idxTime,stats,idxAP,0,'APCCA-CHBusy          ','APSigL',actAPSigLevel_dBm,...
                            '',0,'',0,'',0,'',0,simulation);
                    else
                        logF(fid,idxTime,stats,idxAP,0,'APCCA-APCycle         ','APSigL',actAPSigLevel_dBm,...
                            '',0,'',0,'',0,'',0,simulation);
                    end                   
                end                

            case "APIFS"

                % 'APIFS': channel still free?
                idxSample = round(idxTime/simulation.Ts);
                idxCH = all_bss{idxAP}.ch;
                actAPSigLevel_dBm = CheckAPSignalLevel(idxAP,idxCH,CHAP,idxSample,simulation,OSCHAP);               
                if actAPSigLevel_dBm < CCA_ED
                    % YES: cnt IFS = 0?
                    if APCNT{idxAP}.IFS == 0
                        % YES: 'APBO' + 'BO time'1ST + new slottime cycle + set cnt BO, if zero
                        APSTATE(idxAP) = "APBO";
                        stats.TimeBackoff(idxAP) = stats.TimeBackoff(idxAP) + SLOTTIME*1e-6;
                        newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                        GEQ = [GEQ;newevent];
                        if APCNT{idxAP}.BO == 0
                            APCNT{idxAP}.BO = getBACKOFFcnt(APCNT,idxAP,simulation);
                        end
                        logF(fid,idxTime,stats,idxAP,0,'APIFS-CHIdle-IFScnt=0 ','APSigL',actAPSigLevel_dBm,...
                            'IFScnt',APCNT{idxAP}.IFS,'',0,'',0,'',0,simulation);
                    else
                        % NO: 'APIFS' + 'IFS time'1ST + new slottime cycle + dec cnt IFS-1ST;
                        APSTATE(idxAP) = "APIFS";
                        stats.TimeIFS(idxAP) = stats.TimeIFS(idxAP) + SLOTTIME*1e-6;
                        newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                        GEQ = [GEQ;newevent];
                        logF(fid,idxTime,stats,idxAP,0,'APIFS-CHIdle-IFScnt~=0','APSigL',actAPSigLevel_dBm,...
                            'IFScnt',APCNT{idxAP}.IFS,'',0,'',0,'',0,simulation);
                        APCNT{idxAP}.IFS = APCNT{idxAP}.IFS - 1;                        
                    end
                else
                    % NO: 'APCCA' + 'wait time'1ST + new slottime cycle
                    APSTATE(idxAP) = "APCCA";
                    stats.TimeWait(idxAP) = stats.TimeWait(idxAP) + SLOTTIME*1e-6;
                    newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                    GEQ = [GEQ;newevent];
                    logF(fid,idxTime,stats,idxAP,0,'APIFS-CHBusy          ','APSigL',actAPSigLevel_dBm,...
                        '',0,'',0,'',0,'',0,simulation);
                end                

            case "APBO"

                % 'APBO': channel still free & not already lead AP assigned?
                idxSample = round(idxTime/simulation.Ts);
                idxCH = all_bss{idxAP}.ch;
                actAPSigLevel_dBm = CheckAPSignalLevel(idxAP,idxCH,CHAP,idxSample,simulation,OSCHAP);               
                if (actAPSigLevel_dBm < CCA_ED) && (CheckAPCycle(APCNT)==0)
                    % YES: cnt BO = 0?
                    if APCNT{idxAP}.BO == 0
                        % YES 'APBO': any data on queues?
                        if DATAQ(idxAP,1) > 0
                            % YES: 'SRRTS' + 'SRRTS time'1ST + set APLead + new RTS event current time
                            APSTATE(idxAP) = "APSRRTS";
                            APCNT{idxAP}.APLead = 1;
                            % SRRTS/TX directly after BO = 0, otherwise others will not see channel as busy
    %                         stats.TimeBackoff(idxAP) = stats.TimeBackoff(idxAP) + SLOTTIME*1e-6;
    %                         newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                            newevent = {idxTime, idxAP, 0, "APCycle",0,0,0,0,0};
                            GEQ = [GEQ;newevent];
                            logF(fid,idxTime,stats,idxAP,0,'APBO-CHIdle-BOcnt=0   ','APSigL',actAPSigLevel_dBm,...
                                'BOcnt',APCNT{idxAP}.BO,'',0,'',0,'',0,simulation);
                        else
                            % NO: 'APIdle' + 'IDLE time'1ST + new slottime cycle/jump after next event
                            APSTATE(idxAP) = "APIdle";
                            if height(GEQ) > 1  % 2nd next event available?
                                nextEventTime = GEQ(2,:).(1);
                                stats.TimeIdle(idxAP) = stats.TimeIdle(idxAP) + (nextEventTime-idxTime) + SLOTTIME*1e-6;
                                newevent = {nextEventTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                            else
                                stats.TimeIdle(idxAP) = stats.TimeIdle(idxAP) + SLOTTIME*1e-6;
                                newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                            end
                            GEQ = [GEQ;newevent];
                            logF(fid,idxTime,stats,idxAP,0,'APIdle-DQEmpty        ','',0,'',0,'',0,'',0,'',0,simulation);
                        end
                    else
                        % NO: 'APBO' + 'BO time'1ST + new slottime cycle + dec cnt BO-1ST;
                        APSTATE(idxAP) = "APBO";
                        stats.TimeBackoff(idxAP) = stats.TimeBackoff(idxAP) + SLOTTIME*1e-6;
                        newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                        GEQ = [GEQ;newevent];
                        logF(fid,idxTime,stats,idxAP,0,'APBO-CHIdle-BOcnt~=0  ','APSigL',actAPSigLevel_dBm,...
                            'BOcnt',APCNT{idxAP}.BO,'',0,'',0,'',0,simulation);
                        APCNT{idxAP}.BO = APCNT{idxAP}.BO - 1;                        
                    end
                else
                    % 'APCCA' + 'wait time'1ST + new slottime cycle
                    APSTATE(idxAP) = "APCCA";
                    stats.TimeWait(idxAP) = stats.TimeWait(idxAP) + SLOTTIME*1e-6;
                    newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                    GEQ = [GEQ;newevent];
                    if (CheckAPCycle(APCNT) == 0)
                        logF(fid,idxTime,stats,idxAP,0,'APBO-CHBusy           ','APSigL',actAPSigLevel_dBm,...
                            'BOcnt',APCNT{idxAP}.BO,'',0,'',0,'',0,simulation);
                    else
                        logF(fid,idxTime,stats,idxAP,0,'APBO-APCycle          ','APSigL',actAPSigLevel_dBm,...
                            'BOcnt',APCNT{idxAP}.BO,'',0,'',0,'',0,simulation);
                    end
                end                       

            case "APSRNAV"

                % 'APSRNAV': dummy state to cover one slottime end of SRRTS and/or SRTX slots for defering APs
                % 'APCCA' + 'wait time'1ST + new slottime cycle
                APSTATE(idxAP) = "APCCA";
                stats.TimeSRRTS(idxAP) = stats.TimeSRRTS(idxAP) + SLOTTIME*1e-6;
                newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                GEQ = [GEQ;newevent];
                logF(fid,idxTime,stats,idxAP,0,'APSRNAV SRRTS/SRTX    ','',0,...
                    '',0,'',0,'',0,'',0,simulation);               

            case "APSRRTS"

                % 'APSRRTS': evaluate SR and SDMSR, send SRRTS packet, virtually set all AP's maxTP, maxMCS, TXdur, streamID, numStream
                
                % define default non beamforming for AB comparision, also valid here
                simulation.BFSeed = -1;                
                
                % for the log function
                idxSample = round(idxTime/simulation.Ts);
                idxCH = all_bss{idxAP}.ch;
                actAPSigLevel_dBm = CheckAPSignalLevel(idxAP,idxCH,CHAP,idxSample,simulation,OSCHAP);               
                
                % select the next station idxSTA round robin
                numSTAs = size(all_bss{idxAP}.STAs_pos,1);
                idxSTA = APCNT{idxAP}.SelSTA;
                flagData = false;
                seccnt = 0;
                while flagData == false
                    idxSTA = idxSTA + 1;
                    seccnt = seccnt + 1;
                    if idxSTA > numSTAs
                        idxSTA = 1;
                    end
                    if DATAQ(idxAP,idxSTA) > 0
                        flagData = true;
                    end
                    if seccnt > numSTAs + 1
                        break
                    end
                end
                APCNT{idxAP}.SelSTA = idxSTA;

                idxSample = round(idxTime/simulation.Ts);
 
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % The configuration of the current TX scenario starts here.                
                
                % get the TXOP configuration for all eligible APs based on allocation table and method
                % future task: configuration should include selection of beamforming
                APCNT = getSDMSRTXconfig(all_bss,cfgPHY,DATAQ,TRPsumMCS,PL2TXSU,PL2TXMU,APCNT,simulation);
                                                           
                % the TX scenario configuration ends here, all parameters are defined in APCNT
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                
                % RTS PACKET:
                % always use MCS2 (QPSK, 1/2) and IEEE802.11a for RTS packet for good reach and least overhead
                % SRRTS duration will be 32 us
                actTXbyte = length(simulation.SRRTSpsduBits)/8;              
                cfg = wlanNonHTConfig();
                cfg.ChannelBandwidth = 'CBW20';
%                 cfg.NumTransmitAntennas = 1;
                cfg.NumTransmitAntennas = cfgPHY{idxAP,idxSTA}.NumTransmitAntennas;
                cfg.MCS = 2;     
                cfg.PSDULength = actTXbyte;
                actMCS = cfg.MCS;

                txPSDU = randi([0 1],actTXbyte*8,1,'int8');
                idleTime = cfgSimu{idxAP,idxSTA}.IdleTime;
                txPacket = wlanWaveformGenerator(txPSDU,cfg,'IdleTime',idleTime*1e-6);
                
                % scale packet along transmit power; default is all antennas 30 dBm
    %                 power_sig = mean(abs(txPacket).^2);
    %                 sig1_dbm = 10*log10(power_sig)+30;
                txPower = all_bss{idxAP}.tx_power;
                att_abs = (10^((30 - txPower)/10));
                txPacket = txPacket./sqrt(att_abs);    
    %                 power_sig = mean(abs(txPacket).^2);
    %                 sig2_dbm = 10*log10(power_sig)+30;

                % transmit RTS packet: put on all receive channels (if Int on) after PL, tgax, AWGN
                [CHAP,CHSTA,OSCHAP,OSCHSTA,lastTXPck_DL] = Transmit_DL(idxSample,txPacket,idxAP,CHAP,CHSTA,all_bss,...
                    all_pathloss_STA_DL,all_pathloss_AP_DL,tgaxSTA_DL,tgaxAP_DL,cfgSimu,simulation,OSCHAP,OSCHSTA,lastTXPck_DL,APCNT);    
                
                % select next state per AP depending weather it transmits or not
                TransmitDurationRTS = length(txPacket)*simulation.Ts;
                newTimeRTS = idxTime+TransmitDurationRTS;
                stopSample = idxSample+length(txPacket)-1;
                
                numBSS = numel(all_bss);
                for idx = 1:numBSS
                    % Any AP: any data on queue and allowed to join TX-slot?
                    if (APCNT{idx}.APCont == 1) && (any(DATAQ(idx,:)))
                        
                        % the allocated time has to be calculated from next event on GEQ to end of SRRTS
                        APGEQ = GEQ((GEQ.(2) == idx)&(GEQ.(4) == "APCycle"),:);
                        nextTimeAP = APGEQ(1,:).(1);
                        addTimeAP = newTimeRTS - nextTimeAP;
                        
                        % delete old AP entries to synchronize, but skip first line lead AP as it will be deleted later
                        rows = ((GEQ.(2) == idx)&(GEQ.(4) == "APCycle"));
                        if APCNT{idx}.APLead == 1
                            rows(1) = 0;
                        end
                        GEQ(rows,:) = [];     
                        
                        % YES:'APTX' + 'SRRTS time' + new TX event current time
                        APSTATE(idx) = "APTX";
                        % TX directly
                        newevent = {newTimeRTS, idx, 1, "APCycle",idxSample,stopSample,0,0,0};
                        stats.TimeSRRTS(idx) = stats.TimeSRRTS(idx) + addTimeAP;                         
                        GEQ = [GEQ;newevent];
                        
                    else
                        
                        % NO: 'APSRNAV' + 'wait time' + new slottime cycle/jump after RTS+TX event
                        TransmitDurationTXSlot = APCNT{idxAP}.TXdur*simulation.Ts;
                        newTimeRX = newTimeRTS+TransmitDurationTXSlot;
                        
                        % the allocated time has to be calculated from next event on GEQ to end of SRRTS + TX duration
                        APGEQ = GEQ((GEQ.(2) == idx)&(GEQ.(4) == "APCycle"),:);
                        nextTimeAP = APGEQ(1,:).(1);
                        addTimeAP = newTimeRX - nextTimeAP;
                        
                        % delete old AP entries to synchronize, but skip first line lead AP as it will be deleted later
                        rows = ((GEQ.(2) == idx)&(GEQ.(4) == "APCycle"));
                        if APCNT{idx}.APLead == 1
                            rows(1) = 0;
                        end
                        GEQ(rows,:) = [];     

                        APSTATE(idx) = "APSRNAV";
                        % TX directly
                        newevent = {newTimeRX, idx, 1, "APCycle",idxSample,stopSample,0,0,0};
                        stats.TimeWait(idx) = stats.TimeWait(idx) + addTimeAP;
                        GEQ = [GEQ;newevent];
                        APCNT{idx}.INmax = -200;
                        APCNT{idx}.TXdur = 0;
                        APCNT{idx}.APLead = 0;
                        APCNT{idx}.APCont = 0;

                    end
                end

                logF(fid,idxTime,stats,idxAP,idxSTA,'SRRTS-TX-SLOT         ','',0,...
                    'actMCS',actMCS,'PayL',actTXbyte,'StartPCKS',idxSample,'StopPCKS',stopSample,simulation);
                
            case "APACK"

                % 'APACK': put ACK on channel after packet without PE; simplified version, no RX done               
                idxSample = round(idxTime/simulation.Ts);

                % always use MCS2 (QPSK, 1/2) and IEEE802.11a for ACK packet for good reach and least overhead
                % ACK duration will be 32 us, see Table 10-5 IEEE 802.11-2016
                actTXbyte = length(simulation.ACKpsduBits)/8;              
                cfg = wlanNonHTConfig();
                cfg.ChannelBandwidth = 'CBW20';
                % use number of receive antennas to transmit UL
                cfg.NumTransmitAntennas = all_bss{idxAP}.num_rx;
                cfg.MCS = 2;
                cfg.PSDULength = actTXbyte;

                txPSDU = randi([0 1],actTXbyte*8,1,'int8');
                idleTime = cfgSimu{idxAP,idxSTA}.IdleTime;
                txPacket = wlanWaveformGenerator(txPSDU,cfg,'IdleTime',idleTime*1e-6);
                
                % scale packet along transmit power; default is all antennas 30 dBm, same TX power for STA
                txPower = cfgSimu{idxAP,idxSTA}.TransmitPower;
                att_abs = (10^((30 - txPower)/10));
                txPacket = txPacket./sqrt(att_abs);    

                % transmit ACK packet: put on all receive channels (if Int on) after PL, tgax, AWGN
                [CHAP,CHSTA,OSCHAP,OSCHSTA,lastTXPck_UL] = Transmit_UL(idxSample,txPacket,idxAP,idxSTA,CHAP,CHSTA,all_bss,...
                    all_pathloss_STA_UL,all_pathloss_AP_UL,tgaxSTA_UL,tgaxAP_UL,cfgSimu,simulation,OSCHAP,OSCHSTA,lastTXPck_UL,APCNT);    
                
                % put AP into idle after ACK and record time
                TransmitDurationACK = length(txPacket)*simulation.Ts;
                newTimeACK = idxTime+TransmitDurationACK;
                stopSample = idxSample+length(txPacket)-1;
              
                APSTATE(idxAP) = "APIdle";
                newevent = {newTimeACK, idxAP, 1, "APCycle",idxSample,stopSample,0,0,0};
                stats.TimeACK(idxAP) = stats.TimeACK(idxAP) + TransmitDurationACK;
                GEQ = [GEQ;newevent];

                logF(fid,idxTime,stats,idxAP,idxSTA,'ACK                   ','',0,...
                    '',0,'',0,'StartPCKS',idxSample,'StopPCKS',stopSample,simulation);

                
            case "APTX"

                % 'APTX': transmit: transmit with SR assigned values, put pending queue, send packet,
                %         'APRX' + 'header/data time' + new RX event end of packet

                % define default non beamforming for AB comparision
                simulation.BFSeed = -1;

                % use saved vales; MCS and TP are aligned to SR, PLBytes is alligned to length of lead data packet
                idxSTA = APCNT{idxAP}.SelSTA;
                actMCS = APCNT{idxAP}.SelMCS;
                txPower = APCNT{idxAP}.SelTP;               
                actTXbyte = APCNT{idxAP}.SelPLBytes;
                streamID = APCNT{idxAP}.StreamID;               
                numStream = APCNT{idxAP}.numStream;
                % numStreams defines mode, numStream=0:'classical' or numStream~=0:'SDM across links'
                % classical: actTXbyte is payload for all streams, txPower is value from UI
                % SDMxLinks: actTXbyte is payload for one stream/user, txPower is value from UI

                idxSample = round(idxTime/simulation.Ts);

                % estimate SINR at receiver (from last packets)
                actSTAestSINRLevel_dB = CheckSTAestSINRLevel(idxAP,idxSTA,SINRest); 
                % calculate SINR at receiver (from last packets)
                actSTAcalcSINRLevel_dB = CheckSTAcalcSINRLevel(idxAP,idxSTA,SINRcalc); 

                % update statistics
                stats.Histo(idxAP,idxSTA).MCS = [stats.Histo(idxAP,idxSTA).MCS actMCS];
                stats.Histo(idxAP,idxSTA).estSINR = [stats.Histo(idxAP,idxSTA).estSINR actSTAestSINRLevel_dB];
                stats.Histo(idxAP,idxSTA).calcSINR = [stats.Histo(idxAP,idxSTA).calcSINR actSTAcalcSINRLevel_dB];
                
                % classical mode
                if numStream == 0

                    % use default HESU PHY
                    % use cfgHE cell array to save parameters for packet generation
                    saveCFG(idxAP,idxSTA).MCS = cfgPHY{idxAP,idxSTA}.MCS;
                    cfgPHY{idxAP,idxSTA}.MCS = actMCS;
                    switch simulation.PHYType
                        case 'IEEE 802.11ax'
                            saveCFG(idxAP,idxSTA).Length = cfgPHY{idxAP,idxSTA}.APEPLength;
                            cfgPHY{idxAP,idxSTA}.APEPLength = actTXbyte;
                        case 'IEEE 802.11n'
                            saveCFG(idxAP,idxSTA).Length = cfgPHY{idxAP,idxSTA}.PSDULength;
                            cfgPHY{idxAP,idxSTA}.PSDULength = actTXbyte;
                        case 'IEEE 802.11a'
                            saveCFG(idxAP,idxSTA).Length = cfgPHY{idxAP,idxSTA}.PSDULength;
                            cfgPHY{idxAP,idxSTA}.PSDULength = actTXbyte;
                    end
                
                    % build packet from selected data
                    [txPacket,txPSDU] = BuildPacket(cfgPHY,idxAP,idxSTA,cfgSimu,simulation);

                % SDMxLinks mode
                else
                    
                    % use HEMU PHY and configure, allocation index is 191 + #users for 242 tones for 20 MHz BW
                    % numSTS has to be numTXAnt, just use Ant 1 to transmit; use numStream for definition!
                    HEMUcfg = wlanHEMUConfig(191+numStream);
                    HEMUcfg.NumTransmitAntennas = numStream;
                    HEMUcfg.GuardInterval = 0.8;
                    HEMUcfg.HELTFType = 4;
                    for idxUser = 1:numStream
                        HEMUcfg.User{idxUser}.NumSpaceTimeStreams = 1;
                        HEMUcfg.User{idxUser}.MCS = actMCS;
                        HEMUcfg.User{idxUser}.ChannelCoding = 'LDPC';
                        HEMUcfg.User{idxUser}.APEPLength = actTXbyte;
                    end
                    saveCFG(idxAP,idxSTA).MCS = actMCS;
                    saveCFG(idxAP,idxSTA).Length = actTXbyte;
                                        
                    % make sure that packet dimension fits into channel
                    numTXCH = cfgPHY{idxAP,idxSTA}.NumTransmitAntennas;

                    % build packet from selected data
                    [txPacket,txPSDU] = BuildPacketMU(HEMUcfg,idxAP,idxSTA,cfgSimu,numStream,streamID,numTXCH);
                                        
                end

                % put payload on cell array to allow error check during receive; there is just one PSDU by AP
                txPSDUs_DL{idxAP} = txPSDU;

%                     power_sig = mean(abs(txPacket).^2);
%                     sig1_dbm = 10*log10(power_sig)+30;
                
                % scale packet along transmit power; default is all antennas 30 dBm
                % the waveformgenerator scales by #antennas; for SDRxLinks mode go back to one antenna power 
                if numStream == 0
                    att_abs = (10^((30 - txPower)/10));
                else
                    att_abs = (10^((30 - txPower)/10)) / all_bss{idxAP}.num_tx;
                end
                
                txPacket = txPacket./sqrt(att_abs);  
             
%                     power_sig = mean(abs(txPacket).^2);
%                     sig2_dbm = 10*log10(power_sig)+30;

                % move data from DATAQ to pending data queue, this is actTXbytes for both modes
                movebyte = actTXbyte;
                
                DATAQ(idxAP,idxSTA) = DATAQ(idxAP,idxSTA) - movebyte;
                DATAPENQ(idxAP,idxSTA) = DATAPENQ(idxAP,idxSTA) + movebyte;

                % transmit packet: put on all receive channels (if Int on) after PL, tgax, AWGN
                [CHAP,CHSTA,OSCHAP,OSCHSTA,lastTXPck_DL] = Transmit_DL(idxSample,txPacket,idxAP,CHAP,CHSTA,all_bss,...
                    all_pathloss_STA_DL,all_pathloss_AP_DL,tgaxSTA_DL,tgaxAP_DL,cfgSimu,simulation,OSCHAP,OSCHSTA,lastTXPck_DL,APCNT);    

                % reset SR matrices in first RX as data is needed during other TX
                
                % fall back to default non beamforming for AB comparision
                simulation.BFSeed = -1;
                
                % select next state and prepare RX event
                APSTATE(idxAP) = "APRX";

                % update statistics, based on used model and PHY
                % classic mode
                if numStream == 0
                    
                    ind = wlanFieldIndices(cfgPHY{idxAP,idxSTA});
                    switch simulation.PHYType
                        case 'IEEE 802.11ax'
                            timeHeader = cast((ind.HEData(1) - 1),'double') * simulation.Ts;
                            timeData = cast((ind.HEData(2) - ind.HEData(1) + 1),'double') * simulation.Ts;
                        case 'IEEE 802.11n'
                            timeHeader = cast((ind.HTData(1) - 1),'double') * simulation.Ts;
                            timeData = cast((ind.HTData(2) - ind.HTData(1) + 1),'double') * simulation.Ts;
                        case 'IEEE 802.11a'
                            timeHeader = cast((ind.NonHTData(1) - 1),'double') * simulation.Ts;
                            timeData = cast((ind.NonHTData(2) - ind.NonHTData(1) + 1),'double') * simulation.Ts;
                    end
                    
                % SDMxLinks mode    
                else
                    
                    ind = wlanFieldIndices(HEMUcfg);
                    timeHeader = cast((ind.HEData(1) - 1),'double') * simulation.Ts;
                    timeData = cast((ind.HEData(2) - ind.HEData(1) + 1),'double') * simulation.Ts;
                    
                end
                
                stats.TimeHeader(idxAP) = stats.TimeHeader(idxAP) + timeHeader;
                stats.TimeData(idxAP) = stats.TimeData(idxAP) + timeData;
                stats.TimeIdle(idxAP) = stats.TimeIdle(idxAP) + cfgSimu{idxAP,idxSTA}.IdleTime*1e-6;
                stats.NumberOfPackets(idxAP,idxSTA) = stats.NumberOfPackets(idxAP,idxSTA) + 1;
               
                % build new GEQ entry for RX, var1/2/3/4/5 is samples startoP/EndofP/index txPSDU/numStream/streamID
                % numStream = 0 is HESU, all other is HEMU; cfgPHY will be created based on numStream; TX/RX based on streamID
                stopSample = idxSample+length(txPacket)-1;
                idxLeadAP = GetLeadAP(APCNT);
                TransmitDurationLeadAP = APCNT{idxLeadAP}.TXdur*simulation.Ts;
                
                % statistic has to cover wait time for packets not having full length of TX slot
                packetTime = timeHeader + timeData + cfgSimu{idxAP,idxSTA}.IdleTime*1e-6;
                slotTime = TransmitDurationLeadAP;
                if packetTime < slotTime
                    stats.TimeWait(idxAP) = stats.TimeWait(idxAP) + (slotTime - packetTime);
                end
                
                % RX event has to be at the end of TX slot of lead AP
                newTime = idxTime+TransmitDurationLeadAP;
                newevent = {newTime, idxAP, idxSTA, "APCycle",idxSample,stopSample,0,numStream,streamID};
                GEQ = [GEQ;newevent];
                logF(fid,idxTime,stats,idxAP,idxSTA,'APTX                  ','estSINR',actSTAestSINRLevel_dB,...
                    'actMCS',actMCS,'actTP',txPower,'StartPCKS',idxSample,'StopPCKS',stopSample,simulation);                

            case "APRX"

                % 'APRX': receive: PE?
                % YES: note PE, data queue handling etc., 'APIdle' new slottime cycle
                % No: TP note, data queue handling etc., 'APACK' new slottime cycle

                startSample = NewEvent.(5);
                stopSample = NewEvent.(6);
                numStream = NewEvent.(8);
                streamID = NewEvent.(9);
                % numStream defines mode, numStream=0:'classical' or numStream~=0:'SDM across links'
                % classical: actTXbyte is payload for all streams, saved in cfgPHY
                % SDMxLinks: actTXbyte is payload for one stream/user, saved in savePHY


                % get rx signal from STA channel
                idxCH = all_bss{idxAP}.ch;
                rx = CHSTA{idxAP,idxSTA,idxCH}(startSample+OSCHSTA(idxAP,idxSTA,idxCH):stopSample+OSCHSTA(idxAP,idxSTA,idxCH),:);
                
                % add noise by awgn channel, if selected
                if simulation.useawgn == true
                    rx = awgnChannel(rx);
                else
                    % do nothing
                end

                % calculate SINR by antenna from total signal % signal clean after tgax
                rxIN = rx - lastTXPck_DL{idxAP};

                Spow = mean(abs(lastTXPck_DL{idxAP}).^2,1);
                INpow = mean(mean(abs(rxIN).^2));

                if all(Spow > INpow) && (INpow ~= 0)
                    calcSINR = mean(Spow ./ INpow);
                    calcSINR_dB = 10 * log10(calcSINR);
                                       
                    % store calculated SINR for later use, size to max 10
                    SINRcalcVec = SINRcalc{idxAP,idxSTA};
                    SINRcalcVec = [SINRcalcVec calcSINR_dB];
                    if length(SINRcalcVec) > 10  % along packets
                        SINRcalcVec = SINRcalcVec(end+1-10:end);
                    end
                    SINRcalc{idxAP,idxSTA} = SINRcalcVec;
                else
                    % simply don't add new value
                    calcSINR = 0;
                end
                
                txPSDU = txPSDUs_DL{idxAP};
                
                % classical mode
                if numStream == 0

                    % use HESU format, do nothing as all is covered by default settings
                    % try receive
                    PacketErrorUser = false;
                    try
                        [PacketErrorUser,SINRest] = Receive(rx,txPSDU,idxAP,idxSTA,cfgPHY,SINRest,simulation);
                    catch
                        disp('error during receive of packet');
                    end
                
                % SDMxLinks mode    
                else
                    
                    % use same HEMU format as in TX
                    HEMUcfg = wlanHEMUConfig(191+numStream);
                    HEMUcfg.NumTransmitAntennas = numStream;
                    HEMUcfg.GuardInterval = 0.8;
                    HEMUcfg.HELTFType = 4;
                    for idxUser = 1:numStream
                        HEMUcfg.User{idxUser}.NumSpaceTimeStreams = 1;
                        HEMUcfg.User{idxUser}.MCS = saveCFG(idxAP,idxSTA).MCS;
                        HEMUcfg.User{idxUser}.ChannelCoding = 'LDPC';
                        HEMUcfg.User{idxUser}.APEPLength = saveCFG(idxAP,idxSTA).Length;
                    end
           
                    % try receive
                    PacketErrorUser = false;
                    try
                        [PacketErrorUser,SINRest] = ReceiveMU(rx,txPSDU,idxAP,idxSTA,HEMUcfg,SINRest,simulation,numStream,streamID);
                    catch
                        disp('error during receive of packet');
                    end

                end

                % update data queues based on packet error
                % classical mode has transfered bytes in cfgPHY
                % SDMxLinks mode has transfered bytes in savecfg
                
                % classical mode
                if numStream == 0
                    
                    switch simulation.PHYType
                        case 'IEEE 802.11ax'
                            movebyte = cfgPHY{idxAP,idxSTA}.APEPLength;
                        case 'IEEE 802.11n'
                            movebyte = cfgPHY{idxAP,idxSTA}.PSDULength;
                        case 'IEEE 802.11a'
                            movebyte = cfgPHY{idxAP,idxSTA}.PSDULength;
                    end
                    
                % SDRxLinks mode
                else
                    movebyte = saveCFG(idxAP,idxSTA).Length;
                end
                
                if PacketErrorUser == false 

                    % successful tx rx
                    DATAPENQ(idxAP,idxSTA) = DATAPENQ(idxAP,idxSTA) - movebyte;
                    stats.DatatransferedPlot(idxAP,idxSTA) = stats.DatatransferedPlot(idxAP,idxSTA) + movebyte;
                    
                    % calculate and record latency of PL transfered
                    currAPLT = LT{idxAP};
                    accMoveByte = movebyte;
                    
                    while accMoveByte > 0
                        % check if there are still entries
                        if size(currAPLT,1) > 0
                            % check next entry to be covered by movebyte
                            if currAPLT(1,:).(2) <= accMoveByte
                                % YES: reduce movebyte, remove row and record latency
                                accMoveByte = accMoveByte - currAPLT(1,:).(2);
                                newLatency = idxTime - currAPLT(1,:).(1);
                                stats.Histo(idxAP,idxSTA).timeLatency = [stats.Histo(idxAP,idxSTA).timeLatency newLatency];
                                currAPLT(1,:) = [];
                            else
                                % NO: reduce entry as much as possible and exit
                                currAPLT(1,:).(2) = currAPLT(1,:).(2) - accMoveByte;
                                accMoveByte = 0;
                            end
                        else
                            % exit
                            accMoveByte = 0;
                        end
                    end
                    LT{idxAP} = currAPLT;

                    % reset error counters, for EIFS for all APs
                    APCNT{idxAP}.SRC = 0;
                    APSTACNT{idxAP,idxSTA}.SRC = 0;
                    numBSS = numel(all_bss);
                    for idxClean = 1:numBSS
                        APCNT{idxClean}.PrevError = false;
                    end
                    
                else

                    % error because of data mismatch
                    % data back to data queue, note error
                    DATAPENQ(idxAP,idxSTA) = DATAPENQ(idxAP,idxSTA) - movebyte;
                    DATAQ(idxAP,idxSTA) = DATAQ(idxAP,idxSTA) + movebyte;
                    stats.PacketErrorPlotSTA(idxAP,idxSTA) = stats.PacketErrorPlotSTA(idxAP,idxSTA) + 1;
                    stats.PacketErrorPlotAP(idxAP) = stats.PacketErrorPlotAP(idxAP) + 1;

                    % set error counters
                    APCNT{idxAP}.SRC = APCNT{idxAP}.SRC + 1;
                    APCNT{idxAP}.PrevError = true;
                    try
                        APSTACNT{idxAP,idxSTA}.SRC = APSTACNT{idxAP,idxSTA}.SRC + 1;
                    catch
                        i=1;
                    end
                    
                end
                
                % update statistics
                [stats] = UpdateStatsDataqPlot(idxAP,idxSTA,idxTime,DATAQ,stats);

                % go back to default values after receive
                cfgPHY{idxAP,idxSTA}.MCS = saveCFG(idxAP,idxSTA).MCS;
                
                % the length reload is just needed for the classical mode
                if numStream == 0
                    switch simulation.PHYType
                        case 'IEEE 802.11ax'
                            cfgPHY{idxAP,idxSTA}.APEPLength = saveCFG(idxAP,idxSTA).Length;
                        case 'IEEE 802.11n'
                            cfgPHY{idxAP,idxSTA}.PSDULength = saveCFG(idxAP,idxSTA).Length;
                        case 'IEEE 802.11a'
                            cfgPHY{idxAP,idxSTA}.PSDULength = saveCFG(idxAP,idxSTA).Length;
                    end       
                end
                
                % reset SR matrices as all TX frames are scheduled for that slot
                numBSS = numel(all_bss);
                for idx = 1:numBSS
                    APCNT{idx}.INmax = -200;
                    APCNT{idx}.TXdur = 0;
                    APCNT{idx}.APLead = 0;
                    APCNT{idx}.APCont = 0;
                    APCNT{idx}.SelTP = -200;
                    APCNT{idx}.SelMCS = 0;
                    APCNT{idx}.SelSTA = 1;
                    APCNT{idx}.SelPLBytes = 0;
                    APCNT{idx}.StreamID = 0;
                    APCNT{idx}.numStream = 0;
                end                
                
                % put ACK on channel or idle, depending on PE or not
                if PacketErrorUser == false
                    APSTATE(idxAP) = "APACK";
                    newevent = {idxTime + SLOTTIME*1e-6, idxAP, idxSTA, "APCycle",0,0,0,0,0};
                    GEQ = [GEQ;newevent];
                    % IFS time is SIFS time before ACK
                    stats.TimeIFS(idxAP) = stats.TimeIFS(idxAP) + SLOTTIME*1e-6;
                    logF(fid,idxTime,stats,idxAP,idxSTA,'APRX-ACK              ','PE',PacketErrorUser,'SRC',...
                        APCNT{idxAP}.SRC,'PrevE',APCNT{idxAP}.PrevError,'StartPCKS',startSample,'StopPCKS',...
                        stopSample,simulation);                    
                else
                    % put AP into idle and new event
                    APSTATE(idxAP) = "APIdle";
                    newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                    GEQ = [GEQ;newevent];
                    stats.TimeIdle(idxAP) = stats.TimeIdle(idxAP) + SLOTTIME*1e-6;
                    logF(fid,idxTime,stats,idxAP,idxSTA,'APRX-PE-IDLE          ','PE',PacketErrorUser,'SRC',...
                        APCNT{idxAP}.SRC,'PrevE',APCNT{idxAP}.PrevError,'StartPCKS',startSample,'StopPCKS',...
                        stopSample,simulation);                    
                end

        end     %end APSTATE(idxAP)        


    case 'DataOnQueue'
        
        % put data on data queues along event, arriving from defined load rate; the R2S is positioned 
        % as if there was a busy condition before, adding IFS and BO; however IFS and BO will only be realized
        % in timings when a send packet is really executed, is getting on the channel.
            ByteToFill = NewEvent.(5);
            if ByteToFill > 0
                DATAQ(idxAP,idxSTA) = DATAQ(idxAP,idxSTA) + ByteToFill;
                [stats] = UpdateStatsDataqPlot(idxAP,idxSTA,idxTime,DATAQ,stats);
                % load table for latency measurement
                newentry = {idxTime,ByteToFill};
                LT{idxAP} = [LT{idxAP};newentry];
            end

    case 'ChannelGarbageCollection'
        
        % tgax standard tells max TXTIME = 5.5 ms. Therefore it is save to delete channel information
        % prior to the max TXTIME as each receive is immediately after end of transmission
        % move to samples, size channel and set offset, change all channel accesses
        numSampGW = round(simulation.GarbageWindow/simulation.Ts);
        numBSS = numel(all_bss);
        numCH = simulation.numCH;
        
        for idxCH = 1:numCH

            for idxAP = 1:numBSS                       
            lengthOld = size(CHAP{idxAP,idxCH},1);
                if (lengthOld - numSampGW) >= 2*numSampGW
                    vec = CHAP{idxAP,idxCH};
                    vec = vec(lengthOld-2*numSampGW:lengthOld,:);
                    CHAP{idxAP,idxCH} = vec;
                    lengthNew = size(CHAP{idxAP,idxCH},1);
                    OSCHAP(idxAP,idxCH) = OSCHAP(idxAP,idxCH) + (lengthNew - lengthOld);                           
                end
            end        


            numBSS = numel(all_bss);
            for idxAP = 1:numBSS
                numSTAs = size(all_bss{idxAP}.STAs_pos,1);
                for idxSTA = 1:numSTAs
                    lengthOld = size(CHSTA{idxAP,idxSTA,idxCH},1);
                    if (lengthOld - numSampGW) >= 2*numSampGW
                        vec = CHSTA{idxAP,idxSTA,idxCH};
                        vec = vec(lengthOld-2*numSampGW:lengthOld,:);
                        CHSTA{idxAP,idxSTA,idxCH} = vec;
                        lengthNew = size(CHSTA{idxAP,idxSTA,idxCH},1);
                        OSCHSTA(idxAP,idxSTA,idxCH) = OSCHSTA(idxAP,idxSTA,idxCH) + (lengthNew - lengthOld); 
                    end
                end
            end
            
        end

    otherwise
        
        disp('event type not covered');

end % switch event case

GEQ(1,:) = [];                  % remove event from GEQ
GEQ = sortrows(GEQ,{'Time'});   % resort queue along event time

end


% **********************************************************************************************************************
function [actAPSigLevel_dBm] = CheckAPSignalLevel(idxAP,idxCH,CHAP,idxSample,simulation,OSCHAP)
    sampToCheck = round(simulation.CCATime*1e-6/simulation.Ts);
    % this has changed, now packet starts at idxSample; needs to look 1 slottime ahead
%     sampToStart = idxSample-sampToCheck;
    sampToStart = idxSample-sampToCheck + simulation.SLOTTIME*1e-6/simulation.Ts;
    
    if (((sampToStart+sampToCheck+OSCHAP(idxAP,idxCH)) > length(CHAP{idxAP,idxCH}))||(sampToStart<1))
        actAPSigLevel_dBm = -200;
    else
        
        % mean mean for multiple streams
        actAPSigLevel = mean(mean(abs(CHAP{idxAP,idxCH}(sampToStart+OSCHAP(idxAP,idxCH):sampToStart+sampToCheck+OSCHAP(idxAP,idxCH))).^2));
        if actAPSigLevel > 0
            actAPSigLevel_dBm = 10*log10(actAPSigLevel)+30;
        else
            actAPSigLevel_dBm = -200;
        end
    end    
end

% **********************************************************************************************************************
function [actSTASINRLevel_dB] = CheckSTAestSINRLevel(idxAP,idxSTA,SINRest)   
    actSTASINRLevel_dB = 10*log10(mean(10.^(SINRest{idxAP,idxSTA}/10),'all'));
end

% **********************************************************************************************************************
function [actSTAcalcSINRLevel_dB] = CheckSTAcalcSINRLevel(idxAP,idxSTA,SINRcalc)    
    actSTAcalcSINRLevel_dB = 10*log10(mean(10.^(SINRcalc{idxAP,idxSTA}/10),'all'));  
end

% **********************************************************************************************************************
function [APcycle] = CheckAPCycle(APCNT)    
    numAP = numel(APCNT);
    APcycle = 0;
    for idx = 1:numAP
        if APCNT{idx}.APLead ~= 0
            APcycle = 1;
        end
    end
end

% **********************************************************************************************************************
function [idxLeadAP] = GetLeadAP(APCNT)    
    numAP = numel(APCNT);
    idxLeadAP = 0;
    for idx = 1:numAP
        if APCNT{idx}.APLead == 1
            idxLeadAP = idx;
        end
    end
end

% **********************************************************************************************************************
% start with fix length from BSS setup
function [actTXbyte] = DecidePayloadLength(cfgPHY,idxAP,idxSTA,DATAQ,simulation)

    switch simulation.PHYType
        case 'IEEE 802.11ax'
            actTXbyte = cfgPHY{idxAP,idxSTA}.APEPLength;
        case 'IEEE 802.11n'
            actTXbyte = cfgPHY{idxAP,idxSTA}.PSDULength;
        case 'IEEE 802.11a'
            actTXbyte = cfgPHY{idxAP,idxSTA}.PSDULength;
    end                

    if DATAQ(idxAP,idxSTA) < actTXbyte
        actTXbyte = DATAQ(idxAP,idxSTA);
    end    
end

% **********************************************************************************************************************
% start with fix length from BSS setup
function [actTXbyte] = DecidePayloadLengthMU(cfgPHY,idxAP,idxSTA,DATAQ,simulation)

    actTXbyte = cfgPHY{idxAP,idxSTA}.APEPLength / cfgPHY{idxAP,idxSTA}.NumSpaceTimeStreams;

    if DATAQ(idxAP,idxSTA) < actTXbyte
        actTXbyte = DATAQ(idxAP,idxSTA);
    end    
end

% **********************************************************************************************************************
function [tx,txPSDU] = BuildPacket(cfgPHY,idxAP,idxSTA,cfgSimu,simulation)

    % Generate random data for all users
    switch simulation.PHYType
        case 'IEEE 802.11ax'
            psduLength = getPSDULength(cfgPHY{idxAP,idxSTA});
        case 'IEEE 802.11n'
            psduLength = cfgPHY{idxAP,idxSTA}.PSDULength;
        case 'IEEE 802.11a'
            psduLength = cfgPHY{idxAP,idxSTA}.PSDULength;
    end                
    txPSDU = randi([0 1],psduLength*8,1,'int8');
    
    % Idle time or zero padding needed for channel delay
    idleTime = cfgSimu{idxAP,idxSTA}.IdleTime;
    tx = wlanWaveformGenerator(txPSDU,cfgPHY{idxAP,idxSTA},'IdleTime',idleTime*1e-6);
end

% **********************************************************************************************************************
function [tx,txPSDU] = BuildPacketMU(HEMUcfg,idxAP,idxSTA,cfgSimu,numStream,streamID,numTXCH)

    % generate random data for all streams
    psduLength = getPSDULength(HEMUcfg);    
    MUtxPSDU = cell(numStream,1);
    for idxStream = 1:numStream
        MUtxPSDU{idxStream} = randi([0 1],psduLength(idxStream)*8,1,'int8');
    end
    
    % save right stream for later PER checking
    txPSDU = MUtxPSDU{streamID};
    
    % Idle time or zero padding needed for channel delay
    idleTime = cfgSimu{idxAP,idxSTA}.IdleTime;
    tx = wlanWaveformGenerator(MUtxPSDU,HEMUcfg,'IdleTime',idleTime*1e-6);
    
    % signal includes all streams for all users; not wanted signals should not overlay
    txTargetSTS = tx(:,streamID);
    
    % keep format but assign right stream to first stream
    tx = tx.*0;
    tx(:,1) = txTargetSTS;
    
    % reduce dimensions to number of TX of other packets to fit into channel
    tx = tx(:,1:numTXCH);
    
end


% **********************************************************************************************************************
function idx = t2i(time)
    idx = round(time*20e6);
end

% **********************************************************************************************************************
function [stats] = UpdateStatsDataqPlot(idxAP,idxSTA,idxTime,DATAQ,stats)
    currLengths = stats.DATAQPlot(idxAP,idxSTA).lengths;
    currTimes = stats.DATAQPlot(idxAP,idxSTA).times;
    currLengths = [currLengths, DATAQ(idxAP,idxSTA)];
    currTimes = [currTimes, idxTime];
    stats.DATAQPlot(idxAP,idxSTA).lengths = currLengths;
    stats.DATAQPlot(idxAP,idxSTA).times = currTimes;  
end

% **********************************************************************************************************************
function [XTIME,IFS,BACKOFF] = getXTIME(APCNT,idxAP,simulation)
    DIFS = simulation.DIFS;
    EIFS = simulation.EIFS;
    CWMIN = simulation.CWMIN;
    SLOTTIME = simulation.SLOTTIME;
    CWVector = simulation.CWVector;

    CWidx = APCNT{idxAP}.SRC + 1;
    if CWidx > 1    % this is a retry
        if CWidx > length(CWVector)     % check boundary
            CWidx = length(CWVector);
        end
        CW = CWVector(CWidx);
        BACKOFF = randi([0 CW]) * SLOTTIME;   
    else    % no retry
        BACKOFF = randi([0 CWMIN]) * SLOTTIME;                    
    end
    if APCNT{idxAP}.PrevError == true
        XTIME = BACKOFF + EIFS;
        IFS = EIFS;
    else
        XTIME = BACKOFF + DIFS;
        IFS = DIFS;
    end
end

% **********************************************************************************************************************
function [IFScnt] = getIFScnt(APCNT,idxAP,simulation)
    DIFS = simulation.DIFS;
    EIFS = simulation.EIFS;
    SLOTTIME = simulation.SLOTTIME;
    if APCNT{idxAP}.PrevError == true
        IFScnt = round(EIFS/SLOTTIME);
    else
        IFScnt = round(DIFS/SLOTTIME);
    end
end

% **********************************************************************************************************************
function [BACKOFFcnt] = getBACKOFFcnt(APCNT,idxAP,simulation)
    CWMIN = simulation.CWMIN;
    CWVector = simulation.CWVector;

    CWidx = APCNT{idxAP}.SRC + 1;
    if CWidx > 1    % this is a retry
        if CWidx > length(CWVector)     % check boundary
            CWidx = length(CWVector);
        end
        CW = CWVector(CWidx);
        BACKOFFcnt = randi([0 CW]);   
    else    % no retry
        BACKOFFcnt = randi([0 CWMIN]);                    
    end
end

% **********************************************************************************************************************
function [APTXcnt] = getSRTXcnt(APCNT,idxAP,simulation)
    numAP = numel(APCNT);
    SRIFS = simulation.SRIFSBase;
    SLOTTIME = simulation.SLOTTIME;
    APTXcnt = round((SRIFS+(numAP+1)*SLOTTIME)/SLOTTIME);   
end

% **********************************************************************************************************************
function TXlength = getPL2TX(PL2TX,numSTS,MCS,PLlength)
    % format is PL2TXSU(#STS,MCS,PL) or PL2TXMU(#STS/USER,MCS,PL)
    TXlength = PL2TX(numSTS,MCS+1,PLlength);
end

% **********************************************************************************************************************
function [APCNT] = getSDMSRTXconfig(all_bss,cfgPHY,DATAQ,TRPsumMCS,PL2TXSU,PL2TXMU,APCNT,simulation)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % The configuration of the current TX scenario starts here.
    % The lead AP and STA (primary target link) is idxAP, idxSTA, APCNT{idx}. APLead is assigned during entry
    % The lead AP distributes resources and decides which mode is used for which link and multi
    % link configuration.
    % For classical links with 1 or more STS the HESU format is used. This is the same as CSMA/CA, but with
    % additional SRRTS packet and no beamforming to avoid CSI overhead communication
    % For SDM across links the HEMU format is used, with an additional SRRTS paket; each link gets its own stream.
    % Therefore the number of TX-antennas equals the number of RX-antennas equals number of total streams.
    % The lead AP is free to use a mix of modes, based on SDM/SR potential and requirement.
    % Care is needed for the payload and TP. The classical mode reuires PL*STS as assigned during init.
    % Therefore the SDM across links mode needs to break the payload down again to an individual stream.
    % The TP constaint needs reflection. The classic mode is handled by the waveformgenerator for #antennas.
    % The SDM across links mode needs to scale this back to one link.
    
    % select the actual allocation set on different priorities like max system
    % throughput or max link throughput. It is simply a question how to sort the allocation table
    idxSortAP = GetLeadAP(APCNT);
    switch simulation.SchedAllocMethod

        case 'maxLink'                           
            % get actual TX set: best throughput for a link and 2nd best for total TRP
            actSort = sortrows(TRPsumMCS,[(1+idxSortAP) 1]);
            actSet = actSort(end,:);

        case 'maxSystem'
            % get actual TX set: best throughput for total TRP and 2nd best for a link            
            % make sure to use entries with rate for current AP
            minrate = 20;
            actUse = TRPsumMCS(TRPsumMCS(:,1+idxSortAP) > minrate,:);            
            actSort = sortrows(actUse,[1 (1+idxSortAP)]);
%             actSort = sortrows(TRPsumMCS,[1 (1+idxSortAP)]);
            actSet = actSort(end,:);

        case 'maxFairness'                           
            % get actual TX set: use best troughput for link with highest data queue, but should include SortAP
            % get AP and STA with highest data queue load
            [~,idx] = max(DATAQ(:));
            [idxMaxAP,~] = ind2sub(size(DATAQ),idx);
            % select those sets where SortAP has any rate
            actUse = TRPsumMCS(TRPsumMCS(:,1+idxSortAP) > 0,:);            
            % sort selected sets for target AP, than max system
            actSort = sortrows(actUse,[(1+idxMaxAP) 1]);
            actSet = actSort(end,:);

    end            
    
    % going through all APs the questions for allocation are: any data on queue (except lead AP, checked ealier)?
    % is the next AP (not lead AP) eligible to transmit?
    % if yes, is the next AP part of a SDM cluster; if yes allocate all APs of that cluster in HEMU mode.
    % if no, allocate the AP in HESU mode.
    % continue until all APs are covered, but avoid double allocation by tracking an allocation index.
    % layout actSet sumTRP TRP1 TRP2 ... TP1 TP2 ... MCS1 MCS2 ... CL CL ...
    numBSS =  numel(all_bss);
    idxAllocVec = zeros(1,numBSS);
    
    % get lead AP and just calculate TX duration; other parameters of lead Ap will be assigned later
    idxLeadAP = GetLeadAP(APCNT);
    leadAPMCS = actSet(1,1+numBSS+numBSS+idxLeadAP);
    leadAPactCL = actSet(1,1+numBSS+numBSS+numBSS+idxLeadAP);
    leadAPnumSTS = all_bss{idxLeadAP}.STAs_sts(1);
    
    % check leadAP to be part of cluster or not; use HEMU or HESU
    % the TXduration should be the length for 1 stream, but aligned to used #STS
    if leadAPactCL > 0
        leadAPactTXbyte  = DecidePayloadLengthMU(cfgPHY,idxLeadAP,1,DATAQ,simulation); % result is for 1 stream
        % get cluster number and cluster member's index
        leadAPsetCL = actSet(1,1+numBSS+numBSS+numBSS+1:1+numBSS+numBSS+numBSS+numBSS);
        leadAPmemberCL = find(leadAPsetCL == leadAPactCL);
        leadAPmemberCNT = size(leadAPmemberCL,2);
        TXduration = getPL2TX(PL2TXMU, leadAPmemberCNT, leadAPMCS, leadAPactTXbyte);   
    else
        leadAPactTXbyte = DecidePayloadLength(cfgPHY,idxLeadAP,1,DATAQ,simulation); % result is multiple of STS
        TXduration = getPL2TX(PL2TXSU, leadAPnumSTS, leadAPMCS, leadAPactTXbyte/leadAPnumSTS); 
    end
    % loop through all BSS including lead AP
    for idxAP = 1:numBSS
        
        % just for uncovered APs
        if (idxAllocVec(idxAP) == 0)
            
            % current AP no data (except lead AP)?
            if (DATAQ(idxAP) == 0) && (APCNT{idxAP}.APLead == 0)
                
                % set AP to NOT TX
                APCNT{idxAP}.APCont = 0;
                APCNT{idxAP}.TXdur = 0;
                APCNT{idxAP}.SelTP = 0;
                APCNT{idxAP}.SelMCS = 0;
                APCNT{idxAP}.SelPLBytes = 0;
                APCNT{idxAP}.SelSTA = 1;
                APCNT{idxAP}.StreamID = 0;
                APCNT{idxAP}.numStream = 0;
                idxAllocVec(idxAP) = 1;
                
            else
                
                % current AP part of a cluster
                actCL = actSet(1,1+numBSS+numBSS+numBSS+idxAP);
                
                if actCL > 0
                    
                    % curr AP is part of cluster, assign HEMU process
                    % Cluster AP always eligible to transmit! Cover all APs of that cluster
                    
                    % get cluster number and cluster member's index
                    actCL = actSet(1,1+numBSS+numBSS+numBSS+idxAP);
                    setCL = actSet(1,1+numBSS+numBSS+numBSS+1:1+numBSS+numBSS+numBSS+numBSS);
                    memberCL = find(setCL == actCL);
                    memberCNT = size(memberCL,2);
                    
                    % assign each cluster AP specific values
                    idxStream = 1;
                    for idxRow = 1:memberCNT
                        idxCLAP = memberCL(idxRow);

                        % allocate TX
                        APCNT{idxCLAP}.APCont = 1;
                        APCNT{idxCLAP}.TXdur = TXduration;
                        APCNT{idxCLAP}.SelTP = 10*log10(actSet(1,1+numBSS+idxCLAP))+30;
                        APCNT{idxCLAP}.SelMCS = actSet(1,1+numBSS+numBSS+idxCLAP);
                        % cluster APs always have payload for just 1STS
                        tempPL = getTX2PLMU(PL2TXMU,memberCNT,APCNT{idxCLAP}.SelMCS,TXduration);
                        if tempPL > DATAQ(idxCLAP)
                            tempPL = DATAQ(idxCLAP);
                        end
                        APCNT{idxCLAP}.SelPLBytes = tempPL;
                        APCNT{idxCLAP}.SelSTA = 1;
                        APCNT{idxCLAP}.StreamID = idxStream;
                        APCNT{idxCLAP}.numStream = memberCNT;
                        idxStream = idxStream + 1;

                    end
                    
                    % mark cluster APs as covered
                    idxCL = (setCL == actCL);
                    idxAllocVec(idxCL) = 1;
                    
                else
                    
                    % curr AP is not part of cluster, assign HESU process
                    % AP eligible to transmit (switch is rate to be zero or not)?
                    actRate = actSet(1,1+idxAP);
                    if actRate > 0
                        
                        % allocate TX
                        APCNT{idxAP}.APCont = 1;
                        APCNT{idxAP}.TXdur = TXduration;
                        APCNT{idxAP}.SelTP = 10*log10(actSet(1,1+numBSS+idxAP))+30;
                        APCNT{idxAP}.SelMCS = actSet(1,1+numBSS+numBSS+idxAP);
                        % payload in HESU depends on #STS!
                        tempPL = getTX2PLSU(PL2TXSU,1,APCNT{idxAP}.SelMCS,TXduration) * all_bss{idxAP}.STAs_sts(1);
                        if tempPL > DATAQ(idxAP)
                            tempPL = DATAQ(idxAP);
                        end
                        APCNT{idxAP}.SelPLBytes = tempPL;
                        APCNT{idxAP}.SelSTA = 1;
                        APCNT{idxAP}.StreamID = 0;
                        APCNT{idxAP}.numStream = 0;

                    else
                        
                        % set AP to NOT TX
                        APCNT{idxAP}.APCont = 0;
                        APCNT{idxAP}.TXdur = 0;
                        APCNT{idxAP}.SelTP = 0;
                        APCNT{idxAP}.SelMCS = 0;
                        APCNT{idxAP}.SelPLBytes = 0;
                        APCNT{idxAP}.SelSTA = 1;
                        APCNT{idxAP}.StreamID = 0;
                        APCNT{idxAP}.numStream = 0;
                        
                    end                    
                    idxAllocVec(idxAP) = 1;
                    
                end
                
            end
            
        end
       
    end          

end

% **********************************************************************************************************************
function PLlength = getTX2PLSU(PL2TXSU,STS,MCS,TXlength)
    % PL2TXSU(idxSTS,idxMCS+1,idxPL)
    a= PL2TXSU(STS,MCS+1,:);
    b = TXlength;
    d=sort(abs(b-a));
    PLlength = find(abs(b-a)==d(1),1,'last');
end

% **********************************************************************************************************************
function PLlength = getTX2PLMU(PL2TXMU,STS,MCS,TXlength)
    % PL2TXMU(idxSTS,idxMCS+1,idxPL)
    a= PL2TXMU(STS,MCS+1,:);
    b = TXlength;
    d=sort(abs(b-a));
    PLlength = find(abs(b-a)==d(1),1,'last');
end

% **********************************************************************************************************************
function [] = logF(fid,idxTime,stats,idxAP,idxSTA,logType,descVar1,var1,descVar2,var2,descVar3,var3,descVar4,var4,...
    descVar5,var5,simulation)
    sumT = stats.TimeHeader(idxAP) + stats.TimeData(idxAP) + stats.TimeACK(idxAP) + stats.TimeIFS(idxAP) + stats.TimeSRIFS(idxAP) + ...
        stats.TimeSRRTS(idxAP) + stats.TimeBackoff(idxAP) + stats.TimeIdle(idxAP) + stats.TimeWait(idxAP);  

    fprintf(fid, '%s idxT %.5f idxS %.0f %s Stot %.0f Sifs %.0f Sboff %.0f Shead %.0f Sdata %.0f Sack %.0f Sidle %.0f Swait %.0f Ssrifs %.0f Ssrrts %.0f idxAP %i idxSTA %i %s %.0f %s %.0f %s %.0f %s %.0f %s %.0f \n'...
        ,datestr(now, 0),idxTime,idxTime/simulation.Ts,logType,sumT/simulation.Ts,stats.TimeIFS(idxAP)/simulation.Ts,...
        stats.TimeBackoff(idxAP)/simulation.Ts,stats.TimeHeader(idxAP)/simulation.Ts...
        ,stats.TimeData(idxAP)/simulation.Ts,stats.TimeACK(idxAP)/simulation.Ts,stats.TimeIdle(idxAP)/simulation.Ts,stats.TimeWait(idxAP)/simulation.Ts,...
        stats.TimeSRIFS(idxAP)/simulation.Ts,stats.TimeSRRTS(idxAP)/simulation.Ts,idxAP,idxSTA,descVar1,var1,descVar2,var2,descVar3,var3,descVar4,var4,descVar5,var5);

end