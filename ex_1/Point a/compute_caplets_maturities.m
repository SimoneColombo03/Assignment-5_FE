function output = compute_caplets_maturities(flat_vols, dates_bootstrap, discounts)
% COMPUTE_CAPLETS_MATURITIES - Builds the time grid and rate parameters for Caplets.
%
% This function constructs the quarterly timeline for Euribor 3M caplets up 
% to the maximum maturity specified in the volatility surface. It extracts 
% forward rates and discount factors needed for the spot volatility stripping.
%
%
% INPUTS:
%   flat_vols       - [Struct] Market data struct containing:
%                       .valuationDate : Base date of the surface.
%                       .maturity      : Vector of cap maturities.
%   dates_bootstrap - [Vector] Date grid of the baseline discount curve.
%   discounts       - [Vector] Discount factors of the baseline curve.
%
% OUTPUT:
%   output          - [Struct] Contains vectors of length M (M = 4*max_years - 1):
%                       .payment_dates      : Caplet payment dates (datenum).
%                       .T_expiry           : Act/365 time to fixing.
%                       .fwd_libor          : Forward Euribor 3M rates.
%                       .yf_between_caplets : Act/360 year fractions between caplets.
%                       .df_caplets         : Discount factors at payment dates.
%                       .r_eff              : Continuous discount rates.

    % Standard Day Count Conventions
    DC_ACT360 = 2; % Act/365
    DC_ACT365 = 3; % Act/360

    % 1. Define the valuation date
    t0    = business_date_offset(flat_vols.valuationDate, 'day_offset', 2);
    t0_dt = datetime(t0, 'ConvertFrom', 'datenum');

    % 2. Build the Quarterly Unadjusted Grid 
    max_years  = flat_vols.maturity(end);
    n_quarters = 4 * max_years;
    % Generate a sequence of dates every 3 months.
    unadj      = t0_dt + calmonths(3 * (1:n_quarters)');
    
    % 3. Apply Business Day Convention
    grid_dates = zeros(n_quarters, 1);
    for i = 1:n_quarters
        % 'Modified Following': Move to the next business day, unless it crosses 
        % into the next month, in which case move backward.
        grid_dates(i) = business_date_offset(datenum(unadj(i)), ...
            'convention', 'modified_following');
    end

    % 4. Interpolate Discount Curve onto the Grid 
    % Get the precise discount factor for every date in our quarterly grid.
    df_grid = get_discount_factor_by_zero_rates_linear_interp( ...
                  t0, grid_dates, dates_bootstrap, discounts);

    % -5. Shift Grid for Caplet Definitions
    % Caplet i fixes at t_i and pays at t_{i+1}. 
    % We drop t_0 from the fixing dates because the first Libor is deterministic.
    reset_dates           = grid_dates(1:end-1);
    caplets_payment_dates = grid_dates(2:end);
    df_reset              = df_grid(1:end-1);
    df_caplets            = df_grid(2:end);

    % 6. Compute Financial Parameters
    % Year fraction for the accrual period (delta) using Act/360.
    yf_caplets = yearfrac(reset_dates, caplets_payment_dates, DC_ACT360);
    
    % Forward Libor Rate calculation
    fwd_libor  = (df_reset ./ df_caplets - 1) ./ yf_caplets;
    
    % Option Expiry Time (Act/365) from today (t_0) to the reset date.
    T_expiry   = yearfrac(t0, reset_dates, DC_ACT365);
    
    % Continuous risk-free rate
    r_eff = -log(df_caplets) ./ T_expiry; 

    % 7. Package Output
    output = struct('payment_dates', caplets_payment_dates, ...
                    'T_expiry', T_expiry, ...
                    'fwd_libor', fwd_libor, ...
                    'yf_between_caplets', yf_caplets, ...
                    'df_caplets', df_caplets, ...
                    'r_eff', r_eff);
end