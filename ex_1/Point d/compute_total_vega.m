function vega = compute_total_vega(dates, discounts, flat_vols, notional, ...
                                   start_date, maturity_date_unadj, ...
                                   first_coupon_rate, mode_after_6y, ...
                                   spot_vol_parameters, X_base)
% COMPUTE_TOTAL_VEGA - Calculates the total portfolio Vega (volatility sensitivity).
%
% This function measures the sensitivity of the structured bond's Net Present Value (NPV)
% to a parallel shift in the market volatility surface. It follows the "Bump and Revalue"
% approach.
%
% METHODOLOGY:
%   1. Applies a +1% (100bps) parallel bump to the entire flat volatility matrix.
%   2. Re-strips the caplet spot volatilities from the bumped surface.
%   3. Re-compute the bond upfront (X_bumped) using the original discount curve.
%   4. Calculates the change in MTM from the Bank's perspective.
%
% INPUTS:
%   dates/discounts     - [Vector] Baseline dates/discount curve.
%   flat_vols           - [Struct] Baseline market flat volatility surface.
%   notional            - [Scalar] Structured Bond principal amount.
%   start_date          - [Scalar] Settlement date (datenum).
%   maturity_date_unadj - [Scalar] Unadjusted maturity date.
%   first_coupon_rate   - [Scalar] Fixed rate for the first coupon.
%   mode_after_6y       - [String] Payoff logic ('cap' or 'digital').
%   spot_vol_parameters - [Struct] Frozen caplet grid parameters.
%   X_base              - [Scalar] Baseline fair upfront (as a decimal of N).
%
% OUTPUT:
%   vega - [Scalar] Sensitivity in EUR per +1% shift in volatility.
%
    % Define the Volatility Bump: +1% absolute
    BUMP = 1e-2;     

    % Step 1: Bump the Volatility Surface
    % We copy the structure and apply a parallel shift to the entire flatVol matrix.
    flat_vols_bumped         = flat_vols;
    flat_vols_bumped.flatVol = flat_vols.flatVol + BUMP;

    % Step 2: Re-strip Caplet Volatilities
    % Since the volatility surface changed, we must re-run the stripping 
    % algorithm to get the new spot volatilities for each caplet.
    spot_vols_matrix_bumped = compute_spot_vols_Eur_3m( ...
        flat_vols_bumped, spot_vol_parameters);

    % Step 3: Re-compute the Bond Upfront
    % We calculate the new upfront (X_bumped). We reuse the discount 
    % curve and parameters to isolate the volatility effect.
    X_bumped = compute_upfront(notional, ...
                               spot_vols_matrix_bumped, flat_vols.strike(:), ...
                               spot_vol_parameters, ...
                               dates, discounts, ...
                               start_date, maturity_date_unadj, ...
                               first_coupon_rate, mode_after_6y);

    % Step 4: Calculate MTM Change (Vega)
    vega = -(X_bumped - X_base) * notional;

end