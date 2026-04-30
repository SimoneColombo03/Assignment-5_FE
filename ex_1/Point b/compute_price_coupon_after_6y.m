function price_coupon = compute_price_coupon_after_6y( ...
        fwd_libor, spot_vol_caplet, spot_vol_digital, ...
        df_payment, T_expiry, yf_caplet, mode)
% COMPUTE_PRICE_COUPON_AFTER_6Y - Prices a coupon for the final bond period (>6Y).
%
% This function calculates the present value of a single coupon payment for 
% the period from year 6 until maturity. 
% MODES:
%   1. 'cap'     - Logic: "L + 1.10% capped at 5.10%"
%                  Replication: (Libor + Spread) - (Caplet at 4.00%).
%   2. 'digital' - Logic: "L + 1.30% if L <= 5.40%, else 5.60%"
%                  Replication: (Libor + Spread) - (Caplet at 5.40%) - (Digital Gap).
%
% INPUTS:
%   fwd_libor        - [Scalar] Forward Euribor 3M rate.
%   spot_vol_caplet  - [Scalar] Volatility for the standard caplet component.
%   spot_vol_digital - [Scalar] Volatility for the digital component (if mode='digital').
%   df_payment       - [Scalar] Discount factor at payment date.
%   T_expiry         - [Scalar] Time to expiry (Act/365).
%   yf_caplet        - [Scalar] Year fraction for accrual (Act/360).
%   mode             - [String] 'cap' or 'digital' to select the payoff logic.
%
% OUTPUT:
%   price_coupon     - [Scalar] Present value of the coupon per unit of notional.
% -------------------------------------------------------------------------

    % Set 'cap' as the default mode if not specified
    if nargin < 7 || isempty(mode)
        mode = 'cap';   
    end

    switch lower(mode)
        case 'cap'
            % Option A: Standard Capped Floater
            % K = Cap Level - Spread = 5.10% - 1.10% = 4.00%
            K_caplet = 0.0400;     
            spread   = 0.0110;

            % Standard Black-76 d1/d2 calculation
            d1 = ( log(fwd_libor / K_caplet) + 0.5 * spot_vol_caplet^2 * T_expiry ) ...
                 / ( spot_vol_caplet * sqrt(T_expiry) );
            d2 = d1 - spot_vol_caplet * sqrt(T_expiry);
            
            % Caplet Value
            caplet_value = fwd_libor * normcdf(d1) - K_caplet * normcdf(d2);
            
            % Price = DF * YF * (Fwd + Spread - Caplet)
            price_coupon = yf_caplet * df_payment * ( fwd_libor + spread - caplet_value );

        case 'digital'
            % Option B: Capped Floater with Digital Gap
            K_caplet  = 0.0540;
            K_digital = 0.0540;
            spread    = 0.0130;
            % Gap = (K + Spread) - Fixed_Cap = (5.40% + 1.30%) - 5.60% = 1.10%
            gap       = 0.0110;     

            % Caplet component d1/d2
            d1 = ( log(fwd_libor / K_caplet) + 0.5 * spot_vol_caplet^2 * T_expiry ) ...
                 / ( spot_vol_caplet * sqrt(T_expiry) );
            d2 = d1 - spot_vol_caplet * sqrt(T_expiry);
            caplet_value = fwd_libor * normcdf(d1) - K_caplet * normcdf(d2);

            % Digital component d2
            d2_dig = ( log(fwd_libor / K_digital) - 0.5 * spot_vol_digital^2 * T_expiry ) ...
                     / ( spot_vol_digital * sqrt(T_expiry) );
            digital_value = gap * normcdf(d2_dig);

            % Price = DF * YF * (Fwd + Spread - Caplet - Digital)
            price_coupon = yf_caplet * df_payment * ...
                           ( fwd_libor + spread - caplet_value - digital_value );

        otherwise
            error('Unknown mode "%s". Please use ''cap'' or ''digital''.', mode);
    end
end