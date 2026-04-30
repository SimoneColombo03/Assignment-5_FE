function upfront = compute_upfront(notional, ...
                                   spot_vols_matrix, strike_grid, ...
                                   spot_vol_parameters,...
                                   dates_bootstrap, discounts, ...
                                   start_date, maturity_date_unadj,...
                                   first_coupon_rate, mode_after_6y)
% COMPUTE_UPFRONT - Calculates the fair upfront payment for the structured bond.
%
% This function determines the decimal fraction X such that:
% X*N + PV(Party B Structured Coupons) = PV(Party A Floating Leg)

%
% INPUTS:
%   notional          - [Scalar] Notional amount (N).
%   spot_vols_matrix  - [Matrix] The stripped caplet spot volatility surface.
%   strike_grid       - [Vector] The strike levels corresponding to the vol matrix.
%   spot_vol_parameters - [Struct] Contains fwd rates, year fractions, and DFs.
%   dates_bootstrap   - [Vector] Dates from the calibrated discount curve.
%   discounts         - [Vector] Discount factors from the calibrated curve.
%   start_date        - [Scalar] Effective date of the swap (datenum).
%   maturity_date_unadj - [Scalar] Unadjusted maturity date (datenum).
%   first_coupon_rate - [Scalar] The fixed rate for the very first quarterly coupon.
%   mode_after_6y     - [String] 'cap' or 'digital' for the final sub-period logic.
%
% OUTPUT:
%   upfront           - [Scalar] The fair upfront X (decimal fraction of notional).

    % 1. Extract Grid Data
    fwd_libor  = spot_vol_parameters.fwd_libor(:);
    yf_caplets = spot_vol_parameters.yf_between_caplets(:);
    T_expiry   = spot_vol_parameters.T_expiry(:);
    df_caplets = spot_vol_parameters.df_caplets(:);
    
    if nargin < 10 || isempty(mode_after_6y)
        mode_after_6y = 'cap';
    end
    
    n_total_q = 40; % 10 Years * 4 quarters
    q_3y = 12;      % End of year 3
    q_6y = 24;      % End of year 6

    % 2. Volatility Surface Interpolation (Spline on Strike)
    % We need the specific spot volatility for the strike of each sub-period.
    % Since the market grid might not match our strikes exactly, we use splines.
    K1 = 0.0420;
    K2 = 0.0470;
    if strcmpi(mode_after_6y, 'cap')
        K3 = 0.0400; 
    else
        K3 = 0.0540;
    end

    M_use = n_total_q - 1; % We use 39 caplets (Q1 is fixed/deterministic)
    sigma_K1 = arrayfun(@(k) interp1(strike_grid, spot_vols_matrix(k,:), K1, 'spline'), (1:M_use)');
    sigma_K2 = arrayfun(@(k) interp1(strike_grid, spot_vols_matrix(k,:), K2, 'spline'), (1:M_use)');
    sigma_K3 = arrayfun(@(k) interp1(strike_grid, spot_vols_matrix(k,:), K3, 'spline'), (1:M_use)');

    % 3. PV of Party B Leg (Structured Coupons)
    
    % Q1: Fixed Coupon (No optionality, already determined)
    DC_ACT360 = 2;
    t1 = business_date_offset(start_date, 'month_offset', 3, 'convention', 'modified_following');
    df_t1   = get_discount_factor_by_zero_rates_linear_interp(start_date, t1, dates_bootstrap, discounts);
    yf_t0t1 = yearfrac(start_date, t1, DC_ACT360);
    pv_B = notional * yf_t0t1 * df_t1 * first_coupon_rate;

    % Q2 to Q40: Optionality-heavy coupons
    for k = 2:n_total_q
        i = k - 1; % Index for the stripping grid
        if k <= q_3y
            % Period 1: Strikes at 4.20%
            pv_coup = compute_price_coupon_up_to_3years( ...
                fwd_libor(i), sigma_K1(i), sigma_K1(i), ...
                df_caplets(i), T_expiry(i), yf_caplets(i));
        elseif k <= q_6y
            % Period 2: Strikes at 4.70%
            pv_coup = compute_price_coupon_3y_to_6y( ...
                fwd_libor(i), sigma_K2(i), sigma_K2(i), ...
                df_caplets(i), T_expiry(i), yf_caplets(i));
        else
            % Period 3: Strikes/Logic based on mode
            pv_coup = compute_price_coupon_after_6y( ...
                fwd_libor(i), sigma_K3(i), sigma_K3(i), ...
                df_caplets(i), T_expiry(i), yf_caplets(i), mode_after_6y);
        end
        pv_B = pv_B + notional * pv_coup;
    end

    % 4. PV of Party A Leg (Floating Euribor 3M + Spread)
    % PV = Notional * (Floating_Part + Spread_Part)
    BPV = BasisPointValueFloating(start_date, maturity_date_unadj, dates_bootstrap, discounts);
    maturity_date_adj = business_date_offset(maturity_date_unadj);
    
    % We determine the nedeed discount factors
    B_start    = get_discount_factor_by_zero_rates_linear_interp(dates_bootstrap(1), start_date, dates_bootstrap, discounts);
    B_maturity = get_discount_factor_by_zero_rates_linear_interp(dates_bootstrap(1), maturity_date_adj, dates_bootstrap, discounts);
    
    pv_A = notional * (B_start - B_maturity) + notional * 0.02 * BPV;

    % 5. Solve for Upfront X
    % NPV = 0  =>  X*N + PV_B = PV_A  =>  X = (PV_A - PV_B) / N
    upfront = (pv_A - pv_B) / notional;
end