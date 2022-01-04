% simulation type to perform A2B comparision
function [resultU,resultB] = sim_A2B(all_bss,all_paths_STA_DL,all_paths_AP_DL,all_pathloss_STA_DL,...
    all_pathloss_AP_DL,all_paths_STA_UL,all_paths_AP_UL,all_pathloss_STA_UL,all_pathloss_AP_UL,...
    simulation,resultU,resultB, h_start_simu_pushbtn)
% This function runs 2 different approaches; after allocating common parameters for each approach a specific
% initialization takes place, the simulation does run and results are collected in a stats structure. Last part is 
% to generate reports from statistics. For more details see documentation. 

% **********************************************************************************************************************
% COMMON TO A&B APPROACHES
% **********************************************************************************************************************

% **********************************************************************************************************************
% create general simulation configuration
% **********************************************************************************************************************

simulation.diag = true;
diag = simulation.diag;

T = 290;
k = physconst('Boltzmann');
B = 20e6;
N = B*k*T;
NIEEE = -102;
% % % N= -102;        % noise floor in dB
% F = 0;
F = 10;
simulation.BW = B;
simulation.N_dBm = 10*log10(N)+30+F;
% simulation.S_free_dBm = -91.7;
% simulation.CCA_ED = -60;   % in dBm
% simulation.CCA_ED = -50;   % in dBm

simulation.S_free_dBm = -82;
simulation.CCA_ED = -82;   % in dBm
% simulation.S_free_dBm = -57;
% simulation.CCA_ED = -57;
simulation.maxTP = 20; % in dBm

simulation.CarrierFrequency = 2.4E9;
simulation.lambda = physconst('LightSpeed')/simulation.CarrierFrequency;
simulation.fs = 20E6;
simulation.Ts = 1/simulation.fs;

numBSS = numel(all_bss);

simulation.maxRetryCountSuspend = 10;
simulation.SchedulerCountResetSuspend = 30;

usefadingchannel = false;
switch simulation.ChannelModel
    case 'WINNER II'

        usefadingchannel = true;

    case 'TGax'
        
        usefadingchannel = true;

    case 'None'
end

