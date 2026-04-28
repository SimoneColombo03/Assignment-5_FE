function [upfront,pv_A,pv_B] = compute_upfront(notional, ...
                                   spot_vols_matrix, strike_grid, ...
                                   fwd_libor, yf_caplets, T_expiry, df_caplets, ...
                                   dates_bootstrap, discounts, ...
                                   start_date, maturity_date, ...
                                   first_coupon_rate, mode_after_6y)

% COMPUTE_UPFRONT  Compute the upfront X (as a fraction of notional) of the
% 10Y structured bond, by imposing zero NPV on the swap:
%
%       X * N + sum( PV(coupon_B) ) = PV(Party A floating + spread)
%
%   Party A pays Euribor 3m + 2.00% (quarterly).
%   Party B pays:
%       Q1               -> first_coupon_rate (fixed, e.g. 4%)
%       Q2..3Y  (k<=12)  -> L + 1.00% if L<=4.20%, else 4.50%
%       3Y..6Y  (k<=24)  -> L + 1.20% if L<=4.70%, else 4.90%
%       6Y..end (k> 24)  -> see compute_price_coupon_after_6y
%
%   Coupon Q_k (k >= 2) uses the i = k-1 caplet of the stripping grid.
%
%   INPUTS:
%   notional             - notional N
%   spot_vols_matrix     - [M x n_strikes] stripped caplet spot vols
%   strike_grid          - [n_strikes x 1] strikes used in stripping
%   fwd_libor, yf_caplets, T_expiry, df_caplets - stripping grid (length M)
%   dates_bootstrap, discounts - bootstrap curve
%   start_date           - swap Start Date (datenum)
%   maturity_date        - swap Maturity Date (datenum)
%   first_coupon_rate    - first quarter Party B coupon
%   mode_after_6y        - 'cap' or 'digital'
%
%   OUTPUT:
%   upfront              - X (decimal, fraction of N)

    if nargin < 13 || isempty(mode_after_6y)
        mode_after_6y = 'cap';
    end

    n_total_q = 40;        % 10y * 4 quarterly coupons

    % --- Sub-period strikes for spline-on-strike vol pickup ----------------
    K1 = 0.0420;
    K2 = 0.0470;
    if strcmpi(mode_after_6y, 'cap')
        K3 = 0.0400;       % 5.10% - 1.10%
    else
        K3 = 0.0540;
    end

    % Spline interpolation on strike, one row per caplet
    M_use = n_total_q - 1;     % caplets used by Q2..Q40 -> i=1..39
    sigma_K1 = arrayfun(@(k) interp1(strike_grid, spot_vols_matrix(k,:), K1, 'spline'), (1:M_use)');
    sigma_K2 = arrayfun(@(k) interp1(strike_grid, spot_vols_matrix(k,:), K2, 'spline'), (1:M_use)');
    sigma_K3 = arrayfun(@(k) interp1(strike_grid, spot_vols_matrix(k,:), K3, 'spline'), (1:M_use)');

    q_3y = 12;
    q_6y = 24;

    % ---------------------------------------------------------------------
    % PV of Party B leg
    % ---------------------------------------------------------------------
    % Q1 (FIXED): pays first_coupon_rate * delta_1 * N at t_1.
    % We need B(t_0, t_1) and yf(t_0, t_1) which are NOT in the stripping
    % grid (the first deterministic Libor was excluded). We retrieve them
    % from the bootstrap curve directly.
    DC_ACT360 = 2;
    t1 = business_date_offset(start_date, 'month_offset', 3, ...
                              'convention', 'modified_following');
    df_t1   = get_discount_factor_by_zero_rates_linear_interp( ...
                  start_date, t1, dates_bootstrap, discounts);
    yf_t0t1 = yearfrac(start_date, t1, DC_ACT360);

    pv_B = notional * yf_t0t1 * df_t1 * first_coupon_rate;

    for k = 2:n_total_q
        i = k - 1;     % caplet index on the stripping grid

        if k <= q_3y
            pv_coup = compute_price_coupon_up_to_3years( ...
                fwd_libor(i), sigma_K1(i), sigma_K1(i), ...
                df_caplets(i), T_expiry(i), yf_caplets(i));

        elseif k <= q_6y
            pv_coup = compute_price_coupon_3y_to_6y( ...
                fwd_libor(i), sigma_K2(i), sigma_K2(i), ...
                df_caplets(i), T_expiry(i), yf_caplets(i));

        else
            pv_coup = compute_price_coupon_after_6y( ...
                fwd_libor(i), sigma_K3(i), sigma_K3(i), ...
                df_caplets(i), T_expiry(i), yf_caplets(i), mode_after_6y);
        end

        pv_B = pv_B + notional * pv_coup;
    end

    % ---------------------------------------------------------------------
    % PV of Party A leg (Euribor 3m + 2%)
    % ---------------------------------------------------------------------
    %   PV(Eur3m floater) = N * [B(t_0, start) - B(t_0, maturity)]
    %   PV(2% spread)     = N * 0.02 * BPV
    BPV = BasisPointValueFloating(start_date, maturity_date, ...
                                   dates_bootstrap, discounts);

    B_start    = get_discount_factor_by_zero_rates_linear_interp( ...
                     dates_bootstrap(1), start_date, dates_bootstrap, discounts);
    B_maturity = get_discount_factor_by_zero_rates_linear_interp( ...
                     dates_bootstrap(1), maturity_date, dates_bootstrap, discounts);

    pv_A = notional * (B_start - B_maturity) + notional * 0.02 * BPV;

    % --- Upfront ----------------------------------------------------------
    upfront = (pv_A - pv_B) / notional;
end