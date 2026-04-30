function spot_vols = bootstrap_vol(flat_vols_at_strike, strike, spot_vol_parameters,cap_maturities)

% BOOTSTRAP_VOL  Strip caplet (spot) volatilities from flat cap volatilities
% at a single strike, assuming caplet vol is piecewise linear in T_expiry
% with break-points at the cap maturities.
%
%   Numbering convention (consistent with compute_caplets_maturities):
%   the first deterministic Libor is already excluded upstream, so the i-th
%   caplet (i = 1, ..., M) fixes at t_i and pays at t_{i+1}. With quarterly
%   resets, cap T_y contains caplets 1..(4*T_y - 1).
%
%   On the first cap (1Y) the spot vol is taken constant and equal to its
%   flat vol. On every later cap, the new spot vol at the right-end of the
%   bucket is found by a 1-D root search: the difference of cap market
%   prices must equal the sum of the new caplet prices, computed with vols
%   linearly interpolated (in T_expiry) between the previous bucket's
%   right-end vol (known) and the unknown one.
%
%   INPUTS:
%   flat_vols_at_strike - column of flat cap vols at the given strike,
%                         length numel(cap_maturities)
%   strike              - cap/caplet strike (decimal)
%   fwd_libor           - column of forward Libor (length M)
%   yf_caplets          - column of Act/360 year fractions delta_i (length M)
%   T_expiry            - column of Act/365 reset times (length M)
%   r_eff               - column of effective continuous rates (length M)
%   cap_maturities      - column of cap maturities in years (e.g. [1;2;...;10])
%
%   OUTPUT:
%   spot_vols           - column of caplet spot vols (length M)

    fwd_libor = spot_vol_parameters.fwd_libor(:);
    yf_caplets = spot_vol_parameters.yf_between_caplets(:);
    T_expiry = spot_vol_parameters.T_expiry(:);
    r_eff = spot_vol_parameters.r_eff(:);
    
    n_caplets = numel(fwd_libor);
    n_caps    = numel(cap_maturities);
    spot_vols = zeros(n_caplets, 1);

    % Index of the last caplet belonging to cap T_y:
    %   1Y -> caplets 1..3, 2Y -> 1..7, ..., T_y -> 1..(4*T_y - 1)
    last_caplet_idx = round(4 * cap_maturities) - 1;
    last_caplet_idx = last_caplet_idx(:);

    % --- 1Y cap: flat assumption -------------------------------------------
    spot_vols(1:last_caplet_idx(1)) = flat_vols_at_strike(1);

    % --- Pre-compute cap market prices at flat vol -------------------------
    cap_market_price = zeros(n_caps, 1);
    for i = 1:n_caps
        idx           = 1:last_caplet_idx(i);
        caplet_prices = blkprice( fwd_libor(idx), strike, r_eff(idx), ...
                                  T_expiry(idx), flat_vols_at_strike(i) );
        cap_market_price(i) = sum( yf_caplets(idx) .* caplet_prices );
    end

    % --- Stripping loop on subsequent cap maturities -----------------------
    for i = 2:n_caps

        idx_left  = last_caplet_idx(i-1);          % bucket left end (vol known)
        idx_right = last_caplet_idx(i);            % bucket right end (vol unknown)
        idx_to_calibrate = (idx_left+1):idx_right;% caplets to be calibrated

        sigma_left = spot_vols(idx_left);
        T_left     = T_expiry(idx_left);
        T_right    = T_expiry(idx_right);

        T_knots     = [T_left; T_right];
        T_to_interp = T_expiry(idx_to_calibrate);

        target_price_diff = cap_market_price(i) - cap_market_price(i-1);

        residual = @(sigma_right) ...
            cap_increment_price(sigma_right, sigma_left, T_knots, T_to_interp, ...
                                fwd_libor(idx_to_calibrate), strike, r_eff(idx_to_calibrate), ...
                                T_expiry(idx_to_calibrate), yf_caplets(idx_to_calibrate)) ...
            - target_price_diff;

        sigma_right = fzero( residual, flat_vols_at_strike(i));
        
        
        spot_vols(idx_to_calibrate) = interp1( T_knots, [sigma_left; sigma_right], ...
                                      T_to_interp, 'linear' );
    end
end


function p = cap_increment_price(sigma_right, sigma_left, T_knots, T_to_interp, ...
                                 fwd, K, r, T, yf)
% Sum of caplet prices on the new bucket, with vol linearly interpolated
% between (T_left, sigma_left) and (T_right, sigma_right).
    sigma_caplets = interp1( T_knots, [sigma_left; sigma_right], ...
                             T_to_interp, 'linear' );
    caplet_prices = blkprice(fwd, K, r, T, sigma_caplets );
    p = sum( yf .* caplet_prices );
end