% **********************************************************************************************************************
% define rates and MCS requirements by selected PHY for all simulation and plot types
% see also standard in Table 28.75 and Table 28.64 for GI 0.8, BW 20MHz
% min sensitivity see Tables 17-18, 19-23, 27-51, which are also valid for MIMO (TX power level lowered by #STS)

% ATTENTION: For 802.11a and 802.11n RUSER and REQSNR are temporarily taken from 802.11ax.

switch simulation.PHYType

    case 'IEEE 802.11ax'
        simulation.RPHY =[8.6 17.2 25.8 34.4 51.6 68.8 77.4 86.0 103.2 114.7 129.0 143.4];
        simulation.LEG = {'HE BPSK 1/2', 'HE QPSK 1/2', 'HE QPSK 3/4', 'HE 16-QAM 1/2', 'HE 16-QAM 3/4',...
            'HE 64-QAM 2/3', 'HE 64-QAM 3/4', 'HE 64-QAM 5/6', 'HE 256-QAM 3/4', 'HE 256-QAM 5/6',...
            'HE 1024-QAM 3/4', 'HE 1024-QAM 5/6'};
        simulation.MCSLEG = {'MCS0' 'MCS1' 'MCS2' 'MCS3' 'MCS4' 'MCS5' 'MCS6' 'MCS7' 'MCS8' 'MCS9' 'MCS10' 'MCS11'};
        simulation.MCS = [0 1 2 3 4 5 6 7 8 9 10 11];
        simulation.MINSENS = [-82 -79 -77 -74 -70 -66 -65 -64 -59 -57 -54 -52];

    case 'IEEE 802.11n'
        simulation.RPHY =[6.5 13.0 19.5 26.0 39.0 52.0 58.5 65.0];
        simulation.LEG = {'HT BPSK 1/2', 'HT QPSK 1/2', 'HT QPSK 3/4', 'HT 16-QAM 1/2', 'HT 16-QAM 3/4',...
            'HT 64-QAM 2/3', 'HT 64-QAM 3/4', 'HT 64-QAM 5/6'};
        simulation.MCSLEG = {'MCS0' 'MCS1' 'MCS2' 'MCS3' 'MCS4' 'MCS5' 'MCS6' 'MCS7'};
        simulation.MCS = [0 1 2 3 4 5 6 7];
        simulation.MINSENS = [-82 -79 -77 -74 -70 -66 -65 -64];

    case 'IEEE 802.11a'

        simulation.RPHY =[6 9 12 18 24 36 48 54];
        simulation.LEG = {'nonHT BPSK 1/2', 'nonHT BPSK 3/4', 'nonHT QPSK 1/2', 'nonHT QPSK 3/4', 'nonHT 16-QAM 1/2',...
            'nonHT 16-QAM 3/4', 'nonHT 64-QAM 2/3', 'nonHT 64-QAM 3/4'};
        simulation.MCSLEG = {'MCS0' 'MCS1' 'MCS2' 'MCS3' 'MCS4' 'MCS5' 'MCS6' 'MCS7'};
        simulation.MCS = [0 1 2 3 4 5 6 7];
        simulation.MINSENS = [-82 -81 -79 -77 -74 -70 -66 -65];

end          

switch simulation.RSNRBase
    
    case 'Sim1%PER'

        switch simulation.PHYType
            
            case 'IEEE 802.11ax'
%                 if usefadingchannel == true
                    simulation.RUSER = [8 16 23 30 41 53 56 60 70 76 83 84];
                    simulation.REQSNR = [17 19 24 25 29 32 34 37 39 42 44 48];
                    % rates and SNR requirement for SDM and SDMSR with 2 STS per STS
                    simulation.RUSERSR2 = [16 31 45 58 78 100 106 113 130 140 150 151];
                    simulation.REQSNRSR2 = [14 21 27 29 36 38 42 44 46 48 52 56];
                    simulation.RUSERSDMSR2 = [16 31 45 58 78 100 106 113 130 140 150 151]./2;
                    simulation.REQSNRSDMSR2 = [14 21 27 29 36 38 42 44 46 48 52 56];
%                 else % AWGN                   
%                     simulation.RUSER = [8 16 22 29 39 51 54 57 66 71 77 78];
%                     simulation.REQSNR = [5 7 9 13 15 19 21 23 26 28 31 33];
%                 end
                
            case 'IEEE 802.11n'
                if usefadingchannel == true
                    simulation.RUSER = [8 19 22 26 36 45 47 48];
                    simulation.REQSNR = [17 19 24 25 29 32 34 36];
                else % AWGN                   
                    simulation.RUSER = [8 16 22 29 39 51 54 57];
                    simulation.REQSNR = [5 7 9 13 15 19 21 23];
                end

            case 'IEEE 802.11a'
                if usefadingchannel == true
                    simulation.RUSER = [8 9 19 22 26 36 45 47];
                    simulation.REQSNR = [17 18 19 24 25 29 32 34];
                else % AWGN                   
                    simulation.RUSER = [8 9 16 22 29 39 51 54];
                    simulation.REQSNR = [5 6 7 9 13 15 19 21];
                end
                
        end

    case 'SimMAXTRP'

        switch simulation.PHYType
            
            case 'IEEE 802.11ax'
%                 if usefadingchannel == true                    
                    simulation.RUSER = [4 8 14 21 30 44 52 53 60 67 82 84];
                    simulation.REQSNR = [5 8 13 16 21 26 30 32 34 37 44 48];
                    % rates and SNR requirement for SDM and SDMSR with 2 STS per STS
                    simulation.RUSERSR2 = [5 24 33 45 61 83 96 100 119 126 143 151];
                    simulation.REQSNRSR2 = [6 14 18 23 27 33 36 38 41 43 47 54];
                    simulation.RUSERSDMSR2 = [5 24 33 45 61 83 96 100 119 126 143 151]./2;
                    simulation.REQSNRSDMSR2 = [6 14 18 23 27 33 36 38 41 43 47 54];
%                 else % AWGN                   
%                     simulation.RUSER = [8 16 22 29 39 51 54 57 66 71 77 78];
%                     simulation.REQSNR = [5 7 9 13 15 19 21 23 26 28 31 33];
%                 end
                
            case 'IEEE 802.11n'
                if usefadingchannel == true
                    simulation.RUSER = [8 19 22 26 36 45 47 48];
                    simulation.REQSNR = [17 19 24 25 29 32 34 36];
                else % AWGN                   
                    simulation.RUSER = [8 16 22 29 39 51 54 57];
                    simulation.REQSNR = [5 7 9 13 15 19 21 23];
                end

            case 'IEEE 802.11a'
                if usefadingchannel == true
                    simulation.RUSER = [8 9 19 22 26 36 45 47];
                    simulation.REQSNR = [17 18 19 24 25 29 32 34];
                else % AWGN                   
                    simulation.RUSER = [8 9 16 22 29 39 51 54];
                    simulation.REQSNR = [5 6 7 9 13 15 19 21];
                end
                
        end

    case 'IEEE802.11'

        switch simulation.PHYType

            case 'IEEE 802.11ax'
                if usefadingchannel == true
                    simulation.RUSER = [4 12 16 24 36 48 56 59 67 70 83 84]; % max TRP rates
                    simulation.REQSNR = simulation.MINSENS - NIEEE;
                    % rates and SNR requirement for SDM and SDMSR with 2 STS per STS
                    simulation.RUSERSR2 = [14 28 37 53 68 92 100 101 123 129 150 151]; % max TRP rates
                    simulation.REQSNRSR2 = simulation.MINSENS - NIEEE;
                    simulation.RUSERSDMSR2 = [14 28 37 53 68 92 100 101 123 129 150 151]./2; % max TRP rates
                    simulation.REQSNRSDMSR2 = simulation.MINSENS - NIEEE;
                else % AWGN                   
                    simulation.RUSER =[8 16 22 29 39 51 54 57 66 71 77 78];
                    simulation.REQSNR = simulation.MINSENS - NIEEE;
                end
                
            case 'IEEE 802.11n'
                if usefadingchannel == true
                    simulation.RUSER = [8 19 22 26 36 45 47 48];
                    simulation.REQSNR = simulation.MINSENS - NIEEE;
                else % AWGN                   
                    simulation.RUSER = [8 16 22 29 39 51 54 57];
                    simulation.REQSNR = simulation.MINSENS - NIEEE;
                end

            case 'IEEE 802.11a'
                if usefadingchannel == true
                    simulation.RUSER = [8 9 19 22 26 36 45 47];
                    simulation.REQSNR = simulation.MINSENS - NIEEE;
                else % AWGN                   
                    simulation.RUSER = [8 9 16 22 29 39 51 54];
                    simulation.REQSNR = simulation.MINSENS - NIEEE;
                end
                
        end
        
end

simulation.REQSNR = simulation.REQSNR + simulation.PERSNROffset;
switch simulation.PHYType

    case 'IEEE 802.11ax'
        if usefadingchannel == true
            simulation.REQSNRSR2 = simulation.REQSNRSR2 + simulation.PERSNROffset;
            simulation.REQSNRSDMSR2 = simulation.REQSNRSDMSR2 + simulation.PERSNROffset;
        end
end


% **********************************************************************************************************************

% generate pseudo SRRTS (Spatial Reuse RTS) payload in bits, based on ACK which does have space for needed values
macConfig = wlanMACFrameConfig('FrameType','ACK');
[macFrame,~] = wlanMACFrame(macConfig);
decimalBytes = hex2dec(macFrame);
simulation.SRRTSpsduBits = reshape(de2bi(decimalBytes, 8)', [], 1);
% add additional 10 bytes for each STA to cover address, max MCS and max TP
simulation.SRRTSpsduBits = simulation.SRRTSpsduBits + 8*10*(numBSS-1);

% generate pseudo ACK payload in bits
simulation.ACKpsduBits = reshape(de2bi(decimalBytes, 8)', [], 1);
% always use MCS2 (QPSK, 1/2) and IEEE802.11a for ACK packet for good reach and least overhead
% ACK duration will be 32 us, see Table 10-5 IEEE 802.11-2016
actTXbyte = length(simulation.ACKpsduBits)/8;              
cfg = wlanNonHTConfig();
cfg.ChannelBandwidth = 'CBW20';
cfg.NumTransmitAntennas = 1;
cfg.MCS = 2;
cfg.PSDULength = actTXbyte;
txPSDU = randi([0 1],actTXbyte*8,1,'int8');
txPacket = wlanWaveformGenerator(txPSDU,cfg,'IdleTime',2*1e-6);
simulation.ACK = length(txPacket)*simulation.Ts*1e6;

switch simulation.PHYType
    case 'IEEE 802.11ax'
        
        simulation.SLOTTIME = 9;   % in us
        simulation.SIFS =  10;
        simulation.DIFS =  simulation.SIFS + 2*simulation.SLOTTIME;
        simulation.CWMIN = 15;
        simulation.CWMAX = 1023;
        simulation.CWVector = [15 31 63 127 255 511 1023];
%         simulation.ACK = 32;
        simulation.EIFS = simulation.SIFS + simulation.ACK + simulation.DIFS;
        simulation.CCATime = 25;    % in us
        simulation.SINRTime = 25;    % in us
        simulation.SRIFSBase = -1;

    case 'IEEE 802.11n'
    
        simulation.SLOTTIME = 9;   % in us
        simulation.SIFS =  10;
        simulation.DIFS =  simulation.SIFS + 2*simulation.SLOTTIME;
        simulation.CWMIN = 15;
        simulation.CWMAX = 1023;
        simulation.CWVector = [15 31 63 127 255 511 1023];
%         simulation.ACK = 28;
        simulation.EIFS = simulation.SIFS + simulation.ACK + simulation.DIFS;
        simulation.CCATime = 25;    % in us
        simulation.SINRTime = 25;    % in us
        simulation.SRIFSBase = -1;

    case 'IEEE 802.11a'

        simulation.SLOTTIME = 9;   % in us
        simulation.SIFS =  16;
        simulation.DIFS =  simulation.SIFS + 2*simulation.SLOTTIME;
        simulation.CWMIN = 15;
        simulation.CWMAX = 1023;
        simulation.CWVector = [15 31 63 127 255 511 1023];
%         simulation.ACK = 28;
        simulation.EIFS = simulation.SIFS + simulation.ACK + simulation.DIFS;
        simulation.CCATime = 25;    % in us
        simulation.SINRTime = 25;    % in us
        simulation.SRIFSBase = -1;
        
end          

% move to dedicated stream if selected, for AWGN
if  ~strcmp(simulation.RandomStream,'Global stream')
    awgnChannel = comm.AWGNChannel('NoiseMethod','Variance','Variance',10^((simulation.N_dBm-30)/10),...
        'RandomStream','mt19937ar with seed', 'Seed',5);    
else
    awgnChannel = comm.AWGNChannel('NoiseMethod','Variance','Variance',10^((simulation.N_dBm-30)/10));
end

statsA.DATAQPlot = [];
statsA.PacketErrorPlotAP = [];
statsA.PacketErrorPlotSTA = [];
statsA.DatatransferedPlot = [];
statsA.ThroughputPlot = [];
statsA.NumberOfPackets = [];
statsA.Histo = [];
statsA.TimeHeader = [];
statsA.TimeData = [];
statsA.TimeACK = [];
statsA.TimeIFS = [];
statsA.TimeSRIFS = [];
statsA.TimeSRRTS = [];
statsA.TimeBackoff = [];
statsA.TimeIdle = [];
statsA.TimeWait = [];
statsA.TotalData = [];

statsB.DATAQPlot = [];
statsB.PacketErrorPlotAP = [];
statsB.PacketErrorPlotSTA = [];
statsB.DatatransferedPlot = [];
statsB.ThroughputPlot = [];
statsB.NumberOfPackets = [];
statsB.Histo = [];
statsB.TimeHeader = [];
statsB.TimeData = [];
statsB.TimeACK = [];
statsB.TimeIFS = [];
statsB.TimeSRIFS = [];
statsB.TimeSRRTS = [];
statsB.TimeBackoff = [];
statsB.TimeIdle = [];
statsB.TimeWait = [];
statsB.TotalData = [];

% **********************************************************************************************************************
% build channels for all combinations of AP to AP, AP to AP/STA, AP/STA to AP and AP/STA to AP/STA
% the index is 'from' 'to' meaning tgaxSTA_xL{idxAPTX, idxSTATX, idxBSSRX,idxSTARX}
cfgSimu = cell(1,1);
chSTA_DL = cell(1,1);
chAP_DL = cell(1,1);
chSTA_UL = cell(1,1);
chAP_UL = cell(1,1);

switch simulation.ChannelModel
    case 'WINNER II'
        
        % generate generic W2 model
        
        % default antenna arrays, all ULAs, build all versions as this takes time
        disp('Building WINNER II antenna arrays');
        
        % try loading w2 arrays, if not exist create new ones and save
        if isfile('variables/W2ULA.mat')
            load('variables/W2ULA.mat','W2ULA');
            AA = W2ULA;
        else
            for AAidx = 1:8
                W2ULA{AAidx} = winner2.AntennaArray('ULA', AAidx, simulation.lambda/2);
            end
            save('variables/W2ULA.mat','W2ULA');
            AA = W2ULA;
        end
        disp('WINNER II antenna arrays established');
        
        % default layout for AP and STA, only single link
        rndSeed = 12;
        STAIdx   = [2]; 
        APIdx   = {[1]};
        numLinks = 1;
        cfgLayout = winner2.layoutparset(STAIdx, APIdx, numLinks, [AA{1} AA{1}], [], rndSeed);

        switch simulation.w2Scenario
            case 'A1'
                cfgLayout.ScenarioVector = [1];             % A1 scenario
        end        
        
        switch simulation.w2PropCondition
            case 'NLOS'
                cfgLayout.PropagConditionVector = [0];      % NLOS
            case 'LOS'
                cfgLayout.PropagConditionVector = [1];      % LOS
        end
        
        cfgLayout.Stations(1).Pos([1 2 3]) = [1; 2; 3];
        cfgLayout.Stations(2).Pos([1 2 3]) = [4; 5; 6];
        cfgLayout.Pairing = [1; 2];
        
        % use velocity = 0.01 to prevent error and enable f sample calculation
        maxVelocity = 0.01;
        cfgLayout.Stations(2).Velocity = [maxVelocity; 0; 0];
        
        % default model
        cfgModel = winner2.wimparset;
        cfgModel.UseManualPropCondition = 'yes';
        cfgModel.CenterFrequency = simulation.CarrierFrequency;
        % cfgModel.NumTimeSamples = lengthSig; % defined later
    
        % use fixed seed if selected, deafult is global stream
        if  ~strcmp(simulation.RandomStream,'Global stream')
            cfgModel.RandomSeed         = 111;
        end
        
        % use max speed 0.01 m/s which leads to a sample rate equal to bandwidth
        % MATLAB uses other formula than original WINNER II model
        % the sample rate is directly coupled internally to the max velocity defined in stations
        cfgModel.UniformTimeSampling = 'yes';
        cfgModel.SampleDensity = round(physconst('LightSpeed')/cfgModel.CenterFrequency/2/(maxVelocity/simulation.fs));

        % create the default channel object
        w2 = comm.WINNER2Channel(cfgModel, cfgLayout);

% % %         % show parameters
% % %         chanInfo = info(tgax)
        
        % now build channel objects by link and adjust parameters
        for idxAP = 1:numBSS
            for idxBSS = 1:numBSS
                % this is AP to AP DL
                if idxAP ~= idxBSS % no channel to itself
                    chAP_DL{idxAP,idxBSS} = clone(w2);
                    release(chAP_DL{idxAP,idxBSS}); % allow changing non tunable if exists
                    % recreate layoutparset to cover actual antenna configuration
                    numTXAnt = all_bss{idxAP}.num_tx;   % AP antennas from / TX
                    numRXAnt = all_bss{idxBSS}.num_tx;  % AP antennas to / RX, needed for CSA
                    cfgLayout = winner2.layoutparset(STAIdx, APIdx, numLinks, [AA{numTXAnt} AA{numRXAnt}], [], rndSeed);
                    switch simulation.w2Scenario
                        case 'A1'
                            cfgLayout.ScenarioVector = [1];             % A1 scenario
                    end        
                    switch simulation.w2PropCondition
                        case 'NLOS'
                            cfgLayout.PropagConditionVector = [0];      % NLOS
                        case 'LOS'
                            cfgLayout.PropagConditionVector = [1];      % LOS
                    end                    
                    cfgLayout.Pairing = [1; 2];
                    cfgLayout.Stations(2).Velocity = [maxVelocity; 0; 0];
                    % positions
                    xFrom = all_bss{idxAP}.AP_pos(1);
                    yFrom = all_bss{idxAP}.AP_pos(2);
                    zFrom = all_bss{idxAP}.AP_pos(3);
                    xTo = all_bss{idxBSS}.AP_pos(1);
                    yTo = all_bss{idxBSS}.AP_pos(2);
                    zTo = all_bss{idxBSS}.AP_pos(3);
                    cfgLayout.Stations(1).Pos([1 2 3]) = [xFrom; yFrom; zFrom];
                    cfgLayout.Stations(2).Pos([1 2 3]) = [xTo; yTo; zTo];
                    % assign new layout to channel
                    chAP_DL{idxAP,idxBSS}.LayoutConfig = cfgLayout;
                end

                numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
                for idxSTA = 1:numSTAs
                    %this is AP to AP/STA DL
                    chSTA_DL{idxAP,idxBSS,idxSTA} = clone(w2);
                    release(chSTA_DL{idxAP,idxBSS,idxSTA}); % allow changing non tunable if exists
                    % recreate layoutparset to cover actual antenna configuration
                    numTXAnt = all_bss{idxAP}.num_tx;   % AP antennas from / TX
                    numRXAnt = all_bss{idxBSS}.num_rx;  % STA antennas to / RX
                    cfgLayout = winner2.layoutparset(STAIdx, APIdx, numLinks, [AA{numTXAnt} AA{numRXAnt}], [], rndSeed);
                    switch simulation.w2Scenario
                        case 'A1'
                            cfgLayout.ScenarioVector = [1];             % A1 scenario
                    end        
                    switch simulation.w2PropCondition
                        case 'NLOS'
                            cfgLayout.PropagConditionVector = [0];      % NLOS
                        case 'LOS'
                            cfgLayout.PropagConditionVector = [1];      % LOS
                    end                    
                    cfgLayout.Pairing = [1; 2];
                    cfgLayout.Stations(2).Velocity = [maxVelocity; 0; 0];
                    % positions
                    xFrom = all_bss{idxAP}.AP_pos(1);
                    yFrom = all_bss{idxAP}.AP_pos(2);
                    zFrom = all_bss{idxAP}.AP_pos(3);
                    xTo = all_bss{idxBSS}.STAs_pos(idxSTA,1);
                    yTo = all_bss{idxBSS}.STAs_pos(idxSTA,2);
                    zTo = all_bss{idxBSS}.STAs_pos(idxSTA,3);
                    cfgLayout.Stations(1).Pos([1 2 3]) = [xFrom; yFrom; zFrom];
                    cfgLayout.Stations(2).Pos([1 2 3]) = [xTo; yTo; zTo];
                    % assign new layout to channel
                    chSTA_DL{idxAP,idxBSS,idxSTA}.LayoutConfig = cfgLayout;
                end
            end
        end

        for idxAP = 1:numBSS

            numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            for idxTXSTA = 1:numSTAs    
                for idxBSS = 1:numBSS            
                    % this is AP/STA to AP UL
                    chAP_UL{idxAP,idxTXSTA,idxBSS} = clone(w2);
                    release(chAP_UL{idxAP,idxTXSTA,idxBSS}); % allow changing non tunable if exists
                    % recreate layoutparset to cover actual antenna configuration
                    numTXAnt = all_bss{idxAP}.num_rx;   % STA antennas from / TX
                    numRXAnt = all_bss{idxBSS}.num_tx;  % AP antennas to / RX
                    cfgLayout = winner2.layoutparset(STAIdx, APIdx, numLinks, [AA{numTXAnt} AA{numRXAnt}], [], rndSeed);
                    switch simulation.w2Scenario
                        case 'A1'
                            cfgLayout.ScenarioVector = [1];             % A1 scenario
                    end        

                    switch simulation.w2PropCondition
                        case 'NLOS'
                            cfgLayout.PropagConditionVector = [0];      % NLOS
                        case 'LOS'
                            cfgLayout.PropagConditionVector = [1];      % LOS
                    end                    
                    cfgLayout.Pairing = [1; 2];
                    cfgLayout.Stations(2).Velocity = [maxVelocity; 0; 0];
                    % positions
                    xFrom = all_bss{idxAP}.STAs_pos(idxTXSTA,1);
                    yFrom = all_bss{idxAP}.STAs_pos(idxTXSTA,2);
                    zFrom = all_bss{idxAP}.STAs_pos(idxTXSTA,3);
                    xTo = all_bss{idxBSS}.AP_pos(1);
                    yTo = all_bss{idxBSS}.AP_pos(2);
                    zTo = all_bss{idxBSS}.AP_pos(3);
                    cfgLayout.Stations(1).Pos([1 2 3]) = [xFrom; yFrom; zFrom];
                    cfgLayout.Stations(2).Pos([1 2 3]) = [xTo; yTo; zTo];
                    % assign new layout to channel
                    chAP_UL{idxAP,idxTXSTA,idxBSS}.LayoutConfig = cfgLayout;
                    
                    numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
                    for idxSTA = 1:numSTAs

                        %this is AP/STA to AP/STA UL
                        chSTA_UL{idxAP,idxTXSTA,idxBSS,idxSTA} = clone(w2);
                        release(chSTA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}); % allow changing non tunable if exists
                        % recreate layoutparset to cover actual antenna configuration
                        numTXAnt = all_bss{idxAP}.num_rx;   % STA antennas from / TX
                        numRXAnt = all_bss{idxBSS}.num_rx;  % STA antennas to / RX
                        cfgLayout = winner2.layoutparset(STAIdx, APIdx, numLinks, [AA{numTXAnt} AA{numRXAnt}], [], rndSeed);
                        switch simulation.w2Scenario
                            case 'A1'
                                cfgLayout.ScenarioVector = [1];             % A1 scenario
                        end        

                        switch simulation.w2PropCondition
                            case 'NLOS'
                                cfgLayout.PropagConditionVector = [0];      % NLOS
                            case 'LOS'
                                cfgLayout.PropagConditionVector = [1];      % LOS
                        end                    
                        cfgLayout.Pairing = [1; 2];
                        cfgLayout.Stations(2).Velocity = [maxVelocity; 0; 0];
                        % positions
                        xFrom = all_bss{idxAP}.STAs_pos(idxTXSTA,1);
                        yFrom = all_bss{idxAP}.STAs_pos(idxTXSTA,2);
                        zFrom = all_bss{idxAP}.STAs_pos(idxTXSTA,3);
                        xTo = all_bss{idxBSS}.STAs_pos(idxSTA,1);
                        yTo = all_bss{idxBSS}.STAs_pos(idxSTA,2);
                        zTo = all_bss{idxBSS}.STAs_pos(idxSTA,3);
                        cfgLayout.Stations(1).Pos([1 2 3]) = [xFrom; yFrom; zFrom];
                        cfgLayout.Stations(2).Pos([1 2 3]) = [xTo; yTo; zTo];
                        % assign new layout to channel
                        chSTA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}.LayoutConfig = cfgLayout;

                    end            
                end    
            end    
        end        
        
    case 'TGax'

        tgax = wlanTGaxChannel;
        tgax.LargeScaleFadingEffect = 'None';    % done seperately by scaling
        tgax.SampleRate = simulation.fs; 
        tgax.DelayProfile = simulation.DelayProfile;
        tgax.ChannelBandwidth = 'CBW20';
        tgax.CarrierFrequency = simulation.CarrierFrequency;
        tgax.EnvironmentalSpeed = 0;            % doppler effect = time variance
        release(tgax);                          % release to change non tunable if already exists
        tgax.RandomStream = simulation.RandomStream;
        if  ~strcmp(simulation.RandomStream,'Global stream')
            tgax.Seed = 5;
        end

        for idxAP = 1:numBSS
            for idxBSS = 1:numBSS
                % this is AP to AP
                if idxAP ~= idxBSS % no channel to itself
                    chAP_DL{idxAP,idxBSS} = clone(tgax);
                    release(chAP_DL{idxAP,idxBSS}); % allow changing non tunable if exists
                    chAP_DL{idxAP,idxBSS}.NumTransmitAntennas = all_bss{idxAP}.num_tx;
                    chAP_DL{idxAP,idxBSS}.NumReceiveAntennas = all_bss{idxBSS}.num_rx;
        %             tgaxAP_DL{idxAP,idxBSS}.TransmitReceiveDistance = all_paths_AP_DL{idxAP,idxBSS}.distance;
                end

                numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
                for idxSTA = 1:numSTAs
                    %this is AP to AP/STA
                    chSTA_DL{idxAP,idxBSS,idxSTA} = clone(tgax);
                    release(chSTA_DL{idxAP,idxBSS,idxSTA}); % allow changing non tunable if exists
                    chSTA_DL{idxAP,idxBSS,idxSTA}.UserIndex = idxSTA;
                    chSTA_DL{idxAP,idxBSS,idxSTA}.NumTransmitAntennas = all_bss{idxAP}.num_tx;
                    chSTA_DL{idxAP,idxBSS,idxSTA}.NumReceiveAntennas = all_bss{idxBSS}.num_rx;
        %             tgaxSTA_DL{idxAP,idxBSS,idxSTA}.TransmitReceiveDistance = all_paths_STA_DL{idxAP,idxBSS,idxSTA}.distance;
                end
            end
        end

        for idxAP = 1:numBSS

            numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            for idxTXSTA = 1:numSTAs    
                for idxBSS = 1:numBSS            
                    % this is AP/STA to AP
                    chAP_UL{idxAP,idxTXSTA,idxBSS} = clone(tgax);
                    release(chAP_UL{idxAP,idxTXSTA,idxBSS}); % allow changing non tunable if exists
                    chAP_UL{idxAP,idxTXSTA,idxBSS}.NumTransmitAntennas = all_bss{idxAP}.num_tx;
                    chAP_UL{idxAP,idxTXSTA,idxBSS}.NumReceiveAntennas = all_bss{idxBSS}.num_rx;
                    chAP_UL{idxAP,idxTXSTA,idxBSS}.TransmissionDirection = 'Uplink';
        %             tgaxAP_UL{idxAP,idxTXSTA,idxBSS}.TransmitReceiveDistance = all_paths_AP_UL{idxAP,idxTXSTA,idxBSS}.distance;

                    numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
                    for idxSTA = 1:numSTAs

                        %this is AP/STA to AP/STA
                        chSTA_UL{idxAP,idxTXSTA,idxBSS,idxSTA} = clone(tgax);
                        release(chSTA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}); % allow changing non tunable if exists
                        chSTA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}.UserIndex = idxSTA;
                        chSTA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}.NumTransmitAntennas = all_bss{idxAP}.num_tx;
                        chSTA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}.NumReceiveAntennas = all_bss{idxBSS}.num_rx;
                        chSTA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}.TransmissionDirection = 'Uplink';
        %                 tgaxSTA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}.TransmitReceiveDistance = ...
        %                     all_paths_STA_UL{idxAP,idxTXSTA,idxBSS,idxSTA}.distance;
                    end            
                end    
            end    
        end        
        
    case 'None'
