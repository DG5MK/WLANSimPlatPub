%************************************************************************%
% Function to calculate eta power law pathloss (dB)
% for STA to STA; parameters needed are: 
% distance, #floors, #walls, att-walls, att-floors, etas and breakpoint distance
function [PL] = pathloss_etaPL_STA_STA(TXLink,TXSTA,RXLink,RXSTA,all_paths,simulation)

    f = simulation.CarrierFrequency;
    d = all_paths{TXLink,TXSTA,RXLink,RXSTA}.distance;
    n = all_paths{TXLink,TXSTA,RXLink,RXSTA}.floors;
    m = all_paths{TXLink,TXSTA,RXLink,RXSTA}.walls;
    c = physconst('LightSpeed');

    dBP =  simulation.BPDistance;
    eta_bBP =  simulation.etaBeforeBPDistance;
    eta_aBP =  simulation.etaAfterBPDistance;
    Liw = simulation.WallPenetrationLossEta;
    Lif = simulation.FloorPenetrationLossEta;

    PELwall = m * Liw;
    PELfloor = n * Lif;
    
    if d <= dBP
        Ld = 10*log10( ((4*pi*d*f)/c)^eta_bBP );
    elseif d > dBP
        Ld = 10*log10( ((4*pi*dBP*f)/c)^eta_bBP ) + eta_aBP*10*log10(d/dBP);
    end

    PL = Ld + PELfloor + PELwall;

end