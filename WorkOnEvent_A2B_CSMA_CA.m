% function to simulate basic CSMA/CA for single user packets
% base version to cover MAC from IEEE 802.11a
function [stats,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,...
    SINRcalc,OSCHAP,OSCHSTA,LT] = WorkOnEvent_A2B_CSMA_CA(approach,stats,all_bss,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,...
    txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,all_pathloss_STA_DL,all_pathloss_AP_DL,tgaxSTA_DL,tgaxAP_DL,all_pathloss_STA_UL,all_pathloss_AP_UL,tgaxSTA_UL,tgaxAP_UL,awgnChannel,simulation,cfgSimu,saveCFG,...
    APSTATE,APCNT,APSTACNT,SINRest,SINRcalc,OSCHAP,OSCHSTA,fid,LT)

SLOTTIME = simulation.SLOTTIME;
SIFS = simulation.SIFS;
DIFS = simulation.DIFS;
EIFS = simulation.EIFS;
CWMIN = simulation.CWMIN;
CWMAX = simulation.CWMAX;
CWVector = simulation.CWVector;
CCA_ED = simulation.CCA_ED;
diag = simulation.diag;
ACCTime = simulation.AccSimuTime;   % same as idxTime
OLDTime = simulation.OldSimuTime;

switch approach
    
    case 'A'
        simulation.DRC = simulation.A.DRC;
        simulation.NOINT = simulation.A.NOINT;
        simulation.ESTSINR = simulation.A.ESTSINR;
        simulation.BEAMFORMING = simulation.A.BEAMFORMING;
        
    case 'B'
        simulation.DRC = simulation.B.DRC;
        simulation.NOINT = simulation.B.NOINT;
        simulation.ESTSINR = simulation.B.ESTSINR;
        simulation.BEAMFORMING = simulation.B.BEAMFORMING;
        
    case 'LOOP'
        % do nothing, for loop RDC, NOINT, ESTSINR, BEAMFORMING are set correctly
        
end  

NewEvent = GEQ(1,:);    % next event is subtable, just one row
idxTime = NewEvent.(1);
idxAP = NewEvent.(2);
idxSTA = NewEvent.(3);
EventType = NewEvent.(4);


switch EventType

    case 'APCycle'
        
    % AP cycle based on Slottime and AP state, states move from Idle to
    % CCA to IFS to BO to TX to RX to Idle
    %
    % a simplified version of the IEEE 802.11 MAC is implemented as it does not
    % include RTS/CTS, first packet after idle without backoff time
    % nor fragmentation and more...
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
    % 'APBO': channel still free?
    %   NO: 'APCCA' + 'wait time'1ST + new slottime cycle
    %   YES: cnt BO = 0?
    %       YES: 'APTX' + 'BO time'1ST + new TX event current time
    %       NO: 'APBO' + 'BO time'1ST + new slottime cycle + dec cnt BO-1ST;
    % 'APTX': transmit: select data round robin, put pending queue, send packet,
    %                   'APRX' + 'header/data time' + new RX event end of packet
    % 'APRX': receive: PE?
    %       YES: note PE, data queue handling etc., 'APACK' new slottime cycle
    %       No: TP note, data queue handling etc., 'APIdle' new slottime cycle
    %
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
                if actAPSigLevel_dBm < CCA_ED
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
                    logF(fid,idxTime,stats,idxAP,0,'APCCA-CHBusy          ','APSigL',actAPSigLevel_dBm,...
                        '',0,'',0,'',0,'',0,simulation);
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

                % 'APBO': channel still free?
                idxSample = round(idxTime/simulation.Ts);
                idxCH = all_bss{idxAP}.ch;
                actAPSigLevel_dBm = CheckAPSignalLevel(idxAP,idxCH,CHAP,idxSample,simulation,OSCHAP);               
                if actAPSigLevel_dBm < CCA_ED
                    % YES: cnt BO = 0?
                    if APCNT{idxAP}.BO == 0
                        % YES: 'APTX' + 'BO time'1ST + new TX event current time
                        APSTATE(idxAP) = "APTX";
                        % TX directly after BO = 0, otherwise others will not see channel as busy
