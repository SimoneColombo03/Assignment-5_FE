function output = coarse_vega(dates, discounts, flat_vols, notional, ...
                              start_date, maturity_date_unadj, ...
                              first_coupon_rate, mode_after_6y, ...
                              spot_vol_parameters, X_base)

% COARSE_VEGA  Bucketed vega of the structured bond on two coarse buckets
% (0-6y and 6-10y), via triangular shifts of the flat vol surface.
%
%   For each bucket b = 1, 2 we:
%     1) build a triangular weight w_b on the cap maturities;
%     2) bump the flat vol surface by +1bp * w_b (broadcast on all strikes);
%     3) re-strip caplet spot vols and re-price the bond;
%     4) report the MTM change of the swap from Bank XX's side
%
%           coarse_v(b) = -(X_bumped - X_base) * notional.
%
%   The two bumped spot vol matrices are stored in the output struct so
%   that compute_delta_NPV_cap can re-use them (consistent perturbations
%   between bond vega and cap vega are essential for the linear hedge).
%
%   INPUTS:
%   dates, discounts        - bootstrap curve (frozen)
%   flat_vols               - flat vol surface struct
%   notional                - bond notional N
%   start_date, maturity_date_unadj, first_coupon_rate, mode_after_6y
%                           - same parameters as compute_upfront
%   spot_vol_parameters     - caplet stripping grid (frozen)
%   X_base                  - base upfront (decimal)
%
%   OUTPUT struct:
%   .coarse_v               - 2x1 EUR per +1bp in the two buckets
%   .spot_vols_bump_b1/_b2  - [79 x 13] re-stripped surfaces, one per bucket

    bump = 1e-2;                          % +1bp on the flat vols (decimal)
    output    = struct();
    coarse_v  = zeros(2, 1);

    mat_vol = flat_vols.maturity;
    weights = triangular_weights_vega(mat_vol);

    for i = 1:2

        % Bump flat vols by +1bp scaled by the bucket-i triangle.
        % The triangle depends on maturity only -> repmat across strikes.
        flat_vols_bumped         = flat_vols;
        flat_vols_bumped.flatVol = flat_vols.flatVol + ...
            bump * repmat(weights(:, i), 1, size(flat_vols.flatVol, 2));

        % Re-strip caplet spot vols on the bumped surface
        spot_vols_matrix_bumped = compute_spot_vols_Eur_3m( ...
            flat_vols_bumped, spot_vol_parameters);

        % Cache the bumped surface (re-used by compute_delta_NPV_cap)
        if i == 1
            output.spot_vols_bump_b1 = spot_vols_matrix_bumped;
        else
            output.spot_vols_bump_b2 = spot_vols_matrix_bumped;
        end

        % Re-price the bond with the bumped vols (curve unchanged)
        X_bumped = compute_upfront(notional, ...
                                   spot_vols_matrix_bumped, flat_vols.strike(:), ...
                                   spot_vol_parameters, ...
                                   dates, discounts, ...
                                   start_date, maturity_date_unadj, ...
                                   first_coupon_rate, mode_after_6y);

        % MTM change for Bank XX (locked X*N, fair X moves)
        coarse_v(i) = -(X_bumped - X_base) * notional;
    end

    output.coarse_v = coarse_v;
end


function W = triangular_weights_vega(yf)
% TRIANGULAR_WEIGHTS_VEGA  Triangular weights on cap maturities for the
% two vega buckets. Returns an [n x 2] matrix, one column per bucket,
% summing to 1 at every maturity (so that bucket 1 + bucket 2 = parallel).
%
%   Bucket 1 (0-6y) : flat 1 up to 6y, ramps down to 0 between 6y and 10y
%   Bucket 2 (6-10y): ramps up from 0 at 6y to 1 at 10y, flat 1 beyond

    yf = yf(:);
    n  = numel(yf);
    W  = zeros(n, 2);

    % Bucket 1: flat 1 then ramp down to 0 at 10y
    W(:, 1)       = max(0, min(1, (10 - yf) / 4));
    W(yf <= 6, 1) = 1;

    % Bucket 2: ramp up from 6y to 10y, then flat 1
    W(:, 2)        = max(0, min(1, (yf - 6) / 4));
    W(yf >= 10, 2) = 1;
end