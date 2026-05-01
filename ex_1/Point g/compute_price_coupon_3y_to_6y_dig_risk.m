function price_coupon = compute_price_coupon_3y_to_6y_dig_risk( ...
        fwd_libor, spot_vol_caplet, df_payment, T_expiry, yf_caplet, ...
        spot_vols_matrix, strike_grid, caplet_idx)
% COMPUTE_PRICE_COUPON_3Y_TO_6Y_DIG_RISK - Prices structured coupons for years 3 to 6
% considering digital risk.
%
% This function prices a floating rate coupon with a cap and a digital jump 
% specifically for the second sub-period of the bond. To manage "Digital Risk", 
% it replaces the standard Black digital formula with a Call Spread replication 
% to ensure a smooth Delta and consistency with the volatility skew.
%
% PAYOFF LOGIC:
%   Coupon = Libor + 1.20% if Libor <= 4.70%
%   Coupon = 4.90%         if Libor >  4.70%
%
% INPUTS:
%   fwd_libor        - [Scalar] The 3M Forward Euribor rate for the period
%   spot_vol_caplet  - [Scalar] Interpolated spot volatility at the 4.70% strike
%   df_payment       - [Scalar] Discount factor to the payment date
%   T_expiry         - [Scalar] Time to fixing (years, Act/365)
%   yf_caplet        - [Scalar] Accrual factor for the period (years, Act/360)
%   spot_vols_matrix - [Matrix] The stripped caplet spot volatility surface
%   strike_grid      - [Vector] The grid of strikes used in the stripping process
%   caplet_idx       - [Scalar] Index of the caplet maturity in the volatility grid
%
% OUTPUT:
%   price_coupon     - [Scalar] The net present value (NPV) of the structured coupon

    % --- 1. Contractual Parameters ---
    K_caplet = 0.0470; % Strike level for the second period (4.70%)
    spread   = 0.0120; % Margin over Libor (1.20%)
    gap      = 0.0100; % (4.70% + 1.20%) - 4.90% = 1.00%
    epsilon  = 0.0001; % 1bp spread for Call Spread replication

    % --- 2. Vanilla Caplet Component (Black '76) ---
    % Standard caplet at 4.70% strike to cap the (Libor + spread) part.
    d1 = (log(fwd_libor/K_caplet) + 0.5*spot_vol_caplet^2*T_expiry) / (spot_vol_caplet*sqrt(T_expiry));
    d2 = d1 - spot_vol_caplet*sqrt(T_expiry);
    caplet_val = yf_caplet * df_payment * (fwd_libor*normcdf(d1) - K_caplet*normcdf(d2));

    % --- 3. Digital Risk Correction (Call Spread Replication) ---
    % Replaces pure digital PV with a market-replicable Call Spread.
    digital_val = compute_digital_call_spread(fwd_libor, T_expiry, df_payment, yf_caplet, ...
                                              K_caplet, epsilon, gap, ...
                                              spot_vols_matrix, strike_grid, caplet_idx);

    % --- 4. Total Present Value Calculation ---
    % PV = PV(Libor + 1.20%) - PV(Caplet @ 4.70%) - PV(Digital Adjustment)
    price_coupon = yf_caplet * df_payment * (fwd_libor + spread) - caplet_val - digital_val;

end