end


% **********************************************************************************************************************
% build simulation parameters by BSS
for idxBSS = 1:numBSS %every AP/BSS with STAs
    numSTAs = size(all_bss{idxBSS}.STAs_pos,1);    
    for idxSTA = 1:numSTAs %every STA from LINK
        cfgSimu{idxBSS,idxSTA}.NoiseFloor = simulation.N_dBm;
        cfgSimu{idxBSS,idxSTA}.IdleTime = 2;
        cfgSimu{idxBSS,idxSTA}.GuardInterval = 0.8;
        cfgSimu{idxBSS,idxSTA}.Interferer = simulation.interferer;
        cfgSimu{idxBSS,idxSTA}.RandomStream = simulation.RandomStream;    
        cfgSimu{idxBSS,idxSTA}.TransmitPower = all_bss{idxBSS}.tx_power;
    end    
end    

% **********************************************************************************************************************
% RUN A APPROACH
% **********************************************************************************************************************
if diag == true;disp([datestr(now,0),' Starting approach A']);end

% **********************************************************************************************************************
% allocate resources and load to queues
% **********************************************************************************************************************
% the channel is complex baseband by STA by AP at fs, also RX by AP, for CCA the channel may have multiple streams,
% due to n RX antennas; the channel signal strength indicator is used for dynamic MCS etc.

% use table data type for global event queue GEQ
Time = [];
AP = [];
STA = [];
Event = [];
VAR1 = [];
VAR2 = [];
VAR3 = [];
VAR4 = [];
VAR5 = [];
GEQ = table(Time, AP, STA, Event, VAR1, VAR2, VAR3, VAR4, VAR5);

% use cell array of tables for latency measurement
idxT = [];
dPL = [];
for idxBSS = 1:numBSS
    LT{idxBSS} = table(idxT, dPL);
end

APSTATE = "";
DATAQ = [];
DATAPENQ = [];
saveCFG = [];
SINRest = {[]};
SINRcalc = {[]};
CHAP = {[]};
CHSTA = {[]};
OSCHAP = [];                         % offset to address channels, after garbage collection
OSCHSTA = [];                        % offset to address channels, after garbage collection
APCNT = {};                         % cell array to hold counter by AP etc.
APSTACNT = {};                      % cell array to hold counter by STA & AP etc.
SCHEDCNT = 0;                       % count for scheduler
lastTXPck_DL = {};                  % last TX packet by AP for SINR calculation
lastTXPck_UL = {};                  % last TX packet by AP for SINR calculation
txPSDUs_DL = {};                    % holds PSDU content for comparision of payload error
txPSDUs_UL = {};                    % holds PSDU content for comparision of payload error

% **********************************************************************************************************************
% for every AP to STA, allocate zero data into data queue and queue plot; allocate zero complex data into the channel 
% to allow estimation at start
for idxAP = 1:numBSS %every AP
    numSTAs = size(all_bss{idxAP}.STAs_pos,1);
    for idxCH = 1:simulation.numCH
        CHAP{idxAP,idxCH} = complex(zeros(1000,1));
        OSCHAP(idxAP,idxCH) = 0;
    end
    APSTATE(idxAP) = "APIdle";
    APCNT{idxAP}.SRC = 0;                               % reset AP retry count for CSMA/CA
    APCNT{idxAP}.PrevError = false;                     % flag for unsuccessful previous tx attempt
    APCNT{idxAP}.IFS = 0;
    APCNT{idxAP}.BO = 0;
    APCNT{idxAP}.ChannelWasBusy = 0;                    % flag for channel condition busy during CCA
    APCNT{idxAP}.SelSTA = 1;
    APCNT{idxAP}.SelMCS = 0;
    APCNT{idxAP}.SelTP = -200;
    APCNT{idxAP}.SelPLBytes = 0;
    APCNT{idxAP}.INmax = -200;                           % for CSMA/SR spatial reuse
    APCNT{idxAP}.TXdur = 0;
    APCNT{idxAP}.APLead = 0;
    APCNT{idxAP}.APCont = 0;
    APCNT{idxAP}.SRIFS = 0;
    APCNT{idxAP}.SRTX = 0;
    APCNT{idxAP}.idxRTSTXburst = 0;
    APCNT{idxAP}.StreamID = 0;                          % for CSMA/SDM and CSMA/SDMSR
    APCNT{idxAP}.numStream = 0;
    APCNT{idxAP}.useBF = false;
    for idxSTA = 1:numSTAs % every STA from LINK
        APSTACNT{idxAP,idxSTA}.SRC = 0;                 % reset station retry count
        DATAQ(idxAP,idxSTA) = 0;
        DATAPENQ(idxAP,idxSTA) = 0;
        saveCFG(idxAP,idxSTA).MCS = 0;
        saveCFG(idxAP,idxSTA).Length = 0;
        statsA.TotalData(idxAP,idxSTA) = 0;
        statsA.DATAQPlot(idxAP,idxSTA).lengths = [];
        statsA.DATAQPlot(idxAP,idxSTA).times = [];
        statsA.PacketErrorPlotSTA(idxAP,idxSTA) = 0;
        statsA.PacketErrorPlotAP(idxAP) = 0;
        statsA.DatatransferedPlot(idxAP,idxSTA) = 0;
        statsA.ThroughputPlot(idxAP,idxSTA) = 0;
        statsA.NumberOfPackets(idxAP,idxSTA) = 0;
        statsA.Histo(idxAP,idxSTA).TP = [];
        statsA.Histo(idxAP,idxSTA).MCS = [];
        statsA.Histo(idxAP,idxSTA).estSINR = [];
        statsA.Histo(idxAP,idxSTA).calcSINR = [];
        statsA.Histo(idxAP,idxSTA).timeLatency = [];    % latency times
        statsA.TimeHeader(idxAP) = 0;
        statsA.TimeData(idxAP) = 0;
        statsA.TimeACK(idxAP) = 0;
        statsA.TimeIFS(idxAP) = 0;
        statsA.TimeSRIFS(idxAP) = 0;
        statsA.TimeSRRTS(idxAP) = 0;
        statsA.TimeBackoff(idxAP) = 0;
        statsA.TimeIdle(idxAP) = 0;
        statsA.TimeWait(idxAP) = 0;
        SINRest{idxAP, idxSTA} = 27;
        SINRcalc{idxAP, idxSTA} = 27;
        for idxCH = 1:simulation.numCH
            CHSTA{idxAP, idxSTA,idxCH} = complex(zeros(1000,1));
            OSCHSTA(idxAP,idxSTA,idxCH) = 0;
        end
    end
end

% **********************************************************************************************************************
% build optimal setup for OBSS_PD, Rate/MCS and TP based on topology for a centrally scheduled approach
% command for sort: vec = [TRPsumMCS(:,1:7) log10(TRPsumMCS(:,8:13)).*10+30 TRPsumMCS(:,14:19)]

clear TRPsumMCS;
switch simulation.typeA            
        
    case 'CSMA/SDMSR'
        
        % use MCS driven approach to provide TP/MCS sets by pathloss
        % attention: no multi station support!
        % maxTRP TRPbyAP TPbyAP MCSbyAP; the throughput is by stream in case of MIMO

        simulation.approach = 'A';
        TRPsumMCS = SDMSRMCSDAallocset(cell2mat(all_pathloss_STA_DL),all_bss,simulation);
        
        % switch -1 to zero for MCS selection as it creates trouble later
        TRPsumMCS(TRPsumMCS == -1) = 0;
        
    case 'CSMA/SR'
        
        % use MCS driven approach to provide TP/MCS sets by pathloss; same as SDMSR but no SDM cluster
        % attention: no multi station support!
        % maxTRP TRPbyAP TPbyAP MCSbyAP; the throughput is by stream in case of MIMO

        simulation.approach = 'A';
        TRPsumMCS = SRMCSDAallocset(cell2mat(all_pathloss_STA_DL),all_bss,simulation);
        
        % switch -1 to zero for MCS selection as it creates trouble later
        TRPsumMCS(TRPsumMCS == -1) = 0;
        
    otherwise
        
end

% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % load('saveresults\alloc_set_SR_6BSS_0dB.mat')
% % % TRPsumMCS = TRPsumMCS_SR;
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% save sorted allocation table for reference
if exist('TRPsumMCS','var') == 1
    TRPsumMCSA = sortrows(TRPsumMCS,1,'descend');
    save('saveresults/alloc_set_A.mat','TRPsumMCSA');
    disp('alloc set A saved as saveresults/alloc_set_A.mat'); 
end

% **********************************************************************************************************************
% for every STA allocate event on GEQ to add data in bytes to queue
for idxAP = 1:numBSS %every AP
    numSTAs = size(all_bss{idxAP}.STAs_pos,1);
    for idxSTA = 1:numSTAs %every STA
        
        % build event entries for each user
        startTime = 0;
        TotalDataCnt = 0;
        while startTime <= simulation.time
            
            % define event along needed queue load, find time and size to load
            LoadModel = char(all_bss{idxAP}.STAs_load(idxSTA));
            [GEQtime, GEQVAR1, GEQtimeIncr] = DataLoadGetTimeSize(startTime,LoadModel,simulation);
            
            % record requested data
            TotalDataCnt = TotalDataCnt + GEQVAR1;
            
            % put event onto queue
            newevent = {GEQtime, idxAP, idxSTA, "DataOnQueue",GEQVAR1,0,0,0,0};
            GEQ = [GEQ;newevent];
            
            % update time for loop
            startTime = startTime + GEQtimeIncr;
        end
        % save total generated data
        statsA.TotalData(idxAP,idxSTA) = TotalDataCnt;

    end
end

% resort queue along event time
GEQ = sortrows(GEQ,{'Time'});

% **********************************************************************************************************************
% allocate event on GEQ to collect garbage and set CHoffset
startTime =  simulation.GarbageWindow;

while startTime <= simulation.time
    
    % update time for loop
    startTime = startTime + simulation.GarbageCycle;
    
    if startTime < simulation.time
        % put event onto queue
        newevent = {startTime,0,0, "ChannelGarbageCollection",0,0,0,0,0};
        GEQ = [GEQ;newevent];
    end
    
end

% resort queue along event time
GEQ = sortrows(GEQ,{'Time'});

% **********************************************************************************************************************
% build config objects as selected. for all AP STA & AP AP combinations
% result is cfgPHY{idxBSS, idxSTA}
% Note: for CSMA/SDM and CSMA/SDMSR the config objects will be overloaded during execution based on HE MU configuration
cfgPHY = cell(1,1);

for idxBSS = 1:numBSS %every AP/BSS
    numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
    for idxUser = 1:numSTAs

        switch simulation.PHYType

            case 'IEEE 802.11ax'

                % CONFIGURE wlan object, valid for all users within a BSS
                cfgPHY{idxBSS,idxUser} = wlanHESUConfig();
                cfgPHY{idxBSS,idxUser}.ChannelBandwidth = 'CBW20';
                cfgPHY{idxBSS,idxUser}.NumTransmitAntennas = all_bss{idxBSS}.num_tx;
                cfgPHY{idxBSS,idxUser}.NumSpaceTimeStreams = all_bss{idxBSS}.STAs_sts(idxUser);
                cfgPHY{idxBSS,idxUser}.MCS = all_bss{idxBSS}.STAs_mcs(idxUser);     
                cfgPHY{idxBSS,idxUser}.APEPLength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                cfgPHY{idxBSS,idxUser}.GuardInterval = cfgSimu{idxBSS,1}.GuardInterval;
                cfgPHY{idxBSS,idxUser}.BSSColor = all_bss{idxBSS}.bss_cc;
