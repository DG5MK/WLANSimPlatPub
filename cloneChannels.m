% function to clone set of TGax channels to have same state availbale for
% other iterations
function tgaxClone = cloneChannels(tgax)
% Clone the channels before running to ensure the same realization can be
% used in the next simulation
    tgaxClone = cell(size(tgax));
    numUsers = numel(tgax);
    for i=1:numUsers
        tgaxClone{i} = clone(tgax{i});
    end
end