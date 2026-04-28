function [caplets_dates, fwd_libor, yf_caplets, df_caplets, T_expiry, r_eff] = ...
    compute_caplets_maturities(flat_vols, dates_bootstrap, discounts)

% COMPUTE_CAPLETS_MATURITIES  Build the quarterly Euribor 3m caplet grid
% used for cap (flat-vol) -> caplet (spot-vol) stripping.
%
%   The first deterministic Libor is excluded: the i-th caplet (i = 1..M)
%   fixes at t_i and pays at t_{i+1}, with t_0 = valuationDate + 2BD.
%   All output vectors have length M = 4*maxY - 1.

    DC_ACT360 = 2;
    DC_ACT365 = 3;

    % Settlement t_0 = valuationDate + 2BD
    t0    = business_date_offset(flat_vols.valuationDate, 'day_offset', 2);
    t0_dt = datetime(t0, 'ConvertFrom', 'datenum');

    % Quarterly grid t_1..t_N (modified following)
    max_years  = flat_vols.maturity(end);
    n_quarters = 4 * max_years;
    unadj      = t0_dt + calmonths(3 * (1:n_quarters)');
    grid_dates = zeros(n_quarters, 1);
    for i = 1:n_quarters
        grid_dates(i) = business_date_offset(datenum(unadj(i)), ...
            'convention', 'modified_following');
    end

    % Discount factors at every grid date (length N)
    df_grid = get_discount_factor_by_zero_rates_linear_interp( ...
                  t0, grid_dates, dates_bootstrap, discounts);

    % Caplet i fixes at t_i and pays at t_{i+1}  (i = 1..N-1)
    reset_dates   = grid_dates(1:end-1);
    caplets_dates = grid_dates(2:end);

    df_reset   = df_grid(1:end-1);
    df_caplets = df_grid(2:end);

    yf_caplets = yearfrac(reset_dates, caplets_dates, DC_ACT360);
    fwd_libor  = (df_reset ./ df_caplets - 1) ./ yf_caplets;
    T_expiry   = yearfrac(t0, reset_dates, DC_ACT365);

    r_eff      = nan(size(T_expiry));
    pos        = T_expiry > 0;
    r_eff(pos) = -log(df_caplets(pos)) ./ T_expiry(pos);

end