%                 cfgPHY{idxBSS,idxUser}.HELTFType = 1; % type 1 not defined in ax draft 2.0 / R2018b
                % insert special expansion matrix
                [cfgPHY{idxBSS,idxUser}] = defineSpatialMapping(cfgPHY{idxBSS,idxUser},simulation);


            case 'IEEE 802.11n'

                % CONFIGURE wlan object, valid for all users within a BSS
                cfgPHY{idxBSS,idxUser} = wlanHTConfig();
                cfgPHY{idxBSS,idxUser}.ChannelBandwidth = 'CBW20';
                cfgPHY{idxBSS,idxUser}.NumTransmitAntennas = all_bss{idxBSS}.num_tx;
                cfgPHY{idxBSS,idxUser}.NumSpaceTimeStreams = all_bss{idxBSS}.STAs_sts(idxUser);
                cfgPHY{idxBSS,idxUser}.MCS = all_bss{idxBSS}.STAs_mcs(idxUser);     
                cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                % insert special expansion matrix
                [cfgPHY{idxBSS,idxUser}] = defineSpatialMapping(cfgPHY{idxBSS,idxUser},simulation);


            case 'IEEE 802.11a'

                % CONFIGURE wlan object, valid for all users within a BSS
                cfgPHY{idxBSS,idxUser} = wlanNonHTConfig();
                cfgPHY{idxBSS,idxUser}.ChannelBandwidth = 'CBW20';
                cfgPHY{idxBSS,idxUser}.NumTransmitAntennas = all_bss{idxBSS}.num_tx;
                cfgPHY{idxBSS,idxUser}.MCS = all_bss{idxBSS}.STAs_mcs(idxUser);     
                cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser);
                % no MIMO

        end

    end
end


% **********************************************************************************************************************
% build look up table for payload length to tx packet length by MCS
switch simulation.typeA
    
    case 'CSMA/CA'
        
        % do nothing as this type does not require the table
        
    otherwise        
        
        PL2TX = [];
        PLmax = 4095;
        
        switch simulation.PHYType

            case 'IEEE 802.11ax'
                % try loading lookup table, if not exist create new one and save
                % PL2TX = PL2TXtable(PLmin,PLmax,idxAP,cfgxy,cfgSimu);
                if isfile('variables/PL2TXax.mat')
                    load('variables/PL2TXax.mat','PL2TXax');
                    PL2TX = PL2TXax;
                else
                    PL2TXax = PL2TXtable(1,PLmax,1,cfgPHY,cfgSimu,simulation);
                    save('variables/PL2TXax.mat','PL2TXax');
                    PL2TX = PL2TXax;
                end         
        
            case 'IEEE 802.11n'
                % try loading lookup table, if not exist create new one and save
                % PL2TX = PL2TXtable(PLmin,PLmax,idxAP,cfgxy,cfgSimu);
                if isfile('variables/PL2TXn.mat')
                    load('variables/PL2TXn.mat','PL2TXn');
                    PL2TX = PL2TXn;
                else
                    PL2TXn = PL2TXtable(1,PLmax,1,cfgPHY,cfgSimu,simulation);
                    save('variables/PL2TXn.mat','PL2TXn');
                    PL2TX = PL2TXn;
                end         
        
            case 'IEEE 802.11a'
                % try loading lookup table, if not exist create new one and save
                % PL2TX = PL2TXtable(PLmin,PLmax,idxAP,cfgxy,cfgSimu);
                if isfile('variables/PL2TXa.mat')
                    load('variables/PL2TXa.mat','PL2TXa');
                    PL2TX = PL2TXa;
                else
                    PL2TXa = PL2TXtable(1,PLmax,1,cfgPHY,cfgSimu,simulation);
                    save('variables/PL2TXa.mat','PL2TXa');
                    PL2TX = PL2TXa;
                end        

        end
                
end

switch simulation.typeA
        
    case 'CSMA/SDMSR'
        
        PL2TXSU = [];
        PL2TXMU = [];
        PLmaxSTS = 2050;       

        % try loading lookup tables, if not exist create new ones and save
        % [PL2TXSU, PL2TXMU] = PL2TXMIMOtable(PLmin,PLmaxSTS,cfgSimu,simulation);
        if isfile('variables/PL2TXMIMOax.mat')
            load('variables/PL2TXMIMOax.mat','PL2TXSUMIMOax','PL2TXMUMIMOax');
            PL2TXSU = PL2TXSUMIMOax;
            PL2TXMU = PL2TXMUMIMOax;
        else
            [PL2TXSUMIMOax, PL2TXMUMIMOax] = PL2TXMIMOtable(1,PLmaxSTS,cfgSimu,simulation);
            save('variables/PL2TXMIMOax.mat','PL2TXSUMIMOax','PL2TXMUMIMOax');
            PL2TXSU = PL2TXSUMIMOax;
            PL2TXMU = PL2TXMUMIMOax;
        end         
                
    case 'CSMA/SR'
        
        PL2TXSU = [];
        PL2TXMU = [];
        PLmaxSTS = 2050;       

        % try loading lookup tables, if not exist create new ones and save
        % [PL2TXSU, PL2TXMU] = PL2TXMIMOtable(PLmin,PLmaxSTS,cfgSimu,simulation);
        if isfile('variables/PL2TXMIMOax.mat')
            load('variables/PL2TXMIMOax.mat','PL2TXSUMIMOax','PL2TXMUMIMOax');
            PL2TXSU = PL2TXSUMIMOax;
            PL2TXMU = PL2TXMUMIMOax;
        else
            [PL2TXSUMIMOax, PL2TXMUMIMOax] = PL2TXMIMOtable(1,PLmaxSTS,cfgSimu,simulation);
            save('variables/PL2TXMIMOax.mat','PL2TXSUMIMOax','PL2TXMUMIMOax');
            PL2TXSU = PL2TXSUMIMOax;
            PL2TXMU = PL2TXMUMIMOax;
        end         
                
end

% **********************************************************************************************************************
% build first scheduler event or allocate start event for SLOTTIME cycle
switch simulation.typeA
            
    case 'CSMA/SDMSR'        
        for idxAP = 1:numBSS %every AP
            idxTime = simulation.SLOTTIME*1e-6;
            newevent = {idxTime, idxAP, 0, "APCycle",0,0,0,0,0};
            statsA.TimeIdle(idxAP) = idxTime;
            APSTATE(idxAP) = "APIdle";
            GEQ = [GEQ;newevent];
        end
        % resort queue along event time
        GEQ = sortrows(GEQ,{'Time'});      
        
    case 'CSMA/SR'        
        for idxAP = 1:numBSS %every AP
            idxTime = simulation.SLOTTIME*1e-6;
            newevent = {idxTime, idxAP, 0, "APCycle",0,0,0,0,0};
            statsA.TimeIdle(idxAP) = idxTime;
            APSTATE(idxAP) = "APIdle";
            GEQ = [GEQ;newevent];
        end
        % resort queue along event time
        GEQ = sortrows(GEQ,{'Time'});      
        
    case 'CSMA/CA'
        for idxAP = 1:numBSS %every AP
            idxTime = simulation.SLOTTIME*1e-6;
            newevent = {idxTime, idxAP, 0, "APCycle",0,0,0,0,0};
            statsA.TimeIdle(idxAP) = idxTime;
            APSTATE(idxAP) = "APIdle";
            GEQ = [GEQ;newevent];
        end
        % resort queue along event time
        GEQ = sortrows(GEQ,{'Time'});      
        
end

% **********************************************************************************************************************
% main loop on global event queue simulation.typeA.DRC
% **********************************************************************************************************************

% **********************************************************************************************************************
% work on GEQ and fill data queues as requested
SimuTime= 0;
simulation.OldSimuTime = 0;
simulation.AccSimuTime = 0;

% open file for logA
fid = fopen('logs/LogApproachA.txt', 'w');

% move to dedicated stream if selected, for RANDI
if  ~strcmp(simulation.RandomStream,'Global stream')
    oldGlobalStream = RandStream.getGlobalStream();
    stream = RandStream('mt19937ar','Seed',5);
    RandStream.setGlobalStream(stream);
end

while SimuTime < simulation.time && height(GEQ) > 0
    
    % check break condition by Cancel button
    if getappdata(h_start_simu_pushbtn,'cancelflag') == 1
        setappdata(h_start_simu_pushbtn,'cancelflag',0);
        return;
    end
    
    % get new event from global event queue = 1st entry as it is sorted
    simulation.OldSimuTime = SimuTime;
    SimuTime = GEQ{1,'Time'};   % next time is simulation time
    if SimuTime > simulation.time
        break;
    end
    simulation.AccSimuTime = SimuTime;
    
    switch simulation.typeA
        
        case 'CSMA/CA'
            % work on event
            approach = 'A';
            [statsA,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,...
                SINRcalc,OSCHAP,OSCHSTA,LT] = WorkOnEvent_A2B_CSMA_CA(approach,statsA,all_bss,cfgPHY,GEQ,CHAP,CHSTA,...
                DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,all_pathloss_STA_DL,all_pathloss_AP_DL,chSTA_DL,chAP_DL,all_pathloss_STA_UL,all_pathloss_AP_UL,chSTA_UL,chAP_UL,awgnChannel,...
                simulation,cfgSimu,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,SINRcalc,OSCHAP,OSCHSTA,fid,LT);
 
        case 'CSMA/SDMSR' %
            % work on event
            approach = 'A';
            
            switch simulation.A.VER
                
                case 'CSMA/SDMSR V1'
                [statsA,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,...
                    SINRcalc,OSCHAP,OSCHSTA,TRPsumMCS,LT] = WorkOnEvent_A2B_CSMA_SDMSRV1(approach,statsA,all_bss,cfgPHY,GEQ,CHAP,CHSTA,...
                    DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,all_pathloss_STA_DL,all_pathloss_AP_DL,chSTA_DL,chAP_DL,all_pathloss_STA_UL,all_pathloss_AP_UL,chSTA_UL,chAP_UL,awgnChannel,...
                    simulation,cfgSimu,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,SINRcalc,OSCHAP,OSCHSTA,TRPsumMCS,fid,PL2TXSU,PL2TXMU,LT);
                                
            end

        case 'CSMA/SR' %
            % work on event
            approach = 'A';
            
            switch simulation.A.VER
                
                case 'CSMA/SR V1'
                [statsA,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,...
                    SINRcalc,OSCHAP,OSCHSTA,TRPsumMCS,LT] = WorkOnEvent_A2B_CSMA_SDMSRV1(approach,statsA,all_bss,cfgPHY,GEQ,CHAP,CHSTA,...
                    DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,all_pathloss_STA_DL,all_pathloss_AP_DL,chSTA_DL,chAP_DL,all_pathloss_STA_UL,all_pathloss_AP_UL,chSTA_UL,chAP_UL,awgnChannel,...
                    simulation,cfgSimu,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,SINRcalc,OSCHAP,OSCHSTA,TRPsumMCS,fid,PL2TXSU,PL2TXMU,LT);
                                
            end

        case 'Other'
            
        otherwise
            
    end        

    % update GUI
    simulation.handleTime.String = [num2str(SimuTime), ' s'];
    simulation.handlenumPackets.String = [num2str(sum(statsA.NumberOfPackets,'all')), ' P'];
    drawnow;
end

% restore old global stream
if  ~strcmp(simulation.RandomStream,'Global stream')
    RandStream.setGlobalStream(oldGlobalStream);
end

% **********************************************************************************************************************
fclose(fid);
if diag == true;disp([datestr(now,0),' Approach A done']);end

% perform security save of results
save('saveresults/statsLastRun_sim_A.mat','statsA');

% **********************************************************************************************************************
% RUN B APPROACH
% **********************************************************************************************************************
if diag == true;disp([datestr(now,0),' Starting approach B']);end

% **********************************************************************************************************************
% allocate resources and load to queues
% **********************************************************************************************************************
% the channel is complex baseband by STA by AP at fs, also RX by AP, for CCA the channel may have multiple streams,
% due to n RX antennas; the channel signal strength indicator is used for dynamic MCS etc.

% use table data type for GEQ
Time = [];
AP = [];
STA = [];
Event = [];
VAR1 = [];
VAR2 = [];
VAR3 = [];
VAR4 = [];
VAR5 = [];
GEQ = table(Time, AP, STA, Event, VAR1, VAR2, VAR3, VAR4, VAR5);

% use cell array of tables for latency measurement
idxT = [];
dPL = [];
for idxBSS = 1:numBSS
    LT{idxBSS} = table(idxT, dPL);
end

APSTATE = "";
DATAQ = [];
DATAPENQ = [];
saveCFG = [];
SINRest = {[]};
SINRcalc = {[]};
CHAP = {[]};
CHSTA = {[]};
OSCHAP = [];                        % offset to address channels, after garbage collection
OSCHSTA = [];                       % offset to address channels, after garbage collection
APCNT = {};                         % cell array to hold counter by AP etc.
APSTACNT = {};                      % cell array to hold counter by STA & AP etc.
SCHEDCNT = 0;                       % count for scheduler
lastTXPck_DL = {};                  % last TX packet by AP for SINR calculation
lastTXPck_UL = {};                  % last TX packet by AP for SINR calculation
txPSDUs_DL = {};                    % holds PSDU content for comparision of payload error
txPSDUs_UL = {};                    % holds PSDU content for comparision of payload error

