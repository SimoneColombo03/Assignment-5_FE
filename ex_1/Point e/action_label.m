function s = action_label(x)
% Returns a human-readable buy/sell tag for a hedge notional.
    if x > 0
        s = 'long / buy';
    elseif x < 0
        s = 'short / sell';
    else
        s = 'no position';
    end
end