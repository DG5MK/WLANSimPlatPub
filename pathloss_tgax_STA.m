%************************************************************************%
% Function to calculate pathloss (dB) of TGAX channel along standard model
% for AP to STA; parameters needed are: 
% model used (A-F), distance, #floors, #walls, att-walls
function [PL] = pathloss_tgax_STA(TXLink,RXLink,RXSTA,all_paths,simulation)

f = simulation.CarrierFrequency;
f_effect = simulation.LargeScaleFadingEffect;
sf_beforedBP = 3;       % shadow fading before breakpoint distance
d = all_paths{TXLink,RXLink,RXSTA}.distance;
n = all_paths{TXLink,RXLink,RXSTA}.floors;
m = all_paths{TXLink,RXLink,RXSTA}.walls;
Liw = 5;                % default wall penetration loss
simumodel = simulation.DelayProfile;

switch simumodel
    
    case 'Model-A'
        dBP = 5;
        sf_afterdBP = 4;
        
    case 'Model-B'
        dBP = 5;
        sf_afterdBP = 4;
        
    case 'Model-C'
        dBP = 5;
        sf_afterdBP = 5;
        
    case 'Model-D'
        dBP = 10;
        sf_afterdBP = 5;
        
    case 'Model-E'
        dBP = 20;
        sf_afterdBP = 6;
        
    case 'Model-F'
        dBP = 30;
        sf_afterdBP = 6;
        
end

% overwrite Liw if manual wall penetration loss given
if ~strcmp(simulation.WallPenetrationLoss,'ax')
    Liw = str2num(simulation.WallPenetrationLoss);
end

PELwall = m * Liw;
PELfloor = 18.3*n^((n+2)/(n+1)-0.46);

switch f_effect
    
    case 'Pathloss'
        if d <= dBP
            Ld = 20*log10(f/1E9)+20*log10(d/1E3)+92.44;
        elseif d > dBP
            Ld = 20*log10(f/1E9)+20*log10(dBP/1E3)+92.44+35*log10(d/dBP);
        end
        PL = Ld + PELfloor + PELwall;

    case 'Shadowing'
        if d <= dBP
            sf = sf_beforedBP;
        elseif d > dBP
            sf = sf_afterdBP;
        end
        PL = sf + PELfloor + PELwall;

    case 'Pathloss and shadowing'
        if d <= dBP
            Ld = 20*log10(f/1E9)+20*log10(d/1E3)+92.44;
            sf = sf_beforedBP;
        elseif d > dBP
            Ld = 20*log10(f/1E9)+20*log10(dBP/1E3)+92.44+35*log10(d/dBP);
            sf = sf_afterdBP;
        end
        PL = Ld + sf + PELfloor + PELwall;

    case 'None'
        PL = 0;
end

end