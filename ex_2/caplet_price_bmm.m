function price = caplet_price_bmm(K, B_pay, B_reset, delta, T, v)

% CAPLET_PRICE_BMM  Caplet price under the Bond Market Model (BMM).
%
%   A caplet on the Libor L(T_i, T_{i+1}) with strike K is equivalent to
%   (1 + K*delta) put options on the forward ZCB B(0; T_i, T_{i+1}) with
%   strike B^* = 1/(1 + K*delta), since
%
%       (L - K)^+ = (1 + K*delta) / (delta * B_{i+1})  *  (B^* - B_{i+1})^+
%
%   Under the T_i-forward measure the forward bond B_{i+1}(t) is a
%   lognormal martingale with vol v, so the put can be priced by the
%   Black-on-bond formula:
%
%       Caplet = (1 + K*delta) * B(0,T_i) * [ B^* * Phi(-d2) - B_iplus1 * Phi(-d1) ]
%
%   where the discount B(0,T_i) corresponds to the put paying at T_i (the
%   reset date of the caplet), then the (1 + K*delta) scaling converts the
%   bond-payoff units back into Libor-payoff units.
%
%   INPUTS:
%   K       - caplet strike (decimal)
%   B_pay   - discount factor B(0, T_{i+1}) (payment date of the Libor coupon)
%   B_reset - discount factor B(0, T_i)     (reset/expiry date of the caplet)
%   delta   - Act/360 day-count fraction yf(T_i, T_{i+1})
%   T       - Act/365 year fraction yf(t_0, T_i)  -- volatility horizon
%   v       - BMM vol of the forward ZCB B(t; T_i, T_{i+1})
%
%   OUTPUT:
%   price   - caplet price per unit notional (NO N or delta factor outside)

    B_fwd  = B_pay / B_reset;       % forward bond B(0; T_i, T_{i+1})
    B_star = 1 / (1 + K * delta);

    sqrtT = sqrt(T);
    d1 = ( log(B_fwd / B_star) + 0.5 * v.^2 .* T ) ./ ( v .* sqrtT );
    d2 = d1 - v .* sqrtT;

    put_bond = B_star .* normcdf(-d2) - B_fwd .* normcdf(-d1);
    price    = (1 + K * delta) * B_reset * put_bond;
end