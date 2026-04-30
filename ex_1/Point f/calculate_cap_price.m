function cap_price = calculate_cap_price(spot_vol_matrix, target_strike, params, maturity_limit, strike_grid)
% CALCULATE_CAP_PRICE Prices a Cap using a spot volatility matrix.
%

% INPUTS:
%   spot_vol_matrix  - [Matrix] Calibrated spot volatilities (Time rows x Strike columns)
%   target_strike    - [Scalar] Fixed strike price of the Cap
%   params           - [Struct] Contains caplet details
%   maturity_limit   - [Scalar] Maturity in years
%   strike_grid      - [Vector] The strike values corresponding to spot_vol_matrix columns
%
% OUTPUT:
%  cap_price         - [Scalar] Price of the Cap

    % Step 1: Filter Caplets
    % We only consider caplets for which the reset dates are up to the maturity_limit
    % A small tolerance (1e-5) is added to avoid floating-point issues with 'find'
    valid_idx = find(params.T_expiry <= maturity_limit + 1e-5);
    
    % Step 2: Extract Relevant Caplets Data
    % These vectors will have a length equal to the number of caplets
    F = params.fwd_libor(valid_idx);        % Forward Libor rates
    D = params.r_eff(valid_idx);            % Zero-Rates
    T = params.T_expiry(valid_idx);         % year fractions corrisponding to the reset dates for the filtered caplets
    tau = params.yf_between_caplets(valid_idx); % Year fractions between caplets
    
    % Step 3: Volatility Interpolation
    % We interpolate for the target_strike across ALL rows of the spot_vol_matrix simultaneously.
    % 'spline' ensures a smooth volatility smile interpolation
    all_sigmas = interp1(strike_grid, spot_vol_matrix(valid_idx, :).', target_strike, 'spline').';

    % Step 4: Black's Formula Calculation for caplets 
    caplet_prices = blkprice(F, target_strike, D, T, all_sigmas);
    
    % Step 5: Total Price
    cap_price = sum(tau .* caplet_prices);
end