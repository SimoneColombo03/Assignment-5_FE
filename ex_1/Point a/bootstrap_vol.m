function spot_vols = bootstrap_vol(flat_vols_at_strike, strike, spot_vol_parameters, cap_maturities)
% BOOTSTRAP_VOL - Strips caplet volatilities for a single strike
%
% This function implements a recursive bootstrapping algorithm. It assumes that 
% caplet volatility is piecewise linear between cap maturity pillars.
%
% METHODOLOGY:
%   1. Calculate the target market prices for each Cap maturity using Black's formula.
%   2. For the first pillar (up to 1Y), assume spot vol = flat vol.
%   3. For subsequent pillars, use a 1D root finder (fzero) to solve for the 
%      spot vol at the pillar date such that the sum of caplet prices in that 
%      segment matches the incremental market price.
%
% INPUTS:
%   flat_vols_at_strike - [Vector] Column of flat vols for a specific strike.
%   strike              - [Scalar] The strike price in decimal.
%   spot_vol_parameters - [Struct] Timeline and rate data:
%                           .fwd_libor  : Forward rates.
%                           .yf_between_caplets : Act/360 year fractions.
%                           .T_expiry   : Reset times (Act/365).
%                           .r_eff      : Continuous discount rates.
%   cap_maturities      - [Vector] Pillar years
%
% OUTPUT:
%   spot_vols           - [M x 1 Vector] Stripped spot volatilities for each 
%                         individual quarterly caplet.

    % Extract parameters from struct for local use
    fwd_libor = spot_vol_parameters.fwd_libor(:);
    yf_caplets = spot_vol_parameters.yf_between_caplets(:);
    T_expiry = spot_vol_parameters.T_expiry(:);
    r_eff = spot_vol_parameters.r_eff(:);
    
    n_caplets = numel(fwd_libor);
    n_caps    = numel(cap_maturities);
    spot_vols = zeros(n_caplets, 1);

    % Map Cap years to the index of the last Caplet included in that Cap.
    % E.g., for quarterly resets, a 1Y Cap ends at Caplet 3 (the first is deterministic).
    last_caplet_idx = round(4 * cap_maturities) - 1;
    last_caplet_idx = last_caplet_idx(:);

    % Step 1: Initialize 1Y Pillar
    spot_vols(1:last_caplet_idx(1)) = flat_vols_at_strike(1);

    % Step 2: Compute Market Prices
    cap_market_price = zeros(n_caps, 1);
    for i = 1:n_caps
        idx = 1:last_caplet_idx(i);
        caplet_prices = blkprice(fwd_libor(idx), strike, r_eff(idx), ...
                                 T_expiry(idx), flat_vols_at_strike(i));
        cap_market_price(i) = sum(yf_caplets(idx) .* caplet_prices);
    end

    % Step 3: Recursive Calibration
    for i = 2:n_caps
        idx_left  = last_caplet_idx(i-1);         % Pillar i-1 (vol already known)
        idx_right = last_caplet_idx(i);           % Pillar i   (vol to find)
        idx_to_calibrate = (idx_left+1):idx_right;
        
        sigma_left = spot_vols(idx_left);
        T_knots    = [T_expiry(idx_left); T_expiry(idx_right)];
        T_to_interp = T_expiry(idx_to_calibrate);
        
        % The target is the difference in price between Cap(i) and Cap(i-1).
        target_price_diff = cap_market_price(i) - cap_market_price(i-1);
        
        % Residual function for fzero: finds sigma_right such that 
        % sum(caplet_prices) - target_diff = 0.
        residual = @(sigma_right) ...
            cap_increment_price(sigma_right, sigma_left, T_knots, T_to_interp, ...
                                fwd_libor(idx_to_calibrate), strike, r_eff(idx_to_calibrate), ...
                                T_expiry(idx_to_calibrate), yf_caplets(idx_to_calibrate)) ...
            - target_price_diff;
        
        % Search for the root starting from the current flat vol.
        sigma_right = fzero(residual, flat_vols_at_strike(i));
        
        % Populate the spot_vols vector using linear interpolation across
        % the segment (they are already on a line because of
        % cap_increment_price, we just store them in a vector:
        spot_vols(idx_to_calibrate) = interp1(T_knots, [sigma_left; sigma_right], ...
                                      T_to_interp, 'linear');
    end
end