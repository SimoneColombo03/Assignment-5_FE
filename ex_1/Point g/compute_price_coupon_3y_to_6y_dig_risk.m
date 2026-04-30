function price_coupon = compute_price_coupon_3y_to_6y_dig_risk( ...
        fwd_libor, spot_vol_caplet, df_payment, T_expiry, yf_caplet, ...
        spot_vols_matrix, strike_grid, caplet_idx)
% COMPUTE_PRICE_COUPON_3Y_TO_6Y - Prices structured coupons for years 3 to 6.
%
% This function prices a floating rate coupon with a cap and a digital jump 
% specifically for the second sub-period of the bond. To manage "Digital Risk", 
% it replaces the standard Black digital formula with a Call Spread replication 
% to ensure a smooth Delta and consistency with the volatility skew[cite: 1].
%
% PAYOFF LOGIC:
%   Coupon = Libor + 1.20% if Libor <= 4.70%[cite: 1]
%   Coupon = 4.90%         if Libor >  4.70%[cite: 1]
%
% INPUTS:
%   fwd_libor        - [Scalar] The 3M Forward Euribor rate for the period[cite: 1].
%   spot_vol_caplet  - [Scalar] Interpolated spot volatility at the 4.70% strike[cite: 1].
%   df_payment       - [Scalar] Discount factor to the payment date[cite: 1].
%   T_expiry         - [Scalar] Time to fixing (years, Act/365)[cite: 1].
%   yf_caplet        - [Scalar] Accrual factor for the period (years, Act/360)[cite: 1].
%   spot_vols_matrix - [Matrix] The stripped caplet spot volatility surface[cite: 1].
%   strike_grid      - [Vector] The grid of strikes used in the stripping process[cite: 1].
%   caplet_idx       - [Scalar] Index of the caplet maturity in the volatility grid[cite: 1].
%
% OUTPUT:
%   price_coupon     - [Scalar] The present value (PV) of the structured coupon[cite: 1].

    % --- 1. Contractual Parameters ---
    K_caplet = 0.0470; % Strike level for the second period (4.70%)[cite: 1]
    spread   = 0.0120; % Margin over Libor (1.20%)[cite: 1]
    gap      = 0.0100; % (4.70% + 1.20%) - 4.90% = 1.00%[cite: 1]
    epsilon  = 0.0001; % 1bp spread for Call Spread replication[cite: 1]

    % --- 2. Vanilla Caplet Component (Black '76) ---
    % Standard caplet at 4.70% strike to cap the (Libor + spread) part.
    d1 = (log(fwd_libor/K_caplet) + 0.5*spot_vol_caplet^2*T_expiry) / (spot_vol_caplet*sqrt(T_expiry));
    d2 = d1 - spot_vol_caplet*sqrt(T_expiry);
    caplet_val = yf_caplet * df_payment * (fwd_libor*normcdf(d1) - K_caplet*normcdf(d2));

    % --- 3. Digital Risk Correction (Call Spread Replication) ---
    % Replaces pure digital PV with a market-replicable Call Spread[cite: 1].
    digital_val = compute_digital_call_spread(fwd_libor, T_expiry, df_payment, yf_caplet, ...
                                              K_caplet, epsilon, gap, ...
                                              spot_vols_matrix, strike_grid, caplet_idx);

    % --- 4. Total Present Value Calculation ---
    % PV = PV(Libor + 1.20%) - PV(Caplet @ 4.70%) - PV(Digital Adjustment)[cite: 1]
    price_coupon = yf_caplet * df_payment * (fwd_libor + spread) - caplet_val - digital_val;

end