% approach to estimate SR potential for network of interfering links combined with SDM
% base is to test every solution for MCS & TP by given pathloss values
% number of combinations growth very fast by number of APs: #MCS^#AP
% approach is running through base-MCS (12 for ax) system and test each
% combination one by one towards min throughput (MCSmax) and also for
% existing solution. Solutions are checked towards TP constraints.
% Possible SDM cluster mean interference transfer value = zero between STAs.
% For n links and m RX antennas there are i=floor(n/m) possible, exclusive SDM
% clusters. Some clusters are redundant as it does not matter if cluster 2 and
% cluster 1 is used in paralle or vice versa. All links outside the clusters are
% simple SISO links. All clusters are SIMO links.
% The cluster configuration is build as an outer loop to the SR configuration,
% but with hxy transfer coefficient for interference set to zero.
function [AllocMatrix] = SDMSRMCSDAallocset(PLMatrix,all_bss,simulation)

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

% cover all SDM cases
idxSDMComb = 1;
while idxSDMComb < numSDMComb   
    
    % 1 antenna or 1 link does not allow a cluster
    if (numAnt > 1) && (numLink > 1)
        % build AP SDM cluster vector for current combination; lowest value is zero!
        currSDMset = [];
        idx = idxSDMComb;
        while idx ~= 0
          currSDMset = [mod(idx,numElem),currSDMset];
          idx = (idx - currSDMset(1))/numElem;
        end
        currSDMset = [zeros(1,numLink-length(currSDMset)) currSDMset];

        % sort out solutions which do not meet constraints: at least one cluster with elements = numAnt,
        % but any additional cluster (no zero) with elements = numAnt:
        numClust = 0;
        ClustMismatch = false;
        for idxElem = 2:numElem
            cntElem = sum(currSDMset==(idxElem-1));
            if cntElem == numAnt
                numClust = numClust + 1;
            elseif cntElem > 0
                ClustMismatch = true;
            end
        end
        
        % another source for double entries are higher cluster numbers without lower cluster numbers
        % test starting cluster 2 without cluster 1. 
        HigherWOLower = false;
        highCL = max(currSDMset);
        for idxCL = highCL:-1:2
            isLower = any(currSDMset(:) == (idxCL -1));
            if (~isLower)
                HigherWOLower = true;
            end
        end

        if (numClust > 0) && (ClustMismatch == false) && (HigherWOLower == false)
            
            % count cycle to estimate duration
            simulation.idxTempCycle = simulation.idxTempCycle + 1;
            
            % change transfer matrix according to SDM cluster allocation
            currH = getSDMH(TRMatrixabs,currSDMset);
            
            % get and append new allocation matrix
%             currAllocMatrix = OnePassMCSDAallocset(currH,simulation);
            % new version to include rate and SNR requirement settings per SDM cluster
            currAllocMatrix = OnePassMCSDAallocsetSDM(currH,currSDMset,simulation,numSTS);
            
            % there might be sets with defined clusters but thoose APs should not transmit (rate = zero)
            idxNOTX = ~currAllocMatrix(:,2:numLink+1) > 0;
            idxDefCL = currSDMset > 0;
            keepRow = ~any(idxNOTX & idxDefCL,2);
            currAllocMatrix = currAllocMatrix(keepRow,:);
            
            % get length of current allocation matrix to append SDM set
            lenAllocMat = size(currAllocMatrix,1);
            tempSDMSet = repelem(currSDMset,lenAllocMat,1);
            currAllocMatrix = [currAllocMatrix tempSDMSet];

            % add to overall allocation matrix
            AllocMatrix = [AllocMatrix; currAllocMatrix];
           

        end
    end
    
    
    idxSDMComb = idxSDMComb +1;
