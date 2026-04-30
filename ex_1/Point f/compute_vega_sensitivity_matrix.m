function vega_matrix = compute_vega_sensitivity_matrix(flat_vols, ratesSet, spot_vols_base, output_vega, dates, discounts)
% COMPUTE_VEGA_SENSITIVITY_MATRIX - Builds the 2x2 Vega sensitivity matrix for Caps.
%
% This function calculates the change in Net Present Value (NPV) for the 6y and 10y 
% Caps when subject to specific volatility bucket shocks (0-6y and 6-10y).
%
% INPUTS:
%   flat_vols      - [Struct] Market flat volatility data and strikes.
%   ratesSet       - [Struct] Market rates used to define ATM strikes
%   spot_vols_base - [Matrix] The initial calibrated spot volatility matrix
%   output_vega    - [Struct] Contains bumped spot matrices
%   dates/discounts- [Vectors] Dates and discounts from bootsrap
%
% OUTPUT:
%   vega_matrix    - [2x2 Matrix] 
%                    Rows: Volatility Buckets (1=0-6y, 2=6-10y)
%                    Cols: Hedging Instruments (1=Cap 6y, 2=Cap 10y)

    % Step 1: Market Setup & ATM Strike Definition
    % We use the 6y and 10y Swap rates as the ATM strikes for hedging Caps
    strike_6y  = ratesSet.swaps(6); 
    strike_10y = ratesSet.swaps(10);
    
    % Pre-calculate caplet market parameters
    caplet_params = compute_caplets_maturities(flat_vols, dates, discounts);
    strike_grid   = flat_vols.strike;

    % Step 2: Calculate Baseline Prices
    % These represent the Cap prices under current market volatility
    p_base_6y  = calculate_cap_price(spot_vols_base, strike_6y, caplet_params, 6, strike_grid);
    p_base_10y = calculate_cap_price(spot_vols_base, strike_10y, caplet_params, 10, strike_grid);

    % Step 3: Sensitivity of Cap 6y (Column 1)
    % Calculate prices after bumping Bucket 1 (0-6y) and Bucket 2 (6-10y)
    p_bump_6y_B1 = calculate_cap_price(output_vega.bumped_spot_vols{1}, strike_6y, caplet_params, 6, strike_grid);
    p_bump_6y_B2 = calculate_cap_price(output_vega.bumped_spot_vols{2}, strike_6y, caplet_params, 6, strike_grid);
    
    % The 6y Cap should have near-zero sensitivity to the 6-10y bucket
    vega_matrix(1, 1) = p_bump_6y_B1 - p_base_6y; % Sensitivity to 0-6y
    vega_matrix(2, 1) = p_bump_6y_B2 - p_base_6y; % Sensitivity to 6-10y (~0)

    % Step 4: Sensitivity of Cap 10y (Column 2)
    % Calculate prices for the 10y Cap under both bumped scenarios
    p_bump_10y_B1 = calculate_cap_price(output_vega.bumped_spot_vols{1}, strike_10y, caplet_params, 10, strike_grid);
    p_bump_10y_B2 = calculate_cap_price(output_vega.bumped_spot_vols{2}, strike_10y, caplet_params, 10, strike_grid);
    
    % The 10y Cap is sensitive to both buckets as it covers the full 0-10y range
    vega_matrix(1, 2) = p_bump_10y_B1 - p_base_10y; % Sensitivity to 0-6y
    vega_matrix(2, 2) = p_bump_10y_B2 - p_base_10y; % Sensitivity to 6-10y (>0)
end