% **********************************************************************************************************************
% for every AP to STA, allocate zero data into data queue and queue plot; allocate zero complex data into the channel 
% to allow estimation at start
for idxAP = 1:numBSS %every AP
    numSTAs = size(all_bss{idxAP}.STAs_pos,1);    
    for idxCH = 1:simulation.numCH
        CHAP{idxAP,idxCH} = complex(zeros(1000,1));
        OSCHAP(idxAP,idxCH) = 0;
    end   
    APSTATE(idxAP) = "APIdle";
    APCNT{idxAP}.SRC = 0;                               % reset AP retry count for CSMA/CA
    APCNT{idxAP}.PrevError = false;                     % flag for unsuccessful previous tx attempt
    APCNT{idxAP}.IFS = 0;
    APCNT{idxAP}.BO = 0;
    APCNT{idxAP}.ChannelWasBusy = 0;                    % flag for channel condition busy during CCA
    APCNT{idxAP}.SelSTA = 1;
    APCNT{idxAP}.SelMCS = 0;
    APCNT{idxAP}.SelTP = -200;
    APCNT{idxAP}.SelPLBytes = 0;
    APCNT{idxAP}.INmax = -200;                           % for CSMA/SR spatial reuse
    APCNT{idxAP}.TXdur = 0;
    APCNT{idxAP}.APLead = 0;
    APCNT{idxAP}.APCont = 0;
    APCNT{idxAP}.SRIFS = 0;
    APCNT{idxAP}.SRTX = 0;
    APCNT{idxAP}.idxRTSTXburst = 0;
    APCNT{idxAP}.StreamID = 0;                          % for CSMA/SDM and CSMA/SDMSR
    APCNT{idxAP}.numStream = 0;
    APCNT{idxAP}.useBF = false;
   for idxSTA = 1:numSTAs %every STA from LINK
        APSTACNT{idxAP,idxSTA}.SRC = 0;                 % reset station retry count
        DATAQ(idxAP,idxSTA) = 0;
        DATAPENQ(idxAP,idxSTA) = 0;
        saveCFG(idxAP,idxSTA).MCS = 0;
        saveCFG(idxAP,idxSTA).Length = 0;
        statsB.TotalData(idxAP,idxSTA) = 0;
        statsB.DATAQPlot(idxAP,idxSTA).lengths = [];
        statsB.DATAQPlot(idxAP,idxSTA).times = [];
        statsB.PacketErrorPlotSTA(idxAP,idxSTA) = 0;
        statsB.PacketErrorPlotAP(idxAP) = 0;
        statsB.DatatransferedPlot(idxAP,idxSTA) = 0;
        statsB.ThroughputPlot(idxAP,idxSTA) = 0;
        statsB.NumberOfPackets(idxAP,idxSTA) = 0;
        statsB.Histo(idxAP,idxSTA).TP = [];
        statsB.Histo(idxAP,idxSTA).MCS = [];
        statsB.Histo(idxAP,idxSTA).estSINR = [];
        statsB.Histo(idxAP,idxSTA).calcSINR = [];
        statsB.Histo(idxAP,idxSTA).timeLatency = [];    % latency times
        statsB.TimeHeader(idxAP) = 0;
        statsB.TimeData(idxAP) = 0;
        statsB.TimeACK(idxAP) = 0;
        statsB.TimeIFS(idxAP) = 0;
        statsB.TimeSRIFS(idxAP) = 0;
        statsB.TimeSRRTS(idxAP) = 0;
        statsB.TimeBackoff(idxAP) = 0;
        statsB.TimeIdle(idxAP) = 0;
        statsB.TimeWait(idxAP) = 0;
        SINRest{idxAP, idxSTA} = 27;
        SINRcalc{idxAP, idxSTA} = 27;
        for idxCH = 1:simulation.numCH
            CHSTA{idxAP, idxSTA,idxCH} = complex(zeros(1000,1));
            OSCHSTA(idxAP,idxSTA,idxCH) = 0;
        end
    end
end

% **********************************************************************************************************************
% build optimal setup for OBSS_PD, Rate/MCS and TP based on topology
% for a centrally scheduled approach
clear TRPsumMCS;
switch simulation.typeB
    
    case 'CSMA/SDMSR'
        
        % use MCS driven approach to provide TP/MCS sets by pathloss
        % attention: no multi station support!
        % maxTRP TRPbyAP TPbyAP MCSbyAP; the throughput is by stream in case of MIMO

        simulation.approach = 'B';
        TRPsumMCS = SDMSRMCSDAallocset(cell2mat(all_pathloss_STA_DL),all_bss,simulation);
        
        % switch -1 to zero for MCS selection as it creates trouble later
        TRPsumMCS(TRPsumMCS == -1) = 0;
        
    case 'CSMA/SR'
        
        % use MCS driven approach to provide TP/MCS sets by pathloss'; same as SDMSR but without cluster
        % attention: no multi station support!
        % maxTRP TRPbyAP TPbyAP MCSbyAP; the throughput is by stream in case of MIMO

        simulation.approach = 'B';
        TRPsumMCS = SRMCSDAallocset(cell2mat(all_pathloss_STA_DL),all_bss,simulation);
        
        % switch -1 to zero for MCS selection as it creates trouble later
        TRPsumMCS(TRPsumMCS == -1) = 0;
        
    otherwise
                
end

% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % load('saveresults\alloc_set_SDMSR_6BSS_0dB.mat')
% % % TRPsumMCS = TRPsumMCS_SDMSR;
% % % % % % load('saveresults\alloc_set_SR_6BSS_0dB.mat')
% % % % % % TRPsumMCS = TRPsumMCS_SR;
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% save sorted allocation table for reference
if exist('TRPsumMCS','var') == 1
    TRPsumMCSB = sortrows(TRPsumMCS,1,'descend');
    save('saveresults/alloc_set_B.mat','TRPsumMCSB');
    disp('alloc set B saved as saveresults/alloc_set_B.mat');
end

% **********************************************************************************************************************
% for every STA allocate event on GEQ to add data in bytes to queue
for idxAP = 1:numBSS %every AP
    numSTAs = size(all_bss{idxAP}.STAs_pos,1);
    for idxSTA = 1:numSTAs %every STA
        % build event entries for each user
        startTime = 0;
        TotalDataCnt = 0;
        while startTime <= simulation.time
            
            % define event along needed queue load, find time and size to load
            LoadModel = char(all_bss{idxAP}.STAs_load(idxSTA));
            [GEQtime, GEQVAR1, GEQtimeIncr] = DataLoadGetTimeSize(startTime,LoadModel,simulation); 
            
            % record requested data
            TotalDataCnt = TotalDataCnt + GEQVAR1;
            
            % put event onto queue
            newevent = {GEQtime, idxAP, idxSTA, "DataOnQueue",GEQVAR1,0,0,0,0};
            GEQ = [GEQ;newevent];
            
            % update time for loop
            startTime = startTime + GEQtimeIncr;
        end       
        % save total generated data
        statsB.TotalData(idxAP,idxSTA) = TotalDataCnt;
        
    end
end

% resort queue along event time
GEQ = sortrows(GEQ,{'Time'});

% **********************************************************************************************************************
% allocate event on GEQ to collect garbage and set CHoffset
startTime =  simulation.GarbageWindow;

while startTime <= simulation.time
    
    % update time for loop
    startTime = startTime + simulation.GarbageCycle;
    
    if startTime < simulation.time
        % put event onto queue
        newevent = {startTime,0,0, "ChannelGarbageCollection",0,0,0,0,0};
        GEQ = [GEQ;newevent];
    end
    
end

% resort queue along event time
GEQ = sortrows(GEQ,{'Time'});

% **********************************************************************************************************************
% build config opjects as selected. for all AP STA & AP AP combinations
% result is cfgHE{idxBSS, idxSTA}
% Note: for CSMA/SDM and CSMA/SDMSR the config objects will be overloaded during execution based on HE MU configuration
cfgPHY = cell(1,1);

for idxBSS = 1:numBSS %every AP/BSS
    numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
    for idxUser = 1:numSTAs

        switch simulation.PHYType

            case 'IEEE 802.11ax'

                % CONFIGURE wlan object, valid for all users within a BSS
                cfgPHY{idxBSS,idxUser} = wlanHESUConfig();
                cfgPHY{idxBSS,idxUser}.ChannelBandwidth = 'CBW20';
                cfgPHY{idxBSS,idxUser}.NumTransmitAntennas = all_bss{idxBSS}.num_tx;
                cfgPHY{idxBSS,idxUser}.NumSpaceTimeStreams = all_bss{idxBSS}.STAs_sts(idxUser);
                cfgPHY{idxBSS,idxUser}.MCS = all_bss{idxBSS}.STAs_mcs(idxUser);     
                cfgPHY{idxBSS,idxUser}.APEPLength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                cfgPHY{idxBSS,idxUser}.GuardInterval = cfgSimu{idxBSS,1}.GuardInterval;
                cfgPHY{idxBSS,idxUser}.BSSColor = all_bss{idxBSS}.bss_cc;
%                         cfgPHY{idxBSS,idxUser}.HELTFType = 1; % type 1 not defined in ax draft 2.0 / R2018b
                % insert spatial expansion matrix
                [cfgPHY{idxBSS,idxUser}] = defineSpatialMapping(cfgPHY{idxBSS,idxUser},simulation);


            case 'IEEE 802.11n'

                % CONFIGURE wlan object, valid for all users within a BSS
                cfgPHY{idxBSS,idxUser} = wlanHTConfig();
                cfgPHY{idxBSS,idxUser}.ChannelBandwidth = 'CBW20';
                cfgPHY{idxBSS,idxUser}.NumTransmitAntennas = all_bss{idxBSS}.num_tx;
                cfgPHY{idxBSS,idxUser}.NumSpaceTimeStreams = all_bss{idxBSS}.STAs_sts(idxUser);
                cfgPHY{idxBSS,idxUser}.MCS = all_bss{idxBSS}.STAs_mcs(idxUser);     
                cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                % insert spatial expansion matrix
                [cfgPHY{idxBSS,idxUser}] = defineSpatialMapping(cfgPHY{idxBSS,idxUser},simulation);

            case 'IEEE 802.11a'

                % CONFIGURE wlan object, valid for all users within a BSS
                cfgPHY{idxBSS,idxUser} = wlanNonHTConfig();
                cfgPHY{idxBSS,idxUser}.ChannelBandwidth = 'CBW20';
                cfgPHY{idxBSS,idxUser}.NumTransmitAntennas = all_bss{idxBSS}.num_tx;
                cfgPHY{idxBSS,idxUser}.MCS = all_bss{idxBSS}.STAs_mcs(idxUser);     
                cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser);
                % no MIMO    
        end     

    end
end

% **********************************************************************************************************************
% build look up table for payload length to tx packet length by MCS
switch simulation.typeB
    
    case 'CSMA/CA'
        
        % do nothing as this type does not require the table
        
    otherwise        
        
        PL2TX = [];
        PLmax = 4095;
        
        switch simulation.PHYType

            case 'IEEE 802.11ax'
                % try loading lookup table, if not exist create new one and save
                % PL2TX = PL2TXtable(PLmin,PLmax,idxAP,cfgxy,cfgSimu);
                if isfile('variables/PL2TXax.mat')
                    load('variables/PL2TXax.mat','PL2TXax');
                    PL2TX = PL2TXax;
                else
                    PL2TXax = PL2TXtable(1,PLmax,1,cfgPHY,cfgSimu,simulation);
                    save('variables/PL2TXax.mat','PL2TXax');
                    PL2TX = PL2TXax;
                end         
        
            case 'IEEE 802.11n'
                % try loading lookup table, if not exist create new one and save
                % PL2TX = PL2TXtable(PLmin,PLmax,idxAP,cfgxy,cfgSimu);
                if isfile('variables/PL2TXn.mat')
                    load('variables/PL2TXn.mat','PL2TXn');
                    PL2TX = PL2TXn;
                else
                    PL2TXn = PL2TXtable(1,PLmax,1,cfgPHY,cfgSimu,simulation);
                    save('variables/PL2TXn.mat','PL2TXn');
                    PL2TX = PL2TXn;
                end         
        
            case 'IEEE 802.11a'
                % try loading lookup table, if not exist create new one and save
                % PL2TX = PL2TXtable(PLmin,PLmax,idxAP,cfgxy,cfgSimu);
                if isfile('variables/PL2TXa.mat')
                    load('variables/PL2TXa.mat','PL2TXa');
                    PL2TX = PL2TXa;
                else
                    PL2TXa = PL2TXtable(1,PLmax,1,cfgPHY,cfgSimu,simulation);
                    save('variables/PL2TXa.mat','PL2TXa');
                    PL2TX = PL2TXa;
                end         
        end        
end

switch simulation.typeB
                       
    case 'CSMA/SDMSR'
        
        PL2TXSU = [];
        PL2TXMU = [];
        PLmaxSTS = 2050;       

        % try loading lookup tables, if not exist create new ones and save
        % [PL2TXSU, PL2TXMU] = PL2TXMIMOtable(PLmin,PLmaxSTS,cfgSimu,simulation);
        if isfile('variables/PL2TXMIMOax.mat')
            load('variables/PL2TXMIMOax.mat','PL2TXSUMIMOax','PL2TXMUMIMOax');
            PL2TXSU = PL2TXSUMIMOax;
            PL2TXMU = PL2TXMUMIMOax;
        else
            [PL2TXSUMIMOax, PL2TXMUMIMOax] = PL2TXMIMOtable(1,PLmaxSTS,cfgSimu,simulation);
            save('variables/PL2TXMIMOax.mat','PL2TXSUMIMOax','PL2TXMUMIMOax');
            PL2TXSU = PL2TXSUMIMOax;
            PL2TXMU = PL2TXMUMIMOax;
        end         
                
    case 'CSMA/SR'
        
        PL2TXSU = [];
        PL2TXMU = [];
        PLmaxSTS = 2050;       

        % try loading lookup tables, if not exist create new ones and save
        % [PL2TXSU, PL2TXMU] = PL2TXMIMOtable(PLmin,PLmaxSTS,cfgSimu,simulation);
        if isfile('variables/PL2TXMIMOax.mat')
            load('variables/PL2TXMIMOax.mat','PL2TXSUMIMOax','PL2TXMUMIMOax');
            PL2TXSU = PL2TXSUMIMOax;
            PL2TXMU = PL2TXMUMIMOax;
        else
            [PL2TXSUMIMOax, PL2TXMUMIMOax] = PL2TXMIMOtable(1,PLmaxSTS,cfgSimu,simulation);
            save('variables/PL2TXMIMOax.mat','PL2TXSUMIMOax','PL2TXMUMIMOax');
            PL2TXSU = PL2TXSUMIMOax;
            PL2TXMU = PL2TXMUMIMOax;
        end         
                
end

% **********************************************************************************************************************
% build first scheduler event or allocate start event for SLOTTIME cycle
switch simulation.typeB
           
    case 'CSMA/SDMSR'        
        for idxAP = 1:numBSS %every AP
            idxTime = simulation.SLOTTIME*1e-6;
            newevent = {idxTime, idxAP, 0, "APCycle",0,0,0,0,0};
            statsB.TimeIdle(idxAP) = idxTime;
            APSTATE(idxAP) = "APIdle";
            GEQ = [GEQ;newevent];
        end
        
        % resort queue along event time
        GEQ = sortrows(GEQ,{'Time'});        
        
    case 'CSMA/SR'        
        for idxAP = 1:numBSS %every AP
            idxTime = simulation.SLOTTIME*1e-6;
            newevent = {idxTime, idxAP, 0, "APCycle",0,0,0,0,0};
            statsB.TimeIdle(idxAP) = idxTime;
            APSTATE(idxAP) = "APIdle";
            GEQ = [GEQ;newevent];
        end
        
        % resort queue along event time
        GEQ = sortrows(GEQ,{'Time'});        
        
    case 'CSMA/CA'
        for idxAP = 1:numBSS %every AP
            idxTime = simulation.SLOTTIME*1e-6;
            newevent = {idxTime, idxAP, 0, "APCycle",0,0,0,0,0};
            statsB.TimeIdle(idxAP) = idxTime;
            APSTATE(idxAP) = "APIdle";
            GEQ = [GEQ;newevent];
        end
        
        % resort queue along event time
        GEQ = sortrows(GEQ,{'Time'});        
end

% **********************************************************************************************************************
% main loop on global event queue
% **********************************************************************************************************************

