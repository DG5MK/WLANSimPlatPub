% **********************************************************************************************************************
% function to map SNR/dB to MCS and rate/Mb/s
function [MCS,R,LB] = SNR2RMCS(actSNR,simulation)

%     if actSNR < simulation.REQSNR(1)
    if actSNR <= 0

        MCS = 0;
        R = 0;
        LB = 0;

    else

        idxmax = length(simulation.MCS);
        idx = 1;
        SNRtest = 0;
        flagexit = 0;

        while flagexit == 0
            if idx > idxmax
                flagexit = 1;
            else
                SNRtest = simulation.REQSNR(idx);
                if actSNR < SNRtest
                    flagexit = 1;
                else
                    idx = idx + 1;
                end
            end
        end

        if idx == 1
            idx = 2;
        end

        MCS = idx - 2;
        R = simulation.RUSER(idx-1);
        LB = simulation.REQSNR(idx-1);
    end

end