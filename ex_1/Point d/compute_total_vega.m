function vega = compute_total_vega(dates, discounts, flat_vols, notional, ...
                                   start_date, maturity_date_unadj, ...
                                   first_coupon_rate, mode_after_6y, ...
                                   spot_vol_parameters, X_base)

% COMPUTE_TOTAL_VEGA  Total vega of the structured bond from Bank XX's side.
%
%   Bumps EVERY entry of the flat-vol surface by +1bp (parallel shift on
%   the entire matrix), re-strips caplet spot vols, re-prices the bond and
%   returns the MTM change of the swap from XX's locked-upfront position:
%
%       NPV_XX(bumped) - NPV_XX(base) = -(X_bumped - X_base) * N
%
%   The discount curve (dates, discounts) and spot_vol_parameters are NOT
%   re-bootstrapped: vega is the pure vol sensitivity, the rate sensitivity
%   is captured separately by compute_DV01_buckets.
%
%   INPUTS:
%   dates, discounts        - bootstrap curve (frozen)
%   flat_vols               - flat-vol surface struct
%   notional                - notional N
%   start_date, maturity_date_unadj, first_coupon_rate, mode_after_6y
%                           - same parameters as compute_upfront
%   spot_vol_parameters     - caplet grid (frozen, since dates+discounts are frozen)
%   X_base                  - base upfront (decimal fraction of N)
%
%   OUTPUT:
%   vega                    - EUR per +1bp parallel shift on the flat-vol
%                             surface (signed; negative if Bank XX is short vol)

    BUMP = 1e-2;     % +1bp on the flat vol surface (decimal)

    % Bump the entire flat-vol matrix; copy the rest of the struct as-is
    flat_vols_bumped         = flat_vols;
    flat_vols_bumped.flatVol = flat_vols.flatVol + BUMP;

    % Re-strip caplet spot vols on the bumped surface
    spot_vols_matrix_bumped = compute_spot_vols_Eur_3m( ...
        flat_vols_bumped, spot_vol_parameters);

    % Re-price the bond with the bumped vols (curve unchanged)
    X_bumped = compute_upfront(notional, ...
                               spot_vols_matrix_bumped, flat_vols.strike(:), ...
                               spot_vol_parameters, ...
                               dates, discounts, ...
                               start_date, maturity_date_unadj, ...
                               first_coupon_rate, mode_after_6y);

    % MTM change for Bank XX (locked X*N, fair X moves)
    vega = -(X_bumped - X_base) * notional;
end