function p = cap_increment_price(sigma_right, sigma_left, T_knots, T_to_interp, ...
                                 fwd, K, r, T, yf)
% CAP_INCREMENT_PRICE Calculates the sum of caplet prices within a single maturity segment 
% using linearly interpolated volatilities.
%
% INPUTS:
%   sigma_right - [Scalar] Unknown spot vol at the current pillar (to be solved).
%   sigma_left  - [Scalar] Known spot vol from the previous pillar.
%   T_knots     - [2 x 1 Vector] Time boundaries for the current time segment.
%   T_to_interp - [Vector] Expiry times for caplets inside this time segment.
%   fwd         - [Vector] Forward Libor rates for the caplets in the time segment.
%   K           - [Scalar] Strike price in decimal.
%   r           - [Vector] Risk-free continuous rates for discounting.
%   T           - [Vector] Time to reset dates in years (Act/365).
%   yf          - [Vector] Year fractions between caplets(Act/360).
%
% OUTPUT:
%   p           - [Scalar] Aggregate price of the caplet strip in this time segment.

    % Linear interpolation of volatilities between pillars.
    sigma_caplets = interp1(T_knots, [sigma_left; sigma_right], ...
                             T_to_interp, 'linear');
    
    % Price individual caplets and sum them weighted by year fractions.
    caplet_prices = blkprice(fwd, K, r, T, sigma_caplets);
    p = sum(yf .* caplet_prices);
end