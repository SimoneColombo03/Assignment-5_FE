function price_coupon = compute_price_coupon_after_6y_dig_risk( ...
        fwd_libor, spot_vol_caplet, df_payment, T_expiry, yf_caplet, ...
        mode, spot_vols_matrix, strike_grid, caplet_idx)
% COMPUTE_PRICE_COUPON_AFTER_6Y_DIG_RISK - Prices structured coupons from year 6 to maturity
% considering digital risk
%
% This function handles the final sub-period of the bond. Depending on the 'mode' 
% selected, it prices either a standard capped floater or a digital-jump payoff.
% For the digital mode, it applies Call Spread replication to address
% Digital Risk.

% PAYOFF LOGIC:
%   Mode 'cap':     L + 1.10% capped at 5.10%
%   Mode 'digital': L + 1.30% if L <= 5.40%, else 5.60%
%
% INPUTS:
%   fwd_libor        - [Scalar] The 3M Forward Euribor rate for the period
%   spot_vol_caplet  - [Scalar] Interpolated spot volatility at the relevant strike
%   df_payment       - [Scalar] Discount factor to the payment date
%   T_expiry         - [Scalar] Time to fixing (years, Act/365)
%   yf_caplet        - [Scalar] Accrual factor for the period (years, Act/360)
%   mode             - [String] 'cap' or 'digital' to select the payoff structure
%   spot_vols_matrix - [Matrix] The stripped caplet spot volatility surface
%   strike_grid      - [Vector] The grid of strikes from market data
%   caplet_idx       - [Scalar] Index of the caplet maturity in the volatility matrix
%
% OUTPUT:
%   price_coupon     - [Scalar] The net present value (NPV) of the structured coupon


    % Spread for Call Spread replication (1 basis point) to manage digital risk
    epsilon = 0.0001; 

    if strcmpi(mode, 'cap')
        % --- 1. Capped Floater Logic ---
        % Payoff: L + 1.10% capped at 5.10%
        % This is equivalent to: (L + 1.10%) - Max(L + 1.10% - 5.10%, 0)
        % Which simplifies to: (L + 1.10%) - Max(L - 4.00%, 0) -> Strike = 4.00%
        K_caplet = 0.0400; 
        spread   = 0.0110;
        
        % Black '76 for the Caplet component
        d1 = (log(fwd_libor/K_caplet) + 0.5*spot_vol_caplet^2*T_expiry) / (spot_vol_caplet*sqrt(T_expiry));
        d2 = d1 - spot_vol_caplet*sqrt(T_expiry);
        caplet_val = yf_caplet * df_payment * (fwd_libor*normcdf(d1) - K_caplet*normcdf(d2));
        
        % Final PV for Cap mode
        price_coupon = yf_caplet * df_payment * (fwd_libor + spread) - caplet_val;

    else
        % --- 2. Digital Payoff Logic (with Risk Correction) ---
        % Payoff: L + 1.30% if L <= 5.40%, else 5.60%
        K_caplet = 0.0540; % Digital threshold
        spread   = 0.0130; % Margin over Libor
        % Gap calculation: (5.40% + 1.30%) - 5.60% = 1.10%
        gap      = 0.0110; 
        
        % 2a. Vanilla Caplet component at 5.40%
        d1 = (log(fwd_libor/K_caplet) + 0.5*spot_vol_caplet^2*T_expiry) / (spot_vol_caplet*sqrt(T_expiry));
        d2 = d1 - spot_vol_caplet*sqrt(T_expiry);
        cap_val = yf_caplet * df_payment * (fwd_libor*normcdf(d1) - K_caplet*normcdf(d2));

        % 2b. Digital Risk Correction using Call Spread replication
        % This addresses the jump risk at 5.40% by interpolating across the volatility skew.
        digital_val = compute_digital_call_spread(fwd_libor, T_expiry, df_payment, yf_caplet, ...
                                                  K_caplet, epsilon, gap, ...
                                                  spot_vols_matrix, strike_grid, caplet_idx);

        % Final PV for Digital mode: PV(Libor + Spread) - PV(Caplet) - PV(Digital Correction)
        price_coupon = yf_caplet * df_payment * (fwd_libor + spread) - cap_val - digital_val;
    end

end