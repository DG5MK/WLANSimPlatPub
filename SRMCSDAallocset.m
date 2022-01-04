% approach to estimate SR potential for network of interfering links
% base is to test every solution for MCS & TP by given pathloss values
% number of combinations growth very fast by number of APs: #MCS^#AP
% approach is running through base-MCS (12 for ax) system and test each
% combination one by one towards min throughput (MCSmax) and also for
% existing solution. Solutions are checked towards TP constraints.
function [AllocMatrix] = SRMCSDAallocset(PLMatrix,all_bss,simulation)

% calculate abs of wanted and unwanted PL for analysis
TRMatrixabs = 1./(10.^(PLMatrix./10));

% important: simulation uses PL matrix i,k (rows,columns) with i for TX AP and k for RX STA
% for calculation the format has to be PL matrix i,k with i for RX STA and k for TX AP
% this effects the unwanted part (interferer part). The matrix has to be transposed!
TRMatrixabs = TRMatrixabs'; 

numAnt = all_bss{1}.num_rx;     % all links same number of RX antenna
numLink = numel(all_bss);
numSTS = all_bss{1}.STAs_sts(1); % get numSTS for 2 STS SNR assignment

AllocMatrix = [];

% build base system with number of links = digits and number of elements = floor(numLink/NumAnt)
% the alphabet itself is at least 0 or 1 different clusters, or elements different clusters.
numElem = floor(numLink/numAnt)+1;
% at least 0 and 1 as elements
if numElem < 2
    numElem = 2;
end
currSDMset = zeros(1,numLink);
testvector = currSDMset;
numSDMComb = numElem^numLink;

simulation.idxTempCycle = 1;

% cover non SDM case
currH = TRMatrixabs;
currAllocMatrix = OnePassMCSDAallocset(currH,simulation,numSTS);

% get length of current allocation matrix to append SDM set
lenAllocMat = size(currAllocMatrix,1);
tempSDMSet = repelem(currSDMset,lenAllocMat,1);
AllocMatrix = [currAllocMatrix tempSDMSet];

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% this function is the same as one pass MCDA, but H is already aligned to needed format
function [AllocMatrix] = OnePassMCSDAallocset(TRMatrixabs,simulation,numSTS)

    % the method calculates the minimum TP for a stable solution. This could lead to
    % too high PER. A solution is to include a guard buffer for N in dB.
%     noise2buffer = 3;       % assign buffer for lower PER
    noise2buffer = 0;       % assign buffer for lower PER

    %     TPconstrain = (10^((simulation.maxTP-30)/10))/2;
    TPconstrain = (10^((simulation.maxTP-30)/10));

    N = 10^((simulation.N_dBm-30+noise2buffer)/10);
