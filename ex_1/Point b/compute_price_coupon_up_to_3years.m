function price_coupon = compute_price_coupon_up_to_3years( ...
        fwd_libor, spot_vol_caplet, spot_vol_digital, ...
        df_payment, T_expiry, yf_caplet)

% COMPUTE_PRICE_COUPON_UP_TO_3YEARS  Present value (per unit notional) of a
% single coupon payment in the FIRST sub-period of the structured bond
% (Trade date -> 3Y, included), with quarterly Euribor 3m fixings.
%
%   Coupon payoff (rate, expressed as a fraction of N*delta):
%       c =  L + 1.00%                 if L <= 4.20%
%            4.50%                     if L >  4.20%
%
%   Decomposition:
%       c = (L + 1.00%) - (L - 4.20%)^+ - 0.70% * 1{L > 4.20%}
%
%   Black '76 valuation:
%       PV = delta * B(t_0, t_pay) * [
%               F + 1.00%
%             - Caplet(F, K=4.20%, sigma_caplet, T_expiry)
%             - 0.70% * Phi(d_2(K=4.20%, sigma_digital, T_expiry))
%           ]
%
%   INPUTS:
%   fwd_libor        - forward Libor F = L(t_0; t_i, t_{i+1})  [decimal]
%   spot_vol_caplet  - Black vol for the caplet (at strike 4.20%)
%   spot_vol_digital - Black vol for the digital (at strike 4.20%);
%                      equals spot_vol_caplet for plain Black, may differ
%                      after the digital-risk correction (point g)
%   df_payment       - discount factor B(t_0, t_pay)
%   T_expiry         - time-to-fixing (Act/365)
%   yf_caplet        - day-count fraction delta of the period (Act/360)
%
%   OUTPUT:
%   price_coupon     - present value of the coupon per unit notional

    K_caplet  = 0.0420;
    K_digital = 0.0420;
    spread    = 0.0100;
    gap       = 0.0070;          % = (K_digital + spread) - 4.50% = 4.20% + 1% - 4.50%

    % --- Caplet at K = 4.20% (Black '76) -----------------------------------
    d1 = ( log(fwd_libor / K_caplet) + 0.5 * spot_vol_caplet.^2 .* T_expiry ) ...
         ./ ( spot_vol_caplet .* sqrt(T_expiry) );
    d2 = d1 - spot_vol_caplet .* sqrt(T_expiry);
    caplet_value = fwd_libor .* normcdf(d1) - K_caplet .* normcdf(d2);

    % --- Digital  1{L > K_digital}  (probability under T-fwd measure) ------
    d2_dig = ( log(fwd_libor / K_digital) - 0.5 * spot_vol_digital.^2 .* T_expiry ) ...
             ./ ( spot_vol_digital .* sqrt(T_expiry) );
    digital_value = gap .* normcdf(d2_dig);

    % --- Coupon present value (per unit notional) --------------------------
    price_coupon = yf_caplet .* df_payment .* ...
                   ( fwd_libor + spread - caplet_value - digital_value );
end