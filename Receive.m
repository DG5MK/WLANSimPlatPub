% **********************************************************************************************************************
function [PacketErrorUser,SINRest] = Receive(rx,txPSDU,idxAP,idxSTA,cfgPHY,SINRest,simulation)
% rx is baseband stream (#rx antennas) of receive packet after tgax, awgn; txPSDU is cell array of PSDU by user/STA
% idxAP is current BSS; idxSTA is current STA from event, always receive for all users
% cfgHE is cell array by AP & STA to hold configuration

cfg = cfgPHY{idxAP,idxSTA};

% Get the field indices to extract fields from the PPDU
ind = wlanFieldIndices(cfg);
fs = wlanSampleRate(cfg);
chanBW = cfg.ChannelBandwidth;
PacketErrorUser = zeros(1,1);

% Per user processing
userIdx = 1;

switch simulation.PHYType

    case 'IEEE 802.11ax'

        % this is a MU pseudo loop to allow designed exit 
        for ruIdx = 1:1

            % Packet detect and determine coarse packet offset
            coarsePktOffset = wlanPacketDetect(rx,chanBW);
            if isempty(coarsePktOffset) % If empty no L-STF detected; packet error
                PacketErrorUser(userIdx) = PacketErrorUser(userIdx)+1;
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
                PacketErrorUser(userIdx) = PacketErrorUser(userIdx)+1;
                continue; % Go to next loop iteration
            end

            % Extract L-LTF and perform fine frequency offset correction
            rxLLTF = rx(pktOffset+(ind.LLTF(1):ind.LLTF(2)),:);
            fineFreqOff = wlanFineCFOEstimate(rxLLTF,chanBW);
            rx = helperFrequencyOffset(rx,fs,-fineFreqOff);

            % HE-LTF demodulation and channel estimation
            rxHELTF = rx(pktOffset+(ind.HELTF(1):ind.HELTF(2)),:);
            heltfDemod = helperOFDMDemodulate(rxHELTF,'HE-LTF',cfg);
            [chanEst,pilotEst] = heLTFChannelEstimate(heltfDemod,cfg);

            % HE data demodulate
            rxData = rx(pktOffset+(ind.HEData(1):ind.HEData(2)),:); 
            demodSym = helperOFDMDemodulate(rxData,'HE-Data',cfg);

            % Pilot phase tracking
            % Average single-stream pilot estimates over symbols (2nd dimension)
            pilotEstTrack = mean(pilotEst,2);
            demodSym = heCommonPhaseErrorTracking(demodSym,pilotEstTrack,cfg);

            % Estimate noise power in HE fields
            ruMappingInd = helperOccupiedSubcarrierIndices('HE-Data',cfg);
            nVarEst = heNoiseEstimate(demodSym(ruMappingInd.Pilot,:,:),pilotEstTrack,cfg);

            % Equalize
            [eqSym,csi] = heEqualizeCombine(demodSym,chanEst,nVarEst,cfg);

            % Discard pilot subcarriers
            rxDataUser = eqSym(ruMappingInd.Data,:,:);
            csiData = csi(ruMappingInd.Data,:);

            % Demap and decode bits, also join multiple STS to data
            rxPSDU = wlanHEDataBitRecover(rxDataUser,nVarEst,csiData,cfg);

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
            PacketErrorUser(userIdx) = PacketErrorUser(userIdx)+packetError;

        end    
    
    case 'IEEE 802.11n'

        % this is a MU pseudo loop to allow designed exit 
        for ruIdx = 1:1

            % Packet detect and determine coarse packet offset
            coarsePktOffset = wlanPacketDetect(rx,chanBW);
            if isempty(coarsePktOffset) % If empty no L-STF detected; packet error
                PacketErrorUser(userIdx) = PacketErrorUser(userIdx)+1;
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
                PacketErrorUser(userIdx) = PacketErrorUser(userIdx)+1;
                continue; % Go to next loop iteration
            end

            % Extract L-LTF and perform fine frequency offset correction
            rxLLTF = rx(pktOffset+(ind.LLTF(1):ind.LLTF(2)),:);
            fineFreqOff = wlanFineCFOEstimate(rxLLTF,chanBW);
            rx = helperFrequencyOffset(rx,fs,-fineFreqOff);

            % Extract HT-LTF samples from the waveform, demodulate and perform
            % channel estimation
            htltf = rx(pktOffset+(ind.HTLTF(1):ind.HTLTF(2)),:);
            htltfDemod = wlanHTLTFDemodulate(htltf,cfg);
            chanEst = wlanHTLTFChannelEstimate(htltfDemod,cfg);

            % Extract HT Data samples from the waveform
            htdata = rx(pktOffset+(ind.HTData(1):ind.HTData(2)),:);

            % Estimate the noise power in HT data field
            nVarHT = htNoiseEstimate(htdata,chanEst,cfg);

            % Recover the transmitted PSDU in HT Data
            rxPSDU = wlanHTDataRecover(htdata,chanEst,nVarHT,cfg);

            % SNR estimation per receive antenna
            powHTLTF = mean(htltf.*conj(htltf));
            estSigPower = powHTLTF-nVarHT;
            if estSigPower > nVarHT
                estimatedSNR = 10*log10(mean(estSigPower./nVarHT));

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
            PacketErrorUser(userIdx) = PacketErrorUser(userIdx)+packetError;

        end       
    
    case 'IEEE 802.11a'

        % this is a MU pseudo loop to allow designed exit 
        for ruIdx = 1:1

            % Packet detect and determine coarse packet offset
            coarsePktOffset = wlanPacketDetect(rx,chanBW);
            if isempty(coarsePktOffset) % If empty no L-STF detected; packet error
                PacketErrorUser(userIdx) = PacketErrorUser(userIdx)+1;
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
                PacketErrorUser(userIdx) = PacketErrorUser(userIdx)+1;
                continue; % Go to next loop iteration
            end

            % Extract L-LTF and perform fine frequency offset correction
            rxLLTF = rx(pktOffset+(ind.LLTF(1):ind.LLTF(2)),:);
            fineFreqOff = wlanFineCFOEstimate(rxLLTF,chanBW);
            rx = helperFrequencyOffset(rx,fs,-fineFreqOff);

            % Extract NonHT-LTF samples from the waveform, demodulate and perform
            % channel estimation
            nonhtltf = rx(pktOffset+(ind.LLTF(1):ind.LLTF(2)),:);
            nonhtltfDemod = wlanLLTFDemodulate(nonhtltf,cfg);
            chanEst = wlanLLTFChannelEstimate(nonhtltfDemod,cfg);

            % Extract nonHT Data samples from the waveform
            nonhtdata = rx(pktOffset+(ind.NonHTData(1):ind.NonHTData(2)),:);

            % Estimate the noise power in nonHT data field
            nVarnonHT = helperNoiseEstimate(nonhtltfDemod);

            % Recover the transmitted PSDU in nonHT Data
            rxPSDU = wlanNonHTDataRecover(nonhtdata,chanEst,nVarnonHT,cfg);

            % SNR estimation per receive antenna
            powNonHTLTF = mean(nonhtltf.*conj(nonhtltf));
            estSigPower = powNonHTLTF-nVarnonHT;
            if estSigPower > nVarnonHT
                estimatedSNR = 10*log10(mean(estSigPower./nVarnonHT));

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
            PacketErrorUser(userIdx) = PacketErrorUser(userIdx)+packetError;

        end    

end                

end