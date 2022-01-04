% **********************************************************************************************************************
function [CHAP,CHSTA,OSCHAP,OSCHSTA,lastTXPck] = Transmit_UL(idxSample,txPacket,idxAP,idxTXSTA,CHAP,CHSTA,...
    all_bss,all_pathloss_STA,all_pathloss_AP,tgaxSTA,tgaxAP,cfgSimu,simulation,OSCHAP,OSCHSTA,lastTXPck,APCNT)

    % this is the upload version, the index is from AP/STA to AP or from AP/STA to AP/STA
    % idxAP - AP of TX STA
    % idxTXSTA - TX STA
    % idxBSS - target AP or AP of target STA
    % idxSTA - target STA

    % convert time to index of channels
    numBSS = numel(all_bss);
    diag = simulation.diag;
    idxCH = all_bss{idxAP}.ch;
    
    seedCH = -1;  % never give specific seed for UL
    
    % loop through all transmit receive combinations and overlay txPacket
    % after it went through scaling/PL and tgax channel (awgn channel later during RX)
    for idxBSS = 1:numBSS   %idxBSS is the target AP
        
        % this is current AP/STA to AP
        if simulation.NOINT == false
            PL_abs = 10^(all_pathloss_AP{idxAP,idxTXSTA,idxBSS}/10);
            tx = txPacket./sqrt(PL_abs);        % scale along PL
            
            switch simulation.ChannelModel
                case 'WINNER II'

                    % release channel and set tx length if needed
                    if size(tx, 1) ~= tgaxAP{idxAP,idxTXSTA,idxBSS}.ModelConfig.NumTimeSamples
                        release(tgaxAP{idxAP,idxTXSTA,idxBSS});
                        tgaxAP{idxAP,idxTXSTA,idxBSS}.ModelConfig.NumTimeSamples = size(tx, 1);
                        reset(tgaxAP{idxAP,idxTXSTA,idxBSS});
                    end

                    % reset channel, if needed, to fixed seed or global stream
                    if simulation.resetchannel == true                            
                        release(tgaxAP{idxAP,idxTXSTA,idxBSS});
                        % use fixed seed if selected
                        if  strcmp(simulation.RandomStream,'Global stream')
                            pckSeed = randi(99999,1);
                            tgaxAP{idxAP,idxTXSTA,idxBSS}.ModelConfig.RandomSeed         = pckSeed;
                        else
                            tgaxAP{idxAP,idxTXSTA,idxBSS}.ModelConfig.RandomSeed         = 111;                                
                        end
                        reset(tgaxAP{idxAP,idxTXSTA,idxBSS});
                    end

                    % giving a dedicated seed as parameter uses that seed (beamforming etc.)
                    if seedCH ~= -1
                        release(tgaxAP{idxAP,idxTXSTA,idxBSS});                        
                        tgaxAP{idxAP,idxTXSTA,idxBSS}.ModelConfig.RandomSeed = seedCH;
                        reset(tgaxAP{idxAP,idxTXSTA,idxBSS});                            
                    end

                    % move through channel
                    pow_before = mean(mean(abs(tx).^2));    % for constant average power
                    rxcell = tgaxAP{idxAP,idxTXSTA,idxBSS}(tx);
                    rx = rxcell{1};
                    pow_after = mean(mean(abs(rx).^2));     % for constant average power
                    if simulation.ConstAvgPow == true
                        rx = rx./sqrt(pow_after/pow_before);
                    end                   

                case 'TGax'

                    if simulation.resettgax == true
                        reset(tgaxAP{idxAP,idxTXSTA,idxBSS});       % new realization tgax
                    end
                    pow_before = mean(mean(abs(tx).^2));    % for constant average power
                    rx = tgaxAP{idxAP,idxTXSTA,idxBSS}(tx);           
                    pow_after = mean(mean(abs(rx).^2));     % for constant average power
                    if simulation.ConstAvgPow == true
                        rx = rx./sqrt(pow_after/pow_before);
                    end

                case 'None'

                    rx = tx;                        
            end            

