% simulation type to to loop over a parameter
function [resultU, resultB] = sim_LOOP(all_bss,all_paths_STA_DL,all_paths_AP_DL,all_pathloss_STA_DL, ...
    all_pathloss_AP_DL,all_paths_STA_UL,all_paths_AP_UL,all_pathloss_STA_UL,all_pathloss_AP_UL,...
    simulation,resultU,resultB,h_start_simu_pushbtn)
% This function runs different loop approaches; after allocating common parameters for each approach a specific
% initialization takes place, the simulation does run and results are collected in a stats structure. Last part is 
% to generate reports from statistics. For more details see documentation. 

% **********************************************************************************************************************
% COMMON, OUTSIDE the LOOP
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
F = 10;
simulation.BW = B;
simulation.N_dBm = 10*log10(N)+30+F;
simulation.S_free_dBm = -82;
simulation.CCA_ED = -82;   % in dBm
simulation.CCA_ED_LOW = -82;   % in dBm
simulation.maxTP = 20; % in dBm


simulation.CarrierFrequency = 2.4E9;
simulation.lambda = physconst('LightSpeed')/simulation.CarrierFrequency;
simulation.fs = 20E6;
simulation.Ts = 1/simulation.fs;
numBSS = numel(all_bss);

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
                if usefadingchannel == true
                    simulation.RUSER = [8 16 23 30 41 53 56 60 70 76 83 84];
                    simulation.REQSNR = [17 19 24 25 29 32 34 37 39 42 44 48];
                    % rates and SNR requirement for SDM and SDMSR with 2 STS per STS
                    simulation.RUSERSR2 = [16 31 45 58 78 100 106 113 130 140 150 151];
                    simulation.REQSNRSR2 = [14 21 27 29 36 38 42 44 46 48 52 56];
                    simulation.RUSERSDMSR2 = [16 31 45 58 78 100 106 113 130 140 150 151]./2;
                    simulation.REQSNRSDMSR2 = [14 21 27 29 36 38 42 44 46 48 52 56];
                else % AWGN                   
                    simulation.RUSER = [8 16 22 29 39 51 54 57 66 71 77 78];
                    simulation.REQSNR = [5 7 9 13 15 19 21 23 26 28 31 33];
                end
                
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
                if usefadingchannel == true                    
                    simulation.RUSER = [4 8 14 21 30 44 52 53 60 67 82 84];
                    simulation.REQSNR = [5 8 13 16 21 26 30 32 34 37 44 48];
                    % rates and SNR requirement for SDM and SDMSR with 2 STS per STS
                    simulation.RUSERSR2 = [5 24 33 45 61 83 96 100 119 126 143 151];
                    simulation.REQSNRSR2 = [6 14 18 23 27 33 36 38 41 43 47 54];
                    simulation.RUSERSDMSR2 = [5 24 33 45 61 83 96 100 119 126 143 151]./2;
                    simulation.REQSNRSDMSR2 = [6 14 18 23 27 33 36 38 41 43 47 54];
                else % AWGN                   
                    simulation.RUSER = [8 16 22 29 39 51 54 57 66 71 77 78];
                    simulation.REQSNR = [5 7 9 13 15 19 21 23 26 28 31 33];
                end
                
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
simulation.REQSNRSR2 = simulation.REQSNRSR2 + simulation.PERSNROffset;
simulation.REQSNRSDMSR2 = simulation.REQSNRSDMSR2 + simulation.PERSNROffset;

% % for SR and SDMSR index calculation
% R_base = simulation.RUSER(end);
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

% move to dedicated stream if selected, for AWGN and RANDI
if  ~strcmp(simulation.RandomStream,'Global stream')
    awgnChannel = comm.AWGNChannel('NoiseMethod','Variance','Variance',10^((simulation.N_dBm-30)/10),...
        'RandomStream','mt19937ar with seed', 'Seed',5);    
else
    awgnChannel = comm.AWGNChannel('NoiseMethod','Variance','Variance',10^((simulation.N_dBm-30)/10));
end

stats.DATAQPlot = [];
stats.TotalData = [];
stats.PacketErrorPlotAP = [];
stats.PacketErrorPlotSTA = [];
stats.DatatransferedPlot = [];
stats.ThroughputPlot = [];
stats.NumberOfPackets = [];
stats.Histo = [];
stats.TimeHeader = [];
stats.TimeData = [];
stats.TimeACK = [];
stats.TimeIFS = [];
stats.TimeSRIFS = [];
stats.TimeSRRTS = [];
stats.TimeBackoff = [];
stats.TimeIdle = [];
stats.TimeWait = [];

statsPAR.DATAQPlot = {};
statsPAR.TotalData = {};
statsPAR.PacketErrorPlotAP = {};
statsPAR.PacketErrorPlotSTA = {};
statsPAR.DatatransferedPlot = {};
statsPAR.ThroughputPlot = {};
statsPAR.NumberOfPackets = {};
statsPAR.Histo = {};
statsPAR.TimeHeader = {};
statsPAR.TimeData = {};
statsPAR.TimeACK = {};
statsPAR.TimeIFS = {};
statsPAR.TimeSRIFS = [];
statsPAR.TimeSRRTS = [];
statsPAR.TimeBackoff = {};
statsPAR.TimeIdle = {};
statsPAR.TimeWait = {};

% **********************************************************************************************************************
% build tgax channels for all combinations of AP to AP and AP to AP/STA
% tgaxSTA{idxAP,idxBSS,idxSTA}, tgaxAP{idxAP,idxAP}
% the index is 'from' 'to' meaning tgaxSTA{idxAPTX,idxBSSRX,idxSTARX}
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
                % this is AP to AP
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
                    %this is AP to AP/STA
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
                    % this is AP/STA to AP
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

                        %this is AP/STA to AP/STA
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
        tgax.LargeScaleFadingEffect = 'None';    % done separately by scaling
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
    end    
end    

% **********************************************************************************************************************
% PREPARE THE LOOP
% **********************************************************************************************************************

% index is idxPAR
switch simulation.LoopPar
    case 'None'
        numPAR = 1;
    otherwise
        PARvec = simulation.LoopVal;        % vector of simulation parameter
        numPAR = numel(PARvec);             % number of PAR points
