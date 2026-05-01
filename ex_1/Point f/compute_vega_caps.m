function vega_caps_matrix = compute_vega_caps(flat_vols, ratesSet, ...
                                              spot_vols_matrix, output, ...
                                              spot_vol_parameters)

% COMPUTE_VEGA_CAPS  Bucketed Vega of the two hedge caps (6Y ATM and 10Y ATM)
% with respect to the same triangular vega buckets used in coarse_vega.
%
%   Builds the 2x2 matrix
%       M(j, b) = vega of cap_j  w.r.t.  bucket b
%   where j = 1 for the 6Y cap, j = 2 for the 10Y cap; b = 1 for 0-6y, 2 for 6-10y.
%   This matrix is then inverted to find the cap notionals that hedge the
%   bond's bucketed vega (compute_portfolio_hedged_with_cap).
%
%   ATM strike convention: strike = ATM swap rate of same maturity (mid).
%   The cap j is the sum of caplets 1..(4*T_j - 1) (Strada A numbering).
%
%   Each vega is computed by repricing the cap with the spot-vol matrix
%   already bumped in coarse_vega (output.spot_vols_bump_b1/b2) and
%   subtracting the base-vol price.

    % ATM swap rates for the two cap strikes (mid-market, decimal)
    K_6y  = mean(ratesSet.swaps(6,  :), 2);
    K_10y = mean(ratesSet.swaps(10, :), 2);

    % Caplet count per cap: T_y -> (4 T_y - 1) caplets in the Strada A grid
    n_6y  = 4 * 6  - 1;     % 23
    n_10y = 4 * 10 - 1;     % 39

    strikes = flat_vols.strike(:);

    % Base prices (flat vols, no bump)
    cap_6y_base  = price_cap_at_strike(spot_vols_matrix, strikes, K_6y,  ...
                                       spot_vol_parameters, n_6y);
    cap_10y_base = price_cap_at_strike(spot_vols_matrix, strikes, K_10y, ...
                                       spot_vol_parameters, n_10y);

    % Bumped prices (using spot-vol matrices already produced by coarse_vega)
    cap_6y_b1  = price_cap_at_strike(output.spot_vols_bump_b1, strikes, K_6y,  ...
                                     spot_vol_parameters, n_6y);
    cap_6y_b2  = price_cap_at_strike(output.spot_vols_bump_b2, strikes, K_6y,  ...
                                     spot_vol_parameters, n_6y);
    cap_10y_b1 = price_cap_at_strike(output.spot_vols_bump_b1, strikes, K_10y, ...
                                     spot_vol_parameters, n_10y);
    cap_10y_b2 = price_cap_at_strike(output.spot_vols_bump_b2, strikes, K_10y, ...
                                     spot_vol_parameters, n_10y);

    vega_caps_matrix      = zeros(2, 2);
    vega_caps_matrix(1,1) = cap_6y_b1  - cap_6y_base;     % cap6y, bucket 0-6y
    vega_caps_matrix(1,2) = cap_6y_b2  - cap_6y_base;     % cap6y, bucket 6-10y
    vega_caps_matrix(2,1) = cap_10y_b1 - cap_10y_base;    % cap10y, bucket 0-6y
    vega_caps_matrix(2,2) = cap_10y_b2 - cap_10y_base;    % cap10y, bucket 6-10y
end


function p = price_cap_at_strike(spot_vols_matrix, strikes_grid, K_cap, ...
                                 spot_vol_parameters, n_caplets)
% Sum of the first n_caplets caplets, each priced with its own spot vol
% obtained by spline-on-strike at K_cap on its own row of spot_vols_matrix.

    fwd = spot_vol_parameters.fwd_libor(:);
    yf  = spot_vol_parameters.yf_between_caplets(:);
    T   = spot_vol_parameters.T_expiry(:);
    r   = spot_vol_parameters.r_eff(:);

    sigma_caplets = zeros(n_caplets, 1);
    for k = 1:n_caplets
        sigma_caplets(k) = interp1(strikes_grid, spot_vols_matrix(k, :), ...
                                   K_cap, 'spline');
    end

    caplet_prices = blkprice(fwd(1:n_caplets), K_cap, r(1:n_caplets), ...
                             T(1:n_caplets), sigma_caplets);
    p = sum(yf(1:n_caplets) .* caplet_prices);
end