% **********************************************************************************************************************
% work on GEQ and fill data queues as requested
SimuTime= 0;
simulation.OldSimuTime = 0;
simulation.AccSimuTime = 0;
fid = fopen('logs/LogApproachB.txt', 'w');

% move to dedicated stream if selected, for RANDI
if  ~strcmp(simulation.RandomStream,'Global stream')
    oldGlobalStream = RandStream.getGlobalStream();
    stream = RandStream('mt19937ar','Seed',5);
    RandStream.setGlobalStream(stream);
end

while SimuTime < simulation.time && height(GEQ) > 0
    
    % check break condition by Cancel button
    if getappdata(h_start_simu_pushbtn,'cancelflag') == 1
        setappdata(h_start_simu_pushbtn,'cancelflag',0);
        return;
    end
    
    % get new event from global event queue = 1st entry as it is sorted
    simulation.OldSimuTime = SimuTime;
    SimuTime = GEQ{1,'Time'};   % next time is simulation time
    if SimuTime > simulation.time
        break;
    end
    simulation.AccSimuTime = SimuTime;

    switch simulation.typeB
        
        case 'CSMA/CA'
            % work on event
            approach = 'B';
            [statsB,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,...
                SINRcalc,OSCHAP,OSCHSTA,LT] = WorkOnEvent_A2B_CSMA_CA(approach,statsB,all_bss,cfgPHY,GEQ,CHAP,CHSTA,...
                DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,all_pathloss_STA_DL,all_pathloss_AP_DL,chSTA_DL,chAP_DL,all_pathloss_STA_UL,all_pathloss_AP_UL,chSTA_UL,chAP_UL,awgnChannel,...
                simulation,cfgSimu,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,SINRcalc,OSCHAP,OSCHSTA,fid,LT);
                        
        case 'CSMA/SDMSR'
            % work on event
            approach = 'B';           
                        
            switch simulation.B.VER
                
                case 'CSMA/SDMSR V1'
                [statsB,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,...
                SINRcalc,OSCHAP,OSCHSTA,TRPsumMCS,LT] = WorkOnEvent_A2B_CSMA_SDMSRV1(approach,statsB,all_bss,cfgPHY,GEQ,CHAP,CHSTA,...
                DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,all_pathloss_STA_DL,all_pathloss_AP_DL,chSTA_DL,chAP_DL,all_pathloss_STA_UL,all_pathloss_AP_UL,chSTA_UL,chAP_UL,awgnChannel,...
                simulation,cfgSimu,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,SINRcalc,OSCHAP,OSCHSTA,TRPsumMCS,fid,PL2TXSU,PL2TXMU,LT);
                                
            end
            
        case 'CSMA/SR'
            % work on event
            approach = 'B';           
                        
            switch simulation.B.VER
                
                case 'CSMA/SR V1'
                [statsB,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,...
                SINRcalc,OSCHAP,OSCHSTA,TRPsumMCS,LT] = WorkOnEvent_A2B_CSMA_SDMSRV1(approach,statsB,all_bss,cfgPHY,GEQ,CHAP,CHSTA,...
                DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,all_pathloss_STA_DL,all_pathloss_AP_DL,chSTA_DL,chAP_DL,all_pathloss_STA_UL,all_pathloss_AP_UL,chSTA_UL,chAP_UL,awgnChannel,...
                simulation,cfgSimu,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,SINRcalc,OSCHAP,OSCHSTA,TRPsumMCS,fid,PL2TXSU,PL2TXMU,LT);
                                
            end
            
        case 'Other'
            
        otherwise
            
    end    
            
    % update GUI
    simulation.handleTime.String = [num2str(SimuTime), ' s'];
    simulation.handlenumPackets.String = [num2str(sum(statsB.NumberOfPackets,'all')), ' P'];
    drawnow;
end

% restore old global stream
if  ~strcmp(simulation.RandomStream,'Global stream')
    RandStream.setGlobalStream(oldGlobalStream);
end

% **********************************************************************************************************************
fclose(fid);
if diag == true;disp([datestr(now,0),' Approach B done']);end

% perform security save of results
save('saveresults/statsLastRun_sim_B.mat','statsB');

% perform security save of results
save('saveresults/statsLastRun_sim_A2B.mat','statsA','statsB');

% **********************************************************************************************************************
if diag == true;disp(['simulation time over, evaluating results']);end

% **********************************************************************************************************************
% evaluate results and produce stats
% **********************************************************************************************************************

% **********************************************************************************************************************
% BY STA
% **********************************************************************************************************************

Uidx = 1;