end

    AllocMatrix = sortrows(AllocMatrix,1,'descend');
    AllocMatrix(:,1:4) = ceil(AllocMatrix(:,1:4));

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function to eliminate interference components based on built SDM cluster
function currH = getSDMH(TRMatrixabs,currSDMset)

    currH = TRMatrixabs;

    % get number of SDM clusters
    numCL = max(currSDMset);
    
    % eliminate interferer component for each SDM cluster, if any cluster
    if numCL > 0
        
        for idxCL = 1:numCL
            
            % isolate APs index of current cluster
            idxAPs = find(currSDMset == idxCL);
            
            % all combination 2 out of k are needed. k is length of cluster
            combCL = nchoosek(idxAPs,2);
            
            % clear elements, also flipped elements
            for idxRow = 1:size(combCL,1)
                
                midx = combCL(idxRow,1);
                nidx = combCL(idxRow,2);
                
                if midx ~= nidx

                    currH(midx,nidx) = 0;
                    currH(nidx,midx) = 0;                    

                end
                
            end
            
        end        
        
    end
    
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% this function is the same as one pass MCDA, but H is already aligned to needed format
% this version sets right rates and SNR requirements for SDM cluster STAs
function [AllocMatrix] = OnePassMCSDAallocsetSDM(TRMatrixabs,currSDMset, simulation,numSTS)

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
            RatebyMCSSDMSR2 = [0 simulation.RUSERSDMSR2(MCSidxAll)];
            SNRbyMCSSDMSR2 = [0 simulation.REQSNRSDMSR2(MCSidxAll)];

        case 'MCS_Med'
            MCS = [-1 simulation.MCS(MCSidxMed)];
            RatebyMCS = [0 simulation.RUSER(MCSidxMed)];
            SNRbyMCS = [0 simulation.REQSNR(MCSidxMed)];
            RatebyMCSSR2 = [0 simulation.RUSERSR2(MCSidxMed)];
            SNRbyMCSSR2 = [0 simulation.REQSNRSR2(MCSidxMed)];
            RatebyMCSSDMSR2 = [0 simulation.RUSERSDMSR2(MCSidxMed)];
            SNRbyMCSSDMSR2 = [0 simulation.REQSNRSDMSR2(MCSidxMed)];

        case 'MCS_Min'
            MCS = [-1 simulation.MCS(MCSidxMin)];
            RatebyMCS = [0 simulation.RUSER(MCSidxMin)];
            SNRbyMCS = [0 simulation.REQSNR(MCSidxMin)];
            RatebyMCSSR2 = [0 simulation.RUSERSR2(MCSidxMin)];
            SNRbyMCSSR2 = [0 simulation.REQSNRSR2(MCSidxMin)];
            RatebyMCSSDMSR2 = [0 simulation.RUSERSDMSR2(MCSidxMin)];
            SNRbyMCSSDMSR2 = [0 simulation.REQSNRSDMSR2(MCSidxMin)];

        otherwise
    end
    
    % move to 2 STS SNRs and rates if 2 STS are used as default; all cluster APs will get 
    % single stream rates and required SNRs later during cluster assignment
    if numSTS > 1
        RatebyMCS = RatebyMCSSR2;
        SNRbyMCS = SNRbyMCSSR2;
    end

    SNRbyMCSabs = 10.^(SNRbyMCS./10);
    SNRbyMCSabsSDMSR2 = 10.^(SNRbyMCSSDMSR2./10);

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
        
        % replace rates for APs which are part of a cluster
        idxChange = currSet&currSDMset;
        updateRate = RatebyMCSSDMSR2(currSet+1);
        currRate(idxChange) = updateRate(idxChange);

        % test for feasible solution, take care about link dropping
        % build index for transmitting APs and isolate PL matrix 
        currTXidx = currRate > 0;
        % RatetoTest = currRate(currTXidx);
        SettoTest = currSet(currTXidx);
        SNRtoTest = SNRbyMCSabs(SettoTest+1);
        
        % replace SNRs for APs which are part of a cluster
        idxChange = currTXidx&currSDMset;
        idxChangeSet = idxChange(currTXidx);
        updateSNR = SNRbyMCSabsSDMSR2(SettoTest+1);       
        SNRtoTest(idxChangeSet) = updateSNR(idxChangeSet);
        
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

        % valid solution if ev smaller than abs one
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
        
        % replace SNRs for APs which are part of a cluster
        idxChange = currTXidx&currSDMset;
        idxChangeSet = idxChange(currTXidx);
        updateSNR = SNRbyMCSabsSDMSR2(SettoTest+1);       
        SNRtoTest(idxChangeSet) = updateSNR(idxChangeSet); 
        
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