function coarse = coarse_DV01_triangular(datesSet, ratesSet, flat_vols, ...
                                          strike_grid, ...
                                          notional, start_date, maturity_date_unadj, ...
                                          first_coupon_rate, mode_after_6y, X_base)
% COARSE_DV01_TRIANGULAR - Calculates the coarse-grained (bucketed) DV01 of the structured bond.
%
% This function implements the "Bump and Revalue" method by applying 
% triangular (ramp) shocks to the market yield curve to measure the 
% sensitivity of the bond's Net Present Value (NPV) across three specific time buckets.
%
% INPUTS:
%   datesSet            - [Struct] Market instrument maturities (Depos, Futures, Swaps).
%   ratesSet            - [Struct] Market rate quotes for curve construction.
%   flat_vols           - [Struct] Market flat volatility surface.
%   spot_vols_matrix    - [Matrix] Calibrated caplet spot volatility matrix.
%   strike_grid         - [Vector] Strike grid used for volatility interpolation.
%   notional            - [Scalar] Bond principal amount.
%   start_date          - [Scalar] Contract settlement date (datenum).
%   maturity_date_unadj - [Scalar] Unadjusted maturity date (datenum).
%   first_coupon_rate   - [Scalar] Fixed rate for the first quarterly coupon.
%   mode_after_6y       - [String] Payoff mode for the 6y-10y period ('cap' or 'digital').
%   X_base              - [Scalar] Fair upfront % calculated at current market levels.
%
% OUTPUT:
%   coarse - [Struct] Results containing:
%       .name           - Bucket labels: {'0-2y', '2-6y', '6-10y'}.
%       .DV01           - [3x1 Vector] Sensitivities in EUR for each bucket.
%       .bumped_discs    - [1x3 Cell] Discount factor vectors resulting from each shock.

    DC_ACT365 = 3; % Act/365 Day Count Convention for year fraction calculations.

    % Step 1: Calculate Market Instrument Maturities
    % Determine the time to maturity (in years) for every instrument
    yf_depos   = yearfrac(datesSet.settlement, datesSet.depos,        DC_ACT365);
    yf_futures = yearfrac(datesSet.settlement, datesSet.futures(:,2), DC_ACT365);
    yf_swaps   = yearfrac(datesSet.settlement, datesSet.swaps,        DC_ACT365);

    % Step 2: Generate Triangular Weights for Shocks
    % Build weight matrices that define the intensity of a +1bp shock 
    % along the curve for the 0-2y, 2-6y, and 6-10y buckets.
    W_depos   = triangular_weights_swap(yf_depos);
    W_futures = triangular_weights_swap(yf_futures);
    W_swaps   = triangular_weights_swap(yf_swaps);

    % Step 3: Initialize Output Structure
    coarse.name         = {'0-2y', '2-6y', '6-10y'};
    coarse.DV01         = zeros(3, 1);
    coarse.bumped_discs = cell(3, 1); 

    % Step 4: Bump and Revalue Loop
    for b = 1:3
        % 4.1 Define the shift structure for the current bucket.
        % We apply a +1 basis point shift scaled by the triangular weights.
        shift = struct('depos', W_depos(:, b), 'futures', W_futures(:, b), 'swaps', W_swaps(:, b));

        % 4.2 Re-bootstrap the Curve.
        % Generate new discount factors that reflect the +1bp triangular market shock
        [dates_b, discounts_b, ~] = bootstrap(datesSet, ratesSet, shift);
        
        % 4.3 Update Caplet Parameters.
        params_b = compute_caplets_maturities(flat_vols, dates_b, discounts_b);
        spot_vols_matrix_b = compute_spot_vols_Eur_3m(flat_vols, params_b);

        % 4.4 Re-price the Bond Upfront.
        % Calculate the new upfront X (%) required to maintain a zero NPV under the new rates
        X_b = compute_upfront(notional, spot_vols_matrix_b, strike_grid, params_b, ...
                              dates_b, discounts_b, start_date, maturity_date_unadj, ...
                              first_coupon_rate, mode_after_6y);

        % 4.5 Calculate DV01 in EUR.
        coarse.DV01(b)       = -(X_b - X_base) * notional;
        
        % Store the bumped discount factors for subsequent hedging (Delta NPV matrix) calculations
        coarse.bumped_discs{b} = discounts_b; 
    end
end