% **********************************************************************************************************************
% plot AP data queue length by time by STA
if strcmp(simulation.ReportLevel,'Standard') || strcmp(simulation.ReportLevel,'Extended')
    
    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        DQAaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        for idxSTA = 1:numSTAs %every STA from LINK
            plot(DQAaxes{idxAP},statsA.DATAQPlot(idxAP,idxSTA).times,statsA.DATAQPlot(idxAP,idxSTA).lengths...
                ,'DisplayName',['User ',num2str(idxSTA)]);
            hold on;
        end
        title(['Approach A: Data Queue Length by User for AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('time / s');
        ylabel('queue length / bytes');
        resultU{idxAP,Uidx} = DQAaxes{idxAP};

        DQBaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        for idxSTA = 1:numSTAs %every STA from LINK
            plot(DQBaxes{idxAP},statsB.DATAQPlot(idxAP,idxSTA).times,statsB.DATAQPlot(idxAP,idxSTA).lengths...
                ,'DisplayName',['User ',num2str(idxSTA)]);
            hold on;
        end
        title(['Approach B: Data Queue Length by User for AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('time / s');
        ylabel('queue length / bytes');
        resultU{idxAP,Uidx+1} = DQBaxes{idxAP};
    end
    Uidx = Uidx + 2;
end

% **********************************************************************************************************************
% plot AP packet error rate by STA
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')
    
    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        PERAaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        bar(PERAaxes{idxAP},1:numSTAs,statsA.PacketErrorPlotSTA(idxAP,1:numSTAs)./...
            statsA.NumberOfPackets(idxAP,1:numSTAs),'DisplayName','STA');
        title(['Approach A: Packet Error Rate by User for AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('STA');
        ylabel('PER');
        ylim([0 inf]);
        resultU{idxAP,Uidx} = PERAaxes{idxAP};

        PERBaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        bar(PERBaxes{idxAP},1:numSTAs,statsB.PacketErrorPlotSTA(idxAP,1:numSTAs)./...
            statsB.NumberOfPackets(idxAP,1:numSTAs),'DisplayName','STA');
        title(['Approach B: Packet Error Rate by User for AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('STA');
        ylabel('PER');
        ylim([0 inf]);
        resultU{idxAP,Uidx+1} = PERBaxes{idxAP};

    end
    Uidx = Uidx + 2;
end

% **********************************************************************************************************************
% plot AP throughput by STA
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')
    
    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        TPAaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        bar(TPAaxes{idxAP},1:numSTAs,statsA.DatatransferedPlot(idxAP,1:numSTAs)./...
            (simulation.time*1e6).*8,'DisplayName','STA');
        title(['Approach A: Throughput by User AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('STA');
        ylabel('Throughput / Mb/s');
        resultU{idxAP,Uidx} = TPAaxes{idxAP};

        TPBaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        bar(TPBaxes{idxAP},1:numSTAs,statsB.DatatransferedPlot(idxAP,1:numSTAs)./...
            (simulation.time*1e6).*8,'DisplayName','STA');
        title(['Approach B: Throughput by User AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('STA');
        ylabel('Throughput / Mb/s');
        resultU{idxAP,Uidx+1} = TPBaxes{idxAP};

    end
    Uidx = Uidx + 2;
end

% **********************************************************************************************************************
% plot AP MCS usage by STA
if strcmp(simulation.ReportLevel,'Standard') || strcmp(simulation.ReportLevel,'Extended')

    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        MCSAaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        centers = [0:1:11];
        edges = [-0.5:1:11.5];  % MCS 0 to 11
        counts = [];
        disVec = {};

        try
            for idxSTA = 1:numSTAs %every STA from LINK
                curCount = histcounts(statsA.Histo(idxAP,idxSTA).MCS,edges,'Normalization','probability');
                counts = [counts; curCount];
                disVec{idxSTA} = ['STA: ' num2str(idxSTA)];
            end
            hbAMCS = bar3(MCSAaxes{idxAP},centers,counts.');
            set( hbAMCS, {'DisplayName'}, disVec');
        catch
            disp('no sufficient data for histcount');
        end

        title(['Approach A: MCS usage by User for AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('STA');
        ylabel('MCS');
        zlabel('Usage');
        resultU{idxAP,Uidx} = MCSAaxes{idxAP};    

        MCSBaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        centers = [0:1:11];
        edges = [-0.5:1:11.5];  % MCS 0 to 11
        counts = [];
        disVec = {};

        try
            for idxSTA = 1:numSTAs %every STA from LINK
                curCount = histcounts(statsB.Histo(idxAP,idxSTA).MCS,edges,'Normalization','probability');
                counts = [counts; curCount];
                disVec{idxSTA} = ['STA: ' num2str(idxSTA)];
            end
            hbBMCS = bar3(MCSBaxes{idxAP},centers,counts.');
            set( hbBMCS, {'DisplayName'}, disVec');
        catch
            disp('no sufficient data for histcount');
        end

        title(['Approach B: MCS usage by User for AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('STA');
        ylabel('MCS');
        zlabel('Usage');
        resultU{idxAP,Uidx+1} = MCSBaxes{idxAP};

    end
    Uidx = Uidx + 2;
end

% **********************************************************************************************************************
% plot AP estSINR by STA
if strcmp(simulation.ReportLevel,'Extended')

    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        SINRAaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        allSINR = [];
        for idxSTA = 1:numSTAs %every STA from LINK
            currSINR = statsA.Histo(idxAP,idxSTA).estSINR;
            allSINR = [allSINR currSINR];
        end
        minSINR = floor(min(allSINR,[],'all'));
        maxSINR = ceil(max(allSINR,[],'all'));
        edges = minSINR-0.5:1:maxSINR+0.5;
        centers = minSINR:1:maxSINR;    
        counts = [];
        disVec = {};
        OneColumn = false;

        try
            for idxSTA = 1:numSTAs %every STA from LINK
                curCount = histcounts(statsA.Histo(idxAP,idxSTA).estSINR,edges,'Normalization','probability');
                counts = [counts; curCount];
                disVec{idxSTA} = ['STA: ' num2str(idxSTA)];
            end

            if iscolumn(counts)     % trick bar function to think about multiple rows
                counts = horzcat(counts,nan(size(counts)));
                OneColumn = true;
                if length(centers) == 1 % just one value is not allowed for bar3
                    centers = [centers centers+1];
                end
            end
            hbAeSINR = bar3(SINRAaxes{idxAP},centers,counts.');
            set( hbAeSINR, {'DisplayName'}, disVec');
        catch
            disp('no sufficient data for histcount');
        end

        title(['Approach A: est. SINR by STA for AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('STA');
        ylabel('SINR / dB');
        zlabel('Usage');
        if OneColumn == true
            ylim([centers(1)-0.5 centers(1)+0.5]);
        end
        resultU{idxAP,Uidx} = SINRAaxes{idxAP};    

        SINRBaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        allSINR = [];
        disVec = {};
        for idxSTA = 1:numSTAs %every STA from LINK
            currSINR = statsB.Histo(idxAP,idxSTA).estSINR;
            allSINR = [allSINR currSINR];
        end
        minSINR = floor(min(allSINR,[],'all'));
        maxSINR = ceil(max(allSINR,[],'all'));
        edges = minSINR-0.5:1:maxSINR+0.5;
        centers = minSINR:1:maxSINR;    
        counts = [];
        OneColumn = false;

        try
            for idxSTA = 1:numSTAs %every STA from LINK
                curCount = histcounts(statsB.Histo(idxAP,idxSTA).estSINR,edges,'Normalization','probability');
                counts = [counts; curCount];
                disVec{idxSTA} = ['STA: ' num2str(idxSTA)];
            end

            if iscolumn(counts)     % trick bar function to think about multiple rows
                counts = horzcat(counts,nan(size(counts)));
                OneColumn = true;
                if length(centers) == 1 % just one value is not allowed for bar3
                    centers = [centers centers+1];
                end
            end
            hbBeSINR = bar3(SINRBaxes{idxAP},centers,counts.');
            set( hbBeSINR, {'DisplayName'}, disVec');
        catch
            disp('no sufficient data for histcount');
        end

        title(['Approach B: est. SINR by STA for AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('STA');
        ylabel('SINR / dB');
        zlabel('Usage');
        if OneColumn == true
            ylim([centers(1)-0.5 centers(1)+0.5]);
        end
        resultU{idxAP,Uidx+1} = SINRBaxes{idxAP};

    end
    Uidx = Uidx + 2;
end

% **********************************************************************************************************************
% plot AP calcSINR by STA
if strcmp(simulation.ReportLevel,'Standard') || strcmp(simulation.ReportLevel,'Extended')

    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        cSINRAaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        allSINR = [];
        for idxSTA = 1:numSTAs %every STA from LINK
            currSINR = statsA.Histo(idxAP,idxSTA).calcSINR;
            allSINR = [allSINR currSINR];
        end
        minSINR = floor(min(allSINR,[],'all'));
        maxSINR = ceil(max(allSINR,[],'all'));
        edges = minSINR-0.5:1:maxSINR+0.5;
        centers = minSINR:1:maxSINR;    
        counts = [];
        disVec = {};
        OneColumn = false;

        try
            for idxSTA = 1:numSTAs %every STA from LINK
                curCount = histcounts(statsA.Histo(idxAP,idxSTA).calcSINR,edges,'Normalization','probability');
                counts = [counts; curCount];
                disVec{idxSTA} = ['STA: ' num2str(idxSTA)];
            end

            if iscolumn(counts)     % trick bar function to think about multiple rows
                counts = horzcat(counts,nan(size(counts)));
                OneColumn = true;
                if length(centers) == 1 % just one value is not allowed for bar3
                    centers = [centers centers+1];
                end
            end
            hbAcSINR = bar3(cSINRAaxes{idxAP},centers,counts.');
            set( hbAcSINR, {'DisplayName'}, disVec');
        catch
            disp('no sufficient data for histcount');
        end

        title(['Approach A: calc SINR by STA for AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('STA');
        ylabel('SINR / dB');
        zlabel('Usage');
        if OneColumn == true
            ylim([centers(1)-0.5 centers(1)+0.5]);
        end
        resultU{idxAP,Uidx} = cSINRAaxes{idxAP};    

        cSINRBaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        allSINR = [];
        disVec = {};
        for idxSTA = 1:numSTAs %every STA from LINK
            currSINR = statsB.Histo(idxAP,idxSTA).calcSINR;
            allSINR = [allSINR currSINR];
        end
        minSINR = floor(min(allSINR,[],'all'));
        maxSINR = ceil(max(allSINR,[],'all'));
        edges = minSINR-0.5:1:maxSINR+0.5;
        centers = minSINR:1:maxSINR;    
        counts = [];
        OneColumn = false;

        try
            for idxSTA = 1:numSTAs %every STA from LINK
                curCount = histcounts(statsB.Histo(idxAP,idxSTA).calcSINR,edges,'Normalization','probability');
                counts = [counts; curCount];
                disVec{idxSTA} = ['STA: ' num2str(idxSTA)];
            end

            if iscolumn(counts)     % trick bar function to think about multiple rows
                counts = horzcat(counts,nan(size(counts)));
                OneColumn = true;
                if length(centers) == 1 % just one value is not allowed for bar3
                    centers = [centers centers+1];
                end
            end
            hbBcSINR = bar3(cSINRBaxes{idxAP},centers,counts.');
            set( hbBcSINR, {'DisplayName'}, disVec');
        catch
            disp('no sufficient data for histcount');
        end

        title(['Approach B: calc SINR by STA for AP: ',num2str(idxAP)],'FontWeight','normal');
        grid on;
        xlabel('STA');
        ylabel('SINR / dB');
        zlabel('Usage');
        if OneColumn == true
            ylim([centers(1)-0.5 centers(1)+0.5]);
        end
        resultU{idxAP,Uidx+1} = cSINRBaxes{idxAP};

    end
    Uidx = Uidx + 2;
end

% **********************************************************************************************************************
% BY BSS
% **********************************************************************************************************************

Bidx = 1;

% **********************************************************************************************************************
% plot sum of data queue length by time by BSS
if strcmp(simulation.ReportLevel,'Standard') || strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    DQTotaxes = axes();
    NewTimeVector = 0:0.001:simulation.time;

    for idxAP = 1:numBSS %every AP
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        SumUser = zeros(1,length(NewTimeVector));
        for idxSTA = 1:numSTAs %every STA from BSS

            % equaly spaced query points needed as time vectors are different
            times = statsA.DATAQPlot(idxAP,idxSTA).times;
            lengths = statsA.DATAQPlot(idxAP,idxSTA).lengths;

            % avoid multple points in interpolation
            [times, index] = unique(times); 
            if length(times) > 1
                ESValues = interp1(times,lengths(index),NewTimeVector);
            else
                ESValues = 0;
            end
            SumUser = SumUser + ESValues;    
        end
        typeString = convertStringsToChars(simulation.typeA);
        plot(DQTotaxes,NewTimeVector,SumUser,'DisplayName',['A: ',typeString,' AP ',num2str(idxAP)]);
        hold on;
        SumUser = zeros(1,length(NewTimeVector));
        for idxSTA = 1:numSTAs %every STA from BSS

            % equaly spaced query points needed as time vectors are different
            times = statsB.DATAQPlot(idxAP,idxSTA).times;
            lengths = statsB.DATAQPlot(idxAP,idxSTA).lengths;

            % avoid multple points in interpolation
            [times, index] = unique(times); 
            if length(times) > 1
                ESValues = interp1(times,lengths(index),NewTimeVector);
            else
                ESValues = 0;
            end
            SumUser = SumUser + ESValues;
        end
        typeString = convertStringsToChars(simulation.typeB);
        plot(DQTotaxes,NewTimeVector,SumUser,'DisplayName',['B: ', typeString,' AP ',num2str(idxAP)]);
    end

    title('Data Queue Length by BSS','FontWeight','normal');
    grid on;
    xlabel('time / s');
    ylabel('queue length / bytes');
    resultB{Bidx} = DQTotaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot packet error rate by AP
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    PERTaxes = axes();
    datA = statsA.PacketErrorPlotAP./(sum(statsA.NumberOfPackets,2)');
    datB = statsB.PacketErrorPlotAP./(sum(statsB.NumberOfPackets,2)');
    datAB = [datA' datB'];
    OneRow = false;
    if isrow(datAB)     % trick bar function to think about multiple rows
      datAB = vertcat(datAB,nan(size(datAB)));
      OneRow = true;
    end
    hbPERT = bar(PERTaxes,datAB);
    set( hbPERT, {'DisplayName'}, {strcat("A: ", simulation.typeA); strcat("B: ", simulation.typeB)});
    title('Packet Error Rate by AP','FontWeight','normal');
    grid on;
    xlabel('AP');
    ylabel('PER');
    if OneRow == true
        xlim([0.5 1.5]);
    end
    ylim([0 inf]);
    resultB{Bidx} = PERTaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot throughput by AP
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    TPTaxes = axes();
    datA = sum(statsA.DatatransferedPlot,2)./(simulation.time*1e6).*8;
    datB = sum(statsB.DatatransferedPlot,2)./(simulation.time*1e6).*8;
    datAB = [datA datB];
    OneRow = false;
    if isrow(datAB)     % trick bar function to think about multiple rows
      datAB = vertcat(datAB,nan(size(datAB)));
      OneRow = true;
    end
    hbTPT = bar(TPTaxes,datAB);
    set( hbTPT, {'DisplayName'}, {strcat("A: ", simulation.typeA); strcat("B: ", simulation.typeB)} );
    title('Throughput by AP','FontWeight','normal');
    grid on;
    xlabel('AP');
    ylabel('Throughput / Mb/s');
    if OneRow == true
        xlim([0.5 1.5]);
    end
    resultB{Bidx} = TPTaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot latency by AP
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')
    
    LoadModel = char(all_bss{1}.STAs_load(1));    
    if (strcmp(LoadModel,'Lt8kb1Mbs')) || (strcmp(LoadModel,'Lt8kb10Mbs')) || (strcmp(LoadModel,'Lt8kb100Mbs')) || (strcmp(LoadModel,'Lt80b100kbs'))

        figure('Visible','off');

        LATaxes = axes();
        datAAP = [];
        datBAP = [];
        for idxAP = 1:numBSS
            numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            datASTA = [];
            datBSTA = [];
            for idxSTA = 1:numSTAs
                datASTA = [datASTA mean(statsA.Histo(idxAP,idxSTA).timeLatency,2)];
                datBSTA = [datBSTA mean(statsB.Histo(idxAP,idxSTA).timeLatency,2)];
            end
            datAAP = [datAAP; mean(datASTA,2)];
            datBAP = [datBAP; mean(datBSTA,2)];
        end
        try
            datAB = [datAAP datBAP];
        catch
            datAB = [];
        end
        OneRow = false;
        if isrow(datAB)     % trick bar function to think about multiple rows
          datAB = vertcat(datAB,nan(size(datAB)));
          OneRow = true;
        end
        hbLTT = bar(LATaxes,datAB);
        set( hbLTT, {'DisplayName'}, {strcat("A: ", simulation.typeA); strcat("B: ", simulation.typeB)} );
        title('Average Latency by AP','FontWeight','normal');
        grid on;
        xlabel('AP');
        ylabel('Latency / s');
        if OneRow == true
            xlim([0.5 1.5]);
        end
        resultB{Bidx} = LATaxes;
        Bidx = Bidx + 1;
        
    end
    
end

% **********************************************************************************************************************
% plot timings by AP
if strcmp(simulation.ReportLevel,'Standard') || strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    TITAaxes = axes();
    sumIFS = statsA.TimeIFS';
    sumBackoff = statsA.TimeBackoff';
    sumHeader = statsA.TimeHeader';
    sumData = statsA.TimeData';
    sumACK = statsA.TimeACK';
    sumIdle = statsA.TimeIdle';
    sumWait = statsA.TimeWait';
    sumSRIFS = statsA.TimeSRIFS';
    sumSRRTS = statsA.TimeSRRTS';
        
    switch simulation.typeA            

        case 'CSMA/SRold'

            datA = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait sumSRIFS sumSRRTS];
            OneRow = false;
            if isrow(datA)     % trick bar function to think about multiple rows
              datA = vertcat(datA,nan(size(datA)));
              OneRow = true;
            end
            haTIT = bar(TITAaxes,datA,'stacked');
            set( haTIT, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'; 'SRIFS'; 'SRRTS'} );

        case 'CSMA/SDM'
                
            datA = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait sumSRRTS];
            OneRow = false;
            if isrow(datA)     % trick bar function to think about multiple rows
              datA = vertcat(datA,nan(size(datA)));
              OneRow = true;
            end
            haTIT = bar(TITAaxes,datA,'stacked');
            set( haTIT, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'; 'SDMRTS'} );

        case 'CSMA/SDMSR'
                
            datA = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait sumSRRTS];
            OneRow = false;
            if isrow(datA)     % trick bar function to think about multiple rows
              datA = vertcat(datA,nan(size(datA)));
              OneRow = true;
            end
            haTIT = bar(TITAaxes,datA,'stacked');
            set( haTIT, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'; 'SDMSRRTS'} );

        case 'CSMA/SR'
                
            datA = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait sumSRRTS];
            OneRow = false;
            if isrow(datA)     % trick bar function to think about multiple rows
              datA = vertcat(datA,nan(size(datA)));
              OneRow = true;
            end
            haTIT = bar(TITAaxes,datA,'stacked');
            set( haTIT, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'; 'SRRTS'} );

        otherwise
            
            datA = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait];
            OneRow = false;
            if isrow(datA)     % trick bar function to think about multiple rows
              datA = vertcat(datA,nan(size(datA)));
              OneRow = true;
            end
            haTIT = bar(TITAaxes,datA,'stacked');
            set( haTIT, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'} );
        
    end
        
    title('Approach A: Timing by AP','FontWeight','normal');
    grid on;
    xlabel('AP');
    ylabel('Time / s');
    if OneRow == true
        xlim([0.5 1.5]);
        set( haTIT, {'BarWidth'}, {0.2});
    end
    resultB{Bidx} = TITAaxes;
    Bidx = Bidx + 1;

    TITBaxes = axes();
    sumIFS = statsB.TimeIFS';
    sumBackoff = statsB.TimeBackoff';
    sumHeader = statsB.TimeHeader';
    sumData = statsB.TimeData';
    sumACK = statsB.TimeACK';
    sumIdle = statsB.TimeIdle';
    sumWait = statsB.TimeWait';
    sumSRIFS = statsB.TimeSRIFS';
    sumSRRTS = statsB.TimeSRRTS';
    
    
    
    switch simulation.typeB            

        case 'CSMA/SRold'
                
            datB = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait sumSRIFS sumSRRTS];
            OneRow = false;
            if isrow(datB)     % trick bar function to think about multiple rows
              datB = vertcat(datB,nan(size(datB)));
              OneRow = true;
            end
            hbTIT = bar(TITBaxes,datB,'stacked');
            set( hbTIT, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'; 'SRIFS'; 'SRRTS'} );

        case 'CSMA/SDM'
                
            datB = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait sumSRRTS];
            OneRow = false;
            if isrow(datB)     % trick bar function to think about multiple rows
              datB = vertcat(datB,nan(size(datB)));
              OneRow = true;
            end
            hbTIT = bar(TITBaxes,datB,'stacked');
            set( hbTIT, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'; 'SDMRTS'} );

        case 'CSMA/SDMSR'
                
            datB = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait sumSRRTS];
            OneRow = false;
            if isrow(datB)     % trick bar function to think about multiple rows
              datB = vertcat(datB,nan(size(datB)));
              OneRow = true;
            end
            hbTIT = bar(TITBaxes,datB,'stacked');
            set( hbTIT, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'; 'SDMSRRTS'} );

        case 'CSMA/SR'
                
            datB = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait sumSRRTS];
            OneRow = false;
            if isrow(datB)     % trick bar function to think about multiple rows
              datB = vertcat(datB,nan(size(datB)));
              OneRow = true;
            end
            hbTIT = bar(TITBaxes,datB,'stacked');
            set( hbTIT, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'; 'SRRTS'} );

        otherwise
                
            datB = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait];
            OneRow = false;
            if isrow(datB)     % trick bar function to think about multiple rows
              datB = vertcat(datB,nan(size(datB)));
              OneRow = true;
            end
            hbTIT = bar(TITBaxes,datB,'stacked');
            set( hbTIT, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'} );
        
    end
        
    title('Approach B: Timing by AP','FontWeight','normal');
    grid on;
    xlabel('AP');
    ylabel('Time / s');
    if OneRow == true
        xlim([0.5 1.5]);
        set( hbTIT, {'BarWidth'}, {0.2});
    end
    resultB{Bidx} = TITBaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% FOR TOTAL SYSTEM %    
% **********************************************************************************************************************

% **********************************************************************************************************************
% plot packet error rate by System
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    PERSaxes = axes();
    datA = sum(statsA.PacketErrorPlotAP,'all')/(sum(statsA.NumberOfPackets,'all'));
    datB = sum(statsB.PacketErrorPlotAP,'all')/(sum(statsB.NumberOfPackets,'all'));
    datAB = [datA datB];
    OneRow = false;
    if isrow(datAB)     % trick bar function to think about multiple rows
      datAB = vertcat(datAB,nan(size(datAB)));
      OneRow = true;
    end
    hbPERS = bar(PERSaxes,datAB);
    set( hbPERS, {'DisplayName'}, {strcat("A: ", simulation.typeA); strcat("B: ", simulation.typeB)});
    title('Packet Error Rate for System','FontWeight','normal');
    grid on;
    xlabel('System');
    ylabel('PER');
    if OneRow == true
        xlim([0.5 1.5]);
    end
    ylim([0 inf]);
    resultB{Bidx} = PERSaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot throughput by System
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    TPSaxes = axes();
    datA = sum(statsA.DatatransferedPlot,'all')./(simulation.time*1e6).*8;
    datB = sum(statsB.DatatransferedPlot,'all')./(simulation.time*1e6).*8;
    datAB = [datA datB];
    OneRow = false;
    if isrow(datAB)     % trick bar function to think about multiple rows
      datAB = vertcat(datAB,nan(size(datAB)));
      OneRow = true;
    end
    hbTPS = bar(TPSaxes,datAB);
    set( hbTPS, {'DisplayName'}, {strcat("A: ", simulation.typeA); strcat("B: ", simulation.typeB)} );
    title('Throughput for System','FontWeight','normal');
    grid on;
    xlabel('System');
    ylabel('Throughput / Mb/s');
    if OneRow == true
        xlim([0.5 1.5]);
    end
    resultB{Bidx} = TPSaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot latency by System
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')
    LoadModel = char(all_bss{1}.STAs_load(1));    
    
    if (strcmp(LoadModel,'Lt8kb1Mbs')) || (strcmp(LoadModel,'Lt8kb10Mbs')) || (strcmp(LoadModel,'Lt8kb100Mbs')) || (strcmp(LoadModel,'Lt80b100kbs'))

        figure('Visible','off');

        LASaxes = axes();
        datAAP = [];
        datBAP = [];
        for idxAP = 1:numBSS
            numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            datASTA = [];
            datBSTA = [];
            for idxSTA = 1:numSTAs
                datASTA = [datASTA mean(statsA.Histo(idxAP,idxSTA).timeLatency,2)];
                datBSTA = [datBSTA mean(statsB.Histo(idxAP,idxSTA).timeLatency,2)];
            end
            datAAP = [datAAP; mean(datASTA,2)];
            datBAP = [datBAP; mean(datBSTA,2)];
        end
        datAB = [mean(datAAP,1) mean(datBAP,1)];
        OneRow = false;
        if isrow(datAB)     % trick bar function to think about multiple rows
          datAB = vertcat(datAB,nan(size(datAB)));
          OneRow = true;
        end
        hbTPS = bar(LASaxes,datAB);
        set( hbTPS, {'DisplayName'}, {strcat("A: ", simulation.typeA); strcat("B: ", simulation.typeB)} );
        title('Average Latency for System','FontWeight','normal');
        grid on;
        xlabel('System');
        ylabel('Latency / s');
        if OneRow == true
            xlim([0.5 1.5]);
        end
        resultB{Bidx} = LASaxes;
        Bidx = Bidx + 1;
    
    end
end

% **********************************************************************************************************************
% plot Jain's fairness index by System; calculated on TRPactual / TRPrequested 
if strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    JFaxes = axes();
    XiA = [];
    XiB = [];
    cntSTA = 0;
    for idxAP = 1:numBSS
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);        
        for idxSTA = 1:numSTAs
            cntSTA = cntSTA + 1;
            XiA(idxAP,idxSTA) = statsA.DatatransferedPlot(idxAP,idxSTA)/statsA.TotalData(idxAP,idxSTA);
            XiB(idxAP,idxSTA) = statsB.DatatransferedPlot(idxAP,idxSTA)/statsB.TotalData(idxAP,idxSTA);
        end
    end
    FIA = (sum(XiA,'all'))^2/(cntSTA * sum((XiA.^2),'all'));
    FIB = (sum(XiB,'all'))^2/(cntSTA * sum((XiB.^2),'all'));
    
    datAB = [FIA FIB];
    OneRow = false;
    if isrow(datAB)     % trick bar function to think about multiple rows
      datAB = vertcat(datAB,nan(size(datAB)));
      OneRow = true;
    end
    hbJF = bar(JFaxes,datAB);
    set( hbJF, {'DisplayName'}, {strcat("A: ", simulation.typeA); strcat("B: ", simulation.typeB)});
    title('Jain''s Fairness Index for System','FontWeight','normal');
    grid on;
    xlabel('System');
    ylabel('index');
    if OneRow == true
        xlim([0.5 1.5]);
    end
    ylim([0 inf]);
    resultB{Bidx} = JFaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
end % end function sim_A2B

% **********************************************************************************************************************
% FUNCTIONS
% **********************************************************************************************************************

% **********************************************************************************************************************
% function to get GEQ times and #bytes for load model for each STA
function [GEQtime, GEQVAR1, GEQtimeIncr] = DataLoadGetTimeSize(startTime,LoadModel,simulation)

    % all actions based on simulation.DataQueueCycle
    % check borders
    if simulation.DataQueueCycle > simulation.time
        simulation.DataQueueCycle = simulation.time;
    end
    if simulation.DataQueueCycle <= (simulation.SLOTTIME*1E-6)
        simulation.DataQueueCycle = (simulation.SLOTTIME*1E-6);       % min slottime
    end
    
    switch LoadModel
        
        case 'St1Mbs'
            GEQVAR1 = floor(1e6/8*simulation.DataQueueCycle);    % bytes each cycle
            GEQtime = startTime;
            GEQtimeIncr = simulation.DataQueueCycle;    % increment 1 cycle
            
        case 'St5Mbs'
            GEQVAR1 = floor(5e6/8*simulation.DataQueueCycle);
            GEQtime = startTime;
            GEQtimeIncr = simulation.DataQueueCycle;   
            
        case 'St10Mbs'
            GEQVAR1 = floor(10e6/8*simulation.DataQueueCycle);
            GEQtime = startTime;
            GEQtimeIncr = simulation.DataQueueCycle;
            
        case 'St100Mbs'
            GEQVAR1 = floor(100e6/8*simulation.DataQueueCycle);
            GEQtime = startTime;
            GEQtimeIncr = simulation.DataQueueCycle;
            
        case 'St500Mbs'
            GEQVAR1 = floor(500e6/8*simulation.DataQueueCycle);
            GEQtime = startTime;
            GEQtimeIncr = simulation.DataQueueCycle;
            
        case 'St1000Mbs'
            GEQVAR1 = floor(1000e6/8*simulation.DataQueueCycle);
            GEQtime = startTime;
            GEQtimeIncr = simulation.DataQueueCycle;
            
        case 'Pk1Mbs'
            GEQVAR1 = 1e6/8*0.1; 
            GEQtime = startTime + randi([0 200])/1E3;  % on average every 100 ms
            GEQtimeIncr = 0.1;
            
        case 'Pk5Mbs'
            GEQVAR1 = 5e6/8*0.1; 
            GEQtime = startTime + randi([0 200])/1E3;  % on average every 100 ms
            GEQtimeIncr = 0.1;
            
        case 'Pk10Mbs'
            GEQVAR1 = 10e6/8*0.1; 
            GEQtime = startTime + randi([0 200])/1E3;  % on average every 100 ms
            GEQtimeIncr = 0.1;            
            
        case 'Lt80b100kbs'                               % leads to 10 B packets with 0.1 Mb/s stream
            GEQVAR1 = 10; 
            GEQtime = startTime;
            GEQtimeIncr = 0.0008;            
            
        case 'Lt8kb1Mbs'                               % leads to 1 kB packets with 1 Mb/s stream
            GEQVAR1 = 1000; 
            GEQtime = startTime;
            GEQtimeIncr = 0.008;            
            
        case 'Lt8kb10Mbs'                               % leads to 1 kB packets with 10 Mb/s stream
            GEQVAR1 = 1000; 
            GEQtime = startTime;
            GEQtimeIncr = 0.0008;            
            
        case 'Lt8kb100Mbs'                               % leads to 1 kB packets with 100 Mb/s stream
            GEQVAR1 = 1000; 
            GEQtime = startTime;
            GEQtimeIncr = 0.00008;            
            
        case 'PkRandom'
            GEQVAR1 = randi([1 5000]);                 % payload random 1 to 5000 Bytes 
            GEQtime = startTime + randi([0 200])/1E3;  % time random between 0 to 200 ms
            GEQtimeIncr = 0.1;            
            
        otherwise
            disp('load model not covered');
            
    end
end

% **********************************************************************************************************************
% this function generates a look up table for TXLength by PayloadLength by MCS for given cfgPHY
function [PL2TX] = PL2TXtable(PLmin,PLmax,idxAP,cfgPHY,cfgSimu,simulation)
    cfg = cfgPHY{idxAP,1};
    idleTime = cfgSimu{idxAP,1}.IdleTime;
    numMCS = length(simulation.MCS);
    PL2TX = zeros(numMCS,PLmax);
%     for idxMCS=0:11
    for idxMCS=0:numMCS-1
        disp(['Generating LookUp Table for MCS :' num2str(idxMCS)]);
        cfg.MCS = idxMCS;
        for idxPL=PLmin:PLmax
            switch simulation.PHYType
                case 'IEEE 802.11ax'
                    cfg.APEPLength = idxPL;
                case 'IEEE 802.11n'
                    cfg.PSDULength = idxPL;
                case 'IEEE 802.11a'
                    cfg.PSDULength = idxPL;           
            end
            try
                PL2TX(idxMCS+1,idxPL) = length(wlanWaveformGenerator(0,cfg,'IdleTime',idleTime*1e-6));
            catch
                % There are TX time limitations which will not allow all PL length with low MCS
                PL2TX(idxMCS+1,idxPL) = 0;
            end
        end
    end
end

% **********************************************************************************************************************
% this function generates a look up table for TXLength by PayloadLength by MCS by STS for HESU and HE-MU MIMO
function [PL2TXSU, PL2TXMU] = PL2TXMIMOtable(PLmin,PLmaxSTS,cfgSimu,simulation)
    cfg = {};
    idleTime = cfgSimu{1,1}.IdleTime;
    numMCS = length(simulation.MCS);
    numSTS = 8;    
    PL2TXSU = zeros(numSTS,numMCS,PLmaxSTS);
    PL2TXMU = zeros(numSTS,numMCS,PLmaxSTS);
    
    % HESU
    cfg = wlanHESUConfig();
    cfg.ChannelBandwidth = 'CBW20';
    cfg.GuardInterval = cfgSimu{1,1}.GuardInterval;
       
    for idxSTS=1:numSTS
        disp(['Generating LookUp Table for STS :' num2str(idxSTS)]);
        cfg.NumTransmitAntennas = idxSTS;
        cfg.NumSpaceTimeStreams = idxSTS;
        for idxMCS=0:numMCS-1
            disp(['Generating LookUp Table for MCS :' num2str(idxMCS)]);
            cfg.MCS = idxMCS;
            for idxPL=PLmin:PLmaxSTS
                % create table for payload by STS
                cfg.APEPLength = idxPL*idxSTS;
                try
                    PL2TXSU(idxSTS,idxMCS+1,idxPL) = length(wlanWaveformGenerator(0,cfg,'IdleTime',idleTime*1e-6));
                catch
                    % There are TX time limitations which will not allow all PL length with low MCS
                    PL2TXSU(idxSTS,idxMCS+1,idxPL) = 0;
                end
            end
        end
    end
    
    % HEMU, only #STS = #user
       
    for idxSTS=1:numSTS
        disp(['Generating LookUp Table for STS :' num2str(idxSTS)]);
        cfg = wlanHEMUConfig(191+idxSTS);
        cfg.GuardInterval = cfgSimu{1,1}.GuardInterval;
        cfg.NumTransmitAntennas = idxSTS;    
        for idxMCS=0:numMCS-1
            disp(['Generating LookUp Table for MCS :' num2str(idxMCS)]);
            for idxPL=PLmin:PLmaxSTS
                % create table for payload by STS
                for idxUser = 1:idxSTS
                    cfg.User{idxUser}.NumSpaceTimeStreams = 1;
                    cfg.User{idxUser}.MCS = idxMCS;
                    cfg.User{idxUser}.APEPLength = idxPL;
                end
                try
                    PL2TXMU(idxSTS,idxMCS+1,idxPL) = length(wlanWaveformGenerator(0,cfg,'IdleTime',idleTime*1e-6));
                catch
                    % There are TX time limitations which will not allow all PL length with low MCS
                    PL2TXMU(idxSTS,idxMCS+1,idxPL) = 0;
                end
            end
        end
    end
    
end

% **********************************************************************************************************************
% this function generates the spatial mapping of the constellation mapper by #TX and #STS
function [cfgPHY] = defineSpatialMapping(cfgPHY,simulation)
    numTXAnt = cfgPHY.NumTransmitAntennas;
    numSTS = cfgPHY.NumSpaceTimeStreams;   
    
    % default steering matrix to prevent warning [NstsTotal, Nt], only active with 'custom' matrix
    V = complex(zeros(numSTS,numTXAnt)); % Nst-by-Nsts-by-Nr
   
    % use spatial expansion matrices as defined in Std 802.11-2012 Section 20.3.11.11.2
    if numSTS == 1
        if numTXAnt == 1
            V = [1]; % 1 STS to 1 Ntx
            cfgPHY.SpatialMapping = 'Direct';
        elseif numTXAnt == 2
            V = [1 1].*(1/sqrt(2)); % 1 STS to 2 Ntx
            cfgPHY.SpatialMapping = 'Custom';
        elseif numTXAnt == 4
            V = [1 1 1 1].*(1/2); % 1 STS to 4 Ntx
            cfgPHY.SpatialMapping = 'Custom';
        elseif numTXAnt == 8
            V = [1 1 1 1 1 1 1 1].*(1/sqrt(8)); % 1 STS to 8 Ntx
            cfgPHY.SpatialMapping = 'Custom';
        else
            cfgPHY.SpatialMapping = 'Direct';
        end
    elseif numSTS == 2
        if numTXAnt == 2
            V = [1 0;0 1]; % 2 STS to 2 Ntx
            cfgPHY.SpatialMapping = 'Direct';
        elseif numTXAnt == 4
            V = [1 0;0 1;1 0;0 1]'.*(1/sqrt(2)); % 2 STS to 4 Ntx
            cfgPHY.SpatialMapping = 'Custom';
        elseif numTXAnt == 8
            V = [1 0;0 1;1 0;0 1;1 0;0 1;1 0;0 1]'.*(1/2); % 2 STS to 8 Ntx
            cfgPHY.SpatialMapping = 'Custom';
        else
            cfgPHY.SpatialMapping = 'Direct';
        end
    elseif numSTS == 4
        if numTXAnt == 4
            V = [1 0 0 0;0 1 0 0;0 0 1 0;0 0 0 1]; % 4 STS to 4 Ntx
            cfgPHY.SpatialMapping = 'Direct';
        elseif numTXAnt == 8
            V = [1 0 0 0;0 1 0 0;0 0 1 0;0 0 0 1;1 0 0 0;0 1 0 0;0 0 1 0;0 0 0 1]'.*(1/sqrt(2)); % 4 STS to 8 Ntx
            cfgPHY.SpatialMapping = 'Custom';
        else
            cfgPHY.SpatialMapping = 'Direct';
        end
    elseif numSTS == 8
        if numTXAnt == 8
            V = [1 0 0 0 0 0 0 0;0 1 0 0 0 0 0 0;0 0 1 0 0 0 0 0;...
                0 0 0 1 0 0 0 0;0 0 0 0 1 0 0 0;0 0 0 0 0 1 0 0;0 0 0 0 0 0 1 0;0 0 0 0 0 0 0 1]'; % 8 STS to 8 Ntx
            cfgPHY.SpatialMapping = 'Direct';
        end
    else
        cfgPHY.SpatialMapping = 'Direct';
    end
    
    cfgPHY.SpatialMappingMatrix = V;
    
end





