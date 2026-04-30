function output_vega = compute_st_bond_coarse_vega(market_dates, discount_factors, flat_vol_data, ...
                                               bond_notional, start_date, maturity_date, ...
                                               initial_fixed_rate, payoff_mode, ...
                                               calibration_params, base_upfront_pct)
% COMPUTE_BOND_COARSE_VEGA - Calculates the Structured Bond's Vega for aggregated buckets
%
% This function implements the "Bump and Revalue" method for volatility risk.
% It applies a triangular (ramp) shift to the flat volatility surface and 
% re-prices the structured bond to measure the MTM change
%
% INPUTS:
%   market_dates        - [Struct] Maturity dates for curve construction
%   discount_factors    - [Vector] Discount factors from the bootstrap curve
%   flat_vol_data       - [Struct] Market cap volatility data and strikes
%   bond_notional       - [Scalar] Principal amount
%   start_date          - [Scalar] Start date of the contract
%   maturity_date       - [Scalar] Maturity date of the contract
%   initial_fixed_rate  - [Scalar] First quarterly coupon
%   payoff_mode         - [String] For 6y+ period ('cap'/'digital')
%   calibration_params  - [Struct] Parameters for LMM spot vol stripping
%   base_upfront_pct    - [Scalar] The fair upfront X% calculated at base market levels
% OUTPUTS:
%   output_vega         - [Struct] Contains:
%       .coarse_v            - [2x1 Vector] Vega in EUR for Bucket 1 and Bucket 2
%       .bumped_spot_vols    - [1x2 Cell] Re-calibrated spot volatility matrices

    % Configuration 
    vol_bump_size = 1e-2; % 1% shift
    num_buckets = 2;
    
    % Initialize output structure with pre-allocated storage
    output_vega = struct();
    output_vega.coarse_v = zeros(num_buckets, 1);
    output_vega.bumped_spot_vols = cell(1, num_buckets); 

    % Compute the triangular weights for the two buckets (0-6y and 6-10y)
    % W(:,1) = Bucket 1 (0-6y), W(:,2) = Bucket 2 (6-10y)
    bucket_weights = triangular_weights_vega(flat_vol_data.maturity);

    % Bump and Revalue Loop
    for b = 1:num_buckets
        
        % 1. Apply the triangular bump to the Flat Volatility surface
        bumped_flat_vols = flat_vol_data;
        % repmat is used to apply the same ramp weight across all strikes for each maturity
        bumped_flat_vols.flatVol = flat_vol_data.flatVol + ...
            vol_bump_size * repmat(bucket_weights(:, b), 1, size(flat_vol_data.flatVol, 2));
       
        % 2. Re-calibrate (re-strip) the Caplet Spot Volatilities on the bumped surface
        spot_vols_bumped = compute_spot_vols_Eur_3m(bumped_flat_vols, calibration_params);
        
        % Store the bumped matrix for later use in hedging calculations
        output_vega.bumped_spot_vols{b} = spot_vols_bumped;
        
        % 3. Re-price the structured bond with bumped volatilities
        upfront_bumped = compute_upfront(bond_notional, ...
                                         spot_vols_bumped, flat_vol_data.strike(:), ...
                                         calibration_params, ...
                                         market_dates, discount_factors, ...
                                         start_date, maturity_date, ...
                                         initial_fixed_rate, payoff_mode);
        
        % 4. Calculate the Vega in EUR
        % Formula: -(X_bumped - X_base) * Notional
        % This represents the MTM change for Bank XX (payer of the upfront)
        output_vega.coarse_v(b) = -(upfront_bumped - base_upfront_pct) * bond_notional;
    end
end
