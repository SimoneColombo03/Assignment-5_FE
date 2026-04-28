function price_coupon = compute_price_coupon_after_6y( ...
        fwd_libor, spot_vol_caplet, spot_vol_digital, ...
        df_payment, T_expiry, yf_caplet, mode)

% COMPUTE_PRICE_COUPON_AFTER_6Y  Present value (per unit notional) of a
% single coupon payment in the THIRD sub-period of the structured bond
% (after 6Y, up to maturity).
%
%   The annex of the assignment is ambiguous: two formulas appear in the
%   "After 6y" cell. Use 'mode' to choose the intended interpretation.
%   CHECK WITH BAVIERA / GROUP BEFORE USING IN PRODUCTION.
%
%   mode = 'cap'      -- "L + 1.10% capped at 5.10%"
%       Payoff:  c = min(L + 1.10%, 5.10%) = (L + 1.10%) - (L - 4.00%)^+
%       (No digital component, no digital risk.)
%
%   mode = 'digital'  -- "L + 1.30% if L <= 5.40%, else 5.60%"
%       Payoff:  c =  L + 1.30%   if L <= 5.40%
%                     5.60%       if L >  5.40%
%       Decomposition:
%           c = (L + 1.30%) - (L - 5.40%)^+ - 1.10% * 1{L > 5.40%}
%       where gap = 5.40% + 1.30% - 5.60% = 1.10%.
%
%   INPUTS / OUTPUT:  same convention as compute_price_coupon_up_to_3years.

    if nargin < 7 || isempty(mode)
        mode = 'cap';   % conservative default; change after clarification
    end

    switch lower(mode)

        case 'cap'
            K_caplet = 0.0400;     % 5.10% - 1.10%
            spread   = 0.0110;

            d1 = ( log(fwd_libor / K_caplet) + 0.5 * spot_vol_caplet.^2 .* T_expiry ) ...
                 ./ ( spot_vol_caplet .* sqrt(T_expiry) );
            d2 = d1 - spot_vol_caplet .* sqrt(T_expiry);
            caplet_value = fwd_libor .* normcdf(d1) - K_caplet .* normcdf(d2);

            price_coupon = yf_caplet .* df_payment .* ...
                           ( fwd_libor + spread - caplet_value );

        case 'digital'
            K_caplet  = 0.0540;
            K_digital = 0.0540;
            spread    = 0.0130;
            gap       = 0.0110;     % 5.40% + 1.30% - 5.60%

            d1 = ( log(fwd_libor / K_caplet) + 0.5 * spot_vol_caplet.^2 .* T_expiry ) ...
                 ./ ( spot_vol_caplet .* sqrt(T_expiry) );
            d2 = d1 - spot_vol_caplet .* sqrt(T_expiry);
            caplet_value = fwd_libor .* normcdf(d1) - K_caplet .* normcdf(d2);

            d2_dig = ( log(fwd_libor / K_digital) - 0.5 * spot_vol_digital.^2 .* T_expiry ) ...
                     ./ ( spot_vol_digital .* sqrt(T_expiry) );
            digital_value = gap .* normcdf(d2_dig);

            price_coupon = yf_caplet .* df_payment .* ...
                           ( fwd_libor + spread - caplet_value - digital_value );

        otherwise
            error('Unknown mode "%s". Use ''cap'' or ''digital''.', mode);
    end
end