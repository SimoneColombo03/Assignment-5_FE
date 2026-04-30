function upfront = compute_upfront_dig_risk(notional, ...
                                   spot_vols_matrix, strike_grid, ...
                                   spot_vol_parameters,...
                                   dates_bootstrap, discounts, ...
                                   start_date, maturity_date_unadj,...
                                   first_coupon_rate, mode_after_6y)
% COMPUTE_UPFRONT - Calculates the fair upfront X% considering digital risk.
%
% This function prices the structured bond by calculating the present value (PV) 
% of both legs. Leg A is the floating leg (Euribor 3m + 2.00%), and Leg B is the 
% structured coupon leg[cite: 1]. The fair upfront is the difference between 
% Leg A and Leg B, expressed as a percentage of the notional.
%
% INPUTS:
%   notional            - [Scalar] Total principal amount (e.g., 50,000,000 EUR)[cite: 1].
%   spot_vols_matrix    - [Matrix] Stripped spot volatilities for each caplet and strike[cite: 1].
%   strike_grid         - [Vector] Grid of strikes corresponding to the vol matrix columns[cite: 1].
%   spot_vol_parameters - [Struct] Contains fwd_libor, yf_between_caplets, T_expiry, and df_caplets[cite: 1].
%   dates_bootstrap     - [Vector] Dates from the discount curve bootstrapping[cite: 1].
%   discounts           - [Vector] Discount factors from the bootstrapping[cite: 1].
%   start_date          - [Scalar] The issue/start date of the bond (18 Feb 2008)[cite: 1].
%   maturity_date_unadj - [Scalar] Unadjusted 10Y maturity date[cite: 1].
%   first_coupon_rate   - [Scalar] The fixed rate for the first quarter (4%)[cite: 1].
%   mode_after_6y       - [String] 'cap' or 'digital' for the final sub-period payoff[cite: 1].
%
% OUTPUT:
%   upfront             - [Scalar] The fair upfront X% (as a decimal)[cite: 1].
% -------------------------------------------------------------------------

    % --- 1. Parameter Extraction ---
    fwd_libor  = spot_vol_parameters.fwd_libor(:);
    yf_caplets = spot_vol_parameters.yf_between_caplets(:);
    T_expiry   = spot_vol_parameters.T_expiry(:);
    df_caplets = spot_vol_parameters.df_caplets(:);
    
    n_total_q = 40; % Total quarterly coupons over 10 years[cite: 1]
    q_3y = 12;      % Last coupon of the first 3-year period[cite: 1]
    q_6y = 24;      % Last coupon of the second 3-year period[cite: 1]

    % --- 2. Strike Volatility Interpolation ---
    % Use spline interpolation to get the spot vol at the specific contractual strikes[cite: 1].
    K1 = 0.0420; % Strike for <= 3y[cite: 1]
    K2 = 0.0470; % Strike for 3y < t <= 6y[cite: 1]
    
    % Select K3 based on the chosen mode for the last 4 years[cite: 1]
    if strcmpi(mode_after_6y, 'cap')
        K3 = 0.0400; 
    else
        K3 = 0.0540; 
    end

    M_use = n_total_q - 1; % Number of caplets needed (Q2 to Q40)
    sigma_K1 = arrayfun(@(k) interp1(strike_grid, spot_vols_matrix(k,:), K1, 'spline'), (1:M_use)');
    sigma_K2 = arrayfun(@(k) interp1(strike_grid, spot_vols_matrix(k,:), K2, 'spline'), (1:M_use)');
    sigma_K3 = arrayfun(@(k) interp1(strike_grid, spot_vols_matrix(k,:), K3, 'spline'), (1:M_use)');

    % --- 3. PV Calculation of Leg B (Structured) ---
    % Q1: Deterministic fixed coupon[cite: 1]
    t1 = business_date_offset(start_date, 'month_offset', 3, 'convention', 'modified_following');
    df_t1 = get_discount_factor_by_zero_rates_linear_interp(dates_bootstrap(1), t1, dates_bootstrap, discounts);
    yf_t1 = yearfrac(start_date, t1, 2); % Act/360[cite: 1]
    pv_B = notional * yf_t1 * df_t1 * first_coupon_rate;

    % Q2 to Q40: Optionality included (Caplets and Digitals)[cite: 1]
    for k = 2:n_total_q
        i = k - 1; % Index for caplet/vol arrays
        if k <= q_3y
            pv_coup = compute_price_coupon_up_to_3years_dig_risk(fwd_libor(i), sigma_K1(i), ...
                df_caplets(i), T_expiry(i), yf_caplets(i), spot_vols_matrix, strike_grid, i);
        elseif k <= q_6y
            pv_coup = compute_price_coupon_3y_to_6y_dig_risk(fwd_libor(i), sigma_K2(i), ...
                df_caplets(i), T_expiry(i), yf_caplets(i), spot_vols_matrix, strike_grid, i);
        else
            pv_coup = compute_price_coupon_after_6y_dig_risk(fwd_libor(i), sigma_K3(i), ...
                df_caplets(i), T_expiry(i), yf_caplets(i), mode_after_6y, spot_vols_matrix, strike_grid, i);
        end
        pv_B = pv_B + notional * pv_coup;
    end

    % --- 4. PV Calculation of Leg A (Floating: Euribor 3m + 2.00%) ---
    % PV(Floating Leg) = Notional * (Discount_Start - Discount_End) + Notional * Margin * BPV[cite: 1]
    BPV = BasisPointValueFloating(start_date, maturity_date_unadj, dates_bootstrap, discounts);
    B_start = get_discount_factor_by_zero_rates_linear_interp(dates_bootstrap(1), start_date, dates_bootstrap, discounts);
    
    % Adjusted maturity for the final payment
    maturity_adj = business_date_offset(maturity_date_unadj, 'day_offset', 0, 'convention', 'following');
    B_end = get_discount_factor_by_zero_rates_linear_interp(dates_bootstrap(1), maturity_adj, dates_bootstrap, discounts);
    
    pv_A = notional * (B_start - B_end) + notional * 0.02 * BPV;

    % --- 5. Solve for Upfront X ---
    % NPV = PV_A - (PV_B + X * Notional) = 0  =>  X = (PV_A - PV_B) / Notional
    upfront = (pv_A - pv_B) / notional;
end