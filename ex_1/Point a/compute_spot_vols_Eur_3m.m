function spot_vols_matrix = compute_spot_vols_Eur_3m(flat_vols, spot_vol_parameters)
% COMPUTE_SPOT_VOLS_EUR_3M - Strips caplet spot volatilities for the entire strike grid.
%
% This function transforms a Market Flat Volatility surface into a Spot Volatility 
% matrix. It processes each strike independently, running a bootstrapping 
% procedure to extract the underlying caplet volatilities from quoted Cap prices.
%
% INPUTS:
%   flat_vols           - [Struct] Containing the market surface:
%                           .strike   : Row vector of strikes (Decimal).
%                           .maturity : Column vector of Cap maturities (Years).
%                           .flatVol  : [N x S] Matrix of flat volatilities.
%   spot_vol_parameters - [Struct] Parameters pre-calculated from the discount curve:
%                           .fwd_libor : Forward Euribor 3M rates.
%                           .yf_caplets: Year fractions (Act/360)  between caplets.
%                           .T_expiry  : Time to reset date (Act/365) for each caplet.
%                           .r_eff     : Continuous risk-free rates for discounting.
%
% OUTPUT:
%   spot_vols_matrix    - [M x S] Matrix of caplet spot volatilities.
%                         Rows (M): Quarterly caplets (e.g., 39 caplets for a 10Y bond).
%                         Cols (S): Strikes corresponding to the input surface.

    % 1. Data Extraction and Pre-allocation
    % Ensure strikes and maturities are handled as column vectors for consistent indexing.
    strikes        = flat_vols.strike(:);
    cap_maturities = flat_vols.maturity(:);
    flat_matrix    = flat_vols.flatVol;
    
    % The number of caplets (M) is determined by the length of the forward Libor vector.
    fwd_libor = spot_vol_parameters.fwd_libor;
    n_strikes = numel(strikes);
    M         = numel(fwd_libor);
    
    % Pre-allocate the output matrix.
    spot_vols_matrix = zeros(M, n_strikes);

    % 2. Stripping Loop (Iterate by Strike)
    for k = 1:n_strikes
        % Performs the recursive stripping and linear interpolation for the current 
        % strike column.
        spot_vols_matrix(:, k) = bootstrap_vol( ...
            flat_matrix(:, k), ...      % Flat volatilities for this strike
            strikes(k), ...             % Current strike level
            spot_vol_parameters, ...    % Forward rates and time grids
            cap_maturities);            % Quote maturities
    end
end