function price_coupon = compute_price_coupon_up_to_3years( ...
        fwd_libor, spot_vol_caplet, spot_vol_digital, ...
        df_payment, T_expiry, yf_caplet)
% COMPUTE_PRICE_COUPON_UP_TO_3YEARS - Prices a coupon for the initial 3Y period.
%
% This function prices a floating rate coupon with an embedded cap and a "jump" 
% at the threshold. 
%
% PAYOFF LOGIC:
%   c = L + 1.00%  if L <= 4.20%
%   c = 4.50%      if L >  4.20%
%
% DECOMPOSITION FOR BLACK-76:
%   To price this, we view the coupon as a portfolio:
%   Coupon = (Forward Libor + 1.00%) - (Caplet at 4.20%) - (Digital Gap)
%   Where the "Gap" is the difference between (4.20% + 1.00%) and 4.50% = 0.70%.
%
% INPUTS:
%   fwd_libor        - [Scalar] The 3M Forward Euribor rate (decimal).
%   spot_vol_caplet  - [Scalar] Volatility used for the vanilla caplet.
%   spot_vol_digital - [Scalar] Volatility used for the digital component.
%   df_payment       - [Scalar] Discount factor to the payment date.
%   T_expiry         - [Scalar] Time from today to fixing date (Years, Act/365).
%   yf_caplet        - [Scalar] Accrual period for the coupon (Years, Act/360).
%
% OUTPUT:
%   price_coupon     - [Scalar] The current market value of the coupon.

    % 1. Contractual Parameters
    K_caplet  = 0.0420; % Threshold where the payoff changes behavior
    K_digital = 0.0420; % Strike for the binary/digital component
    spread    = 0.0100; % The 1.00% margin over Libor
    gap       = 0.0070; % Adjustment to ensure the payoff reaches exactly 4.50%
    
    % 2. Vanilla Caplet Component (Black-76)
    % Calculation of the d1/d2 parameters for the standard option pricing.
    d1 = ( log(fwd_libor / K_caplet) + 0.5 * spot_vol_caplet^2 * T_expiry ) ...
         / ( spot_vol_caplet * sqrt(T_expiry) );
    d2 = d1 - spot_vol_caplet * sqrt(T_expiry);
    
    % This represents the "cost" of capping the Libor at 4.20%.
    caplet_value = fwd_libor * normcdf(d1) - K_caplet * normcdf(d2);
    
    % 3. Digital Component
    % Prices the probability that Libor exceeds 4.20% multiplied by the gap.
    d2_dig = ( log(fwd_libor / K_digital) - 0.5 * spot_vol_digital^2 * T_expiry ) ...
             / ( spot_vol_digital * sqrt(T_expiry) );
    
    digital_value = gap * normcdf(d2_dig);
    
    % 4. Total Present Value
    % The value is the discounted expectation of the combined payoff:
    % NPV = Discount * Accrual * (Forward + Spread - Caplet_Cost - Digital_Cost)
    price_coupon = yf_caplet * df_payment * ...
                   ( fwd_libor + spread - caplet_value - digital_value );
end