end

% **********************************************************************************************************************
% INSITE THE LOOP
% **********************************************************************************************************************

for idxPAR = 1:numPAR
    
    % ******************************************************************************************************************
    % allocate resources and load to queues
    % ******************************************************************************************************************
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
    OSCHAP = [];                            % offset to address channels, after garbage collection
    OSCHSTA = [];                           % offset to address channels, after garbage collection
    APCNT = {};                             % cell array to hold counter by AP etc.
    APSTACNT = {};                          % cell array to hold counter by STA & AP etc.
    lastTXPck_DL = {};                         % last TX packet by AP for SINR calculation
    txPSDUs_DL = {};                           % holds PSDU content for comparision of payload error
    lastTXPck_UL = {};                         % last TX packet by AP for SINR calculation
    txPSDUs_UL = {};                           % holds PSDU content for comparision of payload error

    % ******************************************************************************************************************
    % for every AP to STA, allocate zero data into data queue and queue plot; allocate zero complex data into the 
    % channel to allow estimation at start
    for idxAP = 1:numBSS %every AP
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        for idxCH = 1:simulation.numCH
            CHAP{idxAP,idxCH} = complex(zeros(1000,1));
            OSCHAP(idxAP,idxCH) = 0;
        end   
        APSTATE(idxAP) = "APIdle";
        APCNT{idxAP}.SRC = 0;           % reset station retry count for CSMA/CA
        APCNT{idxAP}.PrevError = false; % flag for unsuccessful previous tx attempt
        APCNT{idxAP}.IFS = 0;
        APCNT{idxAP}.BO = 0;
        APCNT{idxAP}.SelSTA = 1;
        APCNT{idxAP}.ChannelWasBusy = 0;                    % flag for channel condition busy during CCA
        stats.TimeHeader(idxAP) = 0;
        stats.TimeData(idxAP) = 0;
        stats.TimeACK(idxAP) = 0;
        stats.TimeIFS(idxAP) = 0;
        stats.TimeSRIFS(idxAP) = 0;
        stats.TimeSRRTS(idxAP) = 0;
        stats.TimeBackoff(idxAP) = 0;
        stats.TimeIdle(idxAP) = 0;
        stats.TimeWait(idxAP) = 0;
        for idxSTA = 1:numSTAs % every STA from LINK
            stats.DATAQPlot(idxAP,idxSTA).lengths = [];
            stats.DATAQPlot(idxAP,idxSTA).times = [];
            stats.TotalData(idxAP,idxSTA) = 0;
            stats.PacketErrorPlotSTA(idxAP,idxSTA) = 0;
            stats.PacketErrorPlotAP(idxAP) = 0;
            stats.DatatransferedPlot(idxAP,idxSTA) = 0;
            stats.ThroughputPlot(idxAP,idxSTA) = 0;
            stats.NumberOfPackets(idxAP,idxSTA) = 0;
            stats.Histo(idxAP,idxSTA).MCS = [];
            stats.Histo(idxAP,idxSTA).estSINR = [];
            stats.Histo(idxAP,idxSTA).calcSINR = [];
            stats.Histo(idxAP,idxSTA).eta_t = [];          % space transfer efficiency by packet
            stats.Histo(idxAP,idxSTA).eta_s = [];          % space usage efficiency by packet
            stats.Histo(idxAP,idxSTA).eta_tot = [];        % total efficiency by packet
            stats.Histo(idxAP,idxSTA).eta_wtot = [];       % weighted total efficiency by packet
            stats.Histo(idxAP,idxSTA).eta_wTPtot = [];     % weighted total efficiency by packet (with min TP)
            stats.Histo(idxAP,idxSTA).timeLatency = [];    % latency times
            DATAQ(idxAP,idxSTA) = 0;
            DATAPENQ(idxAP,idxSTA) = 0;
            saveCFG(idxAP,idxSTA).MCS = 0;
            saveCFG(idxAP,idxSTA).Length = 0;  
            SINRest{idxAP, idxSTA} = 27;
            SINRcalc{idxAP, idxSTA} = 27;
            for idxCH = 1:simulation.numCH
                CHSTA{idxAP, idxSTA,idxCH} = complex(zeros(1000,1));
                OSCHSTA(idxAP,idxSTA,idxCH) = 0;
            end
        end
    end
    
    % ******************************************************************************************************************
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

                % save total generated data
                stats.TotalData(idxAP,idxSTA) = TotalDataCnt;
                
            end
        end
    end
    
    % resort queue along event time
    GEQ = sortrows(GEQ,{'Time'});

    % ******************************************************************************************************************
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
    
    % ******************************************************************************************************************
    % for every AP allocate start event for SLOTTIME cycle
    for idxAP = 1:numBSS %every AP
        idxTime = simulation.SLOTTIME*1e-6;
        newevent = {idxTime, idxAP, 0, "APCycle",0,0,0,0,0};
        stats.TimeIdle(idxAP) = idxTime;
        APSTATE(idxAP) = "APIdle";
        GEQ = [GEQ;newevent];
    end
    
    % resort queue along event time
    GEQ = sortrows(GEQ,{'Time'});
    
    % ******************************************************************************************************************
    % build config opjects as selected. for all AP STA & AP AP combinations; result is cfgPHY{idxBSS, idxSTA}
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
                    cfgPHY{idxBSS,idxUser}.GuardInterval = cfgSimu{idxBSS,1}.GuardInterval;
                    cfgPHY{idxBSS,idxUser}.BSSColor = all_bss{idxBSS}.bss_cc;
                    % insert spatial expansion matrix
                    [cfgPHY{idxBSS,idxUser}] = defineSpatialMapping(cfgPHY{idxBSS,idxUser},simulation);
                    
                case 'IEEE 802.11n'             
            
                    % CONFIGURE wlan object, valid for all users within a BSS
                    cfgPHY{idxBSS,idxUser} = wlanHTConfig();
                    cfgPHY{idxBSS,idxUser}.ChannelBandwidth = 'CBW20';
                    cfgPHY{idxBSS,idxUser}.NumTransmitAntennas = all_bss{idxBSS}.num_tx;
                    cfgPHY{idxBSS,idxUser}.NumSpaceTimeStreams = all_bss{idxBSS}.STAs_sts(idxUser);
                    % insert spatial expansion matrix
                    [cfgPHY{idxBSS,idxUser}] = defineSpatialMapping(cfgPHY{idxBSS,idxUser},simulation);
                    
                case 'IEEE 802.11a'             
            
                    % CONFIGURE wlan object, valid for all users within a BSS
                    cfgPHY{idxBSS,idxUser} = wlanNonHTConfig();
                    cfgPHY{idxBSS,idxUser}.ChannelBandwidth = 'CBW20';
                    cfgPHY{idxBSS,idxUser}.NumTransmitAntennas = all_bss{idxBSS}.num_tx;
                    % no MIMO
            end
            
        end
    end
    
    % ******************************************************************************************************************
    % build configuration of loop cycle along selected parameter
    switch simulation.LoopPar
        
        case 'PayloadLength'
            % simulation.CCA_ED = -82;   % in dBm % leave as it is
            for idxBSS = 1:numBSS
                numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
                for idxUser = 1:numSTAs
                    cfgPHY{idxBSS,idxUser}.MCS = all_bss{idxBSS}.STAs_mcs(idxUser);
                    switch simulation.PHYType
                        case 'IEEE 802.11ax'
                            cfgPHY{idxBSS,idxUser}.APEPLength = PARvec(idxPAR) * all_bss{idxBSS}.STAs_sts(idxUser); %%%
                        case 'IEEE 802.11n'
                            cfgPHY{idxBSS,idxUser}.PSDULength = PARvec(idxPAR) * all_bss{idxBSS}.STAs_sts(idxUser); %%%
                        case 'IEEE 802.11a'
                            cfgPHY{idxBSS,idxUser}.PSDULength = PARvec(idxPAR); %%%
                    end
                    cfgSimu{idxBSS,idxUser}.TransmitPower = all_bss{idxBSS}.tx_power;
                end
            end

        case 'MCS'
            % simulation.CCA_ED = -82;   % in dBm % leave as it is
            for idxBSS = 1:numBSS
                numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
                for idxUser = 1:numSTAs
                    cfgPHY{idxBSS,idxUser}.MCS = PARvec(idxPAR); %%%
                    switch simulation.PHYType
                        case 'IEEE 802.11ax'
                            cfgPHY{idxBSS,idxUser}.APEPLength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                        case 'IEEE 802.11n'
                            cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                        case 'IEEE 802.11a'
                            cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser);
                    end
                    cfgSimu{idxBSS,idxUser}.TransmitPower = all_bss{idxBSS}.tx_power;
                end
            end

        case 'TransmitPower'
            % simulation.CCA_ED = -82;   % in dBm % leave as it is
            for idxBSS = 1:numBSS
                numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
                for idxUser = 1:numSTAs
                    cfgPHY{idxBSS,idxUser}.MCS = all_bss{idxBSS}.STAs_mcs(idxUser);     
                    switch simulation.PHYType
                        case 'IEEE 802.11ax'
                            cfgPHY{idxBSS,idxUser}.APEPLength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                        case 'IEEE 802.11n'
                            cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                        case 'IEEE 802.11a'
                            cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser);
                    end
                    cfgSimu{idxBSS,idxUser}.TransmitPower = PARvec(idxPAR);
                end
            end
            
        case 'OBSS_PDLevel'
            simulation.CCA_ED = PARvec(idxPAR); %%%
            for idxBSS = 1:numBSS
                numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
                for idxUser = 1:numSTAs
                    cfgPHY{idxBSS,idxUser}.MCS = all_bss{idxBSS}.STAs_mcs(idxUser);     
                    switch simulation.PHYType
                        case 'IEEE 802.11ax'
                            cfgPHY{idxBSS,idxUser}.APEPLength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                        case 'IEEE 802.11n'
                            cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                        case 'IEEE 802.11a'
                            cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser);
                    end
                    % adjust transmit power invers proportional along OBSS_PD change, if selected                   
                    if (simulation.TPOBSSPD == true) && (simulation.CCA_ED > simulation.CCA_ED_LOW)    % if level raised
                        delta_dB = simulation.CCA_ED - simulation.CCA_ED_LOW;
                        cfgSimu{idxBSS,idxUser}.TransmitPower = all_bss{idxBSS}.tx_power - delta_dB;
                    else
                        cfgSimu{idxBSS,idxUser}.TransmitPower = all_bss{idxBSS}.tx_power;
                    end        
                end
            end

        case 'SNR'
            % simulation.CCA_ED = -82;   % in dBm % leave as it is
            for idxBSS = 1:numBSS
                numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
                for idxUser = 1:numSTAs
                    cfgPHY{idxBSS,idxUser}.MCS = all_bss{idxBSS}.STAs_mcs(idxUser);     
                    switch simulation.PHYType
                        case 'IEEE 802.11ax'
                            cfgPHY{idxBSS,idxUser}.APEPLength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                        case 'IEEE 802.11n'
                            cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser) * all_bss{idxBSS}.STAs_sts(idxUser);
                        case 'IEEE 802.11a'
                            cfgPHY{idxBSS,idxUser}.PSDULength = all_bss{idxBSS}.STAs_apep(idxUser);
                    end
                    cfgSimu{idxBSS,idxUser}.TransmitPower = all_bss{idxBSS}.tx_power;
                    cfgSimu{idxBSS,idxUser}.SNR = PARvec(idxPAR);
                end
            end

    end 

    % ******************************************************************************************************************
    % main loop on global event queue
    % ******************************************************************************************************************

    % ******************************************************************************************************************
    % work on GEQ and fill data queues as requested
    SimuTime= 0;
    simulation.OldSimuTime = 0;
    simulation.AccSimuTime = 0;
    
    currpath = ['logs/LogApproach',num2str(idxPAR),'.txt'];
    % open file for logA
    fid = fopen(currpath, 'w');
    
    % move to dedicated stream for current iteration, if selected, for AWGN and RANDI
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

            % work on event
            approach = 'LOOP';
            [stats,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,saveCFG,APSTATE,APCNT,APSTACNT,SINRest,...
                SINRcalc,OSCHAP,OSCHSTA,LT] = WorkOnEvent_A2B_CSMA_CA(approach,stats,all_bss,cfgPHY,GEQ,CHAP,CHSTA,DATAQ,DATAPENQ,...
                txPSDUs_DL,txPSDUs_UL,lastTXPck_DL,lastTXPck_UL,all_pathloss_STA_DL,all_pathloss_AP_DL,chSTA_DL,chAP_DL,all_pathloss_STA_UL,all_pathloss_AP_UL,chSTA_UL,chAP_UL,awgnChannel,simulation,cfgSimu,...
                saveCFG,APSTATE,APCNT,APSTACNT,SINRest,SINRcalc,OSCHAP,OSCHSTA,fid,LT);

        simulation.handleTime.String = [num2str(SimuTime), ' s'];
        simulation.handlenumPackets.String = [num2str(sum(stats.NumberOfPackets,'all')), ' P'];
        drawnow;
        
    end
    
    % get statistics
    statsPAR.DATAQPlot{idxPAR} = stats.DATAQPlot;
    statsPAR.TotalData{idxPAR} = stats.TotalData;
    statsPAR.PacketErrorPlotAP{idxPAR} = stats.PacketErrorPlotAP;
    statsPAR.PacketErrorPlotSTA{idxPAR} = stats.PacketErrorPlotSTA;
    statsPAR.DatatransferedPlot{idxPAR} = stats.DatatransferedPlot;
    statsPAR.ThroughputPlot{idxPAR} = stats.ThroughputPlot;
    statsPAR.NumberOfPackets{idxPAR} = stats.NumberOfPackets;
    statsPAR.Histo{idxPAR} = stats.Histo;
    statsPAR.TimeHeader{idxPAR} = stats.TimeHeader;
    statsPAR.TimeData{idxPAR} = stats.TimeData;
    statsPAR.TimeACK{idxPAR} = stats.TimeACK;
    statsPAR.TimeIFS{idxPAR} = stats.TimeIFS;
    statsPAR.TimeBackoff{idxPAR} = stats.TimeBackoff;
    statsPAR.TimeIdle{idxPAR} = stats.TimeIdle;
    statsPAR.TimeWait{idxPAR} = stats.TimeWait;
    
    if diag == true;disp([datestr(now,0) ' Parameter Value done: ' num2str(PARvec(idxPAR))]);end
    
    % restore old global stream
    if  ~strcmp(simulation.RandomStream,'Global stream')
        RandStream.setGlobalStream(oldGlobalStream);
    end

