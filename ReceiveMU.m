% **********************************************************************************************************************
function [PacketErrorUser,SINRest] = ReceiveMU(rx,txPSDU,idxAP,idxSTA,cfgPHY,SINRest,simulation,numStream,streamID)
% rx is baseband stream (#rx antennas) of receive packet after tgax, awgn; txPSDU is cell array of PSDU by user/STA
% idxAP is current BSS; idxSTA is current STA from event, always receive for all users
% cfgPHY is cell array by AP & STA to hold configuration
% this version is for SDM across links and MU only with ax. The right stream will be checked for errors.

cfg = cfgPHY;

% Get the field indices to extract fields from the PPDU
ind = wlanFieldIndices(cfg);
fs = wlanSampleRate(cfg);
chanBW = cfg.ChannelBandwidth;
PacketErrorUser = zeros(1,1);
scIndices = helperOccupiedSubcarrierIndices('HE-Data',cfg);

% There is just one RU and STAx is reflected by streamID
ruIdx = 1;
userIdx = streamID;



% this is a MU pseudo loop to allow designed exit 
for ruIdx = 1:1

    % Packet detect and determine coarse packet offset
    coarsePktOffset = wlanPacketDetect(rx,chanBW);
    if isempty(coarsePktOffset) % If empty no L-STF detected; packet error
        PacketErrorUser = PacketErrorUser+1;
        continue; % Go to next loop iteration
    end

    % Extract L-STF and perform coarse frequency offset correction
    lstf = rx(coarsePktOffset+(ind.LSTF(1):ind.LSTF(2)),:); 
    coarseFreqOff = wlanCoarseCFOEstimate(lstf,chanBW);
    rx = helperFrequencyOffset(rx,fs,-coarseFreqOff);

    % Extract the non-HT fields and determine fine packet offset
    nonhtfields = rx(coarsePktOffset+(ind.LSTF(1):ind.LSIG(2)),:); 
    finePktOffset = wlanSymbolTimingEstimate(nonhtfields,chanBW);

    % Determine final packet offset
    pktOffset = coarsePktOffset+finePktOffset;

    % If packet detected outwith the range of expected delays from the channel modeling; packet error
    if pktOffset>50
        PacketErrorUser = PacketErrorUser+1;
        continue; % Go to next loop iteration
    end

    % Extract L-LTF and perform fine frequency offset correction
    rxLLTF = rx(pktOffset+(ind.LLTF(1):ind.LLTF(2)),:);
    fineFreqOff = wlanFineCFOEstimate(rxLLTF,chanBW);
    rx = helperFrequencyOffset(rx,fs,-fineFreqOff);

    % HE-LTF demodulation and channel estimation
    rxHELTF = rx(pktOffset+(ind.HELTF(1):ind.HELTF(2)),:);
    heltfDemod = helperOFDMDemodulate(rxHELTF,'HE-LTF',cfg,ruIdx);
    [chanEst,pilotEst] = heLTFChannelEstimate(heltfDemod,cfg,ruIdx);

    % HE data demodulate
    rxData = rx(pktOffset+(ind.HEData(1):ind.HEData(2)),:); 
    demodSym = helperOFDMDemodulate(rxData,'HE-Data',cfg,ruIdx);

    % Pilot phase tracking
    % Average single-stream pilot estimates over symbols (2nd dimension)
    pilotEstTrack = mean(pilotEst,2);
    demodSym = heCommonPhaseErrorTracking(demodSym,pilotEstTrack,cfg,ruIdx);
    
% % %     % Pilot phase tracking
% % %     demodSym = heCommonPhaseErrorTracking(demodSym,chanEst,cfg,ruIdx);

% % %     % Estimate noise power in HE fields
% % %     ruMappingInd = helperOccupiedSubcarrierIndices('HE-Data',cfg);
% % %     nVarEst = heNoiseEstimate(demodSym(ruMappingInd.Pilot,:,:),pilotEst,cfg);

% % %     % Estimate noise power in HE fields
% % %     nVarEst = heNoiseEstimate(demodSym(scIndices.Pilot,:,:),pilotEst,cfg,ruIdx);

    % Estimate noise power in HE fields
    nVarEst = heNoiseEstimate(demodSym(scIndices.Pilot,:,:),pilotEstTrack,cfg,ruIdx);

% % %     % Equalize
% % %     [eqSym,csi] = heEqualizeCombine(demodSym,chanEst,nVarEst,cfg);
% % % 
% % %     % Discard pilot subcarriers
% % %     rxDataUser = eqSym(ruMappingInd.Data,:,:);
% % %     csiData = csi(ruMappingInd.Data,:);
% % % 
% % %     % Demap and decode bits, also join multiple STS to data
% % %     rxPSDU = wlanHEDataBitRecover(rxDataUser,nVarEst,csiData,cfg);
    
    % Extract data subcarriers from demodulated symbols and channel estimate
    demodDataSym = demodSym(scIndices.Data,:,:);
    chanEstData = chanEst(scIndices.Data,:,:);

    % Equalization, userIdx selects target stream
    [eqDataSym,csi] = heEqualizeCombine(demodDataSym,chanEstData,nVarEst,cfg,userIdx);

    % Recover data
    rxPSDU = wlanHEDataBitRecover(eqDataSym,nVarEst,csi,cfg,userIdx);        

    % SNR estimation per receive antenna
    powHELTF = mean(rxHELTF.*conj(rxHELTF));
    estSigPower = powHELTF-nVarEst;
    if estSigPower > nVarEst
        estimatedSNR = 10*log10(mean(estSigPower./nVarEst));

        % store estimated SINR for later use, size to max 10
        SINRestVec = SINRest{idxAP,idxSTA};
        SINRestVec = [SINRestVec estimatedSNR];
        if length(SINRestVec) > 10  % along packets
            SINRestVec = SINRestVec(end+1-10:end);
        end
        SINRest{idxAP,idxSTA} = SINRestVec;
    else
        SINRest{idxAP,idxSTA} = 0;
    end

    % Compare bit error 
    packetError = ~isequal(txPSDU,rxPSDU);
    PacketErrorUser = PacketErrorUser+packetError;

end    


end                