%             % move trough tgax, if selected
%             if simulation.usetgax == true
%                 rx = tgaxAP{idxAP,idxTXSTA,idxBSS}(tx);
%             else
%                 rx = tx;
%             end
            
            % rx power is S for SINR calculation at AP, take same length for I+N
            % save just the version for own BSS
            if idxAP == idxBSS
                lastTXPck{idxBSS} = rx;
            end

            % pad rx with zeros before idxTime; use TX antennas as UL to AP
            numRxant = all_bss{idxBSS}.num_tx;
            rx = [zeros(idxSample-1+OSCHAP(idxBSS,idxCH),numRxant);rx];

            % align channel and packet for same size to overlay
            nmax = max(size(rx,1),size(CHAP{idxBSS,idxCH},1));
            rx(end+1:nmax,:) = 0;
            CHAP{idxBSS,idxCH}(end+1:nmax,:) = 0;
            CHAP{idxBSS,idxCH} = CHAP{idxBSS,idxCH} + rx;
        end
        
        if simulation.NOINT == false
            numSTAs = size(all_bss{idxBSS}.STAs_pos,1);
            for idxSTA = 1:numSTAs
                
                % not to own STA
                if ~((idxAP == idxBSS) && (idxTXSTA == idxSTA))

                    %this is AP/STA to AP/STA
                    PL_abs = 10^(all_pathloss_STA{idxAP,idxTXSTA,idxBSS,idxSTA}/10);
                    tx = txPacket./sqrt(PL_abs);                % scale along PL
                    
                    switch simulation.ChannelModel
                        case 'WINNER II'

                            % release channel and set tx length if needed
                            if size(tx, 1) ~= tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA}.ModelConfig.NumTimeSamples
                                release(tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA});
                                tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA}.ModelConfig.NumTimeSamples = size(tx, 1);
                                reset(tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA});
                            end

                            % reset channel, if needed, to fixed seed or global stream
                            if simulation.resetchannel == true                            
                                release(tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA});
                                % use fixed seed if selected
                                if  strcmp(simulation.RandomStream,'Global stream')
                                    pckSeed = randi(99999,1);
                                    tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA}.ModelConfig.RandomSeed         = pckSeed;
                                else
                                    tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA}.ModelConfig.RandomSeed         = 111;                                
                                end
                                reset(tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA});
                            end

                            % giving a dedicated seed as parameter uses that seed (beamforming etc.)
                            if seedCH ~= -1
                                release(tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA});                        
                                tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA}.ModelConfig.RandomSeed = seedCH;
                                reset(tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA});                            
                            end

                            % move through channel
                            pow_before = mean(mean(abs(tx).^2));    % for constant average power
                            rxcell = tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA}(tx);
                            rx = rxcell{1};                        
                            pow_after = mean(mean(abs(rx).^2));     % for constant average power
                            if simulation.ConstAvgPow == true
                                rx = rx./sqrt(pow_after/pow_before);
                            end

                        case 'TGax'

                            if simulation.resettgax == true
                                reset(tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA});       % new realization tgax
                            end
                            pow_before = mean(mean(abs(tx).^2));    % for constant average power
                            rx = tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA}(tx);
                            pow_after = mean(mean(abs(rx).^2));     % for constant average power
                            if simulation.ConstAvgPow == true
                                rx = rx./sqrt(pow_after/pow_before);
                            end

                        case 'None'
                            
                            rx = tx;

                    end                                       
% 
%                     % move trough tgax, if selected
%                     if simulation.usetgax == true
%                         rx = tgaxSTA{idxAP,idxTXSTA,idxBSS,idxSTA}(tx);
%                     else
%                         rx = tx;
%                     end

                    % pad rx with zeros before idxTime, but smaller because of offset
                    numRxant = all_bss{idxBSS}.num_rx;
                    rx = [zeros(idxSample-1+OSCHSTA(idxBSS,idxSTA,idxCH),numRxant);rx];

                    % align channel and packet for same size to overlay
                    nmax = max(size(rx,1),size(CHSTA{idxBSS,idxSTA,idxCH},1));
                    rx(end+1:nmax,:) = 0;
                    CHSTA{idxBSS,idxSTA,idxCH}(end+1:nmax,:) = 0;
                    CHSTA{idxBSS,idxSTA,idxCH} = CHSTA{idxBSS,idxSTA,idxCH} + rx;
                    
                end
                
            end
        end
    end
end