end % end parameter loop

% **********************************************************************************************************************
fclose(fid);

% security save of results
save('saveresults/statsLastRun_sim_loop.mat','statsPAR');

% **********************************************************************************************************************
if diag == true;disp(['Simulaton time over, evaluating results']);end

% **********************************************************************************************************************
% evaluate results and produce stats
% **********************************************************************************************************************

% **********************************************************************************************************************
% BY STA
% **********************************************************************************************************************

Uidx = 1;

% **********************************************************************************************************************
% plot AP packet error rate by STA
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')

    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        PERaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);

        % resort PAR along rows and STAs along columns for this AP
        PERvec = [];
        for idxPAR = 1:numPAR
            currPER = statsPAR.PacketErrorPlotSTA{idxPAR}(idxAP,1:numSTAs)./statsPAR.NumberOfPackets{idxPAR}(idxAP,1:numSTAs);
            PERvec = [PERvec; currPER];
        end
        hbPER = semilogy(PERaxes{idxAP},PARvec,PERvec);    
        disVec = {};
        for idxSTA = 1:numSTAs
            disVec{idxSTA} = ['STA: ' num2str(idxSTA)];
        end
        set(hbPER, {'DisplayName'}, disVec');

        switch simulation.LoopPar

            case 'PayloadLength'
                title(['Packet Error Rate by PayloadLength for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('PayloadLength');

            case 'MCS'
                title(['Packet Error Rate by MCS for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('MCS');

            case 'TransmitPower'
                title(['Packet Error Rate by TransmitPower for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('TransmitPower');

            case 'OBSS_PDLevel'
                title(['Packet Error Rate by OBSSPDLevel for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('OBSSPDLevel');

            case 'SNR'
                title(['Packet Error Rate by SNR for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('SNR');

        end

        xticks(PARvec);
        xlim([min(PARvec) max(PARvec)])
        grid on;
        ylabel('PER');
        ylim([0.001 1]);
        resultU{idxAP,Uidx} = PERaxes{idxAP};
    end
    Uidx = Uidx +1;
end

% **********************************************************************************************************************
% plot AP throughput by STA
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')

    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        TPaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);

        % resort PAR along rows and STAs along columns for this AP
        PERvec = [];
        for idxPAR = 1:numPAR
            currPER = statsPAR.DatatransferedPlot{idxPAR}(idxAP,1:numSTAs)./(simulation.time*1e6).*8;
            PERvec = [PERvec; currPER];
        end
        hbPER = plot(TPaxes{idxAP},PARvec,PERvec);    
        disVec = {};
        for idxSTA = 1:numSTAs
            disVec{idxSTA} = ['STA: ' num2str(idxSTA)];
        end
        set(hbPER, {'DisplayName'}, disVec');

        switch simulation.LoopPar

            case 'PayloadLength'
                title(['Throughput by PayloadLength for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('PayloadLength');

            case 'MCS'
                title(['Throughput by MCS for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('MCS');

            case 'TransmitPower'
                title(['Throughput by TransmitPower for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('TransmitPower');

            case 'OBSS_PDLevel'
                title(['Throughput by OBSSPDLevel for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('OBSSPDLevel');

            case 'SNR'
                title(['Throughput by SNR for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('SNR');

        end

        xticks(PARvec);
        grid on;
        ylabel('Throughput / Mb/s');
        resultU{idxAP,Uidx} = TPaxes{idxAP};
    end
    Uidx = Uidx +1;
end

% **********************************************************************************************************************
% plot AP timing
if strcmp(simulation.ReportLevel,'Standard') || strcmp(simulation.ReportLevel,'Extended')

    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        TIaxes{idxAP} = axes();

        % resort PAR along rows and Timings along columns for this AP
        TIvec = [];
        for idxPAR = 1:numPAR
            sumIFS = statsPAR.TimeIFS{idxPAR}(idxAP);
            sumBackoff = statsPAR.TimeBackoff{idxPAR}(idxAP);
            sumHeader = statsPAR.TimeHeader{idxPAR}(idxAP);
            sumData = statsPAR.TimeData{idxPAR}(idxAP);
            sumACK = statsPAR.TimeACK{idxPAR}(idxAP);
            sumIdle = statsPAR.TimeIdle{idxPAR}(idxAP);
            sumWait = statsPAR.TimeWait{idxPAR}(idxAP);
            currTI = [sumIFS sumBackoff sumHeader sumData sumACK sumIdle sumWait];
            TIvec = [TIvec; currTI];
        end

        OneRow = false;
        if isrow(TIvec)     % trick bar function to think about multiple rows
          TIvec = vertcat(TIvec,nan(size(TIvec)));
          OneRow = true;
        end

        haTI = bar(TIaxes{idxAP},PARvec,TIvec,'stacked');
        set( haTI, {'DisplayName'}, {'IFS'; 'BACKOFF'; 'HEADER'; 'DATA'; 'ACK'; 'IDLE'; 'WAIT'});

        switch simulation.LoopPar

            case 'PayloadLength'
                title(['Timing by PayloadLength for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('PayloadLength');

            case 'MCS'
                title(['Timing by MCS for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('MCS');

            case 'TransmitPower'
                title(['Timing by TransmitPower for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('TransmitPower');

            case 'OBSS_PDLevel'
                title(['Timing by OBSSPDLevel for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('OBSSPDLevel');

            case 'SNR'
                title(['Timing  by SNR for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('SNR');

        end

        ylabel('Time / s');
        if OneRow == true
            xlim([0.5 1.5]);
            set( haTI, {'BarWidth'}, {0.2});
        end
        grid on;
        resultU{idxAP,Uidx} = TIaxes{idxAP};
    end
    Uidx = Uidx +1;
end

% **********************************************************************************************************************
% plot AP MCS usage
if strcmp(simulation.ReportLevel,'Standard') || strcmp(simulation.ReportLevel,'Extended')

    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        MCSaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        centers = [0:1:11];
        edges = [-0.5:1:11.5];  % MCS 0 to 11
        counts = [];

        try
            for idxPAR = 1:numPAR
                byAP = [];
                for idxSTA = 1:numSTAs
                    byAP = [byAP statsPAR.Histo{idxPAR}(idxAP,idxSTA).MCS];
                end
                curCount = histcounts(byAP,edges,'Normalization','probability');
                counts = [counts; curCount];
            end
            hbMCS = bar3(MCSaxes{idxAP},centers,counts.');
            set( hbMCS, {'DisplayName'},cellstr(num2str(PARvec')));
        catch
            disp('no sufficient data for histcount');
        end

        switch simulation.LoopPar

            case 'PayloadLength'
                title(['MCS Usage by PayloadLength for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('PayloadLength');

            case 'MCS'
                title(['MCS Usage by MCS for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('MCS');

            case 'TransmitPower'
                title(['MCS Usage by TransmitPower for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('TransmitPower');

            case 'OBSS_PDLevel'
                title(['MCS Usage by OBSSPDLevel for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('OBSSPDLevel');

            case 'SNR'
                title(['MCS Usage  by SNR for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('SNR');

        end

        grid on;
        ylabel('MCS');
        zlabel('Usage');
        resultU{idxAP,Uidx} = MCSaxes{idxAP};   
    end
    Uidx = Uidx +1;
end

% **********************************************************************************************************************
% plot AP estSINR by STA
if strcmp(simulation.ReportLevel,'Extended')

    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        SINRaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        allSINR = [];
        for idxPAR = 1:numPAR
            currSINR = statsPAR.Histo{idxPAR}(idxAP,:).estSINR;
            allSINR = [allSINR currSINR];
        end
        minSINR = floor(min(allSINR,[],'all'));
        maxSINR = ceil(max(allSINR,[],'all'));
        edges = minSINR-0.5:1:maxSINR+0.5;
        centers = minSINR:1:maxSINR;    
        counts = [];
        OneColumn = false;

        try
            for idxPAR = 1:numPAR
                byAP = [];
                for idxSTA = 1:numSTAs
                    byAP = [byAP statsPAR.Histo{idxPAR}(idxAP,idxSTA).estSINR];
                end
                curCount = histcounts(byAP,edges,'Normalization','probability');
                counts = [counts; curCount];
            end

            if iscolumn(counts)     % trick bar function to think about multiple rows
                counts = horzcat(counts,nan(size(counts)));
                OneColumn = true;
                if length(centers) == 1 % just one value is not allowed for bar3
                    centers = [centers centers+1];
                end
            end

            hbSINR = bar3(SINRaxes{idxAP},centers,counts.');
            set( hbSINR, {'DisplayName'},cellstr(num2str(PARvec')));
        catch
            disp('no sufficient data for histcount');
        end

        switch simulation.LoopPar

            case 'PayloadLength'
                title(['est SINR by PayloadLength for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('PayloadLength');

            case 'MCS'
                title(['est SINR by MCS for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('MCS');

            case 'TransmitPower'
                title(['est SINR by TransmitPower for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('TransmitPower');

            case 'OBSS_PDLevel'
                title(['est SINR by OBSSPDLevel for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('OBSSPDLevel');

            case 'SNR'
                title(['est SINR  by SNR for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('SNR');

        end

        grid on;
        ylabel('SINR / dB');
        zlabel('Usage');
        if OneColumn == true
            ylim([centers(1)-0.5 centers(1)+0.5]);
        end
        resultU{idxAP,Uidx} = SINRaxes{idxAP};    
    end
    Uidx = Uidx +1;
end

% **********************************************************************************************************************
% plot AP calcSINR by STA
if strcmp(simulation.ReportLevel,'Standard') || strcmp(simulation.ReportLevel,'Extended')

    for idxAP = 1:numBSS %every AP
        figure('Visible','off');

        cSINRaxes{idxAP} = axes();
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
        allSINR = [];
        for idxPAR = 1:numPAR
            currSINR = statsPAR.Histo{idxPAR}(idxAP,:).calcSINR;
            allSINR = [allSINR currSINR];
        end
        minSINR = floor(min(allSINR,[],'all'));
        maxSINR = ceil(max(allSINR,[],'all'));
        edges = minSINR-0.5:1:maxSINR+0.5;
        centers = minSINR:1:maxSINR;    
        counts = [];
        OneColumn = false;

        try
            for idxPAR = 1:numPAR
                byAP = [];
                for idxSTA = 1:numSTAs
                    byAP = [byAP statsPAR.Histo{idxPAR}(idxAP,idxSTA).calcSINR];
                end
                curCount = histcounts(byAP,edges,'Normalization','probability');
                counts = [counts; curCount];
            end

            if iscolumn(counts)     % trick bar function to think about multiple rows
                counts = horzcat(counts,nan(size(counts)));
                OneColumn = true;
                if length(centers) == 1 % just one value is not allowed for bar3
                    centers = [centers centers+1];
                end
            end

            hbcSINR = bar3(cSINRaxes{idxAP},centers,counts.');
            set( hbcSINR, {'DisplayName'},cellstr(num2str(PARvec')));
        catch
            disp('no sufficient data for histcount');
        end

        switch simulation.LoopPar

            case 'PayloadLength'
                title(['calc SINR by PayloadLength for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('PayloadLength');

            case 'MCS'
                title(['calc SINR by MCS for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('MCS');

            case 'TransmitPower'
                title(['calc SINR by TransmitPower for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('TransmitPower');

            case 'OBSS_PDLevel'
                title(['calc SINR by OBSSPDLevel for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('OBSSPDLevel');

            case 'SNR'
                title(['calc SINR  by SNR for AP: ' num2str(idxAP)],'FontWeight','normal');
                xlabel('SNR');

        end

        grid on;
        ylabel('SINR / dB');
        zlabel('Usage');
        if OneColumn == true
            ylim([centers(1)-0.5 centers(1)+0.5]);
        end
        resultU{idxAP,Uidx} = cSINRaxes{idxAP};    
    end
    Uidx = Uidx +1;
end

% **********************************************************************************************************************
% BY BSS ALONG PARAMETER
% **********************************************************************************************************************

Bidx = 1;

% **********************************************************************************************************************
% plot packet error rate by AP
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    PERTaxes = axes();
    PERvec = [];
    for idxPAR = 1:numPAR
        currPER = statsPAR.PacketErrorPlotAP{idxPAR}./(sum(statsPAR.NumberOfPackets{idxPAR},2)');
        PERvec = [PERvec; currPER];
    end
    for idxAP = 1:numBSS
        semilogy(PERTaxes,PARvec,PERvec(:,idxAP),'DisplayName',['BSS: ' num2str(idxAP)]);
        hold on;
    end

    switch simulation.LoopPar

        case 'PayloadLength'
            title('Packet Error Rate by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Packet Error Rate by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Packet Error Rate by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Packet Error Rate by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Packet Error Rate by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    xlim([min(PARvec) max(PARvec)])
    grid on;
    ylabel('PER');
    ylim([0.001 1]);
    resultB{Bidx} = PERTaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot throughput by AP
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    TPTaxes = axes();
    TPvec = [];
    for idxPAR = 1:numPAR
        currTP = sum(statsPAR.DatatransferedPlot{idxPAR},2)./(simulation.time*1e6).*8;
        TPvec = [TPvec; currTP'];
    end
    hold on;
    for idxAP = 1:numBSS
        plot(TPTaxes,PARvec,TPvec(:,idxAP),'DisplayName',['BSS: ' num2str(idxAP)]);
    end

    switch simulation.LoopPar

        case 'PayloadLength'
            title('Throughput by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Throughput by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Throughput by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Throughput by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Throughput by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('Throughput / Mb/s');
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

        LtToTaxes = axes();
        LtToTvec = [];
        for idxPAR = 1:numPAR
            datAP = [];
            for idxAP = 1:numBSS
            numSTAs = size(all_bss{idxAP}.STAs_pos,1);
                datSTA = [];
                for idxSTA = 1:numSTAs
                    datSTA = [datSTA mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).timeLatency,2)];
                end
                datAP = [datAP; mean(datSTA,2)];
            end

            LtToTvec = [LtToTvec; datAP'];
        end
        hold on;
        for idxAP = 1:numBSS
            plot(LtToTaxes,PARvec,LtToTvec(:,idxAP),'DisplayName',['BSS: ' num2str(idxAP)]);
        end

        switch simulation.LoopPar

            case 'PayloadLength'
                title('Average Latency by PayloadLength','FontWeight','normal');
                xlabel('PayloadLength');

            case 'MCS'
                title('Average Latency by MCS','FontWeight','normal');
                xlabel('MCS');

            case 'TransmitPower'
                title('Average Latency by TransmitPower','FontWeight','normal');
                xlabel('TransmitPower');

            case 'OBSS_PDLevel'
                title('Average Latency by OBSSPDLevel','FontWeight','normal');
                xlabel('OBSSPDLevel');

            case 'SNR'
                title('Average Latency by SNR','FontWeight','normal');
                xlabel('SNR');

        end

        xticks(PARvec);
        grid on;
        ylabel('Latency / s');
        resultB{Bidx} = LtToTaxes;
        Bidx = Bidx + 1;
    
    end

end

% **********************************************************************************************************************
% plot eta transfer by AP
if strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    ETATToTaxes = axes();
    ETATToTvec = [];
    for idxPAR = 1:numPAR
        datAP = [];
        for idxAP = 1:numBSS
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            datSTA = [];
            for idxSTA = 1:numSTAs
                datSTA = [datSTA mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_t,2)];
            end
            datAP = [datAP; mean(datSTA,2)];
        end

        ETATToTvec = [ETATToTvec; datAP'];
    end
    hold on;
    for idxAP = 1:numBSS
        plot(ETATToTaxes,PARvec,ETATToTvec(:,idxAP),'DisplayName',['BSS: ' num2str(idxAP)]);
    end

    switch simulation.LoopPar

        case 'PayloadLength'
            title('Eta Transfer by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Eta Transfer by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Eta Transfer by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Eta Transfer by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Eta Transfer by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('Eta T');
    resultB{Bidx} = ETATToTaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot eta space usage by AP
if strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    ETASToTaxes = axes();
    ETASToTvec = [];
    for idxPAR = 1:numPAR
        datAP = [];
        for idxAP = 1:numBSS
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            datSTA = [];
            for idxSTA = 1:numSTAs
                datSTA = [datSTA mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_s,2)];
            end
            datAP = [datAP; mean(datSTA,2)];
        end

        ETASToTvec = [ETASToTvec; datAP'];
    end
    hold on;
    for idxAP = 1:numBSS
        plot(ETASToTaxes,PARvec,ETASToTvec(:,idxAP),'DisplayName',['BSS: ' num2str(idxAP)]);
    end

    switch simulation.LoopPar

        case 'PayloadLength'
            title('Eta Space Usage by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Eta Space Usage by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Eta Space Usage by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Eta Space Usage by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Eta Space Usage by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('Eta S');
    resultB{Bidx} = ETASToTaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot eta total by AP
if strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    ETAtotToTaxes = axes();
    ETAtotToTvec = [];
    for idxPAR = 1:numPAR
        datAPt = [];
%         datAPs = [];
        for idxAP = 1:numBSS
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            datSTAt = [];
%             datSTAt = [];
%             datSTAs = [];
            for idxSTA = 1:numSTAs
                datSTAt = [datSTAt mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_tot,2)];
%                 datSTAt = [datSTAt mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_t,2)];
%                 datSTAs = [datSTAs mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_s,2)];
            end
            datAPt = [datAPt; mean(datSTAt,2)];
%             datAPt = [datAPt; mean(datSTAt,2)];
%             datAPs = [datAPs; mean(datSTAs,2)];
        end

        ETAtotToTvec = [ETAtotToTvec; (datAPt)'];
%         ETAtotToTvec = [ETAtotToTvec; (datAPt.*datAPs)'];
    end
    hold on;
    for idxAP = 1:numBSS
        plot(ETAtotToTaxes,PARvec,ETAtotToTvec(:,idxAP),'DisplayName',['BSS: ' num2str(idxAP)]);
    end

    switch simulation.LoopPar

        case 'PayloadLength'
            title('Eta Total by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Eta Total by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Eta Total by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Eta Total by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Eta Total by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('Eta Tot');
    resultB{Bidx} = ETAtotToTaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot w eta total by AP
if strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    ETAwtotToTaxes = axes();
    ETAtotToTvec = [];
    for idxPAR = 1:numPAR
        datAPt = [];
%         datAPs = [];
        for idxAP = 1:numBSS
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            datSTAt = [];
%             datSTAt = [];
%             datSTAs = [];
            for idxSTA = 1:numSTAs
                datSTAt = [datSTAt mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_wtot,2)];
%                 datSTAt = [datSTAt mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_t,2)];
%                 datSTAs = [datSTAs mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_s,2)];
            end
            datAPt = [datAPt; mean(datSTAt,2)];
%             datAPt = [datAPt; mean(datSTAt,2)];
%             datAPs = [datAPs; mean(datSTAs,2)];
        end

        ETAtotToTvec = [ETAtotToTvec; (datAPt)'];
%         ETAtotToTvec = [ETAtotToTvec; (datAPt.*datAPs)'];
    end
    hold on;
    for idxAP = 1:numBSS
        plot(ETAwtotToTaxes,PARvec,ETAtotToTvec(:,idxAP),'DisplayName',['BSS: ' num2str(idxAP)]);
    end

    switch simulation.LoopPar

        case 'PayloadLength'
            title('Weighted Eta Total by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Weighted Eta Total by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Weighted Eta Total by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Weighted Eta Total by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Weighted Eta Total by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('Eta Tot * normalized PHY Rate');
    resultB{Bidx} = ETAwtotToTaxes;
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
    PERvec = [];
    for idxPAR = 1:numPAR
        currPER = sum(statsPAR.PacketErrorPlotAP{idxPAR},'all')/(sum(statsPAR.NumberOfPackets{idxPAR},'all')');
        PERvec = [PERvec currPER];
    end
    semilogy(PERSaxes,PARvec,PERvec,'DisplayName','System');

    switch simulation.LoopPar

        case 'PayloadLength'
            title('Packet Error Rate System by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Packet Error Rate System by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Packet Error Rate System by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Packet Error Rate System by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Packet Error Rate System by SNR','FontWeight','normal');
            xlabel('SNR');

    end
    
    xticks(PARvec);
    xlim([min(PARvec) max(PARvec)])
    grid on;
    ylabel('PER');
    ylim([0.001 1]);
    resultB{Bidx} = PERSaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot throughput by System
if strcmp(simulation.ReportLevel,'Basic') || strcmp(simulation.ReportLevel,'Standard') ...
        || strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    TPSaxes = axes();
    TPvec = [];
    for idxPAR = 1:numPAR
        currTP = sum(statsPAR.DatatransferedPlot{idxPAR},'all')/(simulation.time*1e6).*8;
        TPvec = [TPvec currTP];
    end
    plot(TPSaxes,PARvec,TPvec,'DisplayName','System');

    switch simulation.LoopPar
        case 'PayloadLength'
            title('Throughput System by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Throughput System by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Throughput System by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Throughput System by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Throughput System by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('Throughput / Mb/s');
    resultB{Bidx} = TPSaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot eta transfer by System
if strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    ETATStotaxes = axes();
    ETATToTvec = [];
    for idxPAR = 1:numPAR
        datAP = [];
        for idxAP = 1:numBSS
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            datSTA = [];
            for idxSTA = 1:numSTAs
                datSTA = [datSTA mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_t,2)];
            end
            datAP = [datAP; mean(datSTA,2)];
        end

        ETATToTvec = [ETATToTvec mean(datAP,'all')];
    end
    plot(ETATStotaxes,PARvec,ETATToTvec,'DisplayName','System');

    switch simulation.LoopPar
        case 'PayloadLength'
            title('Eta Transfer System by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Eta Transfer System by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Eta Transfer System by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Eta Transfer System by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Eta Transfer System by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('Eta T');
    resultB{Bidx} = ETATStotaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot eta space usage by System
if strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    ETASStotaxes = axes();
    ETATToTvec = [];
    for idxPAR = 1:numPAR
        datAP = [];
        for idxAP = 1:numBSS
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            datSTA = [];
            for idxSTA = 1:numSTAs
                datSTA = [datSTA mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_s,2)];
            end
            datAP = [datAP; mean(datSTA,2)];
        end

        ETATToTvec = [ETATToTvec mean(datAP,'all')];
    end
    plot(ETASStotaxes,PARvec,ETATToTvec,'DisplayName','System');

    switch simulation.LoopPar
        case 'PayloadLength'
            title('Eta Space Usage System by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Eta Space Usage System by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Eta Space Usage System by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Eta Space Usage System by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Eta Space Usage System by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('Eta S');
    resultB{Bidx} = ETASStotaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot eta total by System
if strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    ETAtotStotaxes = axes();
    ETAtotSToTvect = [];
%     ETAtotSToTvecs = [];
    for idxPAR = 1:numPAR
        datAPt = [];
%         datAPs = [];
        for idxAP = 1:numBSS
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            datSTAt = [];
%             datSTAs = [];
            for idxSTA = 1:numSTAs
                datSTAt = [datSTAt mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_tot,2)];
%                 datSTAs = [datSTAs mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_s,2)];
            end
            datAPt = [datAPt; mean(datSTAt,2)];
%             datAPs = [datAPs; mean(datSTAs,2)];
        end

        ETAtotSToTvect = [ETAtotSToTvect mean(datAPt,'all')];
%         ETAtotSToTvecs = [ETAtotSToTvecs mean(datAPs,'all')];
    end
    plot(ETAtotStotaxes,PARvec,ETAtotSToTvect,'DisplayName','System');

    switch simulation.LoopPar
        case 'PayloadLength'
            title('Eta Total System by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Eta Total System by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Eta Total System by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Eta Total System by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Eta Total System by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('Eta Tot');
    resultB{Bidx} = ETAtotStotaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot eta total weighted by rate(MCS)/rate(maxMCS)
if strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    ETAWtotStotaxes = axes();
    ETAtotSToTvect = [];
%     ETAtotSToTvecs = [];

%     idxTRP = [];
%     for idxPAR = 1:numPAR
%         idxTRP = [idxTRP (sum(statsPAR.DatatransferedPlot{idxPAR},'all')/(simulation.time*1e6).*8)];
%     end
%     maxTRP = max(idxTRP,[],'all');

    for idxPAR = 1:numPAR
        datAPt = [];
%         datAPs = [];
        for idxAP = 1:numBSS
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            datSTAt = [];
%             datSTAs = [];
            for idxSTA = 1:numSTAs
                datSTAt = [datSTAt mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_wtot,2)];
%                 datSTAs = [datSTAs mean(statsPAR.Histo{idxPAR}(idxAP,idxSTA).eta_s,2)];
            end
            datAPt = [datAPt; mean(datSTAt,2)];
%             datAPs = [datAPs; mean(datSTAs,2)];
        end

%         currTP = sum(statsPAR.DatatransferedPlot{idxPAR},'all')/(simulation.time*1e6).*8;

        ETAtotSToTvect = [ETAtotSToTvect mean(datAPt,'all')];
%         ETAtotSToTvecs = [ETAtotSToTvecs mean(datAPs,'all')];
    end
    plot(ETAWtotStotaxes,PARvec,ETAtotSToTvect,'DisplayName','System');

    switch simulation.LoopPar

        case 'PayloadLength'
            title('Weighted Eta Total System by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Weighted Eta Total System by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Weighted Eta Total System by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Weighted Eta Total System by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Weighted Eta Total System by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('Eta Tot * normalized PHY Rate');
    resultB{Bidx} = ETAWtotStotaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
% plot Jain's fairness index by System; calculated on TRPactual / TRPrequested 
if strcmp(simulation.ReportLevel,'Extended')

    figure('Visible','off');

    JFaxes = axes();
    FItot = [];

    for idxPAR = 1:numPAR
        
        XiPAR = [];
        cntSTA = 0;

        for idxAP = 1:numBSS
        numSTAs = size(all_bss{idxAP}.STAs_pos,1);
            for idxSTA = 1:numSTAs
                cntSTA = cntSTA + 1;
                XiPAR(idxAP,idxSTA) = statsPAR.DatatransferedPlot{idxPAR}(idxAP,idxSTA)/...
                    statsPAR.TotalData{idxPAR}(idxAP,idxSTA);                       
            end
        end
        FIPAR = (sum(XiPAR,'all'))^2/(cntSTA * sum((XiPAR.^2),'all'));

        FItot = [FItot FIPAR];
    end
    
    plot(JFaxes,PARvec,FItot,'DisplayName','System');

    switch simulation.LoopPar

        case 'PayloadLength'
            title('Jain''s Fairness Index System by PayloadLength','FontWeight','normal');
            xlabel('PayloadLength');

        case 'MCS'
            title('Jain''s Fairness Index System by MCS','FontWeight','normal');
            xlabel('MCS');

        case 'TransmitPower'
            title('Jain''s Fairness Index System by TransmitPower','FontWeight','normal');
            xlabel('TransmitPower');

        case 'OBSS_PDLevel'
            title('Jain''s Fairness Index System by OBSSPDLevel','FontWeight','normal');
            xlabel('OBSSPDLevel');

        case 'SNR'
            title('Jain''s Fairness Index System by SNR','FontWeight','normal');
            xlabel('SNR');

    end

    xticks(PARvec);
    grid on;
    ylabel('index');
    resultB{Bidx} = JFaxes;
    Bidx = Bidx + 1;
end

% **********************************************************************************************************************
end % end function sim_loop

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