%     N = 10^((simulation.N_dBm-30)/10);

    switch simulation.approach
        case 'A'
            simulation.MA = simulation.A.MA;        
        case 'B'
            simulation.MA = simulation.B.MA;        
        otherwise
    end

    % define MCS and rate by MCS; -1 means no transmit

    switch simulation.PHYType

        case 'IEEE 802.11ax'
            MCSidxAll = [1 2 3 4 5 6 7 8 9 10 11 12];
            MCSidxMed = [1 3 5 8 10 12];
            MCSidxMin = [1 6 12];

        case 'IEEE 802.11n'
            MCSidxAll = [1 2 3 4 5 6 7];
            MCSidxMed = [1 3 5 7];
            MCSidxMin = [1 4 7];

        case 'IEEE 802.11a'
            MCSidxAll = [1 2 3 4 5 6 7];
            MCSidxMed = [1 3 5 7];
            MCSidxMin = [1 4 7];

    end   

    switch simulation.MA

        case 'MCS_All'
            MCS = [-1 simulation.MCS(MCSidxAll)];
            RatebyMCS = [0 simulation.RUSER(MCSidxAll)];
            SNRbyMCS = [0 simulation.REQSNR(MCSidxAll)];
            RatebyMCSSR2 = [0 simulation.RUSERSR2(MCSidxAll)];
            SNRbyMCSSR2 = [0 simulation.REQSNRSR2(MCSidxAll)];

        case 'MCS_Med'
            MCS = [-1 simulation.MCS(MCSidxMed)];
            RatebyMCS = [0 simulation.RUSER(MCSidxMed)];
            SNRbyMCS = [0 simulation.REQSNR(MCSidxMed)];
            RatebyMCSSR2 = [0 simulation.RUSERSR2(MCSidxMed)];
            SNRbyMCSSR2 = [0 simulation.REQSNRSR2(MCSidxMed)];

        case 'MCS_Min'
            MCS = [-1 simulation.MCS(MCSidxMin)];
            RatebyMCS = [0 simulation.RUSER(MCSidxMin)];
            SNRbyMCS = [0 simulation.REQSNR(MCSidxMin)];
            RatebyMCSSR2 = [0 simulation.RUSERSR2(MCSidxMin)];
            SNRbyMCSSR2 = [0 simulation.REQSNRSR2(MCSidxMin)];

        otherwise
    end
    
    % move to 2 STS SNRs and rates if 2 STS are used
    if numSTS > 1
        RatebyMCS = RatebyMCSSR2;
        SNRbyMCS = SNRbyMCSSR2;
    end
    SNRbyMCSabs = 10.^(SNRbyMCS./10);

    % isolate structual rank of matrix to get number of APs / links
    numAP = sprank(TRMatrixabs);
    numMCS = length(MCS);
    numComb = numMCS^numAP;

    % estimate duration
    estTime = numComb/1000*0.05;
    disp(['Estimated time in seconds: ' num2str(estTime) ' #Cycle: ' num2str(simulation.idxTempCycle)]);

    % build counter for specified base system
    currSet = zeros(1,numAP);
    AllocMatrix = [];

    % build loop which counts through all combinations of MCS at APs
    idxComb = 1;
    while idxComb < numComb

        % build AP MCS vector for current combination; lowest value is zero!
        currSet = [];
        idx = idxComb;
        while idx ~= 0
          currSet = [mod(idx,numMCS),currSet];
          idx = (idx - currSet(1))/numMCS;
        end
        currSet = [zeros(1,numAP-length(currSet)) currSet];

        % test if sum of rates is greater than MCSmax rate - exclusive channel access
        currRate = RatebyMCS(currSet+1);

        % test for feasible solution, take care about link dropping
        % build index for transmitting APs and isolate PL matrix 
        currTXidx = currRate > 0;
        RatetoTest = currRate(currTXidx);
        SettoTest = currSet(currTXidx);
        SNRtoTest = SNRbyMCSabs(SettoTest+1);
        TRtoTest = TRMatrixabs(currTXidx,currTXidx);

    % % %     % important: simulation uses PL matrix i,k (rows,columns) with i for TX AP and k for RX STA
    % % %     % for calculation the format has to be PL matrix i,k with i for RX STA and k for TX AP
    % % %     % this effects the unwanted part (interferer part). The matrix has to be transposed!
    % % %     TRtoTest = TRtoTest';
    % % %     % transpose done before entry!

        % test solution with Perron Frobenius
        W = diag(diag(TRtoTest));
        U = TRtoTest - W;
        S = diag(SNRtoTest);

        % calculate eigenvalues
        ev = eig(inv(W)*S*U);

    %     % a sufficient test for a valid solution is also all TP valid per link
    %     if (all(TPcurrSet > 0)) && (max(TPcurrSet,[],'all') <= TPconstrain)

        % valid solution if ev smaller than abs one and TP is smaller than constraint
        if (max(abs(ev)) < 1-1e-10)

            % check first for ev and than for TP
            % calculate TP, only if abs ev smaller than 1
            n = zeros(length(SettoTest),1) + N;
            TPcurrSet = inv(inv(S)*W-U) * n;
                        
            if (max(TPcurrSet,[],'all') <= TPconstrain)                       
           
                % save set for later TP calculation
                currMCS = MCS(currSet+1);
                currVector = [currRate currSet];

                if isempty(AllocMatrix)
                    AllocMatrix = currVector;

                else                
                    try
                    AllocMatrix = [AllocMatrix; currVector];
                    catch
                    end

                end

                % test if old solutions are redundant to new solution, get index for not needed solutions
                % min one element is smaller than current solution, all elements are smaller or equal
                idxS = (AllocMatrix(:,1:numAP) < currRate);
                idxSorEline = all((AllocMatrix(:,1:numAP) <= currRate),2);
                % take a line to delete if it is nonzero
                delVec = any(idxS,2) & idxSorEline;
                keepVec = ~delVec;
                AllocMatrix = AllocMatrix(keepVec,:);      
            end
            
        end

        idxComb = idxComb +1;
    end

    % calculate TP only for relevant sets to save time
    tempAllocMatrix = [];
    numRelComb = size(AllocMatrix,1);
    for idx = 1:numRelComb

        % get again all indices and matrixes for TP calculation, set is saved in matrix
        currRate = AllocMatrix(idx,1:numAP);
        currSet = AllocMatrix(idx,numAP+1:2*numAP);
        currTXidx = currRate > 0;
        SettoTest = currSet(currTXidx);
        SNRtoTest = SNRbyMCSabs(SettoTest+1);
        TRtoTest = TRMatrixabs(currTXidx,currTXidx);

% % %         % important: simulation uses PL matrix i,k (rows,columns) with i for TX AP and k for RX STA
% % %         % for calculation the format has to be PL matrix i,k with i for RX STA and k for TX AP
% % %         % this effects the unwanted part (interferer part). The matrix has to be transposed!
% % %         TRtoTest = TRtoTest';
% % %         % transpose done before entry!
% % %     
        W = diag(diag(TRtoTest));
        U = TRtoTest - W;
        S = diag(SNRtoTest);

        % calculate TP
        n = zeros(length(SettoTest),1)+N;
        TPcurrSet = inv(inv(S)*W-U) * n;
    %     TPcurrSetdB = log10(TPcurrSet).*10+30;

        % build TP vector to add to AllocMatrix
        TPVec = [];
        idxTP = 1;
        for idxVec = 1:numAP
            if currTXidx(idxVec) == 0
                TPVec = [TPVec 0];
            else
                TPVec = [TPVec TPcurrSet(idxTP)];
                idxTP = idxTP+1;
            end
        end
        
        % add Vector
        currMCS = MCS(currSet+1);
        tempAllocMatrix(idx,:) = [AllocMatrix(idx,1:numAP) TPVec currMCS];

    end

    AllocMatrix = tempAllocMatrix;

    % add rate sum to alloc set
    sumVec = sum(AllocMatrix(:,1:numAP),2);
    AllocMatrix = [sumVec AllocMatrix];
    AllocMatrix = sortrows(AllocMatrix,1,'descend');

end