%                         stats.TimeBackoff(idxAP) = stats.TimeBackoff(idxAP) + SLOTTIME*1e-6;
%                         newevent = {idxTime + SLOTTIME*1e-6, idxAP, 0, "APCycle",0,0,0,0,0};
                        newevent = {idxTime, idxAP, 0, "APCycle",0,0,0,0,0};
                        GEQ = [GEQ;newevent];
                        logF(fid,idxTime,stats,idxAP,0,'APBO-CHIdle-BOcnt=0   ','APSigL',actAPSigLevel_dBm,...
                            'BOcnt',APCNT{idxAP}.BO,'',0,'',0,'',0,simulation);
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
                    logF(fid,idxTime,stats,idxAP,0,'APBO-CHBusy           ','APSigL',actAPSigLevel_dBm,...
                        'BOcnt',APCNT{idxAP}.BO,'',0,'',0,'',0,simulation);
                end                       
                
                
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

                % 'APTX': transmit: select data round robin, put pending queue, send packet,
                %         'APRX' + 'header/data time' + new RX event end of packet

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

                % estimate SINR at receiver (from last packets)
                actSTAestSINRLevel_dB = CheckSTAestSINRLevel(idxAP,idxSTA,SINRest); 
                % calculate SINR at receiver (from last packets)
                actSTAcalcSINRLevel_dB = CheckSTAcalcSINRLevel(idxAP,idxSTA,SINRcalc); 

                % decide MCS
                switch simulation.approach
                    
                    case 'LoopOver'
                        switch simulation.LoopPar
                            case 'MCS'
                                actMCS = cfgPHY{idxAP,idxSTA}.MCS;
                            otherwise
                                if simulation.ESTSINR == true
                                    if simulation.DRC == true
                                        if all_bss{idxAP}.STAs_sts(idxSTA) > 1
                                            [actMCS,~,~] = SNR2RMCS2(actSTAestSINRLevel_dB,simulation);
                                        else
                                            [actMCS,~,~] = SNR2RMCS(actSTAestSINRLevel_dB,simulation);
                                        end
                                    else
                                        actMCS = cfgPHY{idxAP,idxSTA}.MCS;
                                    end
                                else
                                    if simulation.DRC == true
                                        if all_bss{idxAP}.STAs_sts(idxSTA) > 1
                                            [actMCS,~,~] = SNR2RMCS2(actSTAcalcSINRLevel_dB,simulation);
                                        else
                                            [actMCS,~,~] = SNR2RMCS(actSTAcalcSINRLevel_dB,simulation);
                                        end
                                    else
                                        actMCS = cfgPHY{idxAP,idxSTA}.MCS;
                                    end
                                end
                        end
                        
                    otherwise
                        if simulation.ESTSINR == true
                            if simulation.DRC == true
                                if all_bss{idxAP}.STAs_sts(idxSTA) > 1
                                    [actMCS,~,~] = SNR2RMCS2(actSTAestSINRLevel_dB,simulation);
                                else
                                    [actMCS,~,~] = SNR2RMCS(actSTAestSINRLevel_dB,simulation);
                                end
                            else
                                actMCS = cfgPHY{idxAP,idxSTA}.MCS;
                            end
                        else
                            if simulation.DRC == true
                                if all_bss{idxAP}.STAs_sts(idxSTA) > 1
                                    [actMCS,~,~] = SNR2RMCS2(actSTAcalcSINRLevel_dB,simulation);
                                else
                                    [actMCS,~,~] = SNR2RMCS(actSTAcalcSINRLevel_dB,simulation);
                                end
                            else
                                actMCS = cfgPHY{idxAP,idxSTA}.MCS;
                            end
                        end

                end

                % update statistics
                stats.Histo(idxAP,idxSTA).MCS = [stats.Histo(idxAP,idxSTA).MCS actMCS];
                stats.Histo(idxAP,idxSTA).estSINR = [stats.Histo(idxAP,idxSTA).estSINR actSTAestSINRLevel_dB];
                stats.Histo(idxAP,idxSTA).calcSINR = [stats.Histo(idxAP,idxSTA).calcSINR actSTAcalcSINRLevel_dB];

                % get actual payload length
                switch simulation.approach

                    case 'LoopOver'
                        switch simulation.LoopPar
                            case 'PayloadLength'
                                switch simulation.PHYType
                                    case 'IEEE 802.11ax'
                                        actTXbyte = cfgPHY{idxAP,idxSTA}.APEPLength;
                                    case 'IEEE 802.11n'
                                        actTXbyte = cfgPHY{idxAP,idxSTA}.PSDULength;
                                    case 'IEEE 802.11a'
                                        actTXbyte = cfgPHY{idxAP,idxSTA}.PSDULength;
                                end                
                            otherwise
                                [actTXbyte] = DecidePayloadLength(cfgPHY,idxAP,idxSTA,DATAQ,simulation);                     
                        end

                    otherwise
                        [actTXbyte] = DecidePayloadLength(cfgPHY,idxAP,idxSTA,DATAQ,simulation);

                end               

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
                
                % if beamforming is used test transfer NDP packet, generate steering matrix, change cfgPHY and
                % transmit packet with same seed to get same WINNER II transfer function
                if simulation.BEAMFORMING == true
                    
                    % define common seed for channel for NDP and following data packet
                    simulation.BFSeed = randi(99999,1);
                    
                    % NDP Configuration
                    cfgHENDP = wlanHESUConfig;
                    cfgHENDP.ChannelBandwidth = 'CBW20';  % Channel bandwidth
                    cfgHENDP.NumSpaceTimeStreams = cfgPHY{idxAP,idxSTA}.NumTransmitAntennas;  % Number of STS full band
                    cfgHENDP.NumTransmitAntennas = cfgPHY{idxAP,idxSTA}.NumTransmitAntennas;
                    cfgHENDP.APEPLength = 0;            % Payload length in bytes
                    cfgHENDP.ExtendedRange = false;       % Do not use extended range format
                    cfgHENDP.Upper106ToneRU = false;      % Do not use upper 106 tone RU
                    cfgHENDP.PreHESpatialMapping = false; % Spatial mapping of pre-HE fields
                    cfgHENDP.GuardInterval = 0.8;         % Guard interval duration
                    cfgHENDP.HELTFType = 4;               % HE-LTF compression mode
                    cfgHENDP.ChannelCoding = 'LDPC';      % Channel coding
                    cfgHENDP.MCS = 0;                     % Modulation and coding scheme

                    % Generate the null data packet, with no data
                    txNDPSig = wlanWaveformGenerator([], cfgHENDP);
                    
                    % Add trailing zeros to allow for channel delay
                    txNDPPad = [txNDPSig; zeros(50,cfgPHY{idxAP,idxSTA}.NumTransmitAntennas)];
                    
                    % Scale NDP packet power along pathloss, no PL in case of LOOP-SNR
                    PL_abs = 10^(all_pathloss_STA_DL{idxAP,idxAP,idxSTA}/10);
                    switch simulation.approach
                        case 'LoopOver'
                            switch simulation.LoopPar
                                case 'SNR'
                                    txNDPPad = txNDPPad;
                                otherwise
                                    txNDPPad = txNDPPad./sqrt(PL_abs);                % scale along PL
                            end
                        otherwise
                            txNDPPad = txNDPPad./sqrt(PL_abs);                % scale along PL
                    end       
                    
                    % Transmit NDP DL to target through WINNER II channel with defined seed
                    release(tgaxSTA_DL{idxAP,idxAP,idxSTA});
                    tgaxSTA_DL{idxAP,idxAP,idxSTA}.ModelConfig.NumTimeSamples = size(txNDPPad, 1);
                    tgaxSTA_DL{idxAP,idxAP,idxSTA}.ModelConfig.RandomSeed = simulation.BFSeed;
                    reset(tgaxSTA_DL{idxAP,idxAP,idxSTA});
                    chanOutNDP = tgaxSTA_DL{idxAP,idxAP,idxSTA}(txNDPPad);
        
                    % get output from cell array for target STA
                    rxNDPSig = chanOutNDP{1};
                    
                    % add noise by awgn channel, if selected; use SNR model for AWGN for LOOP-SNR
                    switch simulation.approach
                        case 'LoopOver'
                            switch simulation.LoopPar
                                case 'SNR'
                                    % switch over to SNR model for AWGN
                                        release(awgnChannel);
                                        awgnChannel.NoiseMethod = 'Signal to noise ratio (SNR)';
                                        awgnChannel.SNR = cfgSimu{idxAP,idxSTA}.SNR;
                                        % 1 Watt all STS as scaling and PL is off, SNR by antenna
                                        % parameter for awgn is power / STS with noise / STS
                                        awgnChannel.SignalPower = 1/all_bss{idxAP}.num_rx;
                                otherwise
                                    % stay with variance model
                            end
                        otherwise
                            % stay with variance model
                    end
                    if simulation.useawgn == true
                        rxNDPSig = awgnChannel(rxNDPSig);
                    end
                    
                    % calculate the steering matrix
                    staFeedback = heUserBeamformingFeedback(rxNDPSig,cfgHENDP,true);
                    if isempty(staFeedback)
                        disp('calculation of steering matrix failed; continue without BF');
                    else        
                        steeringMatrix = staFeedback(:,1:cfgPHY{idxAP,idxSTA}.NumSpaceTimeStreams,:);

                        % apply steering matrix to following data transmission
                        cfgPHY{idxAP,idxSTA}.SpatialMapping = 'Custom';
                        cfgPHY{idxAP,idxSTA}.SpatialMappingMatrix = steeringMatrix;
                    end
                    
                else
                    simulation.BFSeed = -1;
                end

                % build packet from selected data
                [txPacket,txPSDU] = BuildPacket(cfgPHY,idxAP,idxSTA,cfgSimu,simulation);

                % put payload on cell array to allow error check during receive; there is just one PSDU by AP
                txPSDUs_DL{idxAP} = txPSDU;

                % scale packet along transmit power; default is all antennas 30 dBm
                txPower = cfgSimu{idxAP,idxSTA}.TransmitPower;
                att_abs = (10^((30 - txPower)/10));

                switch simulation.approach
                    case 'LoopOver'
                        switch simulation.LoopPar
                            case 'SNR'
                                % don't scale
                            otherwise
                                txPacket = txPacket./sqrt(att_abs);                                    
                        end
                    otherwise
                        txPacket = txPacket./sqrt(att_abs);    
                end                                        
    %                 power_sig = mean(abs(txPacket).^2);
    %                 sig2_dbm = 10*log10(power_sig)+30;

                % move data from DATAQ to pending data queue
                switch simulation.PHYType
                    case 'IEEE 802.11ax'
                        movebyte = cfgPHY{idxAP,idxSTA}.APEPLength;
                    case 'IEEE 802.11n'
                        movebyte = cfgPHY{idxAP,idxSTA}.PSDULength;
                    case 'IEEE 802.11a'
                        movebyte = cfgPHY{idxAP,idxSTA}.PSDULength;
                end                
                
                DATAQ(idxAP,idxSTA) = DATAQ(idxAP,idxSTA) - movebyte;
                DATAPENQ(idxAP,idxSTA) = DATAPENQ(idxAP,idxSTA) + movebyte;

                % transmit packet: put on all receive channels (if Int on) after PL, tgax, AWGN
                [CHAP,CHSTA,OSCHAP,OSCHSTA,lastTXPck_DL] = Transmit_DL(idxSample,txPacket,idxAP,CHAP,CHSTA,all_bss,...
                    all_pathloss_STA_DL,all_pathloss_AP_DL,tgaxSTA_DL,tgaxAP_DL,cfgSimu,simulation,OSCHAP,OSCHSTA,lastTXPck_DL,APCNT);    

                % fall back to default non beamforming for AB comparision
                simulation.BFSeed = -1;
                
                % select next state and prepare RX event
                APSTATE(idxAP) = "APRX";

                % update statistics
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
                stats.TimeHeader(idxAP) = stats.TimeHeader(idxAP) + timeHeader;
                stats.TimeData(idxAP) = stats.TimeData(idxAP) + timeData;
                stats.TimeIdle(idxAP) = stats.TimeIdle(idxAP) + cfgSimu{idxAP,idxSTA}.IdleTime*1e-6;
                stats.NumberOfPackets(idxAP,idxSTA) = stats.NumberOfPackets(idxAP,idxSTA) + 1;

                % build new GEQ entry for RX, var1/2/3 is samples startoP/EndofP/index txPSDU
                % RX directly at end of transmission
                TransmitDuration = length(txPacket)*simulation.Ts;
                newTime = idxTime+TransmitDuration;
                stopSample = idxSample+length(txPacket)-1;
                newevent = {newTime, idxAP, idxSTA, "APCycle",idxSample,stopSample,0,0,0};
                GEQ = [GEQ;newevent];
                logF(fid,idxTime,stats,idxAP,idxSTA,'APTX                  ','estSINR',actSTAestSINRLevel_dB,...
                    'actMCS',actMCS,'PayL',actTXbyte,'StartPCKS',idxSample,'StopPCKS',stopSample,simulation);

            case "APRX"

                % 'APRX': receive: PE?
                % YES: note PE, data queue handling etc., 'APIdle' new slottime cycle
                % No: TP note, data queue handling etc., 'APACK' new slottime cycle

                startSample = NewEvent.(5);
                stopSample = NewEvent.(6);

                % get rx signal from STA channel
                idxCH = all_bss{idxAP}.ch;
                rx = CHSTA{idxAP,idxSTA,idxCH}(startSample+OSCHSTA(idxAP,idxSTA,idxCH):stopSample+OSCHSTA(idxAP,idxSTA,idxCH),:);
                
                % add noise by awgn channel, if selected; use SNR model for AWGN for LOOP-SNR
                switch simulation.approach
                    case 'LoopOver'
                        switch simulation.LoopPar
                            case 'SNR'
                                % switch over to SNR model for AWGN
                                    release(awgnChannel);
                                    awgnChannel.NoiseMethod = 'Signal to noise ratio (SNR)';
                                    awgnChannel.SNR = cfgSimu{idxAP,idxSTA}.SNR;
                                    % 1 Watt all STS as scaling and PL is off, SNR by antenna
                                    % parameter for awgn is power / STS with noise / STS
                                    awgnChannel.SignalPower = 1/all_bss{idxAP}.num_rx;
                            otherwise
                                % stay with variance model
                        end
                    otherwise
                        % stay with variance model
                end
                
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
    %                     SINRcalc{idxAP,idxSTA} = 0;
                end

                txPSDU = txPSDUs_DL{idxAP};

                % try receive
                PacketErrorUser = false;
                try
                    [PacketErrorUser,SINRest] = Receive(rx,txPSDU,idxAP,idxSTA,cfgPHY,SINRest,simulation);
                catch
                    disp('error during receive of packet');
                end

                % update data queues based on packet error
                switch simulation.PHYType
                    case 'IEEE 802.11ax'
                        movebyte = cfgPHY{idxAP,idxSTA}.APEPLength;
                    case 'IEEE 802.11n'
                        movebyte = cfgPHY{idxAP,idxSTA}.PSDULength;
                    case 'IEEE 802.11a'
                        movebyte = cfgPHY{idxAP,idxSTA}.PSDULength;
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

                    % reset error counters, EIFS flag for all APs
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
                switch simulation.PHYType
                    case 'IEEE 802.11ax'
                        cfgPHY{idxAP,idxSTA}.APEPLength = saveCFG(idxAP,idxSTA).Length;
                    case 'IEEE 802.11n'
                        cfgPHY{idxAP,idxSTA}.PSDULength = saveCFG(idxAP,idxSTA).Length;
                    case 'IEEE 802.11a'
                        cfgPHY{idxAP,idxSTA}.PSDULength = saveCFG(idxAP,idxSTA).Length;
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