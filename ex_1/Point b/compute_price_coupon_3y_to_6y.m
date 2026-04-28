function price_coupon = compute_price_coupon_3y_to_6y( ...
        fwd_libor, spot_vol_caplet, spot_vol_digital, ...
        df_payment, T_expiry, yf_caplet)

% COMPUTE_PRICE_COUPON_3Y_TO_6Y  Present value (per unit notional) of a
% single coupon payment in the SECOND sub-period of the structured bond
% (after 3Y, up to and including 6Y).
%
%   Coupon payoff:
%       c =  L + 1.20%   if L <= 4.70%
%            4.90%       if L >  4.70%
%
%   Decomposition:
%       c = (L + 1.20%) - (L - 4.70%)^+ - 1.00% * 1{L > 4.70%}
%   where the gap is (4.70% + 1.20%) - 4.90% = 1.00%.
%
%   See compute_price_coupon_up_to_3years for the pricing logic.

    K_caplet  = 0.0470;
    K_digital = 0.0470;
    spread    = 0.0120;
    gap       = 0.0100;          % = 4.70% + 1.20% - 4.90%

    d1 = ( log(fwd_libor / K_caplet) + 0.5 * spot_vol_caplet.^2 .* T_expiry ) ...
         ./ ( spot_vol_caplet .* sqrt(T_expiry) );
    d2 = d1 - spot_vol_caplet .* sqrt(T_expiry);
    caplet_value = fwd_libor .* normcdf(d1) - K_caplet .* normcdf(d2);

    d2_dig = ( log(fwd_libor / K_digital) - 0.5 * spot_vol_digital.^2 .* T_expiry ) ...
             ./ ( spot_vol_digital .* sqrt(T_expiry) );
    digital_value = gap .* normcdf(d2_dig);

    price_coupon = yf_caplet .* df_payment .* ...
                   ( fwd_libor + spread - caplet_value - digital_value );
end