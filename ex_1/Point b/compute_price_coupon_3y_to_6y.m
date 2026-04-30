function price_coupon = compute_price_coupon_3y_to_6y( ...
        fwd_libor, spot_vol_caplet, spot_vol_digital, ...
        df_payment, T_expiry, yf_caplet)
% COMPUTE_PRICE_COUPON_3Y_TO_6Y - Prices a coupon for the 3Y-6Y period.
%
% This function prices a "capped" floating rate coupon. The payoff behaves 
% like a standard Libor + Spread up to a certain threshold (4.70%), 
% after which it is capped at a fixed 4.90%.
%
% PAYOFF LOGIC:
%   c = L + 1.20%  if L <= 4.70%
%   c = 4.90%      if L >  4.70%
%
% DECOMPOSITION FOR PRICING:
% To price this using Black-76, we replicate the payoff as:
%   Coupon = (Floating Rate + Spread) - (Caplet at 4.70%) - (Digital Gap at 4.70%)
%   Where Gap = (K + Spread) - Cap_Level = (4.70% + 1.20%) - 4.90% = 1.00%.
%
% INPUTS:
%   fwd_libor        - [Scalar] Forward Euribor 3M rate for the period.
%   spot_vol_caplet  - [Scalar] Volatility for the standard caplet at strike K.
%   spot_vol_digital - [Scalar] Volatility for the digital option at strike K.
%   df_payment       - [Scalar] Discount factor at the payment date.
%   T_expiry         - [Scalar] Time to expiry in years (Act/365).
%   yf_caplet        - [Scalar] Accrual year fraction (Act/360).
%
% OUTPUT:
%   price_coupon     - [Scalar] Present value of the coupon per unit of notional.
% -------------------------------------------------------------------------

    % 1. Define Contract Parameters
    K_caplet  = 0.0470; % Strike level for the caplet
    K_digital = 0.0470; % Strike level for the digital option
    spread    = 0.0120; % Constant spread added to Libor
    gap       = 0.0100; % Adjustment to hit the 4.90% cap level
    
    % 2. Price the Standard Caplet (Black-76)
    % Calculation of d1 and d2 for the standard Black formula.
    d1 = ( log(fwd_libor / K_caplet) + 0.5 * spot_vol_caplet^2 * T_expiry ) ...
         / ( spot_vol_caplet * sqrt(T_expiry) );
    d2 = d1 - spot_vol_caplet * sqrt(T_expiry);
    
    % Caplet Value = [F*N(d1) - K*N(d2)]
    caplet_value = fwd_libor * normcdf(d1) - K_caplet * normcdf(d2);
    
    % 3. Price the Digital Option (Cash-or-Nothing)
    d2_dig = ( log(fwd_libor / K_digital) - 0.5 * spot_vol_digital^2 * T_expiry ) ...
             / ( spot_vol_digital * sqrt(T_expiry) );
    
    % Digital Value = Gap * N(d2)
    digital_value = gap * normcdf(d2_dig);
    
    % 4. Final Present Value
    % The total coupon price is the discounted expected value of the decomposed components.
    % Price = DF * YearFraction * (Fwd + Spread - Caplet - Digital)
    price_coupon = yf_caplet * df_payment * ...
                   ( fwd_libor + spread - caplet_value - digital_value );
end