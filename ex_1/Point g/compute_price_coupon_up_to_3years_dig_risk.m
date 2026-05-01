function price_coupon = compute_price_coupon_up_to_3years_dig_risk( ...
        fwd_libor, spot_vol_caplet, df_payment, T_expiry, yf_caplet, ...
        spot_vols_matrix, strike_grid, caplet_idx)
% COMPUTE_PRICE_COUPON_UP_TO_3YEARS_DIG_RISK - Prices coupons for the first 3 years
% of the bond considering digital risk
%
% This function prices a floating rate coupon with an embedded cap and a digital 
% jump. It addresses the "Digital Risk" by using a Call Spread replication 
% instead of a pure Black digital formula to ensure numerical stability.
%
% PAYOFF LOGIC:
%   Coupon = Libor + 1.00% if Libor <= 4.20%
%   Coupon = 4.50%         if Libor >  4.20%
%
% INPUTS:
%   fwd_libor        - [Scalar] The 3M Forward Euribor rate for the period.
%   spot_vol_caplet  - [Scalar] The interpolated spot volatility for the 4.20% strike.
%   df_payment       - [Scalar] The discount factor from the payment date to today.
%   T_expiry         - [Scalar] Time to the fixing date (in years, Act/365).
%   yf_caplet        - [Scalar] Accrual factor for the coupon period (in years, Act/360).
%   spot_vols_matrix - [Matrix] The complete matrix of stripped spot volatilities.
%   strike_grid      - [Vector] The set of strikes corresponding to the vol matrix columns.
%   caplet_idx       - [Scalar] The index indicating which row of the vol matrix to use.
%
% OUTPUT:
%   price_coupon     - [Scalar] The present value (PV) of the structured coupon.

    % 1. Contractual Parameters
    K_caplet = 0.0420; % Strike level where the behavior changes (4.20%)
    spread   = 0.0100; % Margin over Libor (1.00%)
    gap      = 0.0070; % Gap between (K + spread) and the fixed cap: (4.2% + 1%) - 4.5% = 0.7%
    epsilon  = 0.0001; % 1 basis point (0.01%) used for Call Spread replication of the digital

    % 2. Vanilla Caplet Component (Black-76)
    % Calculation of the standard caplet at 4.20% to limit the Libor + spread payoff.
    d1 = (log(fwd_libor/K_caplet) + 0.5*spot_vol_caplet^2*T_expiry) / (spot_vol_caplet*sqrt(T_expiry));
    d2 = d1 - spot_vol_caplet*sqrt(T_expiry);
    caplet_val = yf_caplet * df_payment * (fwd_libor*normcdf(d1) - K_caplet*normcdf(d2));

    % 3. Digital Risk Correction (Call Spread Replication)
    % Replaces the pure digital formula to account for the jump at 4.20%.
    digital_val = compute_digital_call_spread(fwd_libor, T_expiry, df_payment, yf_caplet, ...
                                              K_caplet, epsilon, gap, ...
                                              spot_vols_matrix, strike_grid, caplet_idx);

    % 4. Total Present Value Calculation
    % NPV = PV(Floating Leg + Spread) - PV(Caplet) - PV(Digital Adjustment)
    price_coupon = yf_caplet * df_payment * (fwd_libor + spread) - caplet